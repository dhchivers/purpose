// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'objective.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Objective _$ObjectiveFromJson(Map<String, dynamic> json) => Objective(
  id: json['id'] as String,
  goalId: json['goalId'] as String,
  missionId: json['missionId'] as String,
  strategyId: json['strategyId'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  measurableRequirement: json['measurableRequirement'] as String,
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  costMonetary: (json['costMonetary'] as num?)?.toDouble() ?? 0.0,
  costTime: (json['costTime'] as num?)?.toDouble() ?? 0.0,
  achieved: json['achieved'] as bool? ?? false,
  dateAchieved: json['dateAchieved'] == null
      ? null
      : DateTime.parse(json['dateAchieved'] as String),
  dateCreated: DateTime.parse(json['dateCreated'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$ObjectiveToJson(Objective instance) => <String, dynamic>{
  'id': instance.id,
  'goalId': instance.goalId,
  'missionId': instance.missionId,
  'strategyId': instance.strategyId,
  'title': instance.title,
  'description': instance.description,
  'measurableRequirement': instance.measurableRequirement,
  'dueDate': instance.dueDate?.toIso8601String(),
  'costMonetary': instance.costMonetary,
  'costTime': instance.costTime,
  'achieved': instance.achieved,
  'dateAchieved': instance.dateAchieved?.toIso8601String(),
  'dateCreated': instance.dateCreated.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
