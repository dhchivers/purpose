import 'package:json_annotation/json_annotation.dart';

part 'type_preference.g.dart';

/// Represents a baseline preference template for a strategy type
/// Used as templates when creating preferences within specific strategies
@JsonSerializable()
class TypePreference {
  /// Unique identifier for the type preference
  final String id;

  /// Reference to the parent strategy type
  final String strategyTypeId;

  /// Full name of the preference
  final String name;

  /// Short label for display in compact views
  final String shortLabel;

  /// Detailed description of what this preference represents
  final String description;

  /// Display order for sorting preferences
  final int order;

  /// Whether this preference template is currently active
  final bool enabled;

  /// Timestamp when the preference was created
  final DateTime createdAt;

  /// Timestamp when the preference was last updated
  final DateTime updatedAt;

  TypePreference({
    required this.id,
    required this.strategyTypeId,
    required this.name,
    required this.shortLabel,
    required this.description,
    this.order = 0,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy of this preference with optional field updates
  TypePreference copyWith({
    String? id,
    String? strategyTypeId,
    String? name,
    String? shortLabel,
    String? description,
    int? order,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TypePreference(
      id: id ?? this.id,
      strategyTypeId: strategyTypeId ?? this.strategyTypeId,
      name: name ?? this.name,
      shortLabel: shortLabel ?? this.shortLabel,
      description: description ?? this.description,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON for Firestore storage
  Map<String, dynamic> toJson() => _$TypePreferenceToJson(this);

  /// Create from Firestore JSON
  factory TypePreference.fromJson(Map<String, dynamic> json) =>
      _$TypePreferenceFromJson(json);

  @override
  String toString() => 'TypePreference(id: $id, name: $name, shortLabel: $shortLabel, '
      'strategyTypeId: $strategyTypeId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypePreference &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          strategyTypeId == other.strategyTypeId &&
          name == other.name &&
          shortLabel == other.shortLabel &&
          description == other.description &&
          order == other.order &&
          enabled == other.enabled;

  @override
  int get hashCode =>
      id.hashCode ^
      strategyTypeId.hashCode ^
      name.hashCode ^
      shortLabel.hashCode ^
      description.hashCode ^
      order.hashCode ^
      enabled.hashCode;
}
