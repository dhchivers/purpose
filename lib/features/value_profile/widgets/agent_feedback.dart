import 'package:flutter/material.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Widget that displays feedback/reasoning from the AI agent
/// 
/// Shows the AI's explanation of why certain questions are being asked
/// or what changes were made based on user answers.
class AgentFeedback extends StatelessWidget {
  final String feedback;
  final String title;
  final IconData icon;
  final bool isLoading;

  const AgentFeedback({
    Key? key,
    required this.feedback,
    this.title = 'Agent Feedback',
    this.icon = Icons.psychology,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryTintLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                icon,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          if (isLoading)
            _buildLoadingState()
          else if (feedback.isEmpty)
            _buildEmptyState()
          else
            _buildFeedbackText(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Analyzing your preferences...',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Text(
      'Answer questions to refine your value preferences. '
      'The agent will provide feedback as you progress.',
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey[600],
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildFeedbackText() {
    return Text(
      feedback,
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey[800],
        height: 1.5,
      ),
    );
  }
}

/// Compact version of AgentFeedback for smaller spaces
class AgentFeedbackCompact extends StatelessWidget {
  final String feedback;
  final bool isLoading;

  const AgentFeedbackCompact({
    Key? key,
    required this.feedback,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 16,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isLoading
                ? Text(
                    'Thinking...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Text(
                    feedback.isEmpty ? 'No feedback yet' : feedback,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}
