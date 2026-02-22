import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration and initialization
/// 
/// IMPORTANT: Before deploying, update these values with your actual Firebase project configuration.
/// 
/// To get your Firebase web config:
/// 1. Go to https://console.firebase.google.com/
/// 2. Select your project: altruency-purpose
/// 3. Click on the web app icon (</>)
/// 4. Copy your configuration values
/// 5. Also enable Authentication > Email/Password in Firebase Console
class FirebaseConfig {
  /// Initialize Firebase for web platform
  static Future<void> initialize() async {
    if (kIsWeb) {
      // Web configuration
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyD3dLLJuYznC0qzDiqp2t_KQ_dqyqKKYU4',
          authDomain: 'altruency-purpose.firebaseapp.com',
          projectId: 'altruency-purpose',
          storageBucket: 'altruency-purpose.firebasestorage.app',
          messagingSenderId: '519798970874',
          appId: '1:519798970874:web:5e15b35cb136868c5e6c43',
          // Explicitly set the measurementId if you have Google Analytics
          // measurementId: 'G-XXXXXXXXXX',
        ),
      );
      
      // Configure Firestore immediately after initialization
      final firestore = FirebaseFirestore.instance;
      firestore.settings = const Settings(
        persistenceEnabled: false,
        sslEnabled: true,
      );
      
      print('✅ Firestore configured with settings');
    } else {
      // For other platforms (if needed in future)
      await Firebase.initializeApp();
    }
  }
}
