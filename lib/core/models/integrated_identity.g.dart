// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'integrated_identity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IntegratedIdentity _$IntegratedIdentityFromJson(Map<String, dynamic> json) =>
    IntegratedIdentity(
      keyPatterns:
          (json['key_patterns'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tensions:
          (json['tensions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      summary: json['summary'] as String? ?? '',
    );

Map<String, dynamic> _$IntegratedIdentityToJson(IntegratedIdentity instance) =>
    <String, dynamic>{
      'key_patterns': instance.keyPatterns,
      'tensions': instance.tensions,
      'summary': instance.summary,
    };
