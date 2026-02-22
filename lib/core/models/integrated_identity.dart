import 'package:json_annotation/json_annotation.dart';

part 'integrated_identity.g.dart';

/// Cross-tier identity integration results
@JsonSerializable()
class IntegratedIdentity {
  /// Key patterns identified across all tiers
  @JsonKey(name: 'key_patterns', defaultValue: [])
  final List<String> keyPatterns;

  /// Cross-tier tensions or contradictions
  @JsonKey(defaultValue: [])
  final List<String> tensions;

  /// Identity architecture summary paragraph (3-5 sentences)
  @JsonKey(defaultValue: '')
  final String summary;

  const IntegratedIdentity({
    required this.keyPatterns,
    required this.tensions,
    required this.summary,
  });

  /// Creates an IntegratedIdentity from JSON
  factory IntegratedIdentity.fromJson(Map<String, dynamic> json) =>
      _$IntegratedIdentityFromJson(json);

  /// Converts IntegratedIdentity to JSON
  Map<String, dynamic> toJson() => _$IntegratedIdentityToJson(this);

  /// Creates a copy with updated fields
  IntegratedIdentity copyWith({
    List<String>? keyPatterns,
    List<String>? tensions,
    String? summary,
  }) {
    return IntegratedIdentity(
      keyPatterns: keyPatterns ?? this.keyPatterns,
      tensions: tensions ?? this.tensions,
      summary: summary ?? this.summary,
    );
  }
}
