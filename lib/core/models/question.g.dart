// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Question _$QuestionFromJson(Map<String, dynamic> json) => Question(
  id: json['id'] as String,
  questionModuleId: json['questionModuleId'] as String,
  questionText: json['questionText'] as String,
  helperText: json['helperText'] as String?,
  questionType: Question._questionTypeFromJson(json['questionType'] as String),
  options: (json['options'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  allowMultipleSelections: json['allowMultipleSelections'] as bool?,
  scaleMin: (json['scaleMin'] as num?)?.toInt(),
  scaleMax: (json['scaleMax'] as num?)?.toInt(),
  scaleLabels: (json['scaleLabels'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  answerCharacterLimit: (json['answerCharacterLimit'] as num?)?.toInt(),
  order: (json['order'] as num).toInt(),
  isRequired: json['isRequired'] as bool? ?? true,
  isActive: json['isActive'] as bool? ?? true,
  aiPromptTemplate: json['aiPromptTemplate'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$QuestionToJson(Question instance) => <String, dynamic>{
  'id': instance.id,
  'questionModuleId': instance.questionModuleId,
  'questionText': instance.questionText,
  'helperText': instance.helperText,
  'questionType': Question._questionTypeToJson(instance.questionType),
  'options': instance.options,
  'allowMultipleSelections': instance.allowMultipleSelections,
  'scaleMin': instance.scaleMin,
  'scaleMax': instance.scaleMax,
  'scaleLabels': instance.scaleLabels,
  'answerCharacterLimit': instance.answerCharacterLimit,
  'order': instance.order,
  'isRequired': instance.isRequired,
  'isActive': instance.isActive,
  'aiPromptTemplate': instance.aiPromptTemplate,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
