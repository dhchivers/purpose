// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vision_creation_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VisionOption _$VisionOptionFromJson(Map<String, dynamic> json) => VisionOption(
  label: json['label'] as String,
  statement: json['statement'] as String,
);

Map<String, dynamic> _$VisionOptionToJson(VisionOption instance) =>
    <String, dynamic>{'label': instance.label, 'statement': instance.statement};

VisionCreationSession _$VisionCreationSessionFromJson(
  Map<String, dynamic> json,
) => VisionCreationSession(
  id: json['id'] as String,
  userId: json['userId'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  timeframeYears: (json['timeframeYears'] as num?)?.toInt(),
  meaningfulChange: json['meaningfulChange'] as String?,
  influenceScale: $enumDecodeNullable(
    _$InfluenceScaleEnumMap,
    json['influenceScale'],
  ),
  roleDescription: json['roleDescription'] as String?,
  purposeStatement: json['purposeStatement'] as String?,
  coreValues: (json['coreValues'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  visionOptions: (json['visionOptions'] as List<dynamic>?)
      ?.map((e) => VisionOption.fromJson(e as Map<String, dynamic>))
      .toList(),
  selectedOptionIndex: (json['selectedOptionIndex'] as num?)?.toInt(),
  customStatement: json['customStatement'] as String?,
);

Map<String, dynamic> _$VisionCreationSessionToJson(
  VisionCreationSession instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'startedAt': instance.startedAt.toIso8601String(),
  'completedAt': instance.completedAt?.toIso8601String(),
  'timeframeYears': instance.timeframeYears,
  'meaningfulChange': instance.meaningfulChange,
  'influenceScale': _$InfluenceScaleEnumMap[instance.influenceScale],
  'roleDescription': instance.roleDescription,
  'purposeStatement': instance.purposeStatement,
  'coreValues': instance.coreValues,
  'visionOptions': instance.visionOptions?.map((e) => e.toJson()).toList(),
  'selectedOptionIndex': instance.selectedOptionIndex,
  'customStatement': instance.customStatement,
};

const _$InfluenceScaleEnumMap = {
  InfluenceScale.individuals: 'individuals',
  InfluenceScale.organizations: 'organizations',
  InfluenceScale.institutions: 'institutions',
  InfluenceScale.systems: 'systems',
};
