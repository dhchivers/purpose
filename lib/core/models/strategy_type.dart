import 'package:json_annotation/json_annotation.dart';

part 'strategy_type.g.dart';

/// Strategy type classification (Personal, Career, Financial, etc.)
@JsonSerializable()
class StrategyType {
  /// Unique identifier for this strategy type
  final String id;

  /// Display name of the strategy type
  final String name;

  /// Whether this type is currently enabled for selection
  final bool enabled;

  /// Whether this is the default type (cannot be disabled)
  final bool isDefault;

  /// Display order (lower numbers appear first)
  final int order;

  /// Optional description of the strategy type
  final String? description;

  /// Color for this strategy type (stored as ARGB integer)
  final int color;

  /// When this type was created
  final DateTime createdAt;

  /// When this type was last updated
  final DateTime updatedAt;

  const StrategyType({
    required this.id,
    required this.name,
    required this.enabled,
    this.isDefault = false,
    required this.order,
    this.description,
    this.color = 0xFF2196F3, // Default to blue
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a StrategyType from JSON
  factory StrategyType.fromJson(Map<String, dynamic> json) =>
      _$StrategyTypeFromJson(json);

  /// Converts StrategyType to JSON
  Map<String, dynamic> toJson() => _$StrategyTypeToJson(this);

  /// Creates a copy with updated fields
  StrategyType copyWith({
    String? id,
    String? name,
    bool? enabled,
    bool? isDefault,
    int? order,
    String? description,
    int? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StrategyType(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      isDefault: isDefault ?? this.isDefault,
      order: order ?? this.order,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
