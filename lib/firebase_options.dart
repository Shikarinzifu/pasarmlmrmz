// File generated from google-services.json.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD-GzDjWNEr2IhWhZNcZ9CO9jFOf2raMBc',
    appId: '1:967432735906:web:YOUR_WEB_APP_ID',
    messagingSenderId: '967432735906',
    projectId: 'dompetrmz',
    storageBucket: 'dompetrmz.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-GzDjWNEr2IhWhZNcZ9CO9jFOf2raMBc',
    appId: '1:967432735906:android:7363a11f203769132e5bfb',
    messagingSenderId: '967432735906',
    projectId: 'dompetrmz',
    storageBucket: 'dompetrmz.firebasestorage.app',
  );
}
