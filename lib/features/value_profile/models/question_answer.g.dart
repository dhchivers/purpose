// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question_answer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuestionAnswer _$QuestionAnswerFromJson(Map<String, dynamic> json) =>
    QuestionAnswer(
      questionId: json['questionId'] as String,
      questionText: json['questionText'] as String,
      questionType: $enumDecode(_$QuestionTypeEnumMap, json['questionType']),
      selectedOption: json['selectedOption'] as String,
      optionIndex: (json['optionIndex'] as num).toInt(),
      answeredAt: DateTime.parse(json['answeredAt'] as String),
      weightsBefore: (json['weightsBefore'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      weightsAfter: (json['weightsAfter'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      monetaryBefore: (json['monetaryBefore'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      monetaryAfter: (json['monetaryAfter'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      stabilityAtAnswer: (json['stabilityAtAnswer'] as num?)?.toDouble() ?? 0.0,
      explanation: json['explanation'] as String?,
    );

Map<String, dynamic> _$QuestionAnswerToJson(QuestionAnswer instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'questionText': instance.questionText,
      'questionType': _$QuestionTypeEnumMap[instance.questionType]!,
      'selectedOption': instance.selectedOption,
      'optionIndex': instance.optionIndex,
      'answeredAt': instance.answeredAt.toIso8601String(),
      'weightsBefore': instance.weightsBefore,
      'weightsAfter': instance.weightsAfter,
      'monetaryBefore': instance.monetaryBefore,
      'monetaryAfter': instance.monetaryAfter,
      'stabilityAtAnswer': instance.stabilityAtAnswer,
      'explanation': instance.explanation,
    };

const _$QuestionTypeEnumMap = {
  QuestionType.weightComparison: 'WEIGHT_COMPARISON',
  QuestionType.monetaryValue: 'MONETARY_VALUE',
  QuestionType.tradeoff: 'TRADEOFF',
  QuestionType.clarification: 'CLARIFICATION',
};
