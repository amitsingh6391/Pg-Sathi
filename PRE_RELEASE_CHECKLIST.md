# 📋 Pre-Release Checklist for App Store & Play Store

## ✅ Critical Changes Made

### 1. iOS Configuration
- ✅ **Entitlements**: Changed `aps-environment` from `development` to `production`
  - File: `ios/Runner/Runner.entitlements`
  - **Status**: FIXED

### 2. Android Configuration
- ✅ **App Name**: Changed from `library_manager` to `LibraryTrack`
  - File: `android/app/src/main/AndroidManifest.xml`
  - **Status**: FIXED

### 3. Debug Prints
- ✅ **Invoice Repository**: Made debug prints conditional using `kDebugMode`
  - File: `lib/data/repositories/invoice_repository_impl.dart`
  - **Status**: FIXED

---

## 📱 App Information

### Version
- **Current Version**: `38.0.0+38` (pubspec.yaml)
- **App Name**: `LibraryTrack`
- **Bundle ID (iOS)**: `com.academic.master`
- **Package Name (Android)**: `com.academic.master`

---

## ✅ Pre-Release Checklist

### iOS App Store

#### 1. Build Configuration
- [x] Entitlements set to `production` (FIXED)
- [ ] Open `ios/Runner.xcworkspace` in Xcode
- [ ] Verify "Push Notifications" capability is enabled
- [ ] Verify signing certificate is valid
- [ ] Build number matches pubspec.yaml (38)
- [ ] Version number matches pubspec.yaml (38.0.0)

#### 2. App Store Connect
- [ ] App icon (1024x1024) uploaded
- [ ] Screenshots for all required device sizes
- [ ] App description and keywords
- [ ] Privacy policy URL
- [ ] Support URL
- [ ] Age rating completed
- [ ] Pricing and availability set

#### 3. Testing
- [ ] TestFlight build uploaded
- [ ] Internal testing completed
- [ ] External testing (if applicable)

---

### Google Play Store

#### 1. Build Configuration
- [x] App name set to "LibraryTrack" (FIXED)
- [ ] Signing key configured (`android/secrets/key.properties`)
- [ ] Build number matches pubspec.yaml (38)
- [ ] Version name matches pubspec.yaml (38.0.0)

#### 2. Play Console
- [ ] App icon (512x512) uploaded
- [ ] Feature graphic (1024x500)
- [ ] Screenshots for phone and tablet
- [ ] App description (short and full)
- [ ] Privacy policy URL
- [ ] Content rating completed
- [ ] Data safety form completed

#### 3. Testing
- [ ] Internal testing track
- [ ] Closed testing (if applicable)
- [ ] Open testing (if applicable)

---

## 🔍 Code Review Checklist

### Security
- [x] No hardcoded API keys in code (Firebase keys are in config files - OK)
- [x] No test/localhost URLs
- [x] Debug prints are conditional (`kDebugMode`)
- [ ] Review all permissions in AndroidManifest.xml
- [ ] Review all permissions in Info.plist

### Performance
- [ ] No memory leaks
- [ ] Images optimized
- [ ] Network requests optimized
- [ ] Database queries optimized

### User Experience
- [ ] Error messages are user-friendly
- [ ] Loading states implemented
- [ ] Offline handling
- [ ] Network error handling

---

## 📝 Required Store Listings

### App Store (iOS)
1. **App Name**: LibraryTrack
2. **Subtitle**: (Optional, 30 chars)
3. **Description**: (Up to 4000 chars)
4. **Keywords**: (Up to 100 chars, comma-separated)
5. **Support URL**: Required
6. **Marketing URL**: (Optional)
7. **Privacy Policy URL**: Required

### Play Store (Android)
1. **App Name**: LibraryTrack (50 chars max)
2. **Short Description**: (80 chars max)
3. **Full Description**: (4000 chars max)
4. **Privacy Policy URL**: Required
5. **Support Email**: Required

---

## 🔐 Signing & Certificates

### iOS
- [ ] Distribution certificate valid
- [ ] Provisioning profile for App Store
- [ ] Push notification certificate (if using APNs)

### Android
- [ ] Keystore file exists (`android/secrets/key.jks`)
- [ ] `key.properties` file configured
- [ ] Upload key configured (if using Play App Signing)

---

## 🧪 Final Testing

### Functionality
- [ ] User registration/login
- [ ] Library creation
- [ ] Membership assignment
- [ ] Payment processing
- [ ] Invoice generation
- [ ] Push notifications
- [ ] Attendance tracking
- [ ] All owner features
- [ ] All student features

### Devices
- [ ] Test on iOS (iPhone)
- [ ] Test on Android (Phone)
- [ ] Test on iPad (if supported)
- [ ] Test on Android Tablet (if supported)

---

## 📊 Analytics & Monitoring

- [ ] Firebase Analytics enabled
- [ ] Crashlytics enabled
- [ ] Remote Config configured
- [ ] Error tracking set up

---

## 🚨 Known Issues

None currently identified.

---

## 📞 Support Information

- **Support Email**: (Add your support email)
- **Privacy Policy URL**: (Add your privacy policy URL)
- **Terms of Service URL**: (Add if applicable)

---

## ✅ Final Steps Before Release

1. [ ] Run `flutter clean`
2. [ ] Run `flutter pub get`
3. [ ] Build release APK: `flutter build apk --release`
4. [ ] Build release iOS: `flutter build ios --release`
5. [ ] Test release builds on physical devices
6. [ ] Upload to stores
7. [ ] Monitor crash reports after release

---

## 📝 Notes

- Debug prints are now conditional and won't appear in production builds
- iOS entitlements are set to production
- Android app name is now "LibraryTrack"
- All Firestore indexes should be created before release (check console logs)

---

**Last Updated**: $(date)
**Version**: 38.0.0+38

