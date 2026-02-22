import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purpose/core/models/user_model.dart';
import 'package:purpose/core/models/user_type.dart';
import 'package:purpose/core/models/auth_result.dart';

/// Service for handling Firebase Authentication operations
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email and password
  /// Automatically sends email verification and creates user in Firestore
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    int? age,
    String? location,
  }) async {
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        return AuthResult.failure('Please enter a valid email address');
      }

      // Validate password strength
      final passwordValidation = _validatePassword(password);
      if (passwordValidation != null) {
        return AuthResult.failure(passwordValidation);
      }

      // Validate full name
      if (fullName.trim().isEmpty) {
        return AuthResult.failure('Please enter your full name');
      }

      // Create user account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return AuthResult.failure('Failed to create user account');
      }

      // Update display name in Firebase Auth
      await user.updateDisplayName(fullName);

      // Send email verification
      await user.sendEmailVerification();
      print('Email verification sent to ${user.email}');

      // Create user document in Firestore
      final now = DateTime.now();
      final userModel = UserModel(
        uid: user.uid,
        email: email,
        fullName: fullName,
        age: age,
        location: location,
        userType: UserType.member, // Default to member
        emailVerified: user.emailVerified,
        createdAt: now,
        updatedAt: now,
      );

      // Save to Firestore - this must succeed
      try {
        print('=== FIRESTORE WRITE START ===');
        print('User UID: ${user.uid}');
        print('Firestore instance: $_firestore');
        
        final userData = userModel.toJson();
        print('User data to save: $userData');
        
        final docRef = _firestore.collection('users').doc(user.uid);
        print('Document reference: ${docRef.path}');
        
        await docRef.set(userData);
        
        print('✅ User document created successfully in Firestore!');
        print('=== FIRESTORE WRITE END ===');
      } catch (firestoreError, stackTrace) {
        print('❌ ERROR creating Firestore document');
        print('Error: $firestoreError');
        print('Stack trace: $stackTrace');
        
        // If Firestore write fails, delete the Auth user to keep things consistent
        try {
          await user.delete();
          print('Rolled back: Deleted Auth user due to Firestore failure');
        } catch (deleteError) {
          print('Warning: Could not delete Auth user after Firestore failure: $deleteError');
        }
        
        return AuthResult.failure(
          'Failed to create user profile. Please try again. Error: ${firestoreError.toString()}',
        );
      }

      return AuthResult.success(uid: user.uid);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('=== SIGN IN START ===');
      print('Email: $email');
      
      // Validate email format
      if (!_isValidEmail(email)) {
        return AuthResult.failure('Please enter a valid email address');
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return AuthResult.failure('Failed to sign in');
      }

      print('✅ User signed in: ${user.uid}');
      
      // Reload user to get latest email verification status
      await user.reload();
      print('User reloaded, emailVerified: ${user.emailVerified}');
      
      // Update Firestore with latest email verification status
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'emailVerified': user.emailVerified,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        print('Updated Firestore with emailVerified: ${user.emailVerified}');
      } catch (e) {
        print('Warning: Could not update emailVerified in Firestore: $e');
      }
      
      print('=== SIGN IN END ===');
      return AuthResult.success(uid: user.uid);
    } on FirebaseAuthException catch (e) {
      print('❌ Sign in error: ${e.code} - ${e.message}');
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      print('❌ Unexpected sign in error: $e');
      return AuthResult.failure('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Reload current user to get latest data from Firebase Auth
  Future<void> reloadCurrentUser() async {
    try {
      await currentUser?.reload();
    } catch (e) {
      print('Error reloading user: $e');
    }
  }

  /// Sign out the current user
  Future<AuthResult> signOut() async {
    try {
      await _auth.signOut();
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('Failed to sign out: ${e.toString()}');
    }
  }

  /// Send email verification to current user
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('No user is currently signed in');
      }

      if (user.emailVerified) {
        return AuthResult.failure('Email is already verified');
      }

      await user.sendEmailVerification();
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure(
          'Failed to send verification email: ${e.toString()}');
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      if (!_isValidEmail(email)) {
        return AuthResult.failure('Please enter a valid email address');
      }

      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure(
          'Failed to send password reset email: ${e.toString()}');
    }
  }

  /// Update user display name
  Future<AuthResult> updateDisplayName(String displayName) async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('No user is currently signed in');
      }

      await user.updateDisplayName(displayName);
      await user.reload();
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure(
          'Failed to update display name: ${e.toString()}');
    }
  }

  /// Update user email
  Future<AuthResult> updateEmail(String newEmail) async {
    try {
      if (!_isValidEmail(newEmail)) {
        return AuthResult.failure('Please enter a valid email address');
      }

      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('No user is currently signed in');
      }

      await user.verifyBeforeUpdateEmail(newEmail);
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Failed to update email: ${e.toString()}');
    }
  }

  /// Update user password
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      final passwordValidation = _validatePassword(newPassword);
      if (passwordValidation != null) {
        return AuthResult.failure(passwordValidation);
      }

      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('No user is currently signed in');
      }

      await user.updatePassword(newPassword);
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Failed to update password: ${e.toString()}');
    }
  }

  /// Delete user account
  Future<AuthResult> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('No user is currently signed in');
      }

      await user.delete();
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure(
          'Failed to delete account: ${e.toString()}');
    }
  }

  /// Convert Firebase User to UserModel
  /// Note: This only creates a basic UserModel. 
  /// Full user data should be fetched from Firestore.
  UserModel? firebaseUserToUserModel(User? firebaseUser) {
    print('=== firebaseUserToUserModel called ===');
    if (firebaseUser == null) {
      print('❌ firebaseUser is null');
      return null;
    }

    print('Firebase user UID: ${firebaseUser.uid}');
    print('Email: ${firebaseUser.email}');
    print('Display name: ${firebaseUser.displayName}');
    print('Email verified: ${firebaseUser.emailVerified}');

    try {
      final userModel = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        fullName: firebaseUser.displayName ?? 'User',
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        updatedAt: DateTime.now(),
        emailVerified: firebaseUser.emailVerified,
      );
      print('✅ UserModel created successfully');
      return userModel;
    } catch (e, stackTrace) {
      print('❌ Error creating UserModel: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Validate email format using regex
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate password strength
  /// Returns null if valid, error message if invalid
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null; // Password is valid
  }

  /// Get user-friendly error messages from Firebase Auth exceptions
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email address is already registered';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support';
      case 'weak-password':
        return 'Please choose a stronger password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found with this email address';
      case 'wrong-password':
        return 'Incorrect password. Please try again';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}
