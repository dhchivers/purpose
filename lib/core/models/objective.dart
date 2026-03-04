import 'package:json_annotation/json_annotation.dart';

part 'objective.g.dart';

/// Represents an objective linked to a specific goal
/// Objectives are the specific, measurable actions required to achieve a goal
@JsonSerializable(explicitToJson: true)
class Objective {
  final String id;
  final String goalId; // Reference to parent Goal
  final String missionId; // Denormalized for easier querying
  final String strategyId; // Denormalized for easier querying
  final String title;
  final String description;
  final String measurableRequirement; // The specific metric/requirement to measure success
  final DateTime? dueDate; // Target completion date (nullable)
  final double costMonetary; // Actual cost in monetary units
  final double costTime; // Actual time spent in hours/days
  final bool achieved; // Completion status
  final DateTime? dateAchieved; // When the objective was achieved (null if not achieved)
  final DateTime dateCreated;
  final DateTime updatedAt;

  Objective({
    required this.id,
    required this.goalId,
    required this.missionId,
    required this.strategyId,
    required this.title,
    required this.description,
    required this.measurableRequirement,
    this.dueDate,
    this.costMonetary = 0.0,
    this.costTime = 0.0,
    this.achieved = false,
    this.dateAchieved,
    required this.dateCreated,
    required this.updatedAt,
  });

  factory Objective.fromJson(Map<String, dynamic> json) =>
      _$ObjectiveFromJson(json);

  Map<String, dynamic> toJson() => _$ObjectiveToJson(this);

  Objective copyWith({
    String? id,
    String? goalId,
    String? missionId,
    String? strategyId,
    String? title,
    String? description,
    String? measurableRequirement,
    DateTime? dueDate,
    double? costMonetary,
    double? costTime,
    bool? achieved,
    DateTime? dateAchieved,
    DateTime? dateCreated,
    DateTime? updatedAt,
  }) {
    return Objective(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      missionId: missionId ?? this.missionId,
      strategyId: strategyId ?? this.strategyId,
      title: title ?? this.title,
      description: description ?? this.description,
      measurableRequirement: measurableRequirement ?? this.measurableRequirement,
      dueDate: dueDate ?? this.dueDate,
      costMonetary: costMonetary ?? this.costMonetary,
      costTime: costTime ?? this.costTime,
      achieved: achieved ?? this.achieved,
      dateAchieved: dateAchieved ?? this.dateAchieved,
      dateCreated: dateCreated ?? this.dateCreated,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if objective is overdue
  bool get isOverdue {
    if (dueDate == null || achieved) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Get days until due date (negative if overdue)
  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }
}
