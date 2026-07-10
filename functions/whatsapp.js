/**
 * WhatsApp Automation — Meta Cloud API
 *
 * Exports:
 *  • sendWhatsAppExpiryReminders — scheduled cron (9 AM IST daily)
 *    Sends one reminder 1 day before expiry (max 1 per student ever)
 *  • sendWhatsAppInvoice — callable from Flutter
 *    Generates invoice PDF, uploads to Storage, sends via WhatsApp
 *
 * Credentials stored in Firebase Remote Config (never hardcoded):
 *   whatsapp_phone_number_id
 *   whatsapp_access_token
 */

'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

const WA_VERSION = 'v20.0';
const WA_BASE = `https://graph.facebook.com/${WA_VERSION}`;

// Reminder types — used as Firestore doc suffixes to avoid duplicate sends.
const REMINDER_1DAY = '1day';
const REMINDER_LOGS = 'whatsapp_auto_reminder_logs';
const INVOICE_STORAGE_PREFIX = 'whatsapp_invoices';

// ─── WhatsApp credits (wallet) ──────────────────────────────────────────────
// Each automated WhatsApp message consumes one credit from the owner's wallet.
// Owners get FREE_WHATSAPP_CREDITS for free, then buy more (mirrors free seats).
// When the balance hits zero, automated sends are skipped — manual sends, which
// pass { isManual: true }, are never charged or blocked.
const WHATSAPP_CREDITS = 'whatsapp_credits';
const FREE_WHATSAPP_CREDITS = 7;

// ─── Notice broadcasts (WhatsApp) ───────────────────────────────────────────
// Owners may broadcast up to MAX_NOTICE_WHATSAPP_PER_MONTH notices per calendar
// month per library, free of charge. Usage is tracked per library per month in
// the `whatsapp_notice_quota` subcollection (doc id = "YYYY-MM").
const NOTICE_QUOTA_SUBCOLLECTION = 'whatsapp_notice_quota';
const MAX_NOTICE_WHATSAPP_PER_MONTH = 5;
const NOTICE_TEMPLATE = 'notice';

// ─── Credentials ──────────────────────────────────────────────────────────────

/**
 * Reads WhatsApp credentials from Remote Config.
 * Returns null values when keys are missing so callers can fail gracefully.
 */
async function _getCredentials() {
  try {
    const tpl = await admin.remoteConfig().getTemplate();
    const p = tpl.parameters;
    return {
      phoneNumberId: p['whatsapp_phone_number_id']?.defaultValue?.value || null,
      accessToken: p['whatsapp_access_token']?.defaultValue?.value || null,
    };
  } catch (e) {
    console.error('[wa] Remote Config read failed:', e.message);
    return { phoneNumberId: null, accessToken: null };
  }
}

// ─── WhatsApp credit wallet ─────────────────────────────────────────────────

/**
 * Atomically reserves one WhatsApp credit for an owner.
 *
 * Wallet doc (`whatsapp_credits/{ownerId}`):
 *   { totalCredits, usedCredits }     availableCredits = total - used
 * A brand-new owner is seeded with FREE_WHATSAPP_CREDITS on first use.
 *
 * Returns true when a credit was reserved (caller may send), false when the
 * balance is exhausted (caller must skip the send). The deduction is done in a
 * transaction so concurrent sends can never overspend.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} ownerId
 * @returns {Promise<boolean>}
 */
/** Returns true when the owner has an active Pro subscription (unlimited WhatsApp). */
async function _ownerHasProSubscription(db, ownerId) {
  if (!ownerId) return false;
  try {
    const now = admin.firestore.Timestamp.now();
    const snap = await db.collection('subscriptions')
      .where('ownerId', '==', ownerId)
      .where('status', '==', 'active')
      .limit(5)
      .get();
    for (const doc of snap.docs) {
      const d = doc.data();
      // endDate stored as Timestamp or ISO string
      let endDate = d.endDate;
      if (endDate && typeof endDate.toDate === 'function') {
        endDate = endDate.toDate();
      } else if (typeof endDate === 'string') {
        endDate = new Date(endDate);
      }
      if (endDate && endDate > now.toDate()) return true;
    }
    return false;
  } catch (e) {
    console.error('[wa] Pro subscription check failed:', e.message);
    return false;
  }
}

async function _reserveCredit(db, ownerId) {
  if (!ownerId) return false; // cannot bill an unknown owner → block automated send
  const ref = db.collection(WHATSAPP_CREDITS).doc(ownerId);
  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const total = snap.exists
        ? (snap.data().totalCredits || 0)
        : FREE_WHATSAPP_CREDITS;
      const used = snap.exists ? (snap.data().usedCredits || 0) : 0;

      if (total - used <= 0) return false; // no balance left

      tx.set(
        ref,
        {
          totalCredits: total,
          usedCredits: used + 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return true;
    });
  } catch (e) {
    console.error('[wa] credit reserve failed:', e.message);
    return false; // fail closed — never send for free on error
  }
}

/**
 * Refunds one previously-reserved credit (used when the send itself fails so
 * the owner is not charged for an undelivered message).
 */
async function _refundCredit(db, ownerId) {
  if (!ownerId) return;
  const ref = db.collection(WHATSAPP_CREDITS).doc(ownerId);
  try {
    await ref.set(
      { usedCredits: admin.firestore.FieldValue.increment(-1) },
      { merge: true },
    );
  } catch (e) {
    console.error('[wa] credit refund failed:', e.message);
  }
}

/** Resolves the owning ownerId for a library, or null when unknown. */
async function _ownerIdForLibrary(db, libraryId) {
  if (!libraryId) return null;
  try {
    const snap = await db.collection('libraries').doc(libraryId).get();
    return snap.exists ? (snap.data().ownerId || null) : null;
  } catch (_) {
    return null;
  }
}

/** Returns whether an owner allows a specific automated WhatsApp send type. */
async function _autoWhatsAppSettingEnabledForOwner(db, ownerId, settingField) {
  if (!ownerId) return true;
  try {
    const snap = await db.collection('users').doc(ownerId).get();
    if (!snap.exists) return true;
    const data = snap.data();
    if (data[settingField] !== undefined) return data[settingField] !== false;
    return data.autoWhatsAppRemindersEnabled !== false;
  } catch (e) {
    console.error('[wa] owner automation setting read failed:', e.message);
    return true;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Normalises an Indian mobile number to E.164 without leading +.
 * e.g. "9876543210" → "919876543210"
 */
function _normalisePhone(raw) {
  if (!raw) return null;
  const p = String(raw).replace(/[\s\-\(\)\+]/g, '');
  if (p.startsWith('91') && p.length === 12) return p;
  if (p.length === 10) return `91${p}`;
  return null;
}

/** Current calendar month as "YYYY-MM" in IST (matches billing periods). */
function _currentMonthKey() {
  const now = new Date(Date.now() + 5.5 * 60 * 60 * 1000); // shift to IST
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

/** Reference to a library's notice-quota doc for the current month. */
function _noticeQuotaRef(db, libraryId) {
  return db
    .collection('libraries')
    .doc(libraryId)
    .collection(NOTICE_QUOTA_SUBCOLLECTION)
    .doc(_currentMonthKey());
}

/**
 * Atomically reserves one notice broadcast for the month. Returns true if the
 * library was under its monthly cap (and the count was incremented), false if
 * the cap is already reached.
 */
async function _reserveNoticeQuota(db, libraryId) {
  const ref = _noticeQuotaRef(db, libraryId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const used = snap.exists ? (snap.data().count || 0) : 0;
    if (used >= MAX_NOTICE_WHATSAPP_PER_MONTH) return false;
    tx.set(ref, {
      count: used + 1,
      month: _currentMonthKey(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
  });
}

/** Remaining free notice broadcasts for the library this month. */
async function _remainingNoticeQuota(db, libraryId) {
  try {
    const snap = await _noticeQuotaRef(db, libraryId).get();
    const used = snap.exists ? (snap.data().count || 0) : 0;
    return Math.max(0, MAX_NOTICE_WHATSAPP_PER_MONTH - used);
  } catch (_) {
    return 0;
  }
}

/** Rolls back a reserved notice slot when the broadcast reaches nobody. */
async function _releaseNoticeQuota(db, libraryId) {
  const ref = _noticeQuotaRef(db, libraryId);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const used = snap.exists ? (snap.data().count || 0) : 0;
      if (used <= 0) return;
      tx.set(ref, { count: used - 1 }, { merge: true });
    });
  } catch (_) { /* best-effort */ }
}

/** Formats a JS Date/ISO string to dd Mon yyyy (en-IN locale). */
function _fmtDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', {
    day: '2-digit', month: 'short', year: 'numeric',
  });
}

/** Converts stored enum-like values such as "monthly" to "Monthly". */
function _displayLabel(value, fallback = '—') {
  const text = String(value || '').trim();
  if (!text) return fallback;
  return text
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

/** Formats YYYY-MM as a friendly billing period, e.g. "June 2026". */
function _fmtBillingMonth(value) {
  const match = String(value || '').match(/^(\d{4})-(\d{2})$/);
  if (!match) return value || '—';
  const date = new Date(Number(match[1]), Number(match[2]) - 1, 1);
  return date.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });
}

/** Formats a numeric amount using Indian digit grouping. */
function _fmtAmount(value) {
  return Math.round(Number(value) || 0).toLocaleString('en-IN');
}

/** Returns up to two initials for the library monogram. */
function _initials(value) {
  const words = String(value || 'Library').trim().split(/\s+/).filter(Boolean);
  return words.slice(0, 2).map((word) => word[0].toUpperCase()).join('');
}

/** Downloads the optional library profile image without blocking PDF delivery. */
async function _fetchInvoiceLogo(url) {
  if (!url) return null;
  try {
    const parsedUrl = new URL(url);
    if (parsedUrl.protocol !== 'https:') return null;
    const response = await axios.get(url, {
      responseType: 'arraybuffer',
      timeout: 10000,
    });
    return Buffer.from(response.data);
  } catch (err) {
    console.error('[wa] Invoice logo download failed:', err.message);
    return null;
  }
}

/**
 * Old app versions accidentally send slotName as `plan`. Resolve the
 * authoritative membership plan from Firestore so the existing installed app
 * receives a correct PDF without requiring an app update.
 */
async function _resolveInvoicePlan(db, d) {
  if (!d.membershipId) return _displayLabel(d.plan, 'Monthly');

  try {
    const membership = await db.collection('memberships').doc(d.membershipId).get();
    if (membership.exists) {
      const membershipData = membership.data();
      if (!d.libraryId || membershipData.libraryId === d.libraryId) {
        return _displayLabel(membershipData.plan, 'Monthly');
      }
    }
  } catch (err) {
    console.error('[wa] Membership plan lookup failed:', err.message);
  }

  return _displayLabel(d.plan, 'Monthly');
}

/**
 * Fills fields omitted by older app versions so backend-only deployments still
 * produce the same receipt as the in-app invoice.
 */
async function _hydrateInvoiceDetails(db, d) {
  d.plan = await _resolveInvoicePlan(db, d);

  if (d.membershipId && !(Number(d.discountAmount) > 0)) {
    try {
      const membership = await db.collection('memberships').doc(d.membershipId).get();
      const breakdown = membership.exists ? membership.data().paymentBreakdown : null;
      d.discountAmount = Number(breakdown?.discount) || 0;
    } catch (err) {
      console.error('[wa] Invoice discount lookup failed:', err.message);
    }
  }

  let ownerId = d.ownerId || null;
  if (!ownerId && d.libraryId) {
    ownerId = await _ownerIdForLibrary(db, d.libraryId);
  }
  if (ownerId && !d.libraryLogoUrl) {
    try {
      const owner = await db.collection('users').doc(ownerId).get();
      if (owner.exists) d.libraryLogoUrl = owner.data().avatarUrl || '';
    } catch (err) {
      console.error('[wa] Invoice profile image lookup failed:', err.message);
    }
  }
}

// ─── Core WhatsApp API ────────────────────────────────────────────────────────

/**
 * Sends a WhatsApp template message via Meta Cloud API.
 *
 * @param {object} opts
 * @param {string} opts.phoneNumberId
 * @param {string} opts.accessToken
 * @param {string} opts.to           – E.164 without leading + (e.g. "919876543210")
 * @param {string} opts.templateName – approved template name
 * @param {Array}  opts.components   – body / header / button components
 */
async function _sendTemplate({ phoneNumberId, accessToken, to, templateName, components }) {
  const { data } = await axios.post(
    `${WA_BASE}/${phoneNumberId}/messages`,
    {
      messaging_product: 'whatsapp',
      to,
      type: 'template',
      template: {
        name: templateName,
        language: { code: 'en' },
        components,
      },
    },
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      timeout: 15000,
    },
  );
  return data;
}

// ─── PDF Generation ───────────────────────────────────────────────────────────

/**
 * Generates an invoice PDF in-memory using pdfkit,
 * uploads it to Firebase Storage, and returns a 7-day signed URL.
 *
 * @param {object} d – invoice data (matches Invoice entity fields from Flutter)
 * @returns {Promise<{url: string, fileName: string}>}
 */
async function _generateAndUploadInvoicePdf(d) {
  const PDFDocument = require('pdfkit');
  const logo = await _fetchInvoiceLogo(d.libraryLogoUrl);

  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ size: 'A4', margin: 40 });
      const chunks = [];
      doc.on('data', (c) => chunks.push(c));
      doc.on('error', reject);
      doc.on('end', async () => {
        try {
          const buf = Buffer.concat(chunks);
          const bucket = admin.storage().bucket();
          const fileName = `${INVOICE_STORAGE_PREFIX}/${d.membershipId}_${Date.now()}.pdf`;
          const file = bucket.file(fileName);
          await file.save(buf, { metadata: { contentType: 'application/pdf' } });
          const [url] = await file.getSignedUrl({
            action: 'read',
            expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
          });
          resolve({ url, fileName });
        } catch (err) { reject(err); }
      });

      _drawInvoicePdf(doc, d, logo);
      doc.end();
    } catch (err) { reject(err); }
  });
}

/**
 * Draws all invoice content onto the pdfkit Document.
 * Extracted to keep _generateAndUploadInvoicePdf clean.
 */
function _drawInvoicePdf(doc, d, logo) {
  const PAGE_W = doc.page.width;
  const M = 42;
  const W = PAGE_W - (M * 2);
  const NAVY = '#102A43';
  const NAVY_SOFT = '#243B53';
  const GOLD = '#D5A64A';
  const INK = '#172B4D';
  const MUTED = '#6B7C93';
  const LINE = '#E6EBF1';
  const PAPER = '#F7F9FC';
  const GREEN = '#087F5B';
  const GREEN_BG = '#E8F7F1';

  // Premium letterhead.
  doc.rect(0, 0, PAGE_W, 148).fill(NAVY);
  doc.rect(0, 144, PAGE_W, 4).fill(GOLD);

  if (logo) {
    doc.save();
    doc.circle(M + 28, 48, 25).clip();
    doc.image(logo, M + 3, 23, { width: 50, height: 50 });
    doc.restore();
    doc.circle(M + 28, 48, 25).lineWidth(1).strokeColor(GOLD).stroke();
  } else {
    doc.circle(M + 28, 48, 25).fill(GOLD);
    doc.fillColor(NAVY).font('Helvetica-Bold').fontSize(16)
      .text(_initials(d.libraryName), M + 8, 39, {
        width: 40, align: 'center',
      });
  }

  doc.fillColor('white').font('Helvetica-Bold').fontSize(22)
    .text(d.libraryName || 'Library', M + 68, 27, {
      // Helvetica-Bold at 22px needs slightly more than 50px for two lines.
      // A 49px box made PDFKit truncate on line one.
      width: W - 210, height: 58, ellipsis: '...', lineGap: 1,
    });
  doc.fillColor('#C9D5E3').font('Helvetica').fontSize(9)
    .text(d.libraryAddress || '', M + 68, 88, {
      width: W - 210, height: 25, ellipsis: true,
    });

  doc.fillColor('#AFC1D4').font('Helvetica-Bold').fontSize(8)
    .text('PAYMENT RECEIPT', PAGE_W - M - 145, 28, {
      width: 145, align: 'right', characterSpacing: 1.4,
    });
  doc.fillColor('white').font('Helvetica-Bold').fontSize(12)
    .text(d.invoiceNumber ||
      `INV-${(d.membershipId || '').slice(-6).toUpperCase()}`,
    PAGE_W - M - 175, 46, { width: 175, align: 'right' });

  doc.fillColor('#AFC1D4').font('Helvetica').fontSize(8)
    .text('ISSUED ON', PAGE_W - M - 145, 72, {
      width: 145, align: 'right', characterSpacing: 1,
    });
  doc.fillColor('white').font('Helvetica-Bold').fontSize(10)
    .text(_fmtDate(d.paymentDate), PAGE_W - M - 145, 86, {
      width: 145, align: 'right',
    });

  // Receipt intro and paid status.
  let y = 174;
  doc.fillColor(MUTED).font('Helvetica-Bold').fontSize(8)
    .text('RECEIPT FOR', M, y, { characterSpacing: 1.3 });
  doc.fillColor(INK).font('Helvetica-Bold').fontSize(18)
    .text(d.studentName || 'Student', M, y + 16, {
      width: W - 130, ellipsis: true,
    });
  doc.fillColor(MUTED).font('Helvetica').fontSize(9)
    .text(d.studentPhone || '', M, y + 42);

  doc.roundedRect(PAGE_W - M - 92, y + 5, 92, 30, 15).fill(GREEN_BG);
  doc.circle(PAGE_W - M - 74, y + 20, 4).fill(GREEN);
  doc.fillColor(GREEN).font('Helvetica-Bold').fontSize(9)
    .text('PAID', PAGE_W - M - 62, y + 14, { width: 48 });

  // Large amount card.
  y += 76;
  const hasDiscount = Number(d.discountAmount) > 0;
  const amountCardHeight = hasDiscount ? 122 : 104;
  doc.roundedRect(M, y, W, amountCardHeight, 10).fill(PAPER);
  doc.rect(M, y, 5, amountCardHeight).fill(GOLD);
  doc.fillColor(MUTED).font('Helvetica-Bold').fontSize(8)
    .text('TOTAL AMOUNT PAID', M + 25, y + 20, { characterSpacing: 1.2 });
  doc.fillColor(NAVY).font('Helvetica-Bold').fontSize(29)
    .text(`Rs. ${_fmtAmount(d.amountPaid)}`, M + 25, y + 39, {
      width: 240,
    });
  if (hasDiscount) {
    doc.fillColor(GREEN).font('Helvetica-Bold').fontSize(10)
      .text(`Discount: -Rs. ${_fmtAmount(d.discountAmount)}`,
        M + 25, y + 79, { width: 240 });
  }

  doc.fillColor(MUTED).font('Helvetica-Bold').fontSize(8)
    .text('BILLING PERIOD', M + 325, y + 20, { characterSpacing: 1.1 });
  doc.fillColor(INK).font('Helvetica-Bold').fontSize(12)
    .text(_fmtBillingMonth(d.billingMonth), M + 325, y + 38, {
      width: W - 350,
    });
  doc.fillColor(MUTED).font('Helvetica-Bold').fontSize(8)
    .text('PAYMENT ID', M + 325, y + 62, { characterSpacing: 1.1 });
  doc.fillColor(INK).font('Helvetica').fontSize(9)
    .text(d.paymentId || '—', M + 325, y + 77, {
      width: W - 350, ellipsis: true,
    });

  // Membership details.
  y += amountCardHeight + 31;
  doc.fillColor(NAVY).font('Helvetica-Bold').fontSize(10)
    .text('MEMBERSHIP DETAILS', M, y, { characterSpacing: 1.2 });
  doc.moveTo(M, y + 19).lineTo(M + W, y + 19)
    .strokeColor(LINE).lineWidth(1).stroke();

  const detail = (label, value, x, detailY, width) => {
    doc.fillColor(MUTED).font('Helvetica-Bold').fontSize(8)
      .text(label.toUpperCase(), x, detailY, {
        width, characterSpacing: 0.8,
      });
    doc.fillColor(INK).font('Helvetica-Bold').fontSize(11)
      .text(value || '—', x, detailY + 15, {
        width, ellipsis: true,
      });
  };

  const colW = (W - 40) / 3;
  let detailY = y + 38;
  detail('Seat', d.seatNumber || '—', M, detailY, colW);
  detail('Slot', _displayLabel(d.slotName), M + colW + 20, detailY, colW);
  detail('Plan', _displayLabel(d.plan), M + (colW + 20) * 2, detailY, colW);

  detailY += 62;
  detail('Session timing', d.sessionTiming || '—', M, detailY, colW * 2 + 20);
  detail('Valid until', _fmtDate(d.expiryDate),
    M + (colW + 20) * 2, detailY, colW);

  // Contact card.
  y = detailY + 78;
  doc.roundedRect(M, y, W, 72, 8).fill(NAVY_SOFT);
  doc.fillColor('#AFC1D4').font('Helvetica-Bold').fontSize(8)
    .text('LIBRARY CONTACT', M + 20, y + 17, { characterSpacing: 1.1 });
  doc.fillColor('white').font('Helvetica-Bold').fontSize(11)
    .text(d.ownerName || 'Library Manager', M + 20, y + 34, {
      width: W / 2 - 20, ellipsis: true,
    });
  doc.fillColor('#D8E2EC').font('Helvetica').fontSize(10)
    .text(d.ownerContact || 'Contact library', M + W / 2, y + 34, {
      width: W / 2 - 20, align: 'right',
    });

  // Footer.
  y += 101;
  doc.moveTo(M, y).lineTo(M + W, y).strokeColor(LINE).lineWidth(1).stroke();
  doc.fillColor(MUTED).font('Helvetica-Bold').fontSize(8)
    .text('Thank you for choosing us.', M, y + 18, {
      width: W, align: 'center',
    });
  doc.fillColor('#98A6B7').font('Helvetica').fontSize(7.5)
    .text('Fees once paid are non-refundable. This computer-generated receipt ' +
      'does not require a signature.',
    M, y + 34, { width: W, align: 'center' });
}

// ─── Reminder log helpers ─────────────────────────────────────────────────────

/** Returns true if this reminder type was already sent for this membership. */
async function _alreadySent(db, membershipId, type) {
  const ref = db.collection(REMINDER_LOGS).doc(`${membershipId}_${type}`);
  const snap = await ref.get();
  return snap.exists;
}

/** Writes a reminder log so the same type is never sent again. */
async function _logSent(db, membershipId, type, libraryId) {
  await db.collection(REMINDER_LOGS).doc(`${membershipId}_${type}`).set({
    membershipId,
    libraryId,
    type,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ─── Scheduled: daily expiry reminders ───────────────────────────────────────

/**
 * Runs at 9 AM IST every day.
 * Sends at most 1 WhatsApp reminder per membership:
 *   • one when 1 day remains  (type = '1day')
 *
 * Uses `whatsapp_auto_reminder_logs` collection to enforce the 1-reminder cap.
 * Template: membership_expiry_reminder (7 body params)
 */
exports.sendWhatsAppExpiryReminders = functions
  .runWith({ timeoutSeconds: 300, memory: '512MB' })
  .pubsub.schedule('0 9 * * *').timeZone('Asia/Kolkata')
  .onRun(async () => {
    const db = admin.firestore();
    const { phoneNumberId, accessToken } = await _getCredentials();

    if (!phoneNumberId || !accessToken) {
      console.error('[wa] Missing credentials — add to Remote Config and retry');
      return null;
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let sent = 0, failed = 0, skipped = 0;

    for (const { daysAhead, type } of [
      { daysAhead: 1, type: REMINDER_1DAY },
    ]) {
      const windowStart = new Date(today);
      windowStart.setDate(today.getDate() + daysAhead);
      const windowEnd = new Date(windowStart.getTime() + 86_400_000);

      const snap = await db.collection('memberships')
        .where('status', '==', 'active')
        .where('endDate', '>=', admin.firestore.Timestamp.fromDate(windowStart))
        .where('endDate', '<', admin.firestore.Timestamp.fromDate(windowEnd))
        .get();

      if (snap.empty) {
        console.log(`[wa] No memberships expiring in ${daysAhead} day(s)`);
        continue;
      }

      console.log(`[wa] ${snap.size} membership(s) expiring in ${daysAhead} day(s)`);

      for (const doc of snap.docs) {
        const m = doc.data();
        const phone = m.phoneNumber;
        if (!phone) { skipped++; continue; }

        // Enforce max-2 cap
        if (await _alreadySent(db, doc.id, type)) { skipped++; continue; }

        const to = _normalisePhone(phone);
        if (!to) { skipped++; continue; }

        // Fetch library name + owner phone + ownerId (for credit billing)
        let libraryName = 'Your Library';
        let ownerPhone = 'Contact library';
        let ownerId = null;
        let seatNumber = m.assignedSeatId || 'N/A';

        try {
          const libSnap = await db.collection('libraries').doc(m.libraryId).get();
          if (libSnap.exists) {
            libraryName = libSnap.data().name || libraryName;
            ownerPhone = libSnap.data().ownerPhone || ownerPhone;
            ownerId = libSnap.data().ownerId || null;
          }
          if (m.assignedSeatId) {
            const seatSnap = await db.collection('libraries').doc(m.libraryId)
              .collection('seats').doc(m.assignedSeatId).get();
            if (seatSnap.exists) seatNumber = seatSnap.data().seatNumber || seatNumber;
          }
        } catch (_) { /* non-critical */ }

        if (!(await _autoWhatsAppSettingEnabledForOwner(
          db,
          ownerId,
          'autoWhatsAppFeeRemindersEnabled',
        ))) {
          skipped++;
          console.log(`[wa] ⊘ ${type} reminder skipped — fee reminders disabled (owner ${ownerId})`);
          continue;
        }

        // Automated reminder — Pro owners send for free; others use credit wallet.
        const isPro = await _ownerHasProSubscription(db, ownerId);
        let creditReserved = false;
        if (!isPro) {
          const hasCredit = await _reserveCredit(db, ownerId);
          if (!hasCredit) {
            skipped++;
            console.log(`[wa] ⊘ ${type} reminder skipped — no credits (owner ${ownerId})`);
            continue;
          }
          creditReserved = true;
        }

        const expiryDate = m.endDate.toDate();
        const planLabel = (m.plan || 'monthly');
        const planCap = planLabel.charAt(0).toUpperCase() + planLabel.slice(1);
        const studentName = m.studentName || 'Student';
        const formattedDate = expiryDate.toLocaleDateString('en-IN',
          { day: '2-digit', month: '2-digit', year: 'numeric' });

        try {
          await _sendTemplate({
            phoneNumberId, accessToken, to,
            templateName: 'membership_expiry_reminder',
            components: [{
              type: 'body',
              parameters: [
                { type: 'text', text: studentName },
                { type: 'text', text: libraryName },
                { type: 'text', text: formattedDate },
                { type: 'text', text: String(daysAhead) },
                { type: 'text', text: seatNumber },
                { type: 'text', text: planCap },
                { type: 'text', text: ownerPhone },
              ],
            }],
          });

          await _logSent(db, doc.id, type, m.libraryId);
          sent++;
          console.log(`[wa] ✓ ${type} reminder → ${studentName} (${phone})`);
        } catch (err) {
          failed++;
          if (creditReserved) await _refundCredit(db, ownerId); // send failed → don't charge
          console.error(`[wa] ✗ ${type} reminder → ${phone}:`,
            err.response?.data?.error?.message || err.message);
        }
      }
    }

    console.log(`[wa] Done — sent:${sent} failed:${failed} skipped:${skipped}`);
    return { sent, failed, skipped };
  });

// ─── Callable: send invoice PDF via WhatsApp ──────────────────────────────────

/**
 * Called from Flutter after payment approval + invoice generation.
 * Generates the invoice PDF server-side, uploads to Storage,
 * and sends it via WhatsApp using the membership_invoice template.
 *
 * Required payload fields (match Invoice entity in Flutter):
 *   studentPhone, studentName, membershipId, libraryName, libraryAddress,
 *   ownerName, ownerContact, seatNumber, slotName, sessionTiming,
 *   plan, amountPaid, invoiceNumber, paymentId, paymentDate,
 *   expiryDate, billingMonth
 */
exports.sendWhatsAppInvoice = functions
  .runWith({ timeoutSeconds: 120, memory: '512MB' })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      console.warn('[wa] sendWhatsAppInvoice called without auth context — proceeding with payload validation');
    }

    const { phoneNumberId, accessToken } = await _getCredentials();
    if (!phoneNumberId || !accessToken) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'WhatsApp not configured — add credentials to Remote Config',
      );
    }

    const d = data || {};
    if (!d.studentPhone || !d.membershipId) {
      throw new functions.https.HttpsError(
        'invalid-argument', 'studentPhone and membershipId are required',
      );
    }

    const to = _normalisePhone(d.studentPhone);
    if (!to) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid phone number format');
    }

    // Recover fields omitted by older installed app versions.
    await _hydrateInvoiceDetails(admin.firestore(), d);

    // Credit billing: automated invoices are charged to the owner's wallet.
    // Manual sends (d.isManual === true) are always free and never blocked.
    // ownerId is taken from the payload when present, else resolved via library.
    const isManual = d.isManual === true;
    let ownerId = d.ownerId || null;
    if (!isManual && !ownerId && d.libraryId) {
      ownerId = await _ownerIdForLibrary(admin.firestore(), d.libraryId);
    }
    if (!isManual && !(await _autoWhatsAppSettingEnabledForOwner(
      admin.firestore(),
      ownerId,
      'autoWhatsAppInvoicesEnabled',
    ))) {
      console.log(`[wa] ⊘ invoice skipped — auto invoices disabled (owner ${ownerId})`);
      return { success: false, skipped: true, reason: 'automation-disabled' };
    }
    let creditReserved = false;
    if (!isManual) {
      const isPro = await _ownerHasProSubscription(admin.firestore(), ownerId);
      if (!isPro) {
        const hasCredit = await _reserveCredit(admin.firestore(), ownerId);
        if (!hasCredit) {
          throw new functions.https.HttpsError(
            'resource-exhausted',
            'No WhatsApp credits left. Please buy more credits to send invoices.',
          );
        }
        creditReserved = true;
      } else {
        console.log(`[wa] Pro owner ${ownerId} — skipping credit deduction`);
      }
    }

    // Generate PDF → upload to Storage → get signed URL
    let pdfUrl;
    let fileName;
    try {
      const result = await _generateAndUploadInvoicePdf(d);
      pdfUrl = result.url;
      fileName = result.fileName;
      console.log(`[wa] Invoice PDF uploaded: ${fileName}`);
    } catch (err) {
      if (creditReserved) await _refundCredit(admin.firestore(), ownerId);
      console.error('[wa] PDF generation failed:', err.message);
      throw new functions.https.HttpsError('internal', `PDF generation failed: ${err.message}`);
    }

    // Send WhatsApp template with document header
    try {
      await _sendTemplate({
        phoneNumberId, accessToken, to,
        templateName: 'membership_invoice',
        components: [
          {
            type: 'header',
            parameters: [{
              type: 'document',
              document: {
                link: pdfUrl,
                filename: `Invoice_${d.billingMonth || 'receipt'}.pdf`,
              },
            }],
          },
          {
            type: 'body',
            parameters: [
              { type: 'text', text: d.studentName || 'Student' },
              { type: 'text', text: d.libraryName || 'Library' },
              { type: 'text', text: String(Math.round(d.amountPaid || 0)) },
              { type: 'text', text: d.seatNumber || 'N/A' },
              { type: 'text', text: d.plan || 'Monthly' },
              { type: 'text', text: _fmtDate(d.expiryDate) },
              { type: 'text', text: d.ownerContact || 'Contact library' },
            ],
          },
        ],
      });

      console.log(`[wa] ✓ Invoice sent → ${d.studentName} (${d.studentPhone})`);
      return { success: true, message: 'Invoice sent via WhatsApp' };
    } catch (err) {
      const metaError = err.response?.data?.error;
      const metaMessage = metaError?.message || err.message;
      const metaCode = metaError?.code ? ` code ${metaError.code}` : '';
      const metaSubcode = metaError?.error_subcode
        ? ` subcode ${metaError.error_subcode}`
        : '';
      if (creditReserved) await _refundCredit(admin.firestore(), ownerId);
      console.error('[wa] Invoice send failed:', metaError || err.message);
      throw new functions.https.HttpsError(
        'internal', `WhatsApp send failed${metaCode}${metaSubcode}: ${metaMessage}`,
      );
    }
  });

// ─── Notice broadcast (callable) ────────────────────────────────────────────

/**
 * Broadcasts a published notice to a library's active tenants over WhatsApp
 * using the approved `notice` template.
 *
 * Enforces a free monthly cap of MAX_NOTICE_WHATSAPP_PER_MONTH per library,
 * counted server-side so it cannot be bypassed by the client.
 *
 * Payload: { libraryId, noticeId, libraryName, title, description }
 * Returns: { success, sent, failed, remaining } or { skipped, reason, remaining }.
 */
exports.sendWhatsAppNotice = functions
  .runWith({ timeoutSeconds: 300, memory: '256MB' })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      console.warn('[wa] sendWhatsAppNotice called without auth context');
    }

    const d = data || {};
    if (!d.libraryId || !d.title) {
      throw new functions.https.HttpsError(
        'invalid-argument', 'libraryId and title are required',
      );
    }

    const { phoneNumberId, accessToken } = await _getCredentials();
    if (!phoneNumberId || !accessToken) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'WhatsApp not configured — add credentials to Remote Config',
      );
    }

    const db = admin.firestore();

    // Reserve one monthly slot up-front (atomic). Refunded if nobody is reached.
    const reserved = await _reserveNoticeQuota(db, d.libraryId);
    if (!reserved) {
      console.log(`[wa] ⊘ Notice broadcast skipped — monthly limit for ${d.libraryId}`);
      return { skipped: true, reason: 'monthly_limit', remaining: 0 };
    }

    // Resolve library name server-side (fall back to any client-supplied name).
    let libraryName = d.libraryName || 'Your PG';
    try {
      const libSnap = await db.collection('libraries').doc(d.libraryId).get();
      if (libSnap.exists && libSnap.data().name) {
        libraryName = libSnap.data().name;
      }
    } catch (_) { /* non-critical */ }

    let phones = [];
    try {
      const snap = await db.collection('memberships')
        .where('libraryId', '==', d.libraryId)
        .where('status', '==', 'active')
        .get();

      phones = snap.docs
        .map((doc) => _normalisePhone(doc.data().phoneNumber))
        .filter(Boolean);
      phones = Array.from(new Set(phones)); // dedupe
    } catch (err) {
      await _releaseNoticeQuota(db, d.libraryId);
      console.error('[wa] Notice recipient query failed:', err.message);
      throw new functions.https.HttpsError(
        'internal', `Failed to load recipients: ${err.message}`,
      );
    }

    if (phones.length === 0) {
      await _releaseNoticeQuota(db, d.libraryId);
      console.log(`[wa] Notice broadcast reached nobody for ${d.libraryId}`);
      return { skipped: true, reason: 'no_recipients', remaining: await _remainingNoticeQuota(db, d.libraryId) };
    }

    const title = String(d.title).slice(0, 120);
    const description = String(d.description || '').slice(0, 600) || 'Please open the app for details.';

    const components = [{
      type: 'body',
      parameters: [
        { type: 'text', text: libraryName },
        { type: 'text', text: title },
        { type: 'text', text: description },
      ],
    }];

    let sent = 0, failed = 0;
    for (const to of phones) {
      try {
        await _sendTemplate({
          phoneNumberId, accessToken, to,
          templateName: NOTICE_TEMPLATE,
          components,
        });
        sent++;
      } catch (err) {
        failed++;
        const metaError = err.response?.data?.error;
        console.error(`[wa] Notice send failed → ${to}:`, metaError?.message || err.message);
      }
    }

    const remaining = await _remainingNoticeQuota(db, d.libraryId);
    console.log(`[wa] ✓ Notice "${title}" → ${sent} sent, ${failed} failed (${remaining} left this month)`);
    return { success: true, sent, failed, remaining };
  });
