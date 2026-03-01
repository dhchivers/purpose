import 'package:flutter/material.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/features/value_profile/models/agent_question.dart';

/// Widget that displays a slider question for percentage-based input
/// 
/// Shows:
/// - Question number and text
/// - Question type badge
/// - Slider from 0-100%
/// - Current percentage and calculated dollar amount
/// - Optional reasoning (expandable)
class SliderQuestion extends StatefulWidget {
  final AgentQuestion question;
  final int questionNumber;
  final double? initialValue;
  final double? missionBudget;
  final Function(double) onValueChanged;
  final bool showReasoning;

  const SliderQuestion({
    Key? key,
    required this.question,
    required this.questionNumber,
    required this.onValueChanged,
    this.initialValue,
    this.missionBudget,
    this.showReasoning = false,
  }) : super(key: key);

  @override
  State<SliderQuestion> createState() => _SliderQuestionState();
}

class _SliderQuestionState extends State<SliderQuestion> {
  bool _showReasoning = false;
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _showReasoning = widget.showReasoning;
    _currentValue = widget.initialValue ?? 10.0; // Default to 10%
  }

  @override
  Widget build(BuildContext context) {
    final calculatedBudget = widget.missionBudget != null 
        ? widget.missionBudget! * (_currentValue / 100.0)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with question number and type
          Row(
            children: [
              // Question number badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Q${widget.questionNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Question type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[700]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green[700]!.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  'BUDGET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Reasoning toggle if available
              if (widget.question.reasoning != null && widget.question.reasoning!.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _showReasoning ? Icons.expand_less : Icons.info_outline,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _showReasoning = !_showReasoning;
                    });
                  },
                  tooltip: 'Why this question?',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Question text
          Text(
            widget.question.text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
              height: 1.4,
            ),
          ),

          // Reasoning (expandable)
          if (_showReasoning && widget.question.reasoning != null && widget.question.reasoning!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.question.reasoning ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Current value display
          Center(
            child: Column(
              children: [
                Text(
                  '${_currentValue.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                if (calculatedBudget != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '\$${_formatNumber(calculatedBudget.toInt())} per year',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: Colors.grey[300],
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 14,
                elevation: 4,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 24,
              ),
              valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
              valueIndicatorColor: AppTheme.primary,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Slider(
              value: _currentValue,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_currentValue.toStringAsFixed(0)}%',
              onChanged: (value) {
                setState(() {
                  _currentValue = value;
                });
                widget.onValueChanged(value);
              },
            ),
          ),

          const SizedBox(height: 8),

          // Min/Max labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Helpful context
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.green[200]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 16,
                  color: Colors.green[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Adjust the slider to set what percentage of your mission budget you want to dedicate to value preferences',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    // Add thousand separators
    final str = number.toString();
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(regex, (Match m) => '${m[1]},');
  }
}
