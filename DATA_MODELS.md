# Purpose App - Data Models & Authentication

## Overview
This document describes the data models and authentication structure for the Purpose app.

## User Data Model

### UserModel (`lib/core/models/user_model.dart`)
The main user model with JSON serialization support.

**Fields:**
- `uid` (String) - Unique user ID from Firebase Auth
- `email` (String) - User's email address
- `displayName` (String?) - User's display name
- `photoUrl` (String?) - Profile photo URL
- `createdAt` (DateTime) - Account creation timestamp
- `updatedAt` (DateTime) - Last profile update timestamp
- `emailVerified` (bool) - Email verification status
- `purpose` (String?) - User's personal purpose statement
- `vision` (String?) - User's vision statement
- `mission` (String?) - User's mission statement
- `goalIds` (List<String>?) - List of associated goal IDs
- `onboardingCompleted` (bool) - Onboarding completion status

**Features:**
- JSON serialization/deserialization
- `copyWith()` method for immutable updates
- `empty()` factory for initial state

## Authentication Models

### AuthState (`lib/core/models/auth_state.dart`)
Sealed class representing different authentication states:
- `AuthInitial` - Before authentication check
- `AuthLoading` - During authentication operations
- `Authenticated` - User is logged in (contains UserModel)
- `Unauthenticated` - User is not logged in
- `AuthError` - Authentication error occurred

### AuthResult (`lib/core/models/auth_result.dart`)
Result wrapper for authentication operations:
- `success` (bool) - Operation success status
- `message` (String?) - Error/success message
- `uid` (String?) - User ID on successful operations

## Authentication Service

### AuthService (`lib/core/services/auth_service.dart`)
Handles all Firebase Authentication operations with email validation.

**Key Methods:**
- `signUpWithEmail()` - Create new account with email/password
  - Validates email format
  - Validates password strength (min 8 chars, uppercase, lowercase, number)
  - Automatically sends email verification
- `signInWithEmail()` - Sign in existing user
- `signOut()` - Sign out current user
- `sendEmailVerification()` - Resend verification email
- `sendPasswordResetEmail()` - Send password reset link
- `updateDisplayName()` - Update user's display name
- `updateEmail()` - Update user's email with verification
- `updatePassword()` - Update user's password
- `deleteAccount()` - Delete user account
- `firebaseUserToUserModel()` - Convert Firebase User to UserModel

**Email Validation:**
- Uses regex pattern: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
- Validates format before any auth operation

**Password Requirements:**
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number

**Error Handling:**
- User-friendly error messages for all Firebase Auth exceptions
- Handles common cases: email-already-in-use, invalid-email, weak-password, etc.

## State Management

### Auth Providers (`lib/core/services/auth_provider.dart`)
Riverpod providers for authentication:

- `authServiceProvider` - Provides AuthService instance
- `authStateChangesProvider` - Stream of Firebase auth state changes
- `currentUserProvider` - Stream of current UserModel
- `authStateProvider` - StateNotifier for auth state management

### AuthStateNotifier
Manages authentication state and operations:
- `signUp()` - Sign up new user
- `signIn()` - Sign in user
- `signOut()` - Sign out user
- `sendEmailVerification()` - Send verification email
- `sendPasswordResetEmail()` - Send password reset
- `clearError()` - Clear error state

## Utilities

### ValidationUtils (`lib/core/utils/validation_utils.dart`)
Validation helpers for forms:
- `validateEmail()` - Email format validation
- `validatePassword()` - Password strength validation
- `validateName()` - Display name validation
- `validatePasswordConfirmation()` - Password match validation

### AppConstants (`lib/core/constants/app_constants.dart`)
Application-wide constants:
- Route names
- Validation limits
- Error/success messages
- Firebase collection names
- Local storage keys

## Firebase Configuration

### FirebaseConfig (`lib/core/services/firebase_config.dart`)
Firebase initialization for web platform.

**Note:** You need to update the Firebase configuration with your actual project credentials from the Firebase Console.

## Usage Example

```dart
// Sign up a new user
final authNotifier = ref.read(authStateProvider.notifier);
await authNotifier.signUp(
  email: 'user@example.com',
  password: 'SecurePass123',
  displayName: 'John Doe',
);

// Sign in
await authNotifier.signIn(
  email: 'user@example.com',
  password: 'SecurePass123',
);

// Watch authentication state
final authState = ref.watch(authStateProvider);
if (authState is Authenticated) {
  // User is logged in
  final user = authState.user;
}

// Get current user as a stream
final userAsync = ref.watch(currentUserProvider);
userAsync.when(
  data: (user) => user != null ? Text(user.email) : Text('Not logged in'),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

## Next Steps

1. **Configure Firebase**: Update Firebase credentials in `firebase_config.dart`
2. **Build Auth UI**: Create login, signup, and forgot password screens
3. **Add Firestore**: Create UserRepository for storing user profiles
4. **Implement Features**: Build purpose, vision, mission, goals modules
5. **Add AI Integration**: Connect AI service for generating suggestions

## Firebase Setup Required

To complete the setup, you need to:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `altruency-purpose`
3. Enable Authentication > Email/Password
4. Go to Project Settings > General > Your apps > Web app
5. Copy the Firebase configuration and update `firebase_config.dart`
