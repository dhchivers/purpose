import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purpose/core/services/firebase_config.dart';
import 'package:purpose/core/constants/app_constants.dart';
import 'package:purpose/core/services/router.dart';

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

    // Graphite + Signal Blue theme colors
    const signalBlue = Color(0xFF1E6BFF); // Primary blue
    const lightBlue = Color(0xFF4D90FE); // Accent blue
    const graphite = Color(0xFF121417); // Dark graphite
    const lightBackground = Color(0xFFF5F5F7); // Light gray background
    const cardWhite = Color(0xFFFFFFFF); // Card background

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: signalBlue,
          brightness: Brightness.light,
          primary: signalBlue,
          secondary: lightBlue,
          surface: cardWhite,
          background: lightBackground,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: lightBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: graphite,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: cardWhite,
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: signalBlue,
          brightness: Brightness.dark,
          primary: signalBlue,
          secondary: lightBlue,
          surface: graphite,
          background: Color(0xFF0A0A0A),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Color(0xFF0A0A0A),
        appBarTheme: const AppBarTheme(
          backgroundColor: graphite,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: graphite,
          elevation: 2,
        ),
      ),
      themeMode: ThemeMode.light, // Light theme
      routerConfig: router,
    );
  }
}
