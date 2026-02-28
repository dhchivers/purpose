import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/features/value_profile/models/agent_session.dart';
import 'package:purpose/features/value_profile/models/agent_question.dart';
import 'package:purpose/features/value_profile/models/question_answer.dart';
import 'package:purpose/features/value_profile/models/stability_metrics.dart';
import 'package:purpose/features/value_profile/services/value_profile_agent_service.dart';
import 'package:purpose/features/value_profile/services/stability_calculator.dart';

/// Provider for the current active agent session
/// Null if no session is active
final agentSessionProvider = StateProvider<AgentSession?>((ref) => null);

/// Provider for the current questions being presented to the user
final agentQuestionsProvider = StateProvider<List<AgentQuestion>>((ref) => []);

/// Provider for the question/answer history
final questionHistoryProvider = StateProvider<List<QuestionAnswer>>((ref) => []);

/// Provider for the current stability metrics
final agentStabilityProvider = StateProvider<StabilityMetrics>((ref) {
  return StabilityMetrics.initial();
});

/// Provider for tracking if the agent is currently processing (loading state)
final agentProcessingProvider = StateProvider<bool>((ref) => false);

/// Provider for the current agent feedback/reasoning text
final agentFeedbackProvider = StateProvider<String>((ref) => '');

/// Provider for selected answers (question ID -> option index)
final selectedAnswersProvider = StateProvider<Map<String, int>>((ref) => {});

/// Provider for the ValueProfileAgentService instance
/// This service handles AI-powered preference refinement
final valueProfileAgentServiceProvider = FutureProvider<ValueProfileAgentService>((ref) async {
  final geminiService = await ref.watch(geminiServiceProvider.future);
  return ValueProfileAgentService(geminiService);
});

/// Provider for the StabilityCalculator instance
/// This service calculates stability metrics from answer history
final stabilityCalculatorProvider = Provider<StabilityCalculator>((ref) {
  return StabilityCalculator();
});
