import 'package:json_annotation/json_annotation.dart';

part 'goal.g.dart';

/// Represents a goal linked to a specific mission
/// Goals are the key milestones and outcomes to be achieved within a mission
@JsonSerializable(explicitToJson: true)
class Goal {
  final String id;
  final String missionId; // Reference to parent MissionDocument
  final String strategyId; // Denormalized for easier querying
  final String title;
  final String description;
  final double budgetMonetary; // Budget in monetary units
  final double budgetTime; // Budget in hours/days
  final double actualMonetary; // Actual spent in monetary units
  final double actualTime; // Actual time spent in hours/days
  final bool achieved; // Completion status
  final DateTime? dateAchieved; // When the goal was achieved (null if not achieved)
  final DateTime dateCreated;
  final DateTime updatedAt;

  Goal({
    required this.id,
    required this.missionId,
    required this.strategyId,
    required this.title,
    required this.description,
    this.budgetMonetary = 0.0,
    this.budgetTime = 0.0,
    this.actualMonetary = 0.0,
    this.actualTime = 0.0,
    this.achieved = false,
    this.dateAchieved,
    required this.dateCreated,
    required this.updatedAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);

  Map<String, dynamic> toJson() => _$GoalToJson(this);

  Goal copyWith({
    String? id,
    String? missionId,
    String? strategyId,
    String? title,
    String? description,
    double? budgetMonetary,
    double? budgetTime,
    double? actualMonetary,
    double? actualTime,
    bool? achieved,
    DateTime? dateAchieved,
    DateTime? dateCreated,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      strategyId: strategyId ?? this.strategyId,
      title: title ?? this.title,
      description: description ?? this.description,
      budgetMonetary: budgetMonetary ?? this.budgetMonetary,
      budgetTime: budgetTime ?? this.budgetTime,
      actualMonetary: actualMonetary ?? this.actualMonetary,
      actualTime: actualTime ?? this.actualTime,
      achieved: achieved ?? this.achieved,
      dateAchieved: dateAchieved ?? this.dateAchieved,
      dateCreated: dateCreated ?? this.dateCreated,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get budget variance (positive = under budget, negative = over budget)
  double get budgetVarianceMonetary => budgetMonetary - actualMonetary;

  /// Get time variance (positive = under time, negative = over time)
  double get budgetVarianceTime => budgetTime - actualTime;

  /// Get percentage of budget used (monetary)
  double get budgetUsedPercentageMonetary {
    if (budgetMonetary == 0) return 0.0;
    return (actualMonetary / budgetMonetary) * 100;
  }

  /// Get percentage of time used
  double get budgetUsedPercentageTime {
    if (budgetTime == 0) return 0.0;
    return (actualTime / budgetTime) * 100;
  }
}
