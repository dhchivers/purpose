import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purpose/core/services/firebase_config.dart';
import 'package:purpose/core/constants/app_constants.dart';
import 'package:purpose/core/services/router.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/core/services/revenue_cat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    print('=== Firebase Initialization Start ===');
    await FirebaseConfig.initialize();
    print('✅ Firebase initialized successfully');
    
    // Test Firestore connection
    print('Testing Firestore connection...');
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('_health_check').doc('test').get();
      print('✅ Firestore connection test successful');
    } catch (testError) {
      print('⚠️ Firestore connection test failed: $testError');
    }
    
    print('=== Firebase Initialization Complete ===');
  } catch (e, stackTrace) {
    print('❌ Firebase initialization error: $e');
    print('Stack trace: $stackTrace');
  }
  
  // Initialize RevenueCat
  try {
    print('=== RevenueCat Initialization Start ===');
    final revenueCatService = RevenueCatService();
    await revenueCatService.configure();
    print('✅ RevenueCat initialized successfully');
    print('=== RevenueCat Initialization Complete ===');
  } catch (e, stackTrace) {
    print('❌ RevenueCat initialization error: $e');
    print('Stack trace: $stackTrace');
  }
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
