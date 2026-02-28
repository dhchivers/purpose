// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentResponse _$AgentResponseFromJson(Map<String, dynamic> json) =>
    AgentResponse(
      reasoning: json['reasoning'] as String,
      questions: (json['questions'] as List<dynamic>)
          .map((e) => AgentQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextSteps: json['nextSteps'] as String?,
    );

Map<String, dynamic> _$AgentResponseToJson(AgentResponse instance) =>
    <String, dynamic>{
      'reasoning': instance.reasoning,
      'questions': instance.questions.map((e) => e.toJson()).toList(),
      'nextSteps': instance.nextSteps,
    };

AgentRefinement _$AgentRefinementFromJson(Map<String, dynamic> json) =>
    AgentRefinement(
      updatedWeights: (json['updatedWeights'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      updatedMonetary: (json['updatedMonetary'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      explanation: json['explanation'] as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      affectedPreferences:
          (json['affectedPreferences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$AgentRefinementToJson(AgentRefinement instance) =>
    <String, dynamic>{
      'updatedWeights': instance.updatedWeights,
      'updatedMonetary': instance.updatedMonetary,
      'explanation': instance.explanation,
      'confidence': instance.confidence,
      'affectedPreferences': instance.affectedPreferences,
    };
