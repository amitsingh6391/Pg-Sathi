/**
 * sendWhatsAppNotice — callable from Flutter after an owner publishes a notice.
 * Sends the `pg_announcement_notification` template to every active
 * resident of the PG, charging 1 WhatsApp credit per message.
 */

'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {
  _getCredentials, _sendTemplate, _normalisePhone, _studentName,
  WHATSAPP_CREDITS, FREE_WHATSAPP_CREDITS,
} = require('./whatsapp')._shared;

const TEMPLATE = 'pg_announcement_notification';
const MAX_NOTICE_CHARS = 700;
const BATCH_SIZE = 10;
const META_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
// Template has a required IMAGE header; used when no notice/library image exists.
const DEFAULT_HEADER_IMAGE = 'https://pg-sathi.web.app/icons/Icon-512.png';

// Meta rejects body params containing newlines, tabs or 4+ consecutive spaces.
function _templateText(raw, max) {
  const text = String(raw || '').replace(/\s+/g, ' ').trim();
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

/** Notice image (≤5 MB) → owner avatar → PG photo → app banner. */
function _headerImage(notice, lib, ownerAvatarUrl) {
  const attachment = (notice.attachments || [])
    .find((a) => a && a.fileType === 'image' && a.url
      && (a.fileSize || 0) <= META_IMAGE_MAX_BYTES);
  if (attachment) return attachment.url;
  if (ownerAvatarUrl) return ownerAvatarUrl;
  const photo = (lib.photos || []).find((u) => typeof u === 'string' && u);
  return photo || DEFAULT_HEADER_IMAGE;
}

/** Reserves up to `wanted` credits in one transaction; returns how many were granted. */
async function _reserveCredits(db, ownerId, wanted) {
  const ref = db.collection(WHATSAPP_CREDITS).doc(ownerId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const total = snap.exists ? (snap.data().totalCredits || 0) : FREE_WHATSAPP_CREDITS;
    const used = snap.exists ? (snap.data().usedCredits || 0) : 0;
    const granted = Math.max(0, Math.min(wanted, total - used));
    if (granted > 0) {
      tx.set(ref, {
        totalCredits: total,
        usedCredits: used + granted,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    return granted;
  });
}

async function _refundCredits(db, ownerId, count) {
  if (count <= 0) return;
  try {
    await db.collection(WHATSAPP_CREDITS).doc(ownerId).set(
      { usedCredits: admin.firestore.FieldValue.increment(-count) },
      { merge: true },
    );
  } catch (e) {
    console.error('[wa-notice] credit refund failed:', e.message);
  }
}

/** One recipient per phone number among the library's active memberships. */
async function _recipients(db, libraryId) {
  const snap = await db.collection('memberships')
    .where('libraryId', '==', libraryId)
    .where('status', '==', 'active')
    .get();
  const byPhone = new Map();
  for (const doc of snap.docs) {
    const m = doc.data();
    const to = _normalisePhone(m.phoneNumber);
    if (to && !byPhone.has(to)) byPhone.set(to, m);
  }
  return [...byPhone.entries()].map(([to, m]) => ({ to, m }));
}

/**
 * Marks the notice as sending so a retry, double tap or overlapping cron run
 * can never broadcast twice. Returns the notice data, or null if already claimed.
 */
async function _claimNotice(db, noticeRef, validate = () => {}) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(noticeRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Notice not found');
    }
    const n = snap.data();
    validate(n);
    if (n.whatsappStatus) return null;
    tx.update(noticeRef, { whatsappStatus: 'sending' });
    return n;
  });
}

/** Sends a claimed notice to all active members, charging 1 credit each. */
async function _broadcastNotice(db, noticeId, notice) {
  const noticeRef = db.collection('notices').doc(noticeId);
  const { phoneNumberId, accessToken } = await _getCredentials();
  if (!phoneNumberId || !accessToken) {
    await noticeRef.update({ whatsappStatus: admin.firestore.FieldValue.delete() });
    throw new functions.https.HttpsError('failed-precondition', 'WhatsApp not configured');
  }

  const [libSnap, ownerSnap, recipients] = await Promise.all([
    db.collection('libraries').doc(notice.libraryId).get(),
    db.collection('users').doc(notice.ownerId).get(),
    _recipients(db, notice.libraryId),
  ]);
  const lib = libSnap.exists ? libSnap.data() : {};
  const ownerAvatarUrl = ownerSnap.exists ? ownerSnap.data().avatarUrl : null;
  const libraryName = _templateText(lib.name || 'Your PG', 60);
  const contact = _templateText(lib.ownerPhone || 'the PG', 40);
  const noticeText = _templateText(notice.description, MAX_NOTICE_CHARS);
  const headerImage = _headerImage(notice, lib, ownerAvatarUrl);

  const granted = recipients.length
    ? await _reserveCredits(db, notice.ownerId, recipients.length)
    : 0;
  const toSend = recipients.slice(0, granted);
  const noCredit = recipients.length - granted;

  let sent = 0;
  let failed = 0;
  for (let i = 0; i < toSend.length; i += BATCH_SIZE) {
    const batch = toSend.slice(i, i + BATCH_SIZE);
    const results = await Promise.allSettled(batch.map(async ({ to, m }) => {
      const name = _templateText(await _studentName(db, m), 60);
      await _sendTemplate({
        phoneNumberId, accessToken, to,
        templateName: TEMPLATE,
        components: [
          {
            type: 'header',
            parameters: [{ type: 'image', image: { link: headerImage } }],
          },
          {
            type: 'body',
            parameters: [name, libraryName, noticeText, contact]
              .map((text) => ({ type: 'text', text })),
          },
        ],
      });
    }));
    for (const r of results) {
      if (r.status === 'fulfilled') {
        sent++;
      } else {
        failed++;
        console.error('[wa-notice] send failed:', r.reason?.response?.data?.error || r.reason?.message);
      }
    }
  }

  await _refundCredits(db, notice.ownerId, failed);
  await noticeRef.update({
    whatsappStatus: 'sent',
    whatsappSentCount: sent,
    whatsappFailedCount: failed,
    whatsappNoCreditCount: noCredit,
    whatsappSentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`[wa-notice] ${noticeId}: sent ${sent}, failed ${failed}, no-credit ${noCredit}`);
  return { total: recipients.length, sent, failed, noCredit };
}

exports.sendWhatsAppNotice = functions
  .runWith({ timeoutSeconds: 540, memory: '256MB' })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const noticeId = data && data.noticeId;
    if (!noticeId) {
      throw new functions.https.HttpsError('invalid-argument', 'noticeId is required');
    }

    const db = admin.firestore();
    const notice = await _claimNotice(db, db.collection('notices').doc(noticeId), (n) => {
      if (n.ownerId !== context.auth.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Not your notice');
      }
      if (n.status !== 'published') {
        throw new functions.https.HttpsError('failed-precondition', 'Notice is not published');
      }
    });
    if (!notice) {
      throw new functions.https.HttpsError('already-exists', 'Notice already sent on WhatsApp');
    }
    return _broadcastNotice(db, noticeId, notice);
  });

// Used by notice_scheduler.js; non-enumerable so index.js never deploys it.
Object.defineProperty(module.exports, '_shared', {
  enumerable: false,
  value: { _claimNotice, _broadcastNotice, _recipients },
});
