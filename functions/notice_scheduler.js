/**
 * publishScheduledNotices — daily at 9 AM IST. Publishes notices scheduled for
 * that day, then sends their push and, if opted in, the WhatsApp broadcast
 * (charged to the owner's credit wallet like an immediate send).
 */

'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { _claimNotice, _broadcastNotice } = require('./whatsapp_notice')._shared;

const MAX_PER_RUN = 500;

function _pushBody(description) {
  const text = String(description || '').replace(/\s+/g, ' ').trim();
  return text.length > 120 ? `${text.slice(0, 120)}…` : text;
}

/** Push to every active member, mirroring the app's immediate-publish push. */
async function _sendPush(db, noticeId, notice) {
  const memberships = await db.collection('memberships')
    .where('libraryId', '==', notice.libraryId)
    .where('status', '==', 'active')
    .get();
  const userIds = [...new Set(memberships.docs.map((d) => d.data().userId).filter(Boolean))];
  if (!userIds.length) return;

  const tokens = [];
  for (let i = 0; i < userIds.length; i += 500) {
    const refs = userIds.slice(i, i + 500).map((id) => db.collection('fcm_tokens').doc(id));
    const docs = await db.getAll(...refs);
    for (const d of docs) if (d.exists && d.data().token) tokens.push(d.data().token);
  }
  if (!tokens.length) return;

  const data = {
    type: 'notice',
    notice_id: noticeId,
    library_id: notice.libraryId,
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  };
  const notification = { title: 'New Announcement', body: _pushBody(notice.description) };
  for (let i = 0; i < tokens.length; i += 500) {
    await admin.messaging().sendEach(tokens.slice(i, i + 500).map((token) => ({
      token,
      notification,
      data,
      android: { priority: 'high', notification: { sound: 'default', channelId: 'default' } },
      apns: { payload: { aps: { sound: 'default' } }, headers: { 'apns-priority': '10' } },
    })));
  }
}

/** Flips scheduled → published once; returns the notice data or null if already done. */
async function _publish(db, ref) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.data().status !== 'scheduled') return null;
    const now = admin.firestore.FieldValue.serverTimestamp();
    tx.update(ref, { status: 'published', publishedAt: now, updatedAt: now });
    return snap.data();
  });
}

exports.publishScheduledNotices = functions
  .runWith({ timeoutSeconds: 540, memory: '256MB' })
  .pubsub.schedule('0 9 * * *').timeZone('Asia/Kolkata')
  .onRun(async () => {
    const db = admin.firestore();
    const due = await db.collection('notices')
      .where('status', '==', 'scheduled')
      .where('scheduledFor', '<=', admin.firestore.Timestamp.now())
      .limit(MAX_PER_RUN)
      .get();

    for (const doc of due.docs) {
      try {
        const notice = await _publish(db, doc.ref);
        if (!notice) continue;
        console.log(`[notice-cron] published ${doc.id}`);

        if (notice.sendPushNotification !== false) {
          await _sendPush(db, doc.id, notice).catch((e) =>
            console.error(`[notice-cron] push failed ${doc.id}:`, e.message));
        }
        if (notice.sendWhatsApp === true) {
          const claimed = await _claimNotice(db, doc.ref);
          if (claimed) await _broadcastNotice(db, doc.id, claimed);
        }
      } catch (e) {
        console.error(`[notice-cron] ${doc.id} failed:`, e.message);
      }
    }
    return null;
  });
