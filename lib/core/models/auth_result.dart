/// Result of authentication operations (sign up, sign in, etc.)
class AuthResult {
  final bool success;
  final String? message;
  final String? uid;

  const AuthResult({
    required this.success,
    this.message,
    this.uid,
  });

  factory AuthResult.success({String? uid}) {
    return AuthResult(
      success: true,
      uid: uid,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult(
      success: false,
      message: message,
    );
  }
}
