// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'value_creation_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MultipleChoiceQuestion _$MultipleChoiceQuestionFromJson(
  Map<String, dynamic> json,
) => MultipleChoiceQuestion(
  question: json['question'] as String,
  options: (json['options'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$MultipleChoiceQuestionToJson(
  MultipleChoiceQuestion instance,
) => <String, dynamic>{
  'question': instance.question,
  'options': instance.options,
};

ValueCreationSession _$ValueCreationSessionFromJson(
  Map<String, dynamic> json,
) => ValueCreationSession(
  id: json['id'] as String,
  userId: json['userId'] as String,
  seedValue: json['seedValue'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  currentPhase: (json['currentPhase'] as num?)?.toInt() ?? 1,
  phase2Questions: (json['phase2Questions'] as List<dynamic>?)
      ?.map((e) => MultipleChoiceQuestion.fromJson(e as Map<String, dynamic>))
      .toList(),
  phase2Answers: (json['phase2Answers'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  phase3Questions: (json['phase3Questions'] as List<dynamic>?)
      ?.map((e) => MultipleChoiceQuestion.fromJson(e as Map<String, dynamic>))
      .toList(),
  phase3Answers: (json['phase3Answers'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  refinedValuePhase3: json['refinedValuePhase3'] as String?,
  phase4Questions: (json['phase4Questions'] as List<dynamic>?)
      ?.map((e) => MultipleChoiceQuestion.fromJson(e as Map<String, dynamic>))
      .toList(),
  phase4Answers: (json['phase4Answers'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  refinedValuePhase4: json['refinedValuePhase4'] as String?,
  phase5Questions: (json['phase5Questions'] as List<dynamic>?)
      ?.map((e) => MultipleChoiceQuestion.fromJson(e as Map<String, dynamic>))
      .toList(),
  phase5Answers: (json['phase5Answers'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  finalValueOptions: (json['finalValueOptions'] as List<dynamic>?)
      ?.map((e) => ValueOption.fromJson(e as Map<String, dynamic>))
      .toList(),
  selectedOptionIndex: (json['selectedOptionIndex'] as num?)?.toInt(),
  customStatement: json['customStatement'] as String?,
);

Map<String, dynamic> _$ValueCreationSessionToJson(
  ValueCreationSession instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'seedValue': instance.seedValue,
  'startedAt': instance.startedAt.toIso8601String(),
  'completedAt': instance.completedAt?.toIso8601String(),
  'currentPhase': instance.currentPhase,
  'phase2Questions': instance.phase2Questions?.map((e) => e.toJson()).toList(),
  'phase2Answers': instance.phase2Answers,
  'phase3Questions': instance.phase3Questions?.map((e) => e.toJson()).toList(),
  'phase3Answers': instance.phase3Answers,
  'refinedValuePhase3': instance.refinedValuePhase3,
  'phase4Questions': instance.phase4Questions?.map((e) => e.toJson()).toList(),
  'phase4Answers': instance.phase4Answers,
  'refinedValuePhase4': instance.refinedValuePhase4,
  'phase5Questions': instance.phase5Questions?.map((e) => e.toJson()).toList(),
  'phase5Answers': instance.phase5Answers,
  'finalValueOptions': instance.finalValueOptions
      ?.map((e) => e.toJson())
      .toList(),
  'selectedOptionIndex': instance.selectedOptionIndex,
  'customStatement': instance.customStatement,
};

ValueOption _$ValueOptionFromJson(Map<String, dynamic> json) => ValueOption(
  label: json['label'] as String,
  statement: json['statement'] as String,
);

Map<String, dynamic> _$ValueOptionToJson(ValueOption instance) =>
    <String, dynamic>{'label': instance.label, 'statement': instance.statement};
