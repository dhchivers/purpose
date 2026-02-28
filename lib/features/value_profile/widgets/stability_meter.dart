import 'package:flutter/material.dart';
import 'package:purpose/features/value_profile/models/stability_metrics.dart';

/// Widget that displays the current stability status with a visual progress bar
/// 
/// Shows:
/// - Overall stability percentage
/// - Status message (Converged, Converging, Refining, Exploring)
/// - Trend indicator (improving, stable, degrading)
/// - Consistency ratio
class StabilityMeter extends StatelessWidget {
  final StabilityMetrics metrics;
  final bool showDetails;

  const StabilityMeter({
    Key? key,
    required this.metrics,
    this.showDetails = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row with title and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stability',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    metrics.statusMessage,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    metrics.trendEmoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          Stack(
            children: [
              // Background
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Progress fill
              FractionallySizedBox(
                widthFactor: metrics.overallStability.clamp(0.0, 1.0),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: _getProgressColor(),
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        _getProgressColor(),
                        _getProgressColor().withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),
              // Percentage text overlay
              Container(
                height: 24,
                alignment: Alignment.center,
                child: Text(
                  '${metrics.stabilityPercentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: metrics.overallStability > 0.3
                        ? Colors.white
                        : Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),

          // Details section
          if (showDetails) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              'Consistency',
              '${metrics.consistentAnswers}/${metrics.totalAnswers} answers',
              Icons.check_circle_outline,
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              'Volatility',
              _formatVolatility(metrics.weightVolatility),
              Icons.trending_down,
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              'Alignment',
              '${(metrics.weightMonetaryAlignment * 100).toStringAsFixed(0)}%',
              Icons.balance,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _getBackgroundColor() {
    if (metrics.isConverged) {
      return Colors.green[50]!;
    } else if (metrics.overallStability >= 0.70) {
      return Colors.blue[50]!;
    } else if (metrics.overallStability >= 0.40) {
      return Colors.orange[50]!;
    } else {
      return Colors.grey[50]!;
    }
  }

  Color _getBorderColor() {
    if (metrics.isConverged) {
      return Colors.green[300]!;
    } else if (metrics.overallStability >= 0.70) {
      return Colors.blue[300]!;
    } else if (metrics.overallStability >= 0.40) {
      return Colors.orange[300]!;
    } else {
      return Colors.grey[300]!;
    }
  }

  Color _getStatusColor() {
    if (metrics.isConverged) {
      return Colors.green[700]!;
    } else if (metrics.overallStability >= 0.70) {
      return Colors.blue[700]!;
    } else if (metrics.overallStability >= 0.40) {
      return Colors.orange[700]!;
    } else {
      return Colors.grey[700]!;
    }
  }

  Color _getProgressColor() {
    if (metrics.isConverged) {
      return Colors.green[600]!;
    } else if (metrics.overallStability >= 0.70) {
      return Colors.blue[600]!;
    } else if (metrics.overallStability >= 0.40) {
      return Colors.orange[600]!;
    } else {
      return Colors.grey[600]!;
    }
  }

  IconData _getStatusIcon() {
    if (metrics.isConverged) {
      return Icons.check_circle;
    } else if (metrics.overallStability >= 0.70) {
      return Icons.loop;
    } else if (metrics.overallStability >= 0.40) {
      return Icons.tune;
    } else {
      return Icons.explore;
    }
  }

  String _formatVolatility(double volatility) {
    if (volatility < 0.3) {
      return 'Very stable';
    } else if (volatility < 0.5) {
      return 'Stable';
    } else if (volatility < 0.7) {
      return 'Moderate';
    } else {
      return 'High';
    }
  }
}
