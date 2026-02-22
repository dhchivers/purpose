/// App-wide constants for the Purpose application
library;

class AppConstants {
  // App Info
  static const String appName = 'Purpose';
  static const String appVersion = '1.0.0';
  
  // Routes
  static const String homeRoute = '/';
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String purposeRoute = '/purpose';
  static const String purposeAnalysisRoute = '/purpose/analysis';
  static const String visionRoute = '/vision';
  static const String missionRoute = '/mission';
  static const String goalsRoute = '/goals';
  static const String objectivesRoute = '/objectives';
  static const String profileRoute = '/profile';
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  
  // Error Messages
  static const String networkError = 'Network error. Please check your connection.';
  static const String unknownError = 'An unknown error occurred. Please try again.';
  
  // Success Messages
  static const String signUpSuccess = 'Account created! Please check your email to verify.';
  static const String passwordResetSent = 'Password reset email sent! Check your inbox.';
  static const String emailVerificationSent = 'Verification email sent!';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String questionModulesCollection = 'question_modules';
  static const String questionsCollection = 'questions';
  static const String userAnswersCollection = 'user_answers';
  static const String goalsCollection = 'goals';
  static const String objectivesCollection = 'objectives';
  static const String identitySynthesisResultsCollection = 'identity_synthesis_results';
  
  // Local Storage Keys
  static const String themeKey = 'theme_mode';
  static const String onboardingKey = 'onboarding_completed';
}
