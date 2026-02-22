// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tier_analysis.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TierAnalysis _$TierAnalysisFromJson(Map<String, dynamic> json) => TierAnalysis(
  tierName: json['tier_name'] as String? ?? '',
  dominantFeatures:
      (json['dominant_features'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  secondaryFeatures:
      (json['secondary_features'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  tensionsDetected:
      (json['tensions_detected'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  signalStrength: json['signal_strength'] as String? ?? 'Moderate',
  confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.5,
  summary: json['summary'] as String? ?? '',
);

Map<String, dynamic> _$TierAnalysisToJson(TierAnalysis instance) =>
    <String, dynamic>{
      'tier_name': instance.tierName,
      'dominant_features': instance.dominantFeatures,
      'secondary_features': instance.secondaryFeatures,
      'tensions_detected': instance.tensionsDetected,
      'signal_strength': instance.signalStrength,
      'confidence_score': instance.confidenceScore,
      'summary': instance.summary,
    };
