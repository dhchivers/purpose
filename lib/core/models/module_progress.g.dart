// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'module_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModuleProgress _$ModuleProgressFromJson(Map<String, dynamic> json) =>
    ModuleProgress(
      questionModuleId: json['questionModuleId'] as String,
      answeredQuestions: (json['answeredQuestions'] as num).toInt(),
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      isCompleted: json['isCompleted'] as bool,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ModuleProgressToJson(ModuleProgress instance) =>
    <String, dynamic>{
      'questionModuleId': instance.questionModuleId,
      'answeredQuestions': instance.answeredQuestions,
      'totalQuestions': instance.totalQuestions,
      'isCompleted': instance.isCompleted,
      'startedAt': instance.startedAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
