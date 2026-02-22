// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserValue _$UserValueFromJson(Map<String, dynamic> json) => UserValue(
  id: json['id'] as String,
  userId: json['userId'] as String,
  seedValue: json['seedValue'] as String,
  refinedLabel: json['refinedLabel'] as String,
  statement: json['statement'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  sessionId: json['sessionId'] as String?,
  creationContext: json['creationContext'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$UserValueToJson(UserValue instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'seedValue': instance.seedValue,
  'refinedLabel': instance.refinedLabel,
  'statement': instance.statement,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'sessionId': instance.sessionId,
  'creationContext': instance.creationContext,
};
