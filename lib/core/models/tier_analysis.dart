import 'package:json_annotation/json_annotation.dart';

part 'tier_analysis.g.dart';

/// Analysis results for a single tier (question module)
@JsonSerializable()
class TierAnalysis {
  /// Name of the tier being analyzed
  @JsonKey(name: 'tier_name', defaultValue: '')
  final String tierName;

  /// Dominant patterns identified in this tier
  @JsonKey(name: 'dominant_features', defaultValue: [])
  final List<String> dominantFeatures;

  /// Secondary patterns or themes
  @JsonKey(name: 'secondary_features', defaultValue: [])
  final List<String> secondaryFeatures;

  /// Contradictions or tensions detected
  @JsonKey(name: 'tensions_detected', defaultValue: [])
  final List<String> tensionsDetected;

  /// Signal strength: "Low", "Moderate", or "High"
  @JsonKey(name: 'signal_strength', defaultValue: 'Moderate')
  final String signalStrength;

  /// Numeric confidence score (0.0-1.0)
  @JsonKey(name: 'confidence_score', defaultValue: 0.5)
  final double confidenceScore;

  /// Concise summary paragraph for this tier
  @JsonKey(defaultValue: '')
  final String summary;

  const TierAnalysis({
    required this.tierName,
    required this.dominantFeatures,
    required this.secondaryFeatures,
    required this.tensionsDetected,
    required this.signalStrength,
    required this.confidenceScore,
    required this.summary,
  });

  /// Creates a TierAnalysis from JSON
  factory TierAnalysis.fromJson(Map<String, dynamic> json) =>
      _$TierAnalysisFromJson(json);

  /// Converts TierAnalysis to JSON
  Map<String, dynamic> toJson() => _$TierAnalysisToJson(this);

  /// Creates a copy with updated fields
  TierAnalysis copyWith({
    String? tierName,
    List<String>? dominantFeatures,
    List<String>? secondaryFeatures,
    List<String>? tensionsDetected,
    String? signalStrength,
    double? confidenceScore,
    String? summary,
  }) {
    return TierAnalysis(
      tierName: tierName ?? this.tierName,
      dominantFeatures: dominantFeatures ?? this.dominantFeatures,
      secondaryFeatures: secondaryFeatures ?? this.secondaryFeatures,
      tensionsDetected: tensionsDetected ?? this.tensionsDetected,
      signalStrength: signalStrength ?? this.signalStrength,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      summary: summary ?? this.summary,
    );
  }
}
