import 'package:json_annotation/json_annotation.dart';

part 'strategy_preference.g.dart';

/// Represents a preference value within a strategy
/// Used to capture and prioritize different aspects of a strategy
@JsonSerializable()
class StrategyPreference {
  /// Unique identifier for the preference
  final String id;

  /// Reference to the parent strategy
  final String strategyId;

  /// Full name of the preference
  final String name;

  /// Short label for display in compact views
  final String shortLabel;

  /// Detailed description of what this preference represents
  final String description;

  /// Relative importance weight (0.0 to 1.0)
  /// Higher values indicate greater importance
  final double relativeWeight;

  /// Monetary value associated with this preference per year
  /// Can represent cost, revenue, savings, etc.
  final double monetaryFactorPerYear;

  /// Display order for sorting preferences
  final int order;

  /// Whether this preference is currently active
  final bool enabled;

  /// Timestamp when the preference was created
  final DateTime createdAt;

  /// Timestamp when the preference was last updated
  final DateTime updatedAt;

  StrategyPreference({
    required this.id,
    required this.strategyId,
    required this.name,
    required this.shortLabel,
    required this.description,
    required this.relativeWeight,
    required this.monetaryFactorPerYear,
    this.order = 0,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy of this preference with optional field updates
  StrategyPreference copyWith({
    String? id,
    String? strategyId,
    String? name,
    String? shortLabel,
    String? description,
    double? relativeWeight,
    double? monetaryFactorPerYear,
    int? order,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StrategyPreference(
      id: id ?? this.id,
      strategyId: strategyId ?? this.strategyId,
      name: name ?? this.name,
      shortLabel: shortLabel ?? this.shortLabel,
      description: description ?? this.description,
      relativeWeight: relativeWeight ?? this.relativeWeight,
      monetaryFactorPerYear: monetaryFactorPerYear ?? this.monetaryFactorPerYear,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON for Firestore storage
  Map<String, dynamic> toJson() => _$StrategyPreferenceToJson(this);

  /// Create from Firestore JSON
  factory StrategyPreference.fromJson(Map<String, dynamic> json) =>
      _$StrategyPreferenceFromJson(json);

  @override
  String toString() => 'StrategyPreference(id: $id, name: $name, shortLabel: $shortLabel, '
      'relativeWeight: $relativeWeight, monetaryFactorPerYear: $monetaryFactorPerYear)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrategyPreference &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          strategyId == other.strategyId &&
          name == other.name &&
          shortLabel == other.shortLabel &&
          description == other.description &&
          relativeWeight == other.relativeWeight &&
          monetaryFactorPerYear == other.monetaryFactorPerYear &&
          order == other.order &&
          enabled == other.enabled;

  @override
  int get hashCode =>
      id.hashCode ^
      strategyId.hashCode ^
      name.hashCode ^
      shortLabel.hashCode ^
      description.hashCode ^
      relativeWeight.hashCode ^
      monetaryFactorPerYear.hashCode ^
      order.hashCode ^
      enabled.hashCode;
}
