// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_mission_map.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserMissionMap _$UserMissionMapFromJson(Map<String, dynamic> json) =>
    UserMissionMap(
      id: json['id'] as String,
      userId: json['userId'] as String,
      missions: (json['missions'] as List<dynamic>)
          .map((e) => Mission.fromJson(e as Map<String, dynamic>))
          .toList(),
      sessionId: json['sessionId'] as String?,
      currentMissionIndex: (json['currentMissionIndex'] as num?)?.toInt(),
      strategyStartDate: json['strategyStartDate'] == null
          ? null
          : DateTime.parse(json['strategyStartDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$UserMissionMapToJson(UserMissionMap instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'missions': instance.missions.map((e) => e.toJson()).toList(),
      'sessionId': instance.sessionId,
      'currentMissionIndex': instance.currentMissionIndex,
      'strategyStartDate': instance.strategyStartDate?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
