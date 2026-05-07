// File generated based on google-services.json for the GoLorry Customer App
// Project ID: laari-app-owner-6c9d9

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
          'DefaultFirebaseOptions have not been configured for iOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBVUJUOjZH57NYkkb8EYfGJpodg02IrTVQ',
    appId: '1:373993258946:android:d9dcf70fb7323f004da05b',
    messagingSenderId: '373993258946',
    projectId: 'laari-app-owner-6c9d9',
    storageBucket: 'laari-app-owner-6c9d9.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBVUJUOjZH57NYkkb8EYfGJpodg02IrTVQ',
    appId: '1:373993258946:web:d9dcf70fb7323f004da05b',
    messagingSenderId: '373993258946',
    projectId: 'laari-app-owner-6c9d9',
    storageBucket: 'laari-app-owner-6c9d9.firebasestorage.app',
    authDomain: 'laari-app-owner-6c9d9.firebaseapp.com',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBVUJUOjZH57NYkkb8EYfGJpodg02IrTVQ',
    appId: '1:373993258946:web:d9dcf70fb7323f004da05b',
    messagingSenderId: '373993258946',
    projectId: 'laari-app-owner-6c9d9',
    storageBucket: 'laari-app-owner-6c9d9.firebasestorage.app',
    authDomain: 'laari-app-owner-6c9d9.firebaseapp.com',
  );
}
