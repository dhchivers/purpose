import 'package:flutter/material.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/features/value_profile/models/agent_question.dart';
import 'package:purpose/features/value_profile/widgets/multiple_choice_question.dart';
import 'package:purpose/features/value_profile/widgets/slider_question.dart';
import 'package:purpose/features/value_profile/widgets/animated_widgets.dart';

/// Container widget that displays a list of questions with a submit button
/// 
/// Manages:
/// - Multiple question display (multiple choice and sliders)
/// - Answer selection tracking
/// - Submit button state
/// - Submission callback
class QuestionListContainer extends StatefulWidget {
  final List<AgentQuestion> questions;
  final Function(List<int>, Map<String, double>) onSubmit;
  final bool isProcessing;
  final String submitButtonText;
  final double? missionBudget;

  const QuestionListContainer({
    Key? key,
    required this.questions,
    required this.onSubmit,
    this.isProcessing = false,
    this.submitButtonText = 'Submit Answers',
    this.missionBudget,
  }) : super(key: key);

  @override
  State<QuestionListContainer> createState() => _QuestionListContainerState();
}

class _QuestionListContainerState extends State<QuestionListContainer> {
  // Map of question ID to selected option index (for multiple choice)
  final Map<String, int> _selectedAnswers = {};
  
  // Map of question ID to slider value (for slider questions)
  final Map<String, double> _sliderValues = {};

  @override
  void initState() {
    super.initState();
    _initializeAnswers();
  }

  @override
  void didUpdateWidget(QuestionListContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset answers if questions changed
    if (widget.questions != oldWidget.questions) {
      _initializeAnswers();
    }
  }

  void _initializeAnswers() {
    _selectedAnswers.clear();
    _sliderValues.clear();
    // Initialize with -1 (no selection) for each question
    for (final question in widget.questions) {
      if (_isSliderQuestion(question)) {
        // Initialize slider with default value (10%)
        _sliderValues[question.id] = 10.0;
      } else {
        _selectedAnswers[question.id] = -1;
      }
    }
  }
  
  bool _isSliderQuestion(AgentQuestion question) {
    // Slider questions have empty options array
    return question.options.isEmpty;
  }

  bool get _allQuestionsAnswered {
    for (final question in widget.questions) {
      if (_isSliderQuestion(question)) {
        // Slider questions are always "answered" since they have a default value
        continue;
      } else {
        if ((_selectedAnswers[question.id] ?? -1) < 0) {
          return false;
        }
      }
    }
    return true;
  }

  void _handleSubmit() {
    if (!_allQuestionsAnswered || widget.isProcessing) return;

    // Extract multiple choice answers in order of questions
    final answers = widget.questions
        .map((q) => _selectedAnswers[q.id] ?? -1)
        .toList();

    widget.onSubmit(answers, _sliderValues);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Questions
        ...List.generate(widget.questions.length, (index) {
          final question = widget.questions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FadeInSlideUp(
              delay: Duration(milliseconds: index * 100),
              child: _isSliderQuestion(question)
                  ? SliderQuestion(
                      question: question,
                      questionNumber: index + 1,
                      initialValue: _sliderValues[question.id],
                      missionBudget: widget.missionBudget,
                      onValueChanged: (value) {
                        setState(() {
                          _sliderValues[question.id] = value;
                        });
                      },
                    )
                  : MultipleChoiceQuestion(
                      question: question,
                      questionNumber: index + 1,
                      selectedOptionIndex: _selectedAnswers[question.id],
                      onOptionSelected: (optionIndex) {
                        setState(() {
                          _selectedAnswers[question.id] = optionIndex;
                        });
                      },
                    ),
            ),
          );
        }),

        const SizedBox(height: 8),

        // Progress indicator
        _buildProgressIndicator(),

        const SizedBox(height: 16),

        // Submit button
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.question_answer_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No questions yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a session to receive questions',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final answeredCount = _selectedAnswers.values.where((v) => v >= 0).length;
    final totalCount = widget.questions.length;
    final progress = totalCount > 0 ? answeredCount / totalCount : 0.0;

    return Row(
      children: [
        Icon(
          Icons.format_list_numbered,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          'Answered: $answeredCount / $totalCount',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _allQuestionsAnswered ? Colors.green[600]! : AppTheme.primary,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _allQuestionsAnswered && !widget.isProcessing
          ? _handleSubmit
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: _allQuestionsAnswered ? 2 : 0,
      ),
      child: widget.isProcessing
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Processing...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.send, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.submitButtonText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}
