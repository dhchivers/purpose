// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purpose_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PurposeOption _$PurposeOptionFromJson(Map<String, dynamic> json) =>
    PurposeOption(
      label: json['label'] as String? ?? 'Unknown',
      statement: json['statement'] as String? ?? '',
    );

Map<String, dynamic> _$PurposeOptionToJson(PurposeOption instance) =>
    <String, dynamic>{'label': instance.label, 'statement': instance.statement};
