import 'package:flutter/material.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/features/value_profile/models/agent_question.dart';

/// Widget that displays a multiple-choice question with selectable options
/// 
/// Shows:
/// - Question number and text
/// - Question type badge
/// - Radio button options
/// - Optional reasoning (expandable)
class MultipleChoiceQuestion extends StatefulWidget {
  final AgentQuestion question;
  final int questionNumber;
  final int? selectedOptionIndex;
  final Function(int) onOptionSelected;
  final bool showReasoning;

  const MultipleChoiceQuestion({
    Key? key,
    required this.question,
    required this.questionNumber,
    required this.onOptionSelected,
    this.selectedOptionIndex,
    this.showReasoning = false,
  }) : super(key: key);

  @override
  State<MultipleChoiceQuestion> createState() => _MultipleChoiceQuestionState();
}

class _MultipleChoiceQuestionState extends State<MultipleChoiceQuestion> {
  bool _showReasoning = false;

  @override
  void initState() {
    super.initState();
    _showReasoning = widget.showReasoning;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.selectedOptionIndex != null
              ? AppTheme.primary.withOpacity(0.5)
              : Colors.grey[300]!,
          width: widget.selectedOptionIndex != null ? 2 : 1,
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
                  color: _getTypeColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getTypeColor().withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getTypeLabel(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getTypeColor(),
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Reasoning toggle if available
              if (widget.question.reasoning.isNotEmpty)
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
            widget.question.questionText,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
              height: 1.4,
            ),
          ),

          // Reasoning (expandable)
          if (_showReasoning && widget.question.reasoning.isNotEmpty) ...[
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
                      widget.question.reasoning,
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

          const SizedBox(height: 16),

          // Options
          ...List.generate(widget.question.options.length, (index) {
            return _buildOption(index);
          }),
        ],
      ),
    );
  }

  Widget _buildOption(int index) {
    final isSelected = widget.selectedOptionIndex == index;
    final option = widget.question.options[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => widget.onOptionSelected(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Radio button
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primary : Colors.white,
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Option text
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? AppTheme.primary : Colors.grey[800],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (widget.question.type) {
      case QuestionType.weightComparison:
        return Colors.blue[700]!;
      case QuestionType.monetaryValue:
        return Colors.green[700]!;
      case QuestionType.tradeoff:
        return Colors.orange[700]!;
      case QuestionType.clarification:
        return Colors.purple[700]!;
    }
  }

  String _getTypeLabel() {
    switch (widget.question.type) {
      case QuestionType.weightComparison:
        return 'COMPARISON';
      case QuestionType.monetaryValue:
        return 'MONETARY';
      case QuestionType.tradeoff:
        return 'TRADEOFF';
      case QuestionType.clarification:
        return 'CLARIFICATION';
    }
  }
}
