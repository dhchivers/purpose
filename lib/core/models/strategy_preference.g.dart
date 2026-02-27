// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strategy_preference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StrategyPreference _$StrategyPreferenceFromJson(Map<String, dynamic> json) =>
    StrategyPreference(
      id: json['id'] as String,
      strategyId: json['strategyId'] as String,
      name: json['name'] as String,
      shortLabel: json['shortLabel'] as String,
      description: json['description'] as String,
      relativeWeight: (json['relativeWeight'] as num).toDouble(),
      monetaryFactorPerYear: (json['monetaryFactorPerYear'] as num).toDouble(),
      order: (json['order'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$StrategyPreferenceToJson(StrategyPreference instance) =>
    <String, dynamic>{
      'id': instance.id,
      'strategyId': instance.strategyId,
      'name': instance.name,
      'shortLabel': instance.shortLabel,
      'description': instance.description,
      'relativeWeight': instance.relativeWeight,
      'monetaryFactorPerYear': instance.monetaryFactorPerYear,
      'order': instance.order,
      'enabled': instance.enabled,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
