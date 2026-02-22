import 'package:json_annotation/json_annotation.dart';

part 'purpose_option.g.dart';

/// A generated purpose statement option
@JsonSerializable()
class PurposeOption {
  /// Label for this option: "Direct", "Strategic", or "Visionary"
  @JsonKey(defaultValue: 'Unknown')
  final String label;

  /// The purpose statement text
  @JsonKey(defaultValue: '')
  final String statement;

  const PurposeOption({
    required this.label,
    required this.statement,
  });

  /// Creates a PurposeOption from JSON
  factory PurposeOption.fromJson(Map<String, dynamic> json) =>
      _$PurposeOptionFromJson(json);

  /// Converts PurposeOption to JSON
  Map<String, dynamic> toJson() => _$PurposeOptionToJson(this);

  /// Creates a copy with updated fields
  PurposeOption copyWith({
    String? label,
    String? statement,
  }) {
    return PurposeOption(
      label: label ?? this.label,
      statement: statement ?? this.statement,
    );
  }
}
