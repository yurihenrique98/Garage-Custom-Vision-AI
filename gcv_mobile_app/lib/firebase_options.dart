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
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
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
    apiKey: 'AIzaSyCf3_7mWDYGamN-bxUOxt9HeoAa8pLzNKo',
    appId: '1:261841609959:web:80c5e49d43bfb2c0d52e42',
    messagingSenderId: '261841609959',
    projectId: 'gcv-ai-c1ba0',
    authDomain: 'gcv-ai-c1ba0.firebaseapp.com',
    storageBucket: 'gcv-ai-c1ba0.firebasestorage.app',
    measurementId: 'G-HJXXQ4GZZR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAPVpCJoVXuvqLtOsNbygULADIIX2q7O8o',
    appId: '1:261841609959:android:c6ef8874571b52bbd52e42',
    messagingSenderId: '261841609959',
    projectId: 'gcv-ai-c1ba0',
    storageBucket: 'gcv-ai-c1ba0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAu5LZeOgdNn-NqdhMyisTsOGNAHrcY3pI',
    appId: '1:261841609959:ios:11fcfe9c3ecb57b0d52e42',
    messagingSenderId: '261841609959',
    projectId: 'gcv-ai-c1ba0',
    storageBucket: 'gcv-ai-c1ba0.firebasestorage.app',
    iosBundleId: 'com.example.gcvMobileApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAu5LZeOgdNn-NqdhMyisTsOGNAHrcY3pI',
    appId: '1:261841609959:ios:11fcfe9c3ecb57b0d52e42',
    messagingSenderId: '261841609959',
    projectId: 'gcv-ai-c1ba0',
    storageBucket: 'gcv-ai-c1ba0.firebasestorage.app',
    iosBundleId: 'com.example.gcvMobileApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCf3_7mWDYGamN-bxUOxt9HeoAa8pLzNKo',
    appId: '1:261841609959:web:85f7f69e4b0d4e48d52e42',
    messagingSenderId: '261841609959',
    projectId: 'gcv-ai-c1ba0',
    authDomain: 'gcv-ai-c1ba0.firebaseapp.com',
    storageBucket: 'gcv-ai-c1ba0.firebasestorage.app',
    measurementId: 'G-TDWG1R86TF',
  );
}
