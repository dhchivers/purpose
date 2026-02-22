import 'package:json_annotation/json_annotation.dart';

part 'module_progress.g.dart';

/// Tracks a user's progress through a question module
@JsonSerializable()
class ModuleProgress {
  /// ID of the question module
  final String questionModuleId;

  /// Number of questions answered
  final int answeredQuestions;

  /// Total number of questions in the module
  final int totalQuestions;

  /// Whether all questions have been answered
  final bool isCompleted;

  /// When the user started this module
  final DateTime startedAt;

  /// When the user completed this module (null if not completed)
  final DateTime? completedAt;

  /// When this progress was last updated
  final DateTime updatedAt;

  const ModuleProgress({
    required this.questionModuleId,
    required this.answeredQuestions,
    required this.totalQuestions,
    required this.isCompleted,
    required this.startedAt,
    this.completedAt,
    required this.updatedAt,
  });

  /// Creates a ModuleProgress from JSON
  factory ModuleProgress.fromJson(Map<String, dynamic> json) =>
      _$ModuleProgressFromJson(json);

  /// Converts ModuleProgress to JSON
  Map<String, dynamic> toJson() => _$ModuleProgressToJson(this);

  /// Calculate completion percentage
  double get completionPercentage {
    if (totalQuestions == 0) return 0.0;
    return (answeredQuestions / totalQuestions) * 100;
  }

  /// Creates a copy with updated fields
  ModuleProgress copyWith({
    String? questionModuleId,
    int? answeredQuestions,
    int? totalQuestions,
    bool? isCompleted,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return ModuleProgress(
      questionModuleId: questionModuleId ?? this.questionModuleId,
      answeredQuestions: answeredQuestions ?? this.answeredQuestions,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      isCompleted: isCompleted ?? this.isCompleted,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create initial progress for a new module
  factory ModuleProgress.initial({
    required String questionModuleId,
    required int totalQuestions,
  }) {
    final now = DateTime.now();
    return ModuleProgress(
      questionModuleId: questionModuleId,
      answeredQuestions: 0,
      totalQuestions: totalQuestions,
      isCompleted: false,
      startedAt: now,
      updatedAt: now,
    );
  }
}
