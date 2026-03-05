// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_answer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserAnswer _$UserAnswerFromJson(Map<String, dynamic> json) => UserAnswer(
  id: json['id'] as String,
  userId: json['userId'] as String,
  strategyId: json['strategyId'] as String?,
  questionId: json['questionId'] as String,
  questionModuleId: json['questionModuleId'] as String,
  textAnswer: json['textAnswer'] as String?,
  numericAnswer: (json['numericAnswer'] as num?)?.toDouble(),
  selectedOption: json['selectedOption'] as String?,
  booleanAnswer: json['booleanAnswer'] as bool?,
  notes: json['notes'] as String?,
  processedByAI: json['processedByAI'] as bool? ?? false,
  aiResponse: json['aiResponse'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserAnswerToJson(UserAnswer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'strategyId': instance.strategyId,
      'questionId': instance.questionId,
      'questionModuleId': instance.questionModuleId,
      'textAnswer': instance.textAnswer,
      'numericAnswer': instance.numericAnswer,
      'selectedOption': instance.selectedOption,
      'booleanAnswer': instance.booleanAnswer,
      'notes': instance.notes,
      'processedByAI': instance.processedByAI,
      'aiResponse': instance.aiResponse,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
