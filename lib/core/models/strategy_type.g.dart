// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strategy_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StrategyType _$StrategyTypeFromJson(Map<String, dynamic> json) => StrategyType(
  id: json['id'] as String,
  name: json['name'] as String,
  enabled: json['enabled'] as bool,
  isDefault: json['isDefault'] as bool? ?? false,
  order: (json['order'] as num).toInt(),
  description: json['description'] as String?,
  color: (json['color'] as num?)?.toInt() ?? 0xFF2196F3,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$StrategyTypeToJson(StrategyType instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'enabled': instance.enabled,
      'isDefault': instance.isDefault,
      'order': instance.order,
      'description': instance.description,
      'color': instance.color,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
