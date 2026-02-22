import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purpose/core/services/auth_service.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/models/user_model.dart';
import 'package:purpose/core/models/auth_state.dart';

/// Provider for the AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider for Firebase Auth state changes
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider for the current authenticated user (from Firestore)
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  
  // Switch to userStream when authenticated, null stream when not
  return authService.authStateChanges.asyncExpand((firebaseUser) async* {
    if (firebaseUser == null) {
      print('🔴 currentUserProvider: No Firebase user authenticated');
      yield null;
      return;
    }
    
    print('🟢 currentUserProvider: Firebase user authenticated: ${firebaseUser.uid}');
    
    // Create a fallback user from Firebase Auth data
    UserModel createFallbackUser() {
      print('⚠️ Creating fallback user from Firebase Auth data');
      return UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        fullName: firebaseUser.displayName ?? 'User',
        emailVerified: firebaseUser.emailVerified,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    
    try {
      // First check if user exists in Firestore
      print('📖 Checking if user exists in Firestore...');
      UserModel? user;
      
      try {
        user = await firestoreService.getUser(firebaseUser.uid);
      } catch (e) {
        print('⚠️ Failed to get user from Firestore: $e');
        // Yield fallback user immediately
        final fallbackUser = createFallbackUser();
        yield fallbackUser;
        
        // Don't try to start the stream if we can't even read once
        print('⚠️ Skipping stream setup due to connection issues');
        return;
      }
      
      // If user doesn't exist, create a basic profile
      if (user == null) {
        print('⚠️ User not found in Firestore, creating basic profile for ${firebaseUser.uid}');
        final basicUser = createFallbackUser();
        
        print('💾 Saving basic user to Firestore...');
        print('User data: ${basicUser.toJson()}');
        
        // Try to save to Firestore
        try {
          await firestoreService.saveUser(basicUser);
          print('✅ Basic user saved successfully');
          user = basicUser; // Set user so we start streaming it
        } catch (saveError) {
          print('❌ FAILED to save user to Firestore: $saveError');
          // Yield the user anyway so the app can continue
          yield basicUser;
          // Try to stream anyway, might work
          user = basicUser;
        }
      } else {
        print('✅ User found in Firestore: ${user.email}');
      }
      
      // Yield the current user data immediately
      if (user != null) {
        yield user;
      }
      
      // Now stream the user document for real-time updates
      print('📡 Starting user stream...');
      try {
        await for (final userData in firestoreService.userStream(firebaseUser.uid)) {
          if (userData != null) {
            yield userData;
          }
        }
      } catch (streamError) {
        print('❌ Stream error: $streamError');
        // Stream failed, but we already yielded the initial user data
      }
    } catch (e, stackTrace) {
      print('❌ ERROR in currentUserProvider: $e');
      print('Stack trace: $stackTrace');
      // Yield fallback user instead of null
      yield createFallbackUser();
    }
  });
});

/// Provider for authentication state
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthStateNotifier(authService, ref);
});

/// State Notifier for managing authentication state
class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final Ref _ref;

  AuthStateNotifier(this._authService, this._ref) : super(const AuthInitial()) {
    _init();
  }

  /// Initialize and listen to auth state changes
  void _init() {
    _authService.authStateChanges.listen((user) async {
      print('=== AUTH STATE CHANGE ===');
      if (user != null) {
        print('User authenticated: ${user.uid}');
        print('Email verified: ${user.emailVerified}');
        
        // Reload user to get latest status
        try {
          await user.reload();
          print('User reloaded, emailVerified: ${user.emailVerified}');
        } catch (e) {
          print('Error reloading user: $e');
        }
        
        final userModel = _authService.firebaseUserToUserModel(user);
        if (userModel != null) {
          state = Authenticated(userModel);
          print('State set to Authenticated');
        }
      } else {
        print('User signed out');
        state = const Unauthenticated();
      }
    });
  }

  /// Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    int? age,
    String? location,
  }) async {
    state = const AuthLoading();

    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      age: age,
      location: location,
    );

    if (!result.success) {
      state = AuthError(result.message ?? 'Sign up failed');
    } else {
      print('Sign up successful, updating state...');
      
      // Immediately update state
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final userModel = _authService.firebaseUserToUserModel(currentUser);
        if (userModel != null) {
          state = Authenticated(userModel);
          print('✅ State updated to Authenticated after signup');
        }
      }
    }
  }

  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    print('SignIn called from auth provider');
    state = const AuthLoading();

    final result = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    if (!result.success) {
      print('Sign in failed: ${result.message}');
      state = AuthError(result.message ?? 'Sign in failed');
    } else {
      print('Sign in successful, updating state immediately...');
      
      // Immediately update state instead of waiting for listener
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        print('Setting authenticated state for user: ${currentUser.uid}');
        final userModel = _authService.firebaseUserToUserModel(currentUser);
        if (userModel != null) {
          state = Authenticated(userModel);
          print('✅ State updated to Authenticated');
        } else {
          print('❌ firebaseUserToUserModel returned null');
          state = const AuthError('Failed to load user data');
        }
      } else {
        print('❌ Current user is null after sign in');
        state = const AuthError('Failed to authenticate');
      }
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = const AuthLoading();

    final result = await _authService.signOut();

    if (!result.success) {
      state = AuthError(result.message ?? 'Sign out failed');
    }
    // State will be updated by auth state changes listener
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    final result = await _authService.sendEmailVerification();

    if (!result.success) {
      state = AuthError(result.message ?? 'Failed to send verification email');
    }
  }
  
  /// Refresh current user data
  Future<void> refreshUser() async {
    try {
      print('=== REFRESH USER START ===');
      
      // Reload Firebase Auth user to get latest emailVerified status
      await _authService.reloadCurrentUser();
      
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        print('❌ No current user');
        return;
      }
      
      print('Current user UID: ${currentUser.uid}');
      print('Email verified (from Auth): ${currentUser.emailVerified}');
      
      // Update Firestore with latest email verification status
      try {
        final firestoreService = _ref.read(firestoreServiceProvider);
        
        // Get existing user data from Firestore
        final existingUser = await firestoreService.getUser(currentUser.uid);
        
        if (existingUser != null) {
          // Update with latest email verified status
          final updatedUser = existingUser.copyWith(
            emailVerified: currentUser.emailVerified,
            updatedAt: DateTime.now(),
          );
          
          await firestoreService.saveUser(updatedUser);
          print('✅ Updated Firestore with emailVerified: ${currentUser.emailVerified}');
          
          // Update state with refreshed user data
          state = Authenticated(updatedUser);
          print('✅ State updated with refreshed user data');
          
          // Invalidate the currentUserProvider to force UI refresh
          _ref.invalidate(currentUserProvider);
          print('✅ Invalidated currentUserProvider to refresh UI');
        } else {
          print('⚠️ User not found in Firestore, using basic model');
          final userModel = _authService.firebaseUserToUserModel(currentUser);
          if (userModel != null) {
            state = Authenticated(userModel);
            _ref.invalidate(currentUserProvider);
          }
        }
      } catch (e) {
        print('❌ Error updating Firestore: $e');
        // Still update state with basic user data
        final userModel = _authService.firebaseUserToUserModel(currentUser);
        if (userModel != null) {
          state = Authenticated(userModel);
          _ref.invalidate(currentUserProvider);
        }
      }
      
      print('=== REFRESH USER END ===');
    } catch (e) {
      print('❌ Error refreshing user: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    state = const AuthLoading();

    final result = await _authService.sendPasswordResetEmail(email);

    if (!result.success) {
      state = AuthError(result.message ?? 'Failed to send password reset email');
    } else {
      state = const Unauthenticated();
    }
  }

  /// Clear error state
  void clearError() {
    if (state is AuthError) {
      state = const Unauthenticated();
    }
  }
}
