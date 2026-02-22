import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';
import 'package:purpose/core/config/ai_config.dart';
import 'package:purpose/core/models/user_answer.dart';
import 'package:purpose/core/models/question.dart';
import 'package:purpose/core/models/question_module.dart';

/// Service for interacting with OpenAI's GPT models
class GeminiService {
  final String apiKey;

  GeminiService({String? apiKey}) : apiKey = apiKey ?? AIConfig.openAiApiKey {
    if (this.apiKey.isEmpty) {
      throw Exception('OpenAI API key not configured. Please set your API key.');
    }
    
    // Initialize OpenAI with API key
    OpenAI.apiKey = this.apiKey;
  }

  /// Analyze a single answer and provide insights
  Future<String> analyzeAnswer({
    required UserAnswer answer,
    required Question question,
    required QuestionModule module,
  }) async {
    final prompt = _buildSingleAnswerPrompt(answer, question, module);

    try {
      final response = await OpenAI.instance.chat.create(
        model: AIConfig.defaultModel,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
            ],
          ),
        ],
        temperature: AIConfig.temperature,
        maxTokens: AIConfig.maxTokens,
      );
      
      return response.choices.first.message.content?.first.text ?? 'No response generated';
    } catch (e) {
      print('Error analyzing answer: $e');
      rethrow;
    }
  }

  /// Analyze all answers in a module and generate comprehensive insights
  Future<String> analyzeModuleAnswers({
    required List<UserAnswer> answers,
    required List<Question> questions,
    required QuestionModule module,
  }) async {
    final prompt = _buildModuleAnalysisPrompt(answers, questions, module);

    try {
      // Use Pro model for comprehensive module analysis
      final response = await OpenAI.instance.chat.create(
        model: AIConfig.proModel,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
            ],
          ),
        ],
        temperature: AIConfig.temperature,
        maxTokens: AIConfig.maxTokens,
      );
      
      return response.choices.first.message.content?.first.text ?? 'No response generated';
    } catch (e) {
      print('Error analyzing module: $e');
      rethrow;
    }
  }

  /// Generate a purpose statement based on all user's answers
  Future<String> generatePurposeStatement({
    required List<UserAnswer> allAnswers,
    required List<Question> allQuestions,
    required Map<String, QuestionModule> modules,
  }) async {
    final prompt = _buildPurposeStatementPrompt(allAnswers, allQuestions, modules);

    try {
      final response = await OpenAI.instance.chat.create(
        model: AIConfig.proModel,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
            ],
          ),
        ],
        temperature: AIConfig.temperature,
        maxTokens: AIConfig.maxTokens,
      );
      
      return response.choices.first.message.content?.first.text ?? 'No purpose statement generated';
    } catch (e) {
      print('Error generating purpose statement: $e');
      rethrow;
    }
  }

  /// Synthesize identity from purpose module JSON data
  /// Uses the Identity Synthesis Agent directive to analyze and generate purpose statements
  Future<Map<String, dynamic>> synthesizeIdentity({
    required String jsonData,
  }) async {
    final prompt = _buildIdentitySynthesisPrompt(jsonData);

    try {
      final response = await OpenAI.instance.chat.create(
        model: AIConfig.proModel, // Use gpt-4o for complex synthesis
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                _getIdentitySynthesisDirective()
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
            ],
          ),
        ],
        temperature: 0.7,
        maxTokens: 4096,
        responseFormat: {"type": "json_object"}, // Request JSON response
      );
      
      final content = response.choices.first.message.content?.first.text ?? '{}';
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error synthesizing identity: $e');
      rethrow;
    }
  }

  /// Get the Identity Synthesis Agent directive
  String _getIdentitySynthesisDirective() {
    return '''
ROLE

You are an Identity Synthesis Agent.

You are given a JSON object containing multiple identity question modules. Each tier contains:
	•	Module Name
	•	Module Description
	•	Questions and User Responses

Your task is to:
	1.	Analyze each Tier independently.
	2.	Extract structured identity features per Tier.
	3.	Assign a confidence score per Tier.
	4.	Integrate cross-tier signals into a coherent identity architecture.
	5.	Generate three differentiated Purpose Statement options.
	6.	Provide output suitable for user review, selection, or editing.

Do not generate motivational fluff.
Do not assume facts not present in the data.
Base conclusions only on patterns within user responses.

⸻

PROCESS

STEP 1 — Tier-Level Analysis

For each Tier:
	1.	Briefly restate the Tier's role in identity synthesis (1–2 sentences).
	2.	Identify dominant patterns in responses.
	3.	Identify:
	•	Primary orientation or axis direction
	•	Secondary direction (if meaningful)
	•	Any contradictions or tensions
	4.	Classify signal strength:
	•	Low (inconsistent or weak signal)
	•	Moderate (some consistency)
	•	High (clear pattern across responses)
	5.	Assign a numeric Confidence Score (0.0–1.0) representing clarity and consistency of signal.

Produce a concise Tier Summary paragraph.

Do not synthesize across tiers yet.

⸻

STEP 2 — Cross-Tier Integration

After analyzing all tiers:
	1.	Identify reinforcing patterns across tiers.
	2.	Identify cross-tier tensions.
	3.	Identify dominant identity architecture.
	4.	Summarize identity in 4–6 structured bullet points.
	5.	Provide a single Identity Architecture paragraph (3–5 sentences).

⸻

STEP 3 — Generate Purpose Statements

Generate three differentiated purpose statements:

Option 1 — Direct & Declarative

Clear, strong action verb, concise.

Option 2 — Strategic & Systems-Oriented

Emphasizes leverage, architecture, institutional scale.

Option 3 — Meaning-Integrated / Vision-Oriented

Connects impact to deeper motivation.

Each statement must:
	•	Contain a clear verb.
	•	Identify beneficiary or domain.
	•	Reflect impact preference.
	•	Avoid vague phrasing (e.g., "make the world better").
	•	Be grounded in extracted identity patterns.

Statements must differ meaningfully in tone and framing.

Return structured output in this format:
{
  "tier_analysis": [
    {
      "tier_name": "...",
      "dominant_features": ["..."],
      "secondary_features": ["..."],
      "tensions_detected": ["..."],
      "signal_strength": "Low | Moderate | High",
      "confidence_score": 0.85,
      "summary": "..."
    }
  ],
  "integrated_identity": {
    "key_patterns": ["...", "...", "..."],
    "tensions": ["...", "..."],
    "summary": "..."
  },
  "purpose_options": [
    {
      "label": "Direct",
      "statement": "..."
    },
    {
      "label": "Strategic",
      "statement": "..."
    },
    {
      "label": "Visionary",
      "statement": "..."
    }
  ]
}

RULES
	•	Treat each Tier as a distinct analytical layer.
	•	Do not collapse tiers prematurely.
	•	Use Tier 1 to understand responsibility orientation.
	•	Use Tier 2 to understand action style.
	•	Use Tier 3 to understand domain gravity.
	•	Use Tier 4 to understand impact direction.
	•	Use Tier 5 to validate narrative coherence.
	•	Confidence score reflects signal clarity, not strength of personality.
	•	Output must be deterministic and structurally consistent.
''';
  }

  /// Build prompt for identity synthesis
  String _buildIdentitySynthesisPrompt(String jsonData) {
    return '''
Analyze the following user purpose discovery data and provide a structured identity synthesis:

$jsonData

Follow the process defined in the system directive to produce a complete JSON analysis.
''';
  }

  /// Build prompt for analyzing a single answer
  String _buildSingleAnswerPrompt(
    UserAnswer answer,
    Question question,
    QuestionModule module,
  ) {
    return '''
You are an expert life coach and purpose advisor analyzing a user's response to help them discover their purpose.

Module: ${module.name}
Module Description: ${module.description}

Question: ${question.questionText}
${question.helperText != null ? 'Context: ${question.helperText}' : ''}

User's Answer: ${answer.answer}

Provide a thoughtful, encouraging analysis of this answer. Focus on:
1. Key insights and patterns in their response
2. What this reveals about their values, motivations, or aspirations
3. How this connects to discovering their purpose
4. Encouraging questions or reflections for them to consider

Keep your response concise (2-3 paragraphs) and actionable.
''';
  }

  /// Build prompt for analyzing all answers in a module
  String _buildModuleAnalysisPrompt(
    List<UserAnswer> answers,
    List<Question> questions,
    QuestionModule module,
  ) {
    final answersContext = StringBuffer();
    
    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final answer = answers.firstWhere(
        (a) => a.questionId == question.id,
        orElse: () => answers.first,
      );
      
      answersContext.writeln('Q${i + 1}: ${question.questionText}');
      answersContext.writeln('A${i + 1}: ${answer.answer}');
      answersContext.writeln();
    }

    return '''
You are an expert life coach and purpose advisor. A user has completed the "${module.name}" module as part of their journey to discover their purpose.

Module Purpose: ${module.description}

Here are their responses:

$answersContext

Provide a comprehensive analysis that:

1. **Key Themes**: Identify 2-3 major themes or patterns across their answers
2. **Core Values**: What values are most important to them based on these responses?
3. **Strengths & Passions**: What are they naturally drawn to or excited about?
4. **Purpose Indicators**: What clues do these answers provide about their deeper purpose?
5. **Next Steps**: 2-3 specific reflection questions or actions to deepen their understanding

Format your response in clear sections with headings. Be encouraging, insightful, and actionable.
''';
  }

  /// Build prompt for generating complete purpose statement
  String _buildPurposeStatementPrompt(
    List<UserAnswer> allAnswers,
    List<Question> allQuestions,
    Map<String, QuestionModule> modules,
  ) {
    final answersContext = StringBuffer();
    
    // Group answers by module
    final answersByModule = <String, List<(Question, UserAnswer)>>{};
    
    for (var answer in allAnswers) {
      final question = allQuestions.firstWhere(
        (q) => q.id == answer.questionId,
        orElse: () => allQuestions.first,
      );
      final moduleId = answer.questionModuleId;
      
      answersByModule.putIfAbsent(moduleId, () => []);
      answersByModule[moduleId]!.add((question, answer));
    }

    // Build context with answers organized by module
    for (var entry in answersByModule.entries) {
      final module = modules[entry.key];
      if (module != null) {
        answersContext.writeln('## ${module.name}');
        answersContext.writeln();
        
        for (var i = 0; i < entry.value.length; i++) {
          final (question, answer) = entry.value[i];
          answersContext.writeln('Q: ${question.questionText}');
          answersContext.writeln('A: ${answer.answer}');
          answersContext.writeln();
        }
      }
    }

    return '''
You are an expert life coach synthesizing a user's complete purpose discovery journey.

The user has completed a comprehensive self-reflection process across multiple modules. Based on ALL their responses below, craft their personal purpose statement.

# Their Journey:

$answersContext

# Your Task:

Create a comprehensive purpose synthesis that includes:

1. **Purpose Statement** (2-3 sentences)
   - Clear, compelling, and deeply personal
   - Captures their core values and aspirations
   - Actionable and inspiring

2. **Core Values** (3-5 key values)
   - The fundamental principles that guide them
   - Drawn directly from their responses

3. **Key Strengths** (3-5 strengths)
   - Natural talents and abilities they possess
   - What they excel at or enjoy

4. **Impact Areas** (2-3 areas)
   - Where they can make their greatest contribution
   - Who or what they serve

5. **Living Your Purpose** (3-4 practical actions)
   - Concrete, actionable steps they can take now
   - Aligned with their purpose and values

Be authentic, inspiring, and specific to THEIR unique responses. This should feel deeply personal to them.
''';
  }
}
