import 'package:json_annotation/json_annotation.dart';
import 'package:purpose/core/models/module_progress.dart';
import 'package:purpose/core/models/user_type.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'user_model.g.dart';

/// User model representing a user in the Purpose app
@JsonSerializable()
class UserModel {
  /// Unique user ID (from Firebase Auth)
  final String uid;

  /// User's email address
  final String email;

  /// User type (member or admin)
  @JsonKey(
    fromJson: _userTypeFromJson,
    toJson: _userTypeToJson,
  )
  final UserType userType;

  /// User's full name
  final String fullName;

  /// User's age
  final int? age;

  /// User's location (city, state/country)
  final String? location;

  /// User's profile photo URL
  final String? photoUrl;

  /// When the user account was created
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime createdAt;

  /// Last time the user updated their profile
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  /// Whether the user's email is verified
  final bool emailVerified;

  /// User's personal purpose statement
  final String? purpose;

  /// User's vision statement
  final String? vision;

  /// User's mission statement
  final String? mission;

  /// List of goal IDs associated with this user
  final List<String>? goalIds;

  /// User's onboarding status
  final bool onboardingCompleted;

  /// Progress through question modules
  /// Map of questionModuleId to ModuleProgress
  final Map<String, ModuleProgress>? moduleProgress;

  /// IDs of completed question modules (for quick lookup)
  final List<String>? completedModuleIds;

  const UserModel({
    required this.uid,
    required this.email,
    this.userType = UserType.member,
    required this.fullName,
    this.age,
    this.location,
    this.photoUrl,
    required this.createdAt,
    this.moduleProgress,
    this.completedModuleIds,
    required this.updatedAt,
    required this.emailVerified,
    this.purpose,
    this.vision,
    this.mission,
    this.goalIds,
    this.onboardingCompleted = false,
  });

  /// Creates a UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Converts UserModel to JSON
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// Helper to check if user is admin
  bool get isAdmin => userType == UserType.admin;

  /// Creates a copy of UserModel with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    UserType? userType,
    String? fullName,
    int? age,
    String? location,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? emailVerified,
    String? purpose,
    String? vision,
    String? mission,
    Map<String, ModuleProgress>? moduleProgress,
    List<String>? completedModuleIds,
    List<String>? goalIds,
    bool? onboardingCompleted,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      location: location ?? this.location,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      emailVerified: emailVerified ?? this.emailVerified,
      purpose: purpose ?? this.purpose,
      moduleProgress: moduleProgress ?? this.moduleProgress,
      completedModuleIds: completedModuleIds ?? this.completedModuleIds,
      vision: vision ?? this.vision,
      mission: mission ?? this.mission,
      goalIds: goalIds ?? this.goalIds,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  /// Creates an empty UserModel (for initial state)
  factory UserModel.empty() {
    return UserModel(
      uid: '',
      email: '',
      fullName: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      emailVerified: false,
    );
  }
}

/// Helper function to convert UserType from JSON
UserType _userTypeFromJson(String? value) {
  if (value == null) return UserType.member;
  return UserType.fromString(value);
}

/// Helper function to convert UserType to JSON
String _userTypeToJson(UserType userType) {
  return userType.toJson();
}

/// Helper function to convert DateTime from JSON (handles both Timestamp and String)
DateTime _dateTimeFromJson(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is String) {
    return DateTime.parse(value);
  }
  return DateTime.now();
}

/// Helper function to convert DateTime to JSON
String _dateTimeToJson(DateTime dateTime) {
  return dateTime.toIso8601String();
}
