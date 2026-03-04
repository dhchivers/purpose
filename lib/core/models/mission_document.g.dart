// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MissionDocument _$MissionDocumentFromJson(Map<String, dynamic> json) =>
    MissionDocument(
      id: json['id'] as String,
      missionMapId: json['missionMapId'] as String,
      strategyId: json['strategyId'] as String,
      sequenceNumber: (json['sequenceNumber'] as num).toInt(),
      mission: json['mission'] as String,
      missionSequence: json['missionSequence'] as String,
      focus: json['focus'] as String,
      structuralShift: json['structuralShift'] as String,
      capabilityRequired: json['capabilityRequired'] as String,
      riskOrValueGuardrail: json['riskOrValueGuardrail'] as String,
      timeHorizon: json['timeHorizon'] as String,
      riskLevel: $enumDecodeNullable(_$RiskLevelEnumMap, json['riskLevel']),
      durationMonths: (json['durationMonths'] as num?)?.toInt() ?? 12,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$MissionDocumentToJson(MissionDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'missionMapId': instance.missionMapId,
      'strategyId': instance.strategyId,
      'sequenceNumber': instance.sequenceNumber,
      'mission': instance.mission,
      'missionSequence': instance.missionSequence,
      'focus': instance.focus,
      'structuralShift': instance.structuralShift,
      'capabilityRequired': instance.capabilityRequired,
      'riskOrValueGuardrail': instance.riskOrValueGuardrail,
      'timeHorizon': instance.timeHorizon,
      'riskLevel': _$RiskLevelEnumMap[instance.riskLevel],
      'durationMonths': instance.durationMonths,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$RiskLevelEnumMap = {
  RiskLevel.low: 'low',
  RiskLevel.medium: 'medium',
  RiskLevel.high: 'high',
};
