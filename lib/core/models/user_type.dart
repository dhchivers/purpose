import 'package:json_annotation/json_annotation.dart';

/// User type enumeration
enum UserType {
  @JsonValue('member')
  member,
  
  @JsonValue('admin')
  admin;

  /// Convert string to UserType
  static UserType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserType.admin;
      case 'member':
      default:
        return UserType.member;
    }
  }

  /// Convert UserType to string
  String toJson() {
    switch (this) {
      case UserType.admin:
        return 'admin';
      case UserType.member:
        return 'member';
    }
  }
}
