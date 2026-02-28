import 'package:json_annotation/json_annotation.dart';
import 'package:purpose/features/value_profile/models/question_answer.dart';

part 'agent_session.g.dart';

/// Represents an active value profile refinement session
/// Tracks the user's journey through the agent questioning process
@JsonSerializable(explicitToJson: true)
class AgentSession {
  /// Unique identifier for the session
  final String id;

  /// Reference to the strategy being refined
  final String strategyId;

  /// Reference to the strategy type
  final String strategyTypeId;

  /// When the session started
  final DateTime startedAt;

  /// When the session was last updated
  final DateTime updatedAt;

  /// Number of question iterations completed
  final int iterationCount;

  /// Whether the session is currently active
  final bool isActive;

  /// Whether the session has converged (stable)
  final bool isConverged;

  /// Initial relative weights when session started (preference name -> weight)
  final Map<String, double> initialWeights;

  /// Initial monetary factors when session started (preference name -> monetary)
  final Map<String, double> initialMonetary;

  /// Current relative weights (preference name -> weight)
  final Map<String, double> currentWeights;

  /// Current monetary factors (preference name -> monetary)
  final Map<String, double> currentMonetary;

  /// Maximum annual budget for all monetary dedications (null if not yet established)
  final double? maxAnnualBudget;

  /// History of all questions and answers in this session
  final List<QuestionAnswer> history;

  /// Current stability score (0.0 to 1.0)
  final double stabilityScore;

  AgentSession({
    required this.id,
    required this.strategyId,
    required this.strategyTypeId,
    required this.startedAt,
    required this.updatedAt,
    this.iterationCount = 0,
    this.isActive = true,
    this.isConverged = false,
    required this.initialWeights,
    required this.initialMonetary,
    required this.currentWeights,
    required this.currentMonetary,
    this.maxAnnualBudget,
    this.history = const [],
    this.stabilityScore = 0.0,
  });

  /// Create a copy with updated fields
  AgentSession copyWith({
    String? id,
    String? strategyId,
    String? strategyTypeId,
    DateTime? startedAt,
    DateTime? updatedAt,
    int? iterationCount,
    bool? isActive,
    bool? isConverged,
    Map<String, double>? initialWeights,
    Map<String, double>? initialMonetary,
    Map<String, double>? currentWeights,
    Map<String, double>? currentMonetary,
    double? maxAnnualBudget,
    List<QuestionAnswer>? history,
    double? stabilityScore,
  }) {
    return AgentSession(
      id: id ?? this.id,
      strategyId: strategyId ?? this.strategyId,
      strategyTypeId: strategyTypeId ?? this.strategyTypeId,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      iterationCount: iterationCount ?? this.iterationCount,
      isActive: isActive ?? this.isActive,
      isConverged: isConverged ?? this.isConverged,
      initialWeights: initialWeights ?? this.initialWeights,
      initialMonetary: initialMonetary ?? this.initialMonetary,
      currentWeights: currentWeights ?? this.currentWeights,
      currentMonetary: currentMonetary ?? this.currentMonetary,
      maxAnnualBudget: maxAnnualBudget ?? this.maxAnnualBudget,
      history: history ?? this.history,
      stabilityScore: stabilityScore ?? this.stabilityScore,
    );
  }

  /// Convert to JSON for Firestore storage
  Map<String, dynamic> toJson() => _$AgentSessionToJson(this);

  /// Create from Firestore JSON
  factory AgentSession.fromJson(Map<String, dynamic> json) =>
      _$AgentSessionFromJson(json);

  @override
  String toString() => 'AgentSession(id: $id, strategyId: $strategyId, '
      'iterations: $iterationCount, stability: $stabilityScore, '
      'converged: $isConverged)';
}
