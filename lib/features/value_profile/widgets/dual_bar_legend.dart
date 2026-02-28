import 'package:flutter/material.dart';

/// Legend showing what each bar color represents
class DualBarLegend extends StatelessWidget {
  const DualBarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendItem(
            color: Colors.blue[700]!,
            label: 'Relative Weight (%)',
          ),
          const SizedBox(width: 24),
          _LegendItem(
            color: Colors.green[700]!,
            label: 'Monetary Factor (\$/year)',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

/// Dual Y-axis labels for the chart
class DualYAxisLabels extends StatelessWidget {
  final double monetaryMax;

  const DualYAxisLabels({
    super.key,
    required this.monetaryMax,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Row(
        children: [
          // Left axis - Percentage (0-100%)
          _YAxisLabels(
            values: ['100%', '75%', '50%', '25%', '0%'],
            color: Colors.blue[700]!,
            isLeft: true,
          ),
          const SizedBox(width: 8),
          
          // Spacer for chart
          const Expanded(child: SizedBox()),
          
          const SizedBox(width: 8),
          // Right axis - Monetary
          _YAxisLabels(
            values: [
              _formatMonetary(monetaryMax),
              _formatMonetary(monetaryMax * 0.75),
              _formatMonetary(monetaryMax * 0.5),
              _formatMonetary(monetaryMax * 0.25),
              '\$0',
            ],
            color: Colors.green[700]!,
            isLeft: false,
          ),
        ],
      ),
    );
  }

  static String _formatMonetary(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(0)}K';
    } else {
      return '\$${value.toStringAsFixed(0)}';
    }
  }
}

class _YAxisLabels extends StatelessWidget {
  final List<String> values;
  final Color color;
  final bool isLeft;

  const _YAxisLabels({
    required this.values,
    required this.color,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: values.map((value) {
          return Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          );
        }).toList(),
      ),
    );
  }
}
