// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission_map.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MissionMap _$MissionMapFromJson(Map<String, dynamic> json) => MissionMap(
  id: json['id'] as String,
  strategyId: json['strategyId'] as String,
  sessionId: json['sessionId'] as String?,
  currentMissionIndex: (json['currentMissionIndex'] as num?)?.toInt(),
  totalMissions: (json['totalMissions'] as num).toInt(),
  strategyStartDate: json['strategyStartDate'] == null
      ? null
      : DateTime.parse(json['strategyStartDate'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$MissionMapToJson(MissionMap instance) =>
    <String, dynamic>{
      'id': instance.id,
      'strategyId': instance.strategyId,
      'sessionId': instance.sessionId,
      'currentMissionIndex': instance.currentMissionIndex,
      'totalMissions': instance.totalMissions,
      'strategyStartDate': instance.strategyStartDate?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
