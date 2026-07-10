import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set UNUserNotificationCenter delegate
    // This is required for handling notifications when app is in foreground
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      
      // Request notification permissions
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          if let error = error {
            print("FCM: Notification authorization error: \(error.localizedDescription)")
          } else {
            print("FCM: Notification permission granted: \(granted)")
          }
        }
      )
    } else {
      // Fallback for iOS < 10.0
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    // Set Firebase Messaging delegate for handling FCM messages
    Messaging.messaging().delegate = self
    
    // Register for remote notifications
    // This will trigger didRegisterForRemoteNotificationsWithDeviceToken when successful
    application.registerForRemoteNotifications()
    
    // Firebase initialization is handled by Flutter's firebase_core package
    // in main.dart via Firebase.initializeApp()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - APNS Token Registration
  
  /// Called when APNS token is successfully registered
  /// This token is then forwarded to Firebase Messaging
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Convert device token to hex string for logging
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("FCM: APNS token registered: \(token)")
    
    // Pass APNS token to Firebase Messaging
    // This is required for FCM to work on iOS
    Messaging.messaging().apnsToken = deviceToken
  }

  /// Called when APNS token registration fails
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("FCM: Failed to register for remote notifications: \(error.localizedDescription)")
    
    // Common causes:
    // 1. Push Notifications capability not enabled in Xcode
    // 2. App running on iOS Simulator (APNS only works on real devices)
    // 3. Invalid provisioning profile
  }
  
  // MARK: - UNUserNotificationCenterDelegate Methods
  
  /// Called when a notification arrives while app is in FOREGROUND
  /// This allows us to display the notification even when app is open
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("FCM: Notification received in foreground: \(userInfo)")
    
    // Display notification based on iOS version
    if #available(iOS 14.0, *) {
      // iOS 14+: Use banner and list instead of alert
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      // iOS 10-13: Use alert
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  /// Called when user TAPS on a notification.
  /// Forwards to super so the Firebase Messaging Flutter plugin delivers
  /// the event via `onMessageOpenedApp` / `getInitialMessage`.
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("FCM: User tapped notification: \(userInfo)")

    // CRITICAL: Forward to super so FirebaseMessaging Flutter plugin
    // can deliver the tap event to Dart via onMessageOpenedApp.
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
  
}

// MARK: - MessagingDelegate

/// Extension to handle FCM token updates
extension AppDelegate: MessagingDelegate {
  /// Called when FCM token is refreshed
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("FCM: Registration token refreshed: \(fcmToken ?? "nil")")
    
    // The FCM token is automatically handled by FcmTokenService in Flutter
    // This delegate method is useful for debugging
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}
