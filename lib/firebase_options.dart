import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web not configured — will skip Firebase init
      throw UnsupportedError('Firebase is not configured for web');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAKGr8Is4vPFjV5lKJDYj9Y3Yp6Rm7r3oQ',
    appId: '1:1041032348170:android:4e9acc70982761875f15f3',
    messagingSenderId: '1041032348170',
    projectId: 'saloon-acaee',
    storageBucket: 'saloon-acaee.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCwd42AUbGuK2WTZumsZCqwCtRUcY-5Zy4',
    appId: '1:1041032348170:ios:75010c00e1fc779d5f15f3',
    messagingSenderId: '1041032348170',
    projectId: 'saloon-acaee',
    storageBucket: 'saloon-acaee.firebasestorage.app',
    iosBundleId: 'com.saloon.saloonApp',
  );
}
