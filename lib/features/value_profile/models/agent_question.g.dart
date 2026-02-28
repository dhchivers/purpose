// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentQuestion _$AgentQuestionFromJson(Map<String, dynamic> json) =>
    AgentQuestion(
      id: json['id'] as String,
      questionText: json['questionText'] as String,
      options: (json['options'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      type: $enumDecode(_$QuestionTypeEnumMap, json['type']),
      reasoning: json['reasoning'] as String? ?? '',
      relatedPreferences:
          (json['relatedPreferences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      expectedImpact: (json['expectedImpact'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$AgentQuestionToJson(AgentQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'questionText': instance.questionText,
      'options': instance.options,
      'type': _$QuestionTypeEnumMap[instance.type]!,
      'reasoning': instance.reasoning,
      'relatedPreferences': instance.relatedPreferences,
      'expectedImpact': instance.expectedImpact,
    };

const _$QuestionTypeEnumMap = {
  QuestionType.weightComparison: 'WEIGHT_COMPARISON',
  QuestionType.monetaryValue: 'MONETARY_VALUE',
  QuestionType.tradeoff: 'TRADEOFF',
  QuestionType.clarification: 'CLARIFICATION',
};
