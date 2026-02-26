// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_strategy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserStrategy _$UserStrategyFromJson(Map<String, dynamic> json) => UserStrategy(
  id: json['id'] as String,
  userId: json['userId'] as String,
  name: json['name'] as String,
  strategyTypeId: json['strategyTypeId'] as String,
  description: json['description'] as String?,
  status: _strategyStatusFromJson(json['status'] as String),
  isDefault: json['isDefault'] as bool? ?? false,
  purpose: json['purpose'] as String?,
  valueCount: (json['valueCount'] as num?)?.toInt() ?? 0,
  currentVision: json['currentVision'] as String?,
  currentMission: json['currentMission'] as String?,
  createdAt: _dateTimeFromJson(json['createdAt']),
  updatedAt: _dateTimeFromJson(json['updatedAt']),
  archivedAt: _dateTimeFromJsonNullable(json['archivedAt']),
  displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$UserStrategyToJson(UserStrategy instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'name': instance.name,
      'strategyTypeId': instance.strategyTypeId,
      'description': instance.description,
      'status': _strategyStatusToJson(instance.status),
      'isDefault': instance.isDefault,
      'purpose': instance.purpose,
      'valueCount': instance.valueCount,
      'currentVision': instance.currentVision,
      'currentMission': instance.currentMission,
      'createdAt': _dateTimeToJson(instance.createdAt),
      'updatedAt': _dateTimeToJson(instance.updatedAt),
      'archivedAt': _dateTimeToJsonNullable(instance.archivedAt),
      'displayOrder': instance.displayOrder,
    };
