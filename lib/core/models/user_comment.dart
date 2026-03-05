import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'user_comment.g.dart';

/// Represents a user comment or feedback on an entity
/// Can be used for feedback on goals/objectives or journal entries
@JsonSerializable(explicitToJson: true)
class UserComment {
  final String id;
  final String userId;
  final String entityId;
  final String entityType; // e.g., 'goal', 'objective', 'mission', 'journal'
  final String commentText;
  final String? parentCommentId; // For threaded replies
  
  @JsonKey(fromJson: _dateTimeFromTimestamp, toJson: _dateTimeToTimestamp)
  final DateTime createdAt;
  
  @JsonKey(fromJson: _dateTimeFromTimestamp, toJson: _dateTimeToTimestamp)
  final DateTime updatedAt;

  const UserComment({
    required this.id,
    required this.userId,
    required this.entityId,
    required this.entityType,
    required this.commentText,
    this.parentCommentId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor for JSON deserialization
  factory UserComment.fromJson(Map<String, dynamic> json) => _$UserCommentFromJson(json);

  /// Method for JSON serialization
  Map<String, dynamic> toJson() => _$UserCommentToJson(this);

  /// Create a copy with updated fields
  UserComment copyWith({
    String? id,
    String? userId,
    String? entityId,
    String? entityType,
    String? commentText,
    String? parentCommentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserComment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      commentText: commentText ?? this.commentText,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Helper to convert Firestore Timestamp to DateTime
  static DateTime _dateTimeFromTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }

  /// Helper to convert DateTime to Firestore Timestamp
  static Timestamp _dateTimeToTimestamp(DateTime dateTime) {
    return Timestamp.fromDate(dateTime);
  }

  @override
  String toString() {
    return 'UserComment(id: $id, userId: $userId, entityId: $entityId, entityType: $entityType, parentCommentId: $parentCommentId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserComment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
