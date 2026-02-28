import 'package:flutter/material.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/features/value_profile/models/agent_question.dart';
import 'package:purpose/features/value_profile/models/stability_metrics.dart';
import 'package:purpose/features/value_profile/widgets/stability_meter.dart';
import 'package:purpose/features/value_profile/widgets/agent_feedback.dart';
import 'package:purpose/features/value_profile/widgets/question_list_container.dart';
import 'package:purpose/features/value_profile/widgets/animated_widgets.dart';

/// Composite widget that combines all agent UI components
/// 
/// This is the main interface for the AI-powered preference refinement agent,
/// displayed in the right column of the Value Profile page.
class AgentPanel extends StatelessWidget {
  final StabilityMetrics stability;
  final String feedback;
  final List<AgentQuestion> questions;
  final Function(List<int>, Map<String, double>) onSubmitAnswers;
  final VoidCallback? onStartSession;
  final VoidCallback? onEndSession;
  final bool isProcessing;
  final bool hasActiveSession;
  final double? maxAnnualBudget;
  final Map<String, double>? currentMonetary;
  final double? missionBudget;

  const AgentPanel({
    Key? key,
    required this.stability,
    required this.feedback,
    required this.questions,
    required this.onSubmitAnswers,
    this.onStartSession,
    this.onEndSession,
    this.isProcessing = false,
    this.hasActiveSession = false,
    this.maxAnnualBudget,
    this.currentMonetary,
    this.missionBudget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stability meter
                  if (hasActiveSession) ...[
                    FadeInSlideUp(
                      child: StabilityMeter(
                        metrics: stability,
                        showDetails: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Budget utilization
                  if (hasActiveSession && maxAnnualBudget != null) ...[
                    FadeInSlideUp(
                      delay: const Duration(milliseconds: 50),
                      child: _buildBudgetUtilization(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Agent feedback
                  if (hasActiveSession || feedback.isNotEmpty) ...[
                    FadeInSlideUp(
                      delay: const Duration(milliseconds: 100),
                      child: AgentFeedback(
                        feedback: feedback,
                        isLoading: isProcessing && questions.isEmpty,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Questions
                  if (hasActiveSession)
                    QuestionListContainer(
                      questions: questions,
                      onSubmit: onSubmitAnswers,
                      isProcessing: isProcessing,
                      missionBudget: missionBudget,
                    )
                  else
                    _buildStartPrompt(),

                  // End session button (if converged)
                  if (hasActiveSession && stability.isConverged) ...[
                    const SizedBox(height: 16),
                    _buildEndSessionButton(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryTintLight,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.psychology,
            color: AppTheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Value Refinement Agent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  hasActiveSession
                      ? 'Answer questions to refine your preferences'
                      : 'AI-powered preference optimization',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (hasActiveSession && !stability.isConverged && onEndSession != null)
            TextButton(
              onPressed: onEndSession,
              child: const Text('Pause'),
            ),
        ],
      ),
    );
  }

  Widget _buildStartPrompt() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: AppTheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ready to Refine Your Values?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'The AI agent will ask you thoughtful questions to help '
            'clarify and optimize your value preferences and monetary factors.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onStartSession,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Refinement Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  size: 20,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Answer honestly - there are no wrong answers. '
                    'The agent learns from your choices.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
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

  Widget _buildBudgetUtilization() {
    if (maxAnnualBudget == null) return const SizedBox.shrink();
    
    final currentTotal = currentMonetary?.values.fold(0.0, (sum, val) => sum + val) ?? 0.0;
    final utilization = (currentTotal / maxAnnualBudget!) * 100.0;
    final remaining = maxAnnualBudget! - currentTotal;
    
    // Color based on utilization
    Color progressColor;
    if (utilization > 95) {
      progressColor = Colors.red[600]!;
    } else if (utilization > 80) {
      progressColor = Colors.orange[600]!;
    } else {
      progressColor = Colors.green[600]!;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 18,
                color: progressColor,
              ),
              const SizedBox(width: 8),
              const Text(
                'Annual Budget',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '\$${maxAnnualBudget!.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: utilization / 100.0,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allocated',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${currentTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Remaining',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${remaining.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: remaining < 0 ? Colors.red[600] : Colors.grey[800],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${utilization.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEndSessionButton() {
    return ElevatedButton.icon(
      onPressed: onEndSession,
      icon: const Icon(Icons.check_circle),
      label: const Text('Complete Session'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Placeholder widget shown when agent is not active
class AgentPlaceholder extends StatelessWidget {
  final VoidCallback? onActivate;

  const AgentPlaceholder({
    Key? key,
    this.onActivate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              'AI Agent Ready',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Use the agent to refine your\nvalue preferences through AI-guided questions',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (onActivate != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onActivate,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Activate Agent'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
