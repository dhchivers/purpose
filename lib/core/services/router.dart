import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/models/auth_state.dart';
import 'package:purpose/features/home/login_page.dart';
import 'package:purpose/features/home/signup_page.dart';
import 'package:purpose/features/home/dashboard_page.dart';
import 'package:purpose/features/admin/admin_settings_page.dart';
import 'package:purpose/features/admin/admin_modules_page.dart';
import 'package:purpose/features/admin/admin_module_detail_page.dart';
import 'package:purpose/features/admin/admin_values_seeds_page.dart';
import 'package:purpose/features/purpose/purpose_modules_page.dart';
import 'package:purpose/features/purpose/module_questionnaire_page.dart';
import 'package:purpose/features/purpose/identity_analysis_page.dart';
import 'package:purpose/core/constants/app_constants.dart';

/// Provider for GoRouter configuration
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppConstants.loginRoute,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState is Authenticated;
      final isLoading = authState is AuthLoading || authState is AuthInitial;
      
      final isLoginRoute = state.matchedLocation == AppConstants.loginRoute;
      final isSignupRoute = state.matchedLocation == AppConstants.signupRoute;
      final isAuthRoute = isLoginRoute || isSignupRoute;

      print('=== ROUTER REDIRECT ===');
      print('Current location: ${state.matchedLocation}');
      print('Auth state: ${authState.runtimeType}');
      print('isAuthenticated: $isAuthenticated');
      print('isLoading: $isLoading');
      print('isAuthRoute: $isAuthRoute');

      // If loading, don't redirect
      if (isLoading) {
        print('Loading, no redirect');
        return null;
      }

      // If authenticated and trying to access auth pages, redirect to home
      if (isAuthenticated && isAuthRoute) {
        print('Authenticated on auth page, redirecting to home');
        return AppConstants.homeRoute;
      }

      // If not authenticated and not on auth pages, redirect to login
      if (!isAuthenticated && !isAuthRoute) {
        print('Not authenticated, redirecting to login');
        return AppConstants.loginRoute;
      }

      print('No redirect needed');
      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.homeRoute,
        name: 'home',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: AppConstants.loginRoute,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppConstants.signupRoute,
        name: 'signup',
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminSettingsPage(),
      ),
      GoRoute(
        path: '/admin/modules',
        name: 'admin-modules',
        builder: (context, state) => const AdminModulesPage(),
      ),
      GoRoute(
        path: '/admin/modules/:id',
        name: 'admin-module-detail',
        builder: (context, state) {
          final moduleId = state.pathParameters['id']!;
          return AdminModuleDetailPage(moduleId: moduleId);
        },
      ),
      GoRoute(
        path: '/admin/values-seeds',
        name: 'admin-values-seeds',
        builder: (context, state) => const AdminValuesSeedsPage(),
      ),
      GoRoute(
        path: '/purpose',
        name: 'purpose',
        builder: (context, state) => const PurposeModulesPage(),
      ),
      GoRoute(
        path: '/purpose/module/:id',
        name: 'purpose-module',
        builder: (context, state) {
          final moduleId = state.pathParameters['id']!;
          return ModuleQuestionnairePage(moduleId: moduleId);
        },
      ),
      GoRoute(
        path: '/purpose/analysis',
        name: 'purpose-analysis',
        builder: (context, state) => const IdentityAnalysisPage(),
      ),
      // TODO: Add more routes as features are developed
      // GoRoute(
      //   path: AppConstants.visionRoute,
      //   name: 'vision',
      //   builder: (context, state) => const VisionPage(),
      // ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppConstants.homeRoute),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
