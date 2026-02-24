// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission_creation_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Mission _$MissionFromJson(Map<String, dynamic> json) => Mission(
  mission: json['mission'] as String,
  missionSequence: json['missionSequence'] as String,
  focus: json['focus'] as String,
  structuralShift: json['structuralShift'] as String,
  capabilityRequired: json['capabilityRequired'] as String,
  riskOrValueGuardrail: json['riskOrValueGuardrail'] as String,
  timeHorizon: json['timeHorizon'] as String,
  riskLevel: $enumDecodeNullable(_$RiskLevelEnumMap, json['riskLevel']),
  durationMonths: (json['durationMonths'] as num?)?.toInt() ?? 12,
);

Map<String, dynamic> _$MissionToJson(Mission instance) => <String, dynamic>{
  'mission': instance.mission,
  'missionSequence': instance.missionSequence,
  'focus': instance.focus,
  'structuralShift': instance.structuralShift,
  'capabilityRequired': instance.capabilityRequired,
  'riskOrValueGuardrail': instance.riskOrValueGuardrail,
  'timeHorizon': instance.timeHorizon,
  'riskLevel': _$RiskLevelEnumMap[instance.riskLevel],
  'durationMonths': instance.durationMonths,
};

const _$RiskLevelEnumMap = {
  RiskLevel.low: 'low',
  RiskLevel.medium: 'medium',
  RiskLevel.high: 'high',
};

MissionCreationSession _$MissionCreationSessionFromJson(
  Map<String, dynamic> json,
) => MissionCreationSession(
  id: json['id'] as String,
  userId: json['userId'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  purposeStatement: json['purposeStatement'] as String?,
  coreValues: (json['coreValues'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  visionStatement: json['visionStatement'] as String?,
  visionTimeframeYears: (json['visionTimeframeYears'] as num?)?.toInt(),
  currentBuilding: json['currentBuilding'] as String?,
  currentScale: json['currentScale'] as String?,
  currentAuthority: json['currentAuthority'] as String?,
  visionInfluenceScale: json['visionInfluenceScale'] as String?,
  visionEnvironment: json['visionEnvironment'] as String?,
  visionResponsibility: json['visionResponsibility'] as String?,
  visionMeasurableChange: json['visionMeasurableChange'] as String?,
  constraintValues: (json['constraintValues'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  nonNegotiableCommitments: json['nonNegotiableCommitments'] as String?,
  riskTolerance: json['riskTolerance'] as String?,
  missionMap: (json['missionMap'] as List<dynamic>?)
      ?.map((e) => Mission.fromJson(e as Map<String, dynamic>))
      .toList(),
  selectedMissionIndex: (json['selectedMissionIndex'] as num?)?.toInt(),
);

Map<String, dynamic> _$MissionCreationSessionToJson(
  MissionCreationSession instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'startedAt': instance.startedAt.toIso8601String(),
  'completedAt': instance.completedAt?.toIso8601String(),
  'purposeStatement': instance.purposeStatement,
  'coreValues': instance.coreValues,
  'visionStatement': instance.visionStatement,
  'visionTimeframeYears': instance.visionTimeframeYears,
  'currentBuilding': instance.currentBuilding,
  'currentScale': instance.currentScale,
  'currentAuthority': instance.currentAuthority,
  'visionInfluenceScale': instance.visionInfluenceScale,
  'visionEnvironment': instance.visionEnvironment,
  'visionResponsibility': instance.visionResponsibility,
  'visionMeasurableChange': instance.visionMeasurableChange,
  'constraintValues': instance.constraintValues,
  'nonNegotiableCommitments': instance.nonNegotiableCommitments,
  'riskTolerance': instance.riskTolerance,
  'missionMap': instance.missionMap?.map((e) => e.toJson()).toList(),
  'selectedMissionIndex': instance.selectedMissionIndex,
};
