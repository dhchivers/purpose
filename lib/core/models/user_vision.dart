import 'package:json_annotation/json_annotation.dart';

part 'user_vision.g.dart';

/// Represents a user's finalized vision statement
@JsonSerializable()
class UserVision {
  final String id;
  final String strategyId; // Links to parent strategy
  @Deprecated('Use strategyId instead. Kept for backward compatibility during migration.')
  final String? userId; // Deprecated: Use strategyId
  final int timeframeYears; // 5, 10, or 15
  final String visionStatement;
  final String? sessionId; // Reference to VisionCreationSession
  final DateTime createdAt;
  final DateTime updatedAt;

  UserVision({
    required this.id,
    required this.strategyId,
    @Deprecated('Use strategyId instead') this.userId,
    required this.timeframeYears,
    required this.visionStatement,
    this.sessionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserVision.fromJson(Map<String, dynamic> json) =>
      _$UserVisionFromJson(json);

  Map<String, dynamic> toJson() => _$UserVisionToJson(this);

  UserVision copyWith({
    String? id,
    String? strategyId,
    String? userId,
    int? timeframeYears,
    String? visionStatement,
    String? sessionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserVision(
      id: id ?? this.id,
      strategyId: strategyId ?? this.strategyId,
      userId: userId ?? this.userId,
      timeframeYears: timeframeYears ?? this.timeframeYears,
      visionStatement: visionStatement ?? this.visionStatement,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
