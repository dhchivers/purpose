import 'dart:convert';
import 'package:purpose/core/services/gemini_service.dart';
import 'package:purpose/core/models/type_preference.dart';
import 'package:purpose/features/value_profile/models/agent_question.dart';
import 'package:purpose/features/value_profile/models/agent_response.dart';
import 'package:purpose/features/value_profile/models/question_answer.dart';
import 'package:purpose/features/value_profile/models/stability_metrics.dart';

/// Service for AI-powered refinement of preference weights and monetary values
class ValueProfileAgentService {
  final GeminiService _geminiService;

  ValueProfileAgentService(this._geminiService);

  /// Generate questions to refine preference weights and monetary values
  /// 
  /// Uses AI to analyze current values and history to generate insightful
  /// multiple-choice questions that reveal true priorities and resolve inconsistencies.
  Future<AgentResponse> generateQuestions({
    required List<TypePreference> preferences,
    required Map<String, double> currentWeights,
    required Map<String, double> currentMonetary,
    required List<QuestionAnswer> history,
    required StabilityMetrics stability,
    double? maxAnnualBudget,
    double? missionBudget,
    String? missionName,
  }) async {
    try {
      // Budget is now set via the slider in the UI, so skip budget question

      // Build the prompt for question generation
      final prompt = _buildQuestionPrompt(
        preferences: preferences,
        currentWeights: currentWeights,
        currentMonetary: currentMonetary,
        history: history,
        stability: stability,
        maxAnnualBudget: maxAnnualBudget ?? 25000.0, // Default if not set
      );

      // Make AI request with structured JSON output
      final response = await _geminiService.generateStructuredResponse(
        prompt: prompt,
        systemPrompt: _getSystemPrompt(),
        model: 'gpt-4o',  // Use GPT-4 for better reasoning
      );

      // Parse the JSON response
      final jsonData = jsonDecode(response);
      return AgentResponse.fromJson(jsonData);
    } catch (e) {
      print('Error generating questions: $e');
      // Return fallback questions on error
      return _getFallbackQuestions(preferences);
    }
  }

  /// Process user answers and calculate refined weights/monetary values
  /// 
  /// Analyzes the user's selected options and updates the preference
  /// values accordingly, ensuring mathematical consistency.
  Future<AgentRefinement> processAnswers({
    required List<TypePreference> preferences,
    required List<AgentQuestion> questions,
    required List<int> selectedOptionIndices,
    required Map<String, double> currentWeights,
    required Map<String, double> currentMonetary,
    required List<QuestionAnswer> history,
    double? maxAnnualBudget,
  }) async {
    try {
      // Build the prompt for refinement calculation
      final prompt = _buildRefinementPrompt(
        preferences: preferences,
        questions: questions,
        selectedOptionIndices: selectedOptionIndices,
        currentWeights: currentWeights,
        currentMonetary: currentMonetary,
        history: history,
        maxAnnualBudget: maxAnnualBudget,
      );

      // Make AI request with structured JSON output
      final response = await _geminiService.generateStructuredResponse(
        prompt: prompt,
        systemPrompt: _getRefinementSystemPrompt(),
        model: 'gpt-4o',
      );

      // Parse the JSON response
      final jsonData = jsonDecode(response);
      return AgentRefinement.fromJson(jsonData);
    } catch (e) {
      print('Error processing answers: $e');
      // Return conservative refinement on error
      return _getConservativeRefinement(
        currentWeights: currentWeights,
        currentMonetary: currentMonetary,
      );
    }
  }

  /// Build the system prompt for question generation
  String _getSystemPrompt() {
    return '''You are an expert preference elicitation agent. Your role is to help users 
accurately define their value preferences through thoughtful multiple-choice questions.

Your questions should:
1. Reveal true priorities through comparisons and tradeoffs
2. Clarify monetary valuations in concrete terms
3. Resolve contradictions in previous answers
4. Be clear, specific, and realistic
5. Present 3-4 meaningful options per question

Generate 1-3 questions that will most effectively refine the user's preferences.
Provide brief reasoning explaining why these questions matter.

Respond with valid JSON matching this structure:
{
  "reasoning": "Brief explanation (3-5 sentences) of why these questions are important",
  "questions": [
    {
      "id": "unique_question_id",
      "questionText": "Clear, specific question text",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "reasoning": "Why this question helps clarify preferences",
      "type": "WEIGHT_COMPARISON" | "MONETARY_VALUE" | "TRADEOFF" | "CLARIFICATION",
      "relatedPreferences": ["PreferenceName1", "PreferenceName2"]
    }
  ],
  "nextSteps": "Optional guidance for what comes next"
}''';
  }

  /// Build the system prompt for refinement calculation
  String _getRefinementSystemPrompt() {
    return '''You are a mathematical preference refinement engine. Your role is to calculate
updated preference weights and monetary values based on user answers.

Your calculations must:
1. Ensure all weights sum exactly to 1.0
2. Keep monetary values realistic and consistent with weights
3. Make gradual changes (max 15% shift per iteration)
4. Maintain mathematical coherence in tradeoffs
5. Respect the maximum annual budget constraint (sum of all monetary values must not exceed it)
6. Provide clear explanations of changes

Respond with valid JSON matching this structure:
{
  "updatedWeights": {"PreferenceName": 0.0-1.0, ...},
  "updatedMonetary": {"PreferenceName": number, ...},
  "explanation": "Brief explanation of changes (2-3 sentences)",
  "confidence": 0.0-1.0,
  "affectedPreferences": ["PreferenceName", ...]
}''';
  }

  /// Build the prompt for question generation
  String _buildQuestionPrompt({
    required List<TypePreference> preferences,
    required Map<String, double> currentWeights,
    required Map<String, double> currentMonetary,
    required List<QuestionAnswer> history,
    required StabilityMetrics stability,
    required double maxAnnualBudget,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('# Current Preference Values\n');
    
    double totalMonetary = 0.0;
    for (final pref in preferences) {
      final weight = currentWeights[pref.name] ?? 0.0;
      final monetary = currentMonetary[pref.name] ?? 0.0;
      totalMonetary += monetary;
      buffer.writeln('**${pref.name}** (${pref.shortLabel})');
      buffer.writeln('- Weight: ${(weight * 100).toStringAsFixed(1)}%');
      buffer.writeln('- Monetary: \$${monetary.toStringAsFixed(0)}/year');
      buffer.writeln('- Description: ${pref.description}');
      buffer.writeln();
    }

    buffer.writeln('\n# Budget Information\n');
    buffer.writeln('- Maximum Annual Budget: \$${maxAnnualBudget.toStringAsFixed(0)}');
    buffer.writeln('- Current Total Allocation: \$${totalMonetary.toStringAsFixed(0)}');
    buffer.writeln('- Remaining: \$${(maxAnnualBudget - totalMonetary).toStringAsFixed(0)}');
    buffer.writeln('- Utilization: ${((totalMonetary / maxAnnualBudget) * 100).toStringAsFixed(1)}%');

    buffer.writeln('\n# Stability Status\n');
    buffer.writeln('- Overall Stability: ${(stability.overallStability * 100).toStringAsFixed(1)}%');
    buffer.writeln('- Converged: ${stability.isConverged ? "Yes" : "No"}');
    buffer.writeln('- Consistent Answers: ${stability.consistentAnswers}/${stability.totalAnswers}');
    
    if (history.isNotEmpty) {
      buffer.writeln('\n# Previous Questions & Answers\n');
      for (int i = 0; i < history.length && i < 5; i++) {
        final qa = history[history.length - 1 - i];
        buffer.writeln('Q: ${qa.questionText}');
        buffer.writeln('A: ${qa.selectedOption}');
        buffer.writeln();
      }
    }

    buffer.writeln('\n# Task\n');
    buffer.writeln('Generate 1-3 multiple-choice questions that will help refine these preferences.');
    buffer.writeln('Focus on areas with:');
    buffer.writeln('- Low stability scores');
    buffer.writeln('- Inconsistencies between weight and monetary values');
    buffer.writeln('- Contradictions in previous answers');
    buffer.writeln('- Unclear tradeoffs between preferences');
    
    return buffer.toString();
  }

  /// Build the prompt for refinement calculation
  String _buildRefinementPrompt({
    required List<TypePreference> preferences,
    required List<AgentQuestion> questions,
    required List<int> selectedOptionIndices,
    required Map<String, double> currentWeights,
    required Map<String, double> currentMonetary,
    required List<QuestionAnswer> history,
    double? maxAnnualBudget,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('# Current Values\n');
    double totalMonetary = 0.0;
    for (final pref in preferences) {
      final weight = currentWeights[pref.name] ?? 0.0;
      final monetary = currentMonetary[pref.name] ?? 0.0;
      totalMonetary += monetary;
      buffer.writeln('**${pref.name}**: Weight=${(weight * 100).toStringAsFixed(1)}%, Monetary=\$${monetary.toStringAsFixed(0)}');
    }

    if (maxAnnualBudget != null) {
      buffer.writeln('\n# Budget Constraint\n');
      buffer.writeln('- Maximum Annual Budget: \$${maxAnnualBudget.toStringAsFixed(0)}');
      buffer.writeln('- Current Total: \$${totalMonetary.toStringAsFixed(0)}');
      buffer.writeln('- IMPORTANT: Sum of all monetary values must NOT exceed \$${maxAnnualBudget.toStringAsFixed(0)}');
    }

    buffer.writeln('\n# Questions & User Answers\n');
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final answerIndex = i < selectedOptionIndices.length ? selectedOptionIndices[i] : 0;
      final selectedOption = answerIndex < question.options.length 
          ? question.options[answerIndex] 
          : 'Unknown';
      
      buffer.writeln('Q${i + 1}: ${question.questionText}');
      buffer.writeln('Type: ${question.type.toString().split('.').last}');
      buffer.writeln('Answer: $selectedOption');
      buffer.writeln();
    }

    if (history.isNotEmpty) {
      buffer.writeln('\n# Recent History (for context)\n');
      for (int i = 0; i < history.length && i < 3; i++) {
        final qa = history[history.length - 1 - i];
        buffer.writeln('- ${qa.questionText} → ${qa.selectedOption}');
      }
    }

    buffer.writeln('\n# Task\n');
    buffer.writeln('Calculate updated weights and monetary values based on the answers.');
    buffer.writeln('Ensure:');
    buffer.writeln('1. Weights sum to exactly 1.0');
    buffer.writeln('2. Changes are gradual (max 15% per preference)');
    buffer.writeln('3. Higher-valued preferences get higher weights');
    buffer.writeln('4. Monetary values align with relative importance');
    
    return buffer.toString();
  }

  /// Generate fallback questions when AI fails
  AgentResponse _getFallbackQuestions(List<TypePreference> preferences) {
    if (preferences.length < 2) {
      return AgentResponse(
        reasoning: 'Not enough preferences to generate meaningful questions.',
        questions: [],
      );
    }

    // Create a simple comparison question between top preferences
    final pref1 = preferences[0];
    final pref2 = preferences.length > 1 ? preferences[1] : preferences[0];

    return AgentResponse(
      reasoning: 'Let\'s clarify the relative importance of your top priorities. '
          'Understanding these tradeoffs helps ensure your strategy aligns with what matters most.',
      questions: [
        AgentQuestion(
          id: 'fallback_comparison_1',
          questionText: 'If you had to choose, which would you prioritize: ${pref1.shortLabel} or ${pref2.shortLabel}?',
          options: [
            '${pref1.shortLabel} is much more important',
            '${pref1.shortLabel} is somewhat more important',
            'They are equally important',
            '${pref2.shortLabel} is somewhat more important',
            '${pref2.shortLabel} is much more important',
          ],
          reasoning: 'This helps clarify the relative importance between your primary preferences.',
          type: QuestionType.weightComparison,
        ),
      ],
    );
  }

  /// Generate conservative refinement when AI fails
  AgentRefinement _getConservativeRefinement({
    required Map<String, double> currentWeights,
    required Map<String, double> currentMonetary,
  }) {
    // Return current values unchanged with low confidence
    return AgentRefinement(
      updatedWeights: Map.from(currentWeights),
      updatedMonetary: Map.from(currentMonetary),
      explanation: 'Unable to process answers at this time. Values remain unchanged.',
      confidence: 0.0,
      affectedPreferences: [],
    );
  }
}
