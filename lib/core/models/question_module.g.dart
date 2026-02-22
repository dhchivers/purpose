// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question_module.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuestionModule _$QuestionModuleFromJson(Map<String, dynamic> json) =>
    QuestionModule(
      id: json['id'] as String,
      parentModule: QuestionModule._moduleTypeFromJson(
        json['parentModule'] as String,
      ),
      name: json['name'] as String,
      description: json['description'] as String,
      order: (json['order'] as num).toInt(),
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      isActive: json['isActive'] as bool? ?? true,
      measureName: json['measureName'] as String?,
      measureDescription: json['measureDescription'] as String?,
      maxMeasureValue: json['maxMeasureValue'] as String?,
      agentPrompt: json['agentPrompt'] as String?,
      agentResponse: json['agentResponse'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$QuestionModuleToJson(QuestionModule instance) =>
    <String, dynamic>{
      'id': instance.id,
      'parentModule': QuestionModule._moduleTypeToJson(instance.parentModule),
      'name': instance.name,
      'description': instance.description,
      'order': instance.order,
      'totalQuestions': instance.totalQuestions,
      'isActive': instance.isActive,
      'measureName': instance.measureName,
      'measureDescription': instance.measureDescription,
      'maxMeasureValue': instance.maxMeasureValue,
      'agentPrompt': instance.agentPrompt,
      'agentResponse': instance.agentResponse,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
