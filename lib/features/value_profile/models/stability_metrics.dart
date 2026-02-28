/// Represents the stability and convergence status of an agent session
class StabilityMetrics {
  /// Overall stability score (0.0 to 1.0)
  /// 1.0 = fully stable/converged
  final double overallStability;

  /// Stability score for each individual preference (preference name -> score)
  final Map<String, double> preferenceStability;

  /// Number of answers that are consistent with previous answers
  final int consistentAnswers;

  /// Total number of answers given
  final int totalAnswers;

  /// Whether the session has converged (stable enough to finish)
  final bool isConverged;

  /// Convergence threshold used (typically 0.85)
  final double convergenceThreshold;

  /// Trend indicator: positive = improving, negative = degrading, zero = stable
  final double trendDirection;

  /// Weight volatility (lower is better) - average change per iteration
  final double weightVolatility;

  /// Answer consistency score (0.0 to 1.0)
  final double answerConsistency;

  /// How well aligned weights and monetary values are (0.0 to 1.0)
  final double weightMonetaryAlignment;

  StabilityMetrics({
    required this.overallStability,
    this.preferenceStability = const {},
    this.consistentAnswers = 0,
    this.totalAnswers = 0,
    this.convergenceThreshold = 0.85,
    this.trendDirection = 0.0,
    this.weightVolatility = 0.0,
    this.answerConsistency = 0.0,
    this.weightMonetaryAlignment = 0.0,
  }) : isConverged = overallStability >= convergenceThreshold;

  /// Get consistency percentage (0-100)
  double get consistencyPercentage {
    if (totalAnswers == 0) return 0.0;
    return (consistentAnswers / totalAnswers) * 100;
  }

  /// Get stability percentage (0-100)
  double get stabilityPercentage => overallStability * 100;

  /// Get a human-readable status message
  String get statusMessage {
    if (isConverged) {
      return 'Converged ✓';
    } else if (overallStability >= 0.70) {
      return 'Converging... 🔄';
    } else if (overallStability >= 0.40) {
      return 'Refining... ⚙️';
    } else {
      return 'Exploring... 🔍';
    }
  }

  /// Get trend indicator emoji
  String get trendEmoji {
    if (trendDirection > 0.05) return '↗️';
    if (trendDirection < -0.05) return '↘️';
    return '→';
  }

  /// Create a copy with updated fields
  StabilityMetrics copyWith({
    double? overallStability,
    Map<String, double>? preferenceStability,
    int? consistentAnswers,
    int? totalAnswers,
    double? convergenceThreshold,
    double? trendDirection,
    double? weightVolatility,
    double? answerConsistency,
    double? weightMonetaryAlignment,
  }) {
    return StabilityMetrics(
      overallStability: overallStability ?? this.overallStability,
      preferenceStability: preferenceStability ?? this.preferenceStability,
      consistentAnswers: consistentAnswers ?? this.consistentAnswers,
      totalAnswers: totalAnswers ?? this.totalAnswers,
      convergenceThreshold: convergenceThreshold ?? this.convergenceThreshold,
      trendDirection: trendDirection ?? this.trendDirection,
      weightVolatility: weightVolatility ?? this.weightVolatility,
      answerConsistency: answerConsistency ?? this.answerConsistency,
      weightMonetaryAlignment: weightMonetaryAlignment ?? this.weightMonetaryAlignment,
    );
  }

  /// Create a default/initial stability metrics
  factory StabilityMetrics.initial() {
    return StabilityMetrics(
      overallStability: 0.0,
      preferenceStability: {},
      consistentAnswers: 0,
      totalAnswers: 0,
      convergenceThreshold: 0.85,
      trendDirection: 0.0,
      weightVolatility: 0.0,
      answerConsistency: 0.0,
      weightMonetaryAlignment: 0.0,
    );
  }

  @override
  String toString() => 'StabilityMetrics(overall: $overallStability, '
      'converged: $isConverged, trend: $trendDirection)';
}
