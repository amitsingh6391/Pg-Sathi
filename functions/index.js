/**
 * Firebase Cloud Functions for Library Manager
 * Handles FCM push notifications, SMS Portals OTP authentication,
 * and automated daily current affairs generation (3x daily).
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// =============================================================================
// Push Notifications
// =============================================================================

/**
 * Cloud Function to send FCM notifications.
 * Triggered when a document is created in 'notification_requests' collection.
 */
exports.sendNotification = functions
  .runWith({ serviceAccount: 'pg-sathi@appspot.gserviceaccount.com' })
  .firestore
  .document('notification_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const request = snap.data();

    if (request.status === 'sent' || request.status === 'failed') {
      return null;
    }

    const { token, userId, topic, title, body, data } = request;

    // Broadcast to ALL students directly via their FCM tokens (no topic subscription needed)
    if (request.broadcast === true) {
      if (!title || !body) {
        await snap.ref.update({ status: 'failed', error: 'Missing title or body' });
        return null;
      }
      try {
        const db = admin.firestore();
        const dataPayload = {};
        if (data) {
          for (const [key, value] of Object.entries(data)) {
            dataPayload[key] = String(value);
          }
        }
        dataPayload.click_action = 'FLUTTER_NOTIFICATION_CLICK';

        // Fetch all student FCM tokens
        const usersSnap = await db.collection('users').where('role', '==', 'student').select().get();
        const userIds = usersSnap.docs.map(d => d.id);
        const tokens = [];
        for (let i = 0; i < userIds.length; i += 500) {
          const refs = userIds.slice(i, i + 500).map(id => db.collection('fcm_tokens').doc(id));
          const docs = await db.getAll(...refs);
          for (const doc of docs) {
            if (doc.exists && doc.data().token) tokens.push(doc.data().token);
          }
        }

        if (tokens.length === 0) {
          await snap.ref.update({ status: 'skipped', error: 'No student FCM tokens found' });
          return null;
        }

        const messages = tokens.map(t => ({
          token: t,
          notification: { title, body },
          data: dataPayload,
          android: { priority: 'high', notification: { sound: 'default', channelId: 'default' } },
          apns: { payload: { aps: { sound: 'default', badge: 1, 'content-available': 1 } }, headers: { 'apns-priority': '10' } },
        }));

        let successCount = 0, failureCount = 0;
        for (let i = 0; i < messages.length; i += 500) {
          const result = await admin.messaging().sendEach(messages.slice(i, i + 500));
          successCount += result.successCount;
          failureCount += result.failureCount;
        }

        await snap.ref.update({
          status: 'sent',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          successCount,
          failureCount,
        });
        return { successCount, failureCount };
      } catch (error) {
        await snap.ref.update({ status: 'failed', error: error.message });
        return null;
      }
    }

    if ((!token && !userId) || !title || !body) {
      await snap.ref.update({ status: 'failed', error: 'Missing required fields' });
      return null;
    }

    let targetToken = token;

    if (!targetToken && userId) {
      try {
        const fcmTokenDoc = await admin.firestore()
          .collection('fcm_tokens').doc(userId).get();
        if (fcmTokenDoc.exists && fcmTokenDoc.data().token) {
          targetToken = fcmTokenDoc.data().token;
        } else {
          await snap.ref.update({ status: 'skipped', error: 'No FCM token found' });
          return null;
        }
      } catch (error) {
        await snap.ref.update({ status: 'failed', error: error.message });
        return null;
      }
    }

    if (!targetToken) {
      await snap.ref.update({ status: 'failed', error: 'No FCM token available' });
      return null;
    }

    try {
      const dataPayload = {};
      if (data) {
        for (const [key, value] of Object.entries(data)) {
          dataPayload[key] = String(value);
        }
      }
      dataPayload.click_action = 'FLUTTER_NOTIFICATION_CLICK';

      const message = {
        token: targetToken,
        notification: { title, body },
        data: dataPayload,
        android: {
          priority: 'high',
          notification: { sound: 'default', channelId: 'default' },
        },
        apns: {
          payload: { aps: { sound: 'default', badge: 1 } },
          headers: { 'apns-priority': '10' },
        },
      };

      const response = await admin.messaging().send(message);
      await snap.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response,
      });
      return response;
    } catch (error) {
      await snap.ref.update({
        status: 'failed',
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (error.code === 'messaging/invalid-registration-token' ||
          error.code === 'messaging/registration-token-not-registered') {
        if (userId) {
          try {
            await admin.firestore().collection('fcm_tokens').doc(userId).delete();
          } catch (_) {}
        }
        return null;
      }
      throw error;
    }
  });

// =============================================================================
// Auth
// =============================================================================

exports.createCustomToken = functions.https.onCall(async (data) => {
  try {
    const { phoneNumber } = data;
    if (!phoneNumber) {
      throw new functions.https.HttpsError('invalid-argument', 'Phone number required');
    }

    let userRecord;
    try {
      userRecord = await admin.auth().getUserByPhoneNumber(phoneNumber);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        userRecord = await admin.auth().createUser({ phoneNumber });
      } else {
        throw error;
      }
    }

    const customToken = await admin.auth().createCustomToken(userRecord.uid);
    return { success: true, customToken, uid: userRecord.uid };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message || 'Failed');
  }
});

// =============================================================================
// SMS OTP Proxy (required for Flutter Web — browsers block direct HTTP/CORS)
// =============================================================================

/**
 * Callable Cloud Function that proxies the SMS Portals OTP request server-side,
 * avoiding CORS and mixed-content issues on Flutter Web.
 *
 * Expected payload: { phoneNumber: "9548582776", otp: "139402" }
 */
exports.sendSmsOtp = functions.https.onCall(async (data) => {
  const { phoneNumber, otp } = data;

  if (!phoneNumber || !otp) {
    throw new functions.https.HttpsError('invalid-argument', 'phoneNumber and otp are required');
  }

  // Sanitize: strip country code, keep 10 digits
  let cleanPhone = String(phoneNumber).replace(/\D/g, '');
  if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
    cleanPhone = cleanPhone.substring(2);
  }
  if (cleanPhone.length !== 10) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid phone number');
  }

  const apiKey = 'Z4AhuKgyunOWAbXnkGoo9V7yjePc130zi-zMErN9K_o4dDSpFDulNYOTosU4MuHe';
  const senderId = 'PTPSMS';
  const dltTemplateId = '1207168605001414924';
  const message = `Hi Your User OTP is: ${otp} Thank you ! LibraryTrack  PTPSMS`;

  const url = `http://sms.smsportals.org/api_v2/message/send`
    + `?api_key=${encodeURIComponent(apiKey)}`
    + `&dlt_template_id=${encodeURIComponent(dltTemplateId)}`
    + `&sender_id=${encodeURIComponent(senderId)}`
    + `&mobile_no=${cleanPhone}`
    + `&message=${encodeURIComponent(message)}`
    + `&unicode=0`;

  try {
    const response = await axios.get(url, { timeout: 30000 });
    const body = response.data;
    if (typeof body === 'object' && body.success === false) {
      throw new functions.https.HttpsError('internal', `SMS API error: ${body.error || 'unknown'}`);
    }
    return { success: true };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Failed to send SMS: ${error.message}`);
  }
});

// =============================================================================
// WhatsApp — Invoice & Expiry Reminders (Meta Cloud API)
// =============================================================================
const wa = require('./whatsapp');
exports.sendWhatsAppInvoice = wa.sendWhatsAppInvoice;
exports.sendWhatsAppExpiryReminders = wa.sendWhatsAppExpiryReminders;
exports.sendWhatsAppNotice = wa.sendWhatsAppNotice;
