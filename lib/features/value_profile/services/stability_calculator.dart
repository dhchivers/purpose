import 'dart:math';
import 'package:purpose/features/value_profile/models/question_answer.dart';
import 'package:purpose/features/value_profile/models/stability_metrics.dart';
import 'package:purpose/features/value_profile/models/agent_question.dart';

/// Service for calculating stability metrics from question/answer history
/// 
/// Analyzes patterns in user responses and weight changes to determine
/// when preferences have converged to a stable, consistent state.
class StabilityCalculator {
  /// Convergence threshold - session is considered converged above this value
  static const double convergenceThreshold = 0.85;

  /// Calculate comprehensive stability metrics from answer history
  /// 
  /// Combines multiple scoring dimensions:
  /// - Weight volatility (30%): How much weights fluctuate
  /// - Answer consistency (30%): Agreement between similar questions
  /// - Convergence trend (20%): Improving stability over time
  /// - Weight-monetary alignment (20%): Values make sense together
  StabilityMetrics calculateStability({
    required List<QuestionAnswer> history,
    required Map<String, double> currentWeights,
    required Map<String, double> currentMonetary,
  }) {
    if (history.isEmpty) {
      return StabilityMetrics.initial();
    }

    // Calculate individual components
    final weightVolatility = _calculateWeightVolatility(history);
    final answerConsistency = _calculateAnswerConsistency(history);
    final convergenceTrend = _calculateConvergenceTrend(history);
    final alignment = _calculateWeightMonetaryAlignment(
      currentWeights,
      currentMonetary,
    );

    // Calculate per-preference stability
    final preferenceStability = _calculatePerPreferenceStability(
      history,
      currentWeights.keys.toList(),
    );

    // Count consistent answers
    final consistency = _countConsistentAnswers(history);

    // Calculate overall stability (weighted average)
    final overallStability = (
      weightVolatility * 0.30 +
      answerConsistency * 0.30 +
      convergenceTrend * 0.20 +
      alignment * 0.20
    ).clamp(0.0, 1.0);

    return StabilityMetrics(
      overallStability: overallStability,
      preferenceStability: preferenceStability,
      consistentAnswers: consistency['consistent']!,
      totalAnswers: consistency['total']!,
      convergenceThreshold: convergenceThreshold,
      trendDirection: _calculateTrendDirection(history),
      weightVolatility: 1.0 - weightVolatility, // Invert so higher = more volatile
      answerConsistency: answerConsistency,
      weightMonetaryAlignment: alignment,
    );
  }

  /// Calculate weight volatility score (0.0 to 1.0)
  /// Higher score = more stable (less volatility)
  /// 
  /// Measures how much weights change between iterations. Lower volatility
  /// indicates preferences are settling into stable values.
  double _calculateWeightVolatility(List<QuestionAnswer> history) {
    if (history.length < 2) return 0.0;

    // Calculate average absolute weight change per answer
    double totalChange = 0.0;
    int changeCount = 0;

    for (final answer in history) {
      for (final preferenceName in answer.weightsAfter.keys) {
        final change = answer.getWeightChange(preferenceName).abs();
        totalChange += change;
        changeCount++;
      }
    }

    if (changeCount == 0) return 1.0;

    // Average change per preference per question
    final avgChange = totalChange / changeCount;

    // Convert to stability score (lower change = higher stability)
    // Assume 0.10 (10%) average change = 0.0 stability
    // Assume 0.01 (1%) average change = 1.0 stability
    // Use exponential decay
    final volatilityScore = exp(-avgChange * 10);
    return volatilityScore.clamp(0.0, 1.0);
  }

  /// Calculate answer consistency score (0.0 to 1.0)
  /// Higher score = more consistent answers
  /// 
  /// Looks for similar question types and checks if the user's
  /// responses align logically with each other.
  double _calculateAnswerConsistency(List<QuestionAnswer> history) {
    if (history.length < 3) return 0.0;

    // Group questions by type
    final byType = <QuestionType, List<QuestionAnswer>>{};
    for (final answer in history) {
      byType.putIfAbsent(answer.questionType, () => []).add(answer);
    }

    double totalConsistency = 0.0;
    int comparisonCount = 0;

    // For each question type with multiple answers, check consistency
    for (final typeAnswers in byType.values) {
      if (typeAnswers.length < 2) continue;

      // Compare each pair of answers of the same type
      for (int i = 0; i < typeAnswers.length - 1; i++) {
        for (int j = i + 1; j < typeAnswers.length; j++) {
          final consistency = _compareAnswerPairConsistency(
            typeAnswers[i],
            typeAnswers[j],
          );
          totalConsistency += consistency;
          comparisonCount++;
        }
      }
    }

    if (comparisonCount == 0) return 0.5; // Neutral if can't compare

    return (totalConsistency / comparisonCount).clamp(0.0, 1.0);
  }

  /// Compare two answers for consistency
  /// Returns 0.0-1.0 indicating how well they align
  double _compareAnswerPairConsistency(
    QuestionAnswer answer1,
    QuestionAnswer answer2,
  ) {
    // Compare the direction of weight changes for overlapping preferences
    final prefs1 = answer1.weightsAfter.keys.toSet();
    final prefs2 = answer2.weightsAfter.keys.toSet();
    final overlap = prefs1.intersection(prefs2);

    if (overlap.isEmpty) return 0.5; // Can't compare, neutral

    double agreementScore = 0.0;
    for (final pref in overlap) {
      final change1 = answer1.getWeightChange(pref);
      final change2 = answer2.getWeightChange(pref);

      // If both changes are in the same direction, that's consistent
      if (change1.sign == change2.sign && change1 != 0 && change2 != 0) {
        agreementScore += 1.0;
      } else if (change1.abs() < 0.01 && change2.abs() < 0.01) {
        // Both stable = consistent
        agreementScore += 0.8;
      } else {
        // Opposite directions = inconsistent
        agreementScore += 0.0;
      }
    }

    return agreementScore / overlap.length;
  }

  /// Calculate convergence trend (0.0 to 1.0)
  /// Higher score = improving stability over time
  /// 
  /// Compares recent stability to earlier stability to detect
  /// if the user is converging toward consistent preferences.
  double _calculateConvergenceTrend(List<QuestionAnswer> history) {
    if (history.length < 5) return 0.5; // Not enough data

    // Split history into segments
    final recentCount = (history.length * 0.3).ceil().clamp(2, 10);
    final recentHistory = history.sublist(history.length - recentCount);
    final earlierHistory = history.sublist(0, history.length - recentCount);

    // Calculate volatility for each segment
    final recentVolatility = _calculateWeightVolatility(recentHistory);
    final earlierVolatility = _calculateWeightVolatility(earlierHistory);

    // Trend is positive if recent volatility is lower (more stable)
    // both are already 0-1 where higher = more stable
    if (earlierVolatility == 0) return recentVolatility;

    final improvement = recentVolatility - earlierVolatility;
    
    // Map improvement to 0-1 score
    // +0.3 improvement = 1.0 (excellent trend)
    // -0.3 degradation = 0.0 (poor trend)
    final trendScore = 0.5 + (improvement / 0.6);
    return trendScore.clamp(0.0, 1.0);
  }

  /// Calculate weight-monetary alignment (0.0 to 1.0)
  /// Higher score = values are consistent with each other
  /// 
  /// Checks if preferences with higher weights also have higher
  /// monetary values, indicating the user's values make sense.
  double _calculateWeightMonetaryAlignment(
    Map<String, double> weights,
    Map<String, double> monetary,
  ) {
    if (weights.isEmpty || monetary.isEmpty) return 0.0;

    // Sort preferences by weight
    final sortedByWeight = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sort preferences by monetary value
    final sortedByMonetary = monetary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Convert to preference name lists
    final weightOrder = sortedByWeight.map((e) => e.key).toList();
    final monetaryOrder = sortedByMonetary.map((e) => e.key).toList();

    // Calculate rank correlation (simplified Spearman's rho)
    double rankDiff = 0.0;
    for (int i = 0; i < weightOrder.length; i++) {
      final pref = weightOrder[i];
      final monetaryRank = monetaryOrder.indexOf(pref);
      if (monetaryRank >= 0) {
        rankDiff += (i - monetaryRank).abs();
      }
    }

    // Perfect correlation = 0 rank difference
    // Worst correlation = max possible rank difference
    final maxPossibleDiff = (weightOrder.length * (weightOrder.length - 1)) / 2;
    if (maxPossibleDiff == 0) return 1.0;

    final correlation = 1.0 - (rankDiff / maxPossibleDiff);
    return correlation.clamp(0.0, 1.0);
  }

  /// Calculate stability for each individual preference
  /// Returns map of preference name -> stability score (0.0-1.0)
  Map<String, double> _calculatePerPreferenceStability(
    List<QuestionAnswer> history,
    List<String> preferenceNames,
  ) {
    if (history.isEmpty) return {};

    final result = <String, double>{};

    for (final pref in preferenceNames) {
      // Calculate volatility for this specific preference
      double totalChange = 0.0;
      int changeCount = 0;

      for (final answer in history) {
        final change = answer.getWeightChange(pref).abs();
        totalChange += change;
        changeCount++;
      }

      if (changeCount == 0) {
        result[pref] = 0.0;
        continue;
      }

      final avgChange = totalChange / changeCount;
      // Convert to stability (lower change = higher stability)
      final stability = exp(-avgChange * 10).clamp(0.0, 1.0);
      result[pref] = stability;
    }

    return result;
  }

  /// Count consistent vs inconsistent answers
  /// Returns map with 'consistent' and 'total' keys
  Map<String, int> _countConsistentAnswers(List<QuestionAnswer> history) {
    if (history.length < 2) {
      return {'consistent': 0, 'total': history.length};
    }

    int consistentCount = 0;
    int totalComparisons = 0;

    // Compare each answer with subsequent answers
    for (int i = 0; i < history.length - 1; i++) {
      for (int j = i + 1; j < history.length; j++) {
        if (history[i].questionType != history[j].questionType) continue;

        final consistency = _compareAnswerPairConsistency(
          history[i],
          history[j],
        );

        totalComparisons++;
        if (consistency >= 0.7) {
          consistentCount++;
        }
      }
    }

    // If no comparisons possible, be optimistic
    if (totalComparisons == 0) {
      return {'consistent': history.length, 'total': history.length};
    }

    // Scale consistent count to answer count
    final ratio = consistentCount / totalComparisons;
    final scaledConsistent = (ratio * history.length).round();

    return {
      'consistent': scaledConsistent,
      'total': history.length,
    };
  }

  /// Calculate trend direction (positive = improving, negative = degrading)
  /// Returns value roughly in range -0.3 to +0.3
  double _calculateTrendDirection(List<QuestionAnswer> history) {
    if (history.length < 5) return 0.0;

    // Compare recent vs earlier stability
    final recentCount = (history.length * 0.3).ceil().clamp(2, 10);
    final recentHistory = history.sublist(history.length - recentCount);
    final earlierHistory = history.sublist(0, history.length - recentCount);

    final recentStability = _calculateWeightVolatility(recentHistory);
    final earlierStability = _calculateWeightVolatility(earlierHistory);

    return (recentStability - earlierStability).clamp(-0.5, 0.5);
  }

  /// Check if a session has converged (reached stable state)
  bool isConverged(StabilityMetrics metrics) {
    return metrics.overallStability >= convergenceThreshold;
  }

  /// Estimate how many more questions might be needed to converge
  /// Returns estimated question count, or null if already converged
  int? estimateQuestionsToConvergence(StabilityMetrics metrics) {
    if (metrics.isConverged) return null;

    final currentStability = metrics.overallStability;
    final remaining = convergenceThreshold - currentStability;

    // Assume roughly 0.10 stability gain per question (optimistic)
    // Adjust based on trend
    double gainPerQuestion = 0.10;
    if (metrics.trendDirection > 0) {
      gainPerQuestion = 0.12; // Improving trend
    } else if (metrics.trendDirection < 0) {
      gainPerQuestion = 0.07; // Degrading trend
    }

    final estimated = (remaining / gainPerQuestion).ceil();
    return estimated.clamp(1, 20); // Between 1 and 20 questions
  }
}
