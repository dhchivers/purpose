import 'package:json_annotation/json_annotation.dart';

part 'user_value.g.dart';

/// Represents a user's refined personal value
@JsonSerializable()
class UserValue {
  final String id;
  final String strategyId; // Links to parent strategy
  @Deprecated('Use strategyId instead. Kept for backward compatibility during migration.')
  final String? userId; // Deprecated: Use strategyId
  final String seedValue; // The original seed value
  final String refinedLabel; // The final refined label
  final String statement; // The final value statement
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Context from the creation process (optional, for reference)
  final String? sessionId; // Link back to the creation session
  final Map<String, dynamic>? creationContext; // Summary of key insights

  UserValue({
    required this.id,
    required this.strategyId,
    @Deprecated('Use strategyId instead') this.userId,
    required this.seedValue,
    required this.refinedLabel,
    required this.statement,
    required this.createdAt,
    this.updatedAt,
    this.sessionId,
    this.creationContext,
  });

  factory UserValue.fromJson(Map<String, dynamic> json) =>
      _$UserValueFromJson(json);

  Map<String, dynamic> toJson() => _$UserValueToJson(this);

  UserValue copyWith({
    String? id,
    String? strategyId,
    String? userId,
    String? seedValue,
    String? refinedLabel,
    String? statement,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sessionId,
    Map<String, dynamic>? creationContext,
  }) {
    return UserValue(
      id: id ?? this.id,
      strategyId: strategyId ?? this.strategyId,
      userId: userId ?? this.userId,
      seedValue: seedValue ?? this.seedValue,
      refinedLabel: refinedLabel ?? this.refinedLabel,
      statement: statement ?? this.statement,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sessionId: sessionId ?? this.sessionId,
      creationContext: creationContext ?? this.creationContext,
    );
  }
}
