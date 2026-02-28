// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentSession _$AgentSessionFromJson(Map<String, dynamic> json) => AgentSession(
  id: json['id'] as String,
  strategyId: json['strategyId'] as String,
  strategyTypeId: json['strategyTypeId'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  iterationCount: (json['iterationCount'] as num?)?.toInt() ?? 0,
  isActive: json['isActive'] as bool? ?? true,
  isConverged: json['isConverged'] as bool? ?? false,
  initialWeights: (json['initialWeights'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
  initialMonetary: (json['initialMonetary'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
  currentWeights: (json['currentWeights'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
  currentMonetary: (json['currentMonetary'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
  maxAnnualBudget: (json['maxAnnualBudget'] as num?)?.toDouble(),
  history:
      (json['history'] as List<dynamic>?)
          ?.map((e) => QuestionAnswer.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  stabilityScore: (json['stabilityScore'] as num?)?.toDouble() ?? 0.0,
);

Map<String, dynamic> _$AgentSessionToJson(AgentSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'strategyId': instance.strategyId,
      'strategyTypeId': instance.strategyTypeId,
      'startedAt': instance.startedAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'iterationCount': instance.iterationCount,
      'isActive': instance.isActive,
      'isConverged': instance.isConverged,
      'initialWeights': instance.initialWeights,
      'initialMonetary': instance.initialMonetary,
      'currentWeights': instance.currentWeights,
      'currentMonetary': instance.currentMonetary,
      'maxAnnualBudget': instance.maxAnnualBudget,
      'history': instance.history.map((e) => e.toJson()).toList(),
      'stabilityScore': instance.stabilityScore,
    };
