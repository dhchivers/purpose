// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'type_preference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TypePreference _$TypePreferenceFromJson(Map<String, dynamic> json) =>
    TypePreference(
      id: json['id'] as String,
      strategyTypeId: json['strategyTypeId'] as String,
      name: json['name'] as String,
      shortLabel: json['shortLabel'] as String,
      description: json['description'] as String,
      order: (json['order'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$TypePreferenceToJson(TypePreference instance) =>
    <String, dynamic>{
      'id': instance.id,
      'strategyTypeId': instance.strategyTypeId,
      'name': instance.name,
      'shortLabel': instance.shortLabel,
      'description': instance.description,
      'order': instance.order,
      'enabled': instance.enabled,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
