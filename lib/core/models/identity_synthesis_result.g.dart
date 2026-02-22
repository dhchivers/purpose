// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_synthesis_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IdentitySynthesisResult _$IdentitySynthesisResultFromJson(
  Map<String, dynamic> json,
) => IdentitySynthesisResult(
  id: json['id'] as String,
  userId: json['userId'] as String,
  tierAnalysis: (json['tierAnalysis'] as List<dynamic>)
      .map((e) => TierAnalysis.fromJson(e as Map<String, dynamic>))
      .toList(),
  integratedIdentity: IntegratedIdentity.fromJson(
    json['integratedIdentity'] as Map<String, dynamic>,
  ),
  purposeOptions: (json['purposeOptions'] as List<dynamic>)
      .map((e) => PurposeOption.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: IdentitySynthesisResult._dateTimeFromJson(json['createdAt']),
  answersHash: json['answersHash'] as String,
  selectedOptionIndex: (json['selectedOptionIndex'] as num?)?.toInt(),
  editedStatement: json['editedStatement'] as String?,
  isPromoted: json['isPromoted'] as bool? ?? false,
);

Map<String, dynamic> _$IdentitySynthesisResultToJson(
  IdentitySynthesisResult instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'tierAnalysis': instance.tierAnalysis.map((e) => e.toJson()).toList(),
  'integratedIdentity': instance.integratedIdentity.toJson(),
  'purposeOptions': instance.purposeOptions.map((e) => e.toJson()).toList(),
  'createdAt': IdentitySynthesisResult._dateTimeToJson(instance.createdAt),
  'answersHash': instance.answersHash,
  'selectedOptionIndex': instance.selectedOptionIndex,
  'editedStatement': instance.editedStatement,
  'isPromoted': instance.isPromoted,
};
