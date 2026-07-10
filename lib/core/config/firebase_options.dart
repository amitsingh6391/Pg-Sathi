import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios; // Use iOS config for macOS
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAftIZmHVeSk7ruuOINw-XpQE2o70KweF8',
    appId: '1:199992442320:web:bd60be975db5c18c614dd5',
    messagingSenderId: '199992442320',
    projectId: 'pg-sathi',
    authDomain: 'pg-sathi.firebaseapp.com',
    storageBucket: 'pg-sathi.firebasestorage.app',
    measurementId: 'G-EWQ181058H',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBl14nHIriVD5VoEjjH11yhCSmt2U1zggU',
    appId: '1:199992442320:android:42f0981ee75d86b9614dd5',
    messagingSenderId: '199992442320',
    projectId: 'pg-sathi',
    storageBucket: 'pg-sathi.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAqR2crXYn3PjKgUy5WA37kKTfPxAnt1jE',
    appId: '1:199992442320:ios:0c2b28a33fa3a4a9614dd5',
    messagingSenderId: '199992442320',
    projectId: 'pg-sathi',
    storageBucket: 'pg-sathi.firebasestorage.app',
    iosBundleId: 'in.pgsathi.app',
  );
}
