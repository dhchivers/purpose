// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Goal _$GoalFromJson(Map<String, dynamic> json) => Goal(
  id: json['id'] as String,
  missionId: json['missionId'] as String,
  strategyId: json['strategyId'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  budgetMonetary: (json['budgetMonetary'] as num?)?.toDouble() ?? 0.0,
  budgetTime: (json['budgetTime'] as num?)?.toDouble() ?? 0.0,
  actualMonetary: (json['actualMonetary'] as num?)?.toDouble() ?? 0.0,
  actualTime: (json['actualTime'] as num?)?.toDouble() ?? 0.0,
  achieved: json['achieved'] as bool? ?? false,
  dateAchieved: json['dateAchieved'] == null
      ? null
      : DateTime.parse(json['dateAchieved'] as String),
  dateCreated: DateTime.parse(json['dateCreated'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$GoalToJson(Goal instance) => <String, dynamic>{
  'id': instance.id,
  'missionId': instance.missionId,
  'strategyId': instance.strategyId,
  'title': instance.title,
  'description': instance.description,
  'budgetMonetary': instance.budgetMonetary,
  'budgetTime': instance.budgetTime,
  'actualMonetary': instance.actualMonetary,
  'actualTime': instance.actualTime,
  'achieved': instance.achieved,
  'dateAchieved': instance.dateAchieved?.toIso8601String(),
  'dateCreated': instance.dateCreated.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
