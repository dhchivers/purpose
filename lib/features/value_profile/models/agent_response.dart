import 'package:json_annotation/json_annotation.dart';
import 'package:purpose/features/value_profile/models/agent_question.dart';

part 'agent_response.g.dart';

/// Response from the AI agent containing questions and reasoning
@JsonSerializable(explicitToJson: true)
class AgentResponse {
  /// Brief explanation (3-5 sentences) of why these questions are being asked
  final String reasoning;

  /// List of questions to present (1-3 questions)
  final List<AgentQuestion> questions;

  /// Suggested next steps if needed
  final String? nextSteps;

  AgentResponse({
    required this.reasoning,
    required this.questions,
    this.nextSteps,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$AgentResponseToJson(this);

  /// Create from JSON
  factory AgentResponse.fromJson(Map<String, dynamic> json) =>
      _$AgentResponseFromJson(json);

  @override
  String toString() => 'AgentResponse(questions: ${questions.length})';
}

/// Refinement calculated by the AI after processing user answers
@JsonSerializable()
class AgentRefinement {
  /// Updated preference weights (preference name -> weight 0.0-1.0)
  final Map<String, double> updatedWeights;

  /// Updated monetary factors (preference name -> monetary value)
  final Map<String, double> updatedMonetary;

  /// Explanation of the changes made (2-3 sentences)
  final String explanation;

  /// Confidence in these updates (0.0 to 1.0)
  final double confidence;

  /// Which preferences were most affected
  final List<String> affectedPreferences;

  AgentRefinement({
    required this.updatedWeights,
    required this.updatedMonetary,
    required this.explanation,
    this.confidence = 0.5,
    this.affectedPreferences = const [],
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$AgentRefinementToJson(this);

  /// Create from JSON
  factory AgentRefinement.fromJson(Map<String, dynamic> json) =>
      _$AgentRefinementFromJson(json);

  @override
  String toString() => 'AgentRefinement(affected: ${affectedPreferences.length}, '
      'confidence: $confidence)';
}
