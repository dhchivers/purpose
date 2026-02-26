import 'package:json_annotation/json_annotation.dart';

part 'user_strategy.g.dart';

/// Status of a user's strategy
enum StrategyStatus {
  @JsonValue('draft')
  draft, // Being created, not yet active

  @JsonValue('active')
  active, // Currently in use

  @JsonValue('archived')
  archived, // No longer active but preserved
}

/// Represents a user's strategic journey container
/// Links to purpose, values, vision, and mission elements
@JsonSerializable()
class UserStrategy {
  /// Unique strategy ID
  final String id;

  /// User who owns this strategy
  final String userId;

  /// Strategy name (e.g., "Professional Growth", "Social Impact")
  final String name;

  /// Strategy type ID (references strategy_types collection)
  final String strategyTypeId;

  /// Optional description/context for this strategy
  final String? description;

  /// Current status of the strategy
  @JsonKey(
    fromJson: _strategyStatusFromJson,
    toJson: _strategyStatusToJson,
  )
  final StrategyStatus status;

  /// Whether this is the user's default/primary strategy
  final bool isDefault;

  /// Purpose statement for this strategy (denormalized for quick access)
  final String? purpose;

  /// Count of values associated with this strategy
  final int valueCount;

  /// Current vision statement (denormalized for dashboard display)
  final String? currentVision;

  /// Current mission title (denormalized for dashboard display)
  final String? currentMission;

  /// When the strategy was created
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime createdAt;

  /// Last time the strategy was updated
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  /// When the strategy was archived (if applicable)
  @JsonKey(fromJson: _dateTimeFromJsonNullable, toJson: _dateTimeToJsonNullable)
  final DateTime? archivedAt;

  /// Display order for the strategy (lower numbers appear first)
  final int displayOrder;

  const UserStrategy({
    required this.id,
    required this.userId,
    required this.name,
    required this.strategyTypeId,
    this.description,
    required this.status,
    this.isDefault = false,
    this.purpose,
    this.valueCount = 0,
    this.currentVision,
    this.currentMission,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.displayOrder = 0,
  });

  /// Creates a UserStrategy from JSON
  factory UserStrategy.fromJson(Map<String, dynamic> json) =>
      _$UserStrategyFromJson(json);

  /// Converts UserStrategy to JSON
  Map<String, dynamic> toJson() => _$UserStrategyToJson(this);

  /// Creates a copy of UserStrategy with updated fields
  UserStrategy copyWith({
    String? id,
    String? userId,
    String? name,
    String? strategyTypeId,
    String? description,
    StrategyStatus? status,
    bool? isDefault,
    String? purpose,
    int? valueCount,
    String? currentVision,
    String? currentMission,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    int? displayOrder,
  }) {
    return UserStrategy(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      strategyTypeId: strategyTypeId ?? this.strategyTypeId,
      description: description ?? this.description,
      status: status ?? this.status,
      isDefault: isDefault ?? this.isDefault,
      purpose: purpose ?? this.purpose,
      valueCount: valueCount ?? this.valueCount,
      currentVision: currentVision ?? this.currentVision,
      currentMission: currentMission ?? this.currentMission,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  /// Helper to check if strategy is active
  bool get isActive => status == StrategyStatus.active;

  /// Helper to check if strategy is archived
  bool get isArchived => status == StrategyStatus.archived;

  /// Helper to check if strategy is in draft
  bool get isDraft => status == StrategyStatus.draft;
}

// JSON conversion helpers for StrategyStatus
StrategyStatus _strategyStatusFromJson(String json) {
  switch (json) {
    case 'draft':
      return StrategyStatus.draft;
    case 'active':
      return StrategyStatus.active;
    case 'archived':
      return StrategyStatus.archived;
    default:
      return StrategyStatus.draft;
  }
}

String _strategyStatusToJson(StrategyStatus status) {
  switch (status) {
    case StrategyStatus.draft:
      return 'draft';
    case StrategyStatus.active:
      return 'active';
    case StrategyStatus.archived:
      return 'archived';
  }
}

// JSON conversion helpers for DateTime
DateTime _dateTimeFromJson(dynamic json) {
  if (json == null) return DateTime.now();
  if (json is String) return DateTime.parse(json);
  return DateTime.now();
}

String _dateTimeToJson(DateTime dateTime) => dateTime.toIso8601String();

DateTime? _dateTimeFromJsonNullable(dynamic json) {
  if (json == null) return null;
  if (json is String) return DateTime.parse(json);
  return null;
}

String? _dateTimeToJsonNullable(DateTime? dateTime) => dateTime?.toIso8601String();
