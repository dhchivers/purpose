// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_vision.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserVision _$UserVisionFromJson(Map<String, dynamic> json) => UserVision(
  id: json['id'] as String,
  userId: json['userId'] as String,
  timeframeYears: (json['timeframeYears'] as num).toInt(),
  visionStatement: json['visionStatement'] as String,
  sessionId: json['sessionId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserVisionToJson(UserVision instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'timeframeYears': instance.timeframeYears,
      'visionStatement': instance.visionStatement,
      'sessionId': instance.sessionId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
