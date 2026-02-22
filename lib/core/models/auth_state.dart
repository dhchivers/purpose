import 'package:purpose/core/models/user_model.dart';

/// Represents the authentication state of the application
sealed class AuthState {
  const AuthState();
}

/// Initial state before authentication check
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// User is currently being authenticated
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User is authenticated
class Authenticated extends AuthState {
  final UserModel user;

  const Authenticated(this.user);
}

/// User is not authenticated
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Authentication error occurred
class AuthError extends AuthState {
  final String message;
  final Exception? exception;

  const AuthError(this.message, [this.exception]);
}
