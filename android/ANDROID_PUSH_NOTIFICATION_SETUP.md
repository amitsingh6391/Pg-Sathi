# Android Push Notification Setup Guide
## Firebase Cloud Messaging (FCM) Integration

**Status**: ✅ Fully Configured  
**Reference**: [Firebase Flutter Android Integration](https://firebase.flutter.dev/docs/messaging/usage/)

---

## ✅ Configuration Checklist

### 1. Dependencies
- [x] `firebase_messaging: ^16.1.0` in `pubspec.yaml`
- [x] `firebase-messaging` in `build.gradle.kts`
- [x] Google Services plugin applied
- [x] Firebase BOM `33.7.0`

### 2. Firebase Configuration
- [x] `google-services.json` exists at `android/app/google-services.json`
- [x] Firebase initialized in `main.dart`

### 3. AndroidManifest.xml
- [x] `INTERNET` permission
- [x] `POST_NOTIFICATIONS` permission (Android 13+)
- [x] `launchMode="singleTop"` for proper notification handling

### 4. MainActivity.kt
- [x] Notification channel created (`default` channel)
- [x] Channel configured with high importance
- [x] Vibration and lights enabled

### 5. FCM Service
- [x] `FcmTokenService` implemented
- [x] Token registration and refresh
- [x] Token saved to Firestore

### 6. Background Handler
- [x] `onBackgroundMessage` handler registered in `main.dart`
- [x] Top-level function with `@pragma('vm:entry-point')`

### 7. Cloud Functions
- [x] `sendNotification` function configured
- [x] Android notification payload with:
  - Priority: `high`
  - Channel ID: `default`
  - Sound: `default`

---

## 📋 Current Configuration Details

### Notification Channel

**Channel ID**: `default`  
**Channel Name**: "Default Notifications"  
**Importance**: `HIGH`  
**Features**: Vibration, Lights enabled

This channel is automatically created when the app starts (in `MainActivity.onCreate()`).

### Permissions

**Android 12 and below**: No runtime permission needed  
**Android 13+ (API 33+)**: `POST_NOTIFICATIONS` permission required

The permission is declared in `AndroidManifest.xml`. On Android 13+, the system will automatically prompt the user when the app requests notification permission.

### Background Message Handler

The background handler (`_firebaseMessagingBackgroundHandler`) is registered in `main.dart` and handles notifications when:
- App is in the background
- App is terminated

**Note**: This handler runs in a separate isolate, so Firebase must be initialized again.

---

## 🧪 Testing

### 1. Build and Run

```bash
flutter clean
flutter pub get
flutter run
```

### 2. Verify Token Registration

Check console logs for:
```
FCM: Token saved for user [user_id]
```

### 3. Test Notification

**Option A: Firebase Console**
1. Go to Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Enter FCM token
4. Send notification

**Option B: Use App Feature**
- Use your app's notification feature to send a test notification

### 4. Test Scenarios

- ✅ **Foreground**: App open, notification should appear
- ✅ **Background**: App in background, notification should appear
- ✅ **Terminated**: App closed, notification should appear

---

## 🔧 Troubleshooting

### Issue: Notifications not appearing

**Solutions**:
1. ✅ Check notification permissions (Settings → Apps → Your App → Notifications)
2. ✅ Verify notification channel is created (check logs)
3. ✅ Check FCM token is registered in Firestore
4. ✅ Verify `google-services.json` is correct
5. ✅ Check Cloud Function logs for errors

### Issue: "POST_NOTIFICATIONS permission denied"

**Solutions**:
1. ✅ Permission is declared in `AndroidManifest.xml`
2. ✅ On Android 13+, user must grant permission manually
3. ✅ Check app settings to ensure notifications are enabled

### Issue: Background notifications not working

**Solutions**:
1. ✅ Verify `onBackgroundMessage` is registered before `runApp()`
2. ✅ Check that handler is a top-level function
3. ✅ Verify Firebase is initialized in the handler

### Issue: Notification channel not found

**Solutions**:
1. ✅ Ensure `MainActivity.onCreate()` is called
2. ✅ Check that channel ID matches Cloud Function (`default`)
3. ✅ Verify channel is created before sending notifications

---

## 📱 Android Version Compatibility

| Android Version | API Level | Notes |
|----------------|-----------|-------|
| Android 8.0+ | 26+ | Notification channels required |
| Android 13+ | 33+ | POST_NOTIFICATIONS permission required |
| All versions | - | FCM works on all Android versions |

---

## ✅ What's Working

1. ✅ FCM token registration and refresh
2. ✅ Token storage in Firestore
3. ✅ Notification channel creation
4. ✅ Background message handling
5. ✅ Cloud Function integration
6. ✅ Android 13+ permission support

---

## 📝 Code Files

- `android/app/src/main/AndroidManifest.xml` - Permissions and configuration
- `android/app/src/main/kotlin/com/academic/master/MainActivity.kt` - Notification channel
- `lib/main.dart` - Background message handler
- `lib/data/services/fcm_token_service.dart` - FCM token management
- `functions/index.js` - Cloud Function for sending notifications

---

## 🎯 Summary

**Android push notifications are fully configured and ready to use!**

All required components are in place:
- ✅ Permissions
- ✅ Notification channel
- ✅ Background handler
- ✅ FCM service
- ✅ Cloud Function integration

The app should receive push notifications on all Android devices (8.0+) including Android 13+ with proper permission handling.

