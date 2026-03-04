import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:purpose/core/config/ai_config.dart';
import 'package:purpose/core/models/user_answer.dart';
import 'package:purpose/core/models/question.dart';
import 'package:purpose/core/models/question_module.dart';

/// Service for interacting with OpenAI's GPT models
class GeminiService {
  final String apiKey;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  GeminiService({String? apiKey}) : apiKey = apiKey ?? AIConfig.openAiApiKey {
    if (this.apiKey.isEmpty) {
      throw Exception('OpenAI API key not configured. Please set your API key.');
    }
    
    // Initialize OpenAI with API key (only used for non-web platforms)
    if (!kIsWeb) {
      OpenAI.apiKey = this.apiKey;
    }
  }

  /// Make OpenAI API request, routing through Cloud Functions on web
  Future<Map<String, dynamic>> _makeOpenAIRequest({
    required String model,
    required List<Map<String, dynamic>> messages,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? responseFormat,
  }) async {
    if (kIsWeb) {
      // On web: use Firebase Cloud Function to avoid CORS
      print('Using Cloud Function for OpenAI request (web platform)');
      
      final callable = _functions.httpsCallable('openaiProxy');
      final result = await callable.call({
        'requestBody': {
          'model': model,
          'messages': messages,
          if (temperature != null) 'temperature': temperature,
          if (maxTokens != null) 'max_tokens': maxTokens,
          if (responseFormat != null) 'response_format': responseFormat,
        },
      });
      
      // Convert to JSON and back to ensure plain Dart types (avoid Int64 issues)
      final jsonString = jsonEncode(result.data);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } else {
      // On native platforms: use dart_openai directly
      print('Using dart_openai directly (native platform)');
      
      // Build messages for dart_openai
      final openAIMessages = messages.map((m) {
        return OpenAIChatCompletionChoiceMessageModel(
          role: m['role'] == 'system' 
              ? OpenAIChatMessageRole.system 
              : OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
              m['content'] is List ? m['content'][0]['text'] : m['content']
            ),
          ],
        );
      }).toList();
      
      // Call OpenAI with appropriate parameters
      final response = responseFormat != null
          ? await OpenAI.instance.chat.create(
              model: model,
              messages: openAIMessages,
              temperature: temperature,
              maxTokens: maxTokens,
              responseFormat: responseFormat.cast<String, String>(),
            )
          : await OpenAI.instance.chat.create(
              model: model,
              messages: openAIMessages,
              temperature: temperature,
              maxTokens: maxTokens,
            );
      
      // Convert to same format as cloud function response
      return {
        'choices': response.choices.map((c) => {
          'message': {
            'content': c.message.content?.first.text ?? '',
          },
        }).toList(),
      };
    }
  }

  /// Extract content from OpenAI response
  String _extractContent(Map<String, dynamic> response) {
    final choices = response['choices'] as List;
    if (choices.isEmpty) return '';
    
    final firstChoice = choices[0] as Map<String, dynamic>;
    final message = firstChoice['message'] as Map<String, dynamic>;
    
    return message['content'] as String? ?? '';
  }

  /// Analyze a single answer and provide insights
  Future<String> analyzeAnswer({
    required UserAnswer answer,
    required Question question,
    required QuestionModule module,
  }) async {
    final prompt = _buildSingleAnswerPrompt(answer, question, module);

    try {
      final response = await _makeOpenAIRequest(
        model: AIConfig.defaultModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: AIConfig.temperature,
        maxTokens: AIConfig.maxTokens,
      );
      
      return _extractContent(response);
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
      final response = await _makeOpenAIRequest(
        model: AIConfig.proModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: AIConfig.temperature,
        maxTokens: AIConfig.maxTokens,
      );
      
      return _extractContent(response);
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
      final response = await _makeOpenAIRequest(
        model: AIConfig.proModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: AIConfig.temperature,
        maxTokens: AIConfig.maxTokens,
      );
      
      return _extractContent(response);
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
      final response = await _makeOpenAIRequest(
        model: AIConfig.proModel, // Use gpt-4o for complex synthesis
        messages: [
          {
            'role': 'system',
            'content': _getIdentitySynthesisDirective(),
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.7,
        maxTokens: 4096,
        responseFormat: {"type": "json_object"}, // Request JSON response
      );
      
      final content = _extractContent(response);
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

  /// Generate clarification questions for Phase 2 of value creation
  Future<List<Map<String, dynamic>>> generateValueClarificationQuestions({
    required String seedValue,
  }) async {
    final prompt = '''
You are a values clarification expert helping a user explore what a value truly means to them.

The user has selected "$seedValue" as a value they want to develop and articulate.

Generate exactly 3 multiple choice questions that will help them:
1. Define what this value personally means to them (not just dictionary definition)
2. Identify how this value shows up or could show up in their life
3. Connect the value to their deeper motivations or aspirations

Each question should have 4 answer options that represent different perspectives or interpretations.

Questions should be:
- Thought-provoking and insightful
- Personal and introspective
- Have options that feel authentic and meaningful
- Focused on the user's unique interpretation and experience

Return ONLY a JSON array of objects with this exact structure:
[
  {
    "question": "Question 1 text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"]
  },
  {
    "question": "Question 2 text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"]
  },
  {
    "question": "Question 3 text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"]
  }
]

No additional text or formatting, just the JSON array.
''';

    try {
      final response = await _makeOpenAIRequest(
        model: AIConfig.defaultModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.8, // Higher temperature for creative questions
        maxTokens: 800,
      );
      
      final content = _extractContent(response);
      final questions = jsonDecode(content) as List;
      return questions.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error generating clarification questions: $e');
      // Fallback to generic questions if AI fails
      return [
        {
          'question': 'What does "$seedValue" mean to you personally?',
          'options': [
            'Living authentically according to my principles',
            'Achieving specific outcomes or goals',
            'The way I treat and relate to others',
            'How I develop and improve myself'
          ]
        },
        {
          'question': 'When is this value most important to you?',
          'options': [
            'When making major life decisions',
            'In my daily interactions and routines',
            'During challenging or stressful times',
            'When pursuing my goals and aspirations'
          ]
        },
        {
          'question': 'How would you like this value to guide your life?',
          'options': [
            'As a constant compass for all decisions',
            'As inspiration for specific goals or projects',
            'As a foundation for my relationships',
            'As a measure of my personal growth'
          ]
        },
      ];
    }
  }

  /// Generate scope narrowing questions and refined label for Phase 3
  Future<Map<String, dynamic>> generateValueScopeNarrowing({
    required String seedValue,
    required List<String> phase2Questions,
    required List<String> phase2Answers,
  }) async {
    final answersContext = StringBuffer();
    for (int i = 0; i < phase2Questions.length; i++) {
      answersContext.writeln('Q: ${phase2Questions[i]}');
      answersContext.writeln('A: ${phase2Answers[i]}');
      answersContext.writeln();
    }

    final prompt = '''
You are a values clarification expert helping a user narrow down and refine their understanding of a value.

Original Value: "$seedValue"

The user has answered clarification questions:
$answersContext

Based on their responses, you need to:
1. Generate a refined, more specific label for this value (2-4 words)
2. Create 3 multiple choice questions that help narrow the scope further

The refined label should:
- Capture the essence of what they described
- Be more specific than the original "$seedValue"
- Feel personal and authentic to their responses
- Be concise (2-4 words)

The 3 questions should:
- Help identify specific contexts where this value applies
- Clarify boundaries or limits of this value
- Distinguish what this value is vs. what it's not for them
- Each question should have 4 answer options

Return ONLY a JSON object in this exact format:
{
  "refinedLabel": "Your refined 2-4 word label here",
  "questions": [
    {
      "question": "Question 1 text here?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    },
    {
      "question": "Question 2 text here?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    },
    {
      "question": "Question 3 text here?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    }
  ]
}

No additional text, just the JSON object.
''';

    try {
      final response = await _makeOpenAIRequest(
        model: AIConfig.defaultModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.8,
        maxTokens: 1000,
      );
      
      final content = _extractContent(response);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error generating scope narrowing: $e');
      // Fallback
      return {
        'refinedLabel': 'Personal $seedValue',
        'questions': [
          {
            'question': 'In what areas of your life does this value matter most?',
            'options': [
              'Career and professional development',
              'Personal relationships and family',
              'Personal growth and learning',
              'Community and social impact'
            ]
          },
          {
            'question': 'What are the limits or boundaries of this value for you?',
            'options': [
              'It applies to almost everything I do',
              'It\'s context-specific to certain situations',
              'It\'s balanced with other important values',
              'It\'s aspirational, not yet fully realized'
            ]
          },
          {
            'question': 'How is your interpretation unique?',
            'options': [
              'I emphasize the practical application',
              'I focus on the emotional or relational aspects',
              'I connect it to my long-term vision',
              'I balance it with competing priorities'
            ]
          }
        ],
      };
    }
  }

  /// Generate friction & sacrifice questions and refined label for Phase 4
  Future<Map<String, dynamic>> generateValueFrictionSacrifice({
    required String seedValue,
    required String refinedLabel,
    required List<String> phase3Questions,
    required List<String> phase3Answers,
  }) async {
    final answersContext = StringBuffer();
    for (int i = 0; i < phase3Questions.length; i++) {
      answersContext.writeln('Q: ${phase3Questions[i]}');
      answersContext.writeln('A: ${phase3Answers[i]}');
      answersContext.writeln();
    }

    final prompt = '''
You are a values clarification expert helping a user test the strength and commitment to their value.

Original Value: "$seedValue"
Currently Refined As: "$refinedLabel"

The user has answered scope narrowing questions:
$answersContext

Based on their responses, you need to:
1. Test this value against friction and sacrifice scenarios
2. Create 3 multiple choice questions that explore trade-offs and commitment
3. Optionally provide a further refined label (2-4 words) if needed, or keep it the same

The questions should:
- Present realistic scenarios where this value conflicts with other priorities
- Test willingness to sacrifice or face difficulty
- Reveal the true depth of their commitment
- Help distinguish this value from superficial preferences
- Each question should have 4 answer options representing different levels of commitment

Return ONLY a JSON object in this exact format:
{
  "refinedLabel": "Keep same or provide more refined 2-4 word label",
  "questions": [
    {
      "question": "Question 1 about sacrifice or trade-off?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    },
    {
      "question": "Question 2 about commitment or difficulty?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    },
    {
      "question": "Question 3 about boundaries or limits?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    }
  ]
}

No additional text, just the JSON object.
''';

    try {
      final response = await _makeOpenAIRequest(
        model: AIConfig.defaultModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.8,
        maxTokens: 1000,
      );
      
      final content = _extractContent(response);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error generating friction & sacrifice questions: $e');
      // Fallback
      return {
        'refinedLabel': refinedLabel, // Keep the same
        'questions': [
          {
            'question': 'What would you be willing to sacrifice to honor this value?',
            'options': [
              'Time and immediate comfort',
              'Some relationships or social approval',
              'Career opportunities or financial gain',
              'Personal desires or preferences'
            ]
          },
          {
            'question': 'When this value conflicts with other priorities, how do you respond?',
            'options': [
              'I consistently choose this value over others',
              'I seek creative solutions to honor both',
              'I compromise based on the situation',
              'I struggle with the tension but stay committed'
            ]
          },
          {
            'question': 'How would you continue living this value during difficult times?',
            'options': [
              'Through small daily actions and reminders',
              'By connecting with others who share this value',
              'By focusing on long-term meaning over short-term pain',
              'By adapting how I express it while maintaining the core'
            ]
          }
        ],
      };
    }
  }

  /// Generate Phase 5: Operationalization questions
  /// Explores practical behaviors, boundaries, and measurement
  Future<Map<String, dynamic>> generateValueOperationalization({
    required String seedValue,
    required String refinedLabel,
    required List<String> phase4Questions,
    required List<String> phase4Answers,
  }) async {
    final answersContext = StringBuffer();
    for (int i = 0; i < phase4Questions.length; i++) {
      answersContext.writeln('Q: ${phase4Questions[i]}');
      answersContext.writeln('A: ${phase4Answers[i]}');
      answersContext.writeln();
    }

    final prompt = '''
You are helping a user operationalize their personal value: "$refinedLabel" (originally stemming from "$seedValue").

They have just completed Phase 4 (Friction & Sacrifice), answering questions about their commitment:
$answersContext

Now in Phase 5, we need to make this value OPERATIONAL - translating commitment into concrete action.

Generate 3 multiple choice questions that explore:
1. BEHAVIORS: What specific actions demonstrate this value in daily life?
2. BOUNDARIES: In what contexts does this value apply, and where are its limits?
3. MEASUREMENT: How will they know if they're living according to this value?

Each question should have 4 options that represent different levels of specificity or practical application.

Return ONLY a JSON object in this exact format:
{
  "refinedLabel": "<refined label (may be same as input or further refined if needed)>",
  "questions": [
    {
      "question": "<question 1 about behaviors>",
      "options": ["<option 1>", "<option 2>", "<option 3>", "<option 4>"]
    },
    {
      "question": "<question 2 about boundaries>",
      "options": ["<option 1>", "<option 2>", "<option 3>", "<option 4>"]
    },
    {
      "question": "<question 3 about measurement>",
      "options": ["<option 1>", "<option 2>", "<option 3>", "<option 4>"]
    }
  ]
}

No additional text, just the JSON object.
''';

    try {
      final response = await _makeOpenAIRequest(
        model: AIConfig.defaultModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.8,
        maxTokens: 1000,
      );
      
      final content = _extractContent(response);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error generating operationalization questions: $e');
      // Return fallback structure
      return {
        'refinedLabel': refinedLabel,
        'questions': [
          {
            'question':
                'What daily actions would best demonstrate $refinedLabel in your life?',
            'options': [
              'Specific morning and evening routines',
              'Actions when making important decisions',
              'How I interact with others regularly',
              'Regular reflection and self-assessment'
            ]
          },
          {
            'question':
                'When and where does this value apply most strongly?',
            'options': [
              'In all areas of life without exception',
              'Primarily in relationships with close ones',
              'Mostly in professional and public contexts',
              'In specific situations when stakes are high'
            ]
          },
          {
            'question':
                'How will you measure whether you\'re living according to $refinedLabel?',
            'options': [
              'Daily check-ins and journaling',
              'Monthly review of specific behaviors',
              'Feedback from people I trust',
              'Internal sense of alignment and peace'
            ]
          }
        ]
      };
    }
  }

  /// Generate value summary after Phase 5
  /// Creates a comprehensive summary of the core value and how it applies to the user
  /// This summary is used for context in later strategy development
  Future<String> generateValueSummary({
    required String seedValue,
    required String refinedLabel,
    required List<String> phase2Questions,
    required List<String> phase2Answers,
    required List<String> phase3Questions,
    required List<String> phase3Answers,
    required List<String> phase4Questions,
    required List<String> phase4Answers,
    required List<String> phase5Questions,
    required List<String> phase5Answers,
  }) async {
    final phase2Context = StringBuffer();
    for (int i = 0; i < phase2Questions.length; i++) {
      phase2Context.writeln('Q: ${phase2Questions[i]}');
      phase2Context.writeln('A: ${phase2Answers[i]}');
    }

    final phase3Context = StringBuffer();
    for (int i = 0; i < phase3Questions.length; i++) {
      phase3Context.writeln('Q: ${phase3Questions[i]}');
      phase3Context.writeln('A: ${phase3Answers[i]}');
    }

    final phase4Context = StringBuffer();
    for (int i = 0; i < phase4Questions.length; i++) {
      phase4Context.writeln('Q: ${phase4Questions[i]}');
      phase4Context.writeln('A: ${phase4Answers[i]}');
    }

    final phase5Context = StringBuffer();
    for (int i = 0; i < phase5Questions.length; i++) {
      phase5Context.writeln('Q: ${phase5Questions[i]}');
      phase5Context.writeln('A: ${phase5Answers[i]}');
    }

    final prompt = '''
You are summarizing a user's personal value that they've refined through a comprehensive 5-phase process.

Original Value Seed: "$seedValue"
Final Refined Label: "$refinedLabel"

=== PHASE 2: CLARIFICATION ===
$phase2Context

=== PHASE 3: SCOPE NARROWING ===
$phase3Context

=== PHASE 4: FRICTION & SACRIFICE ===
$phase4Context

=== PHASE 5: OPERATIONALIZATION ===
$phase5Context

Create a comprehensive summary (3-4 paragraphs) that captures:

1. CORE ESSENCE: What this value fundamentally means to the user, beyond the label itself
2. PERSONAL APPLICATION: How this value specifically applies in their life context based on their answers
3. BEHAVIORAL MANIFESTATION: The concrete ways this value shows up in their actions and decisions
4. STRATEGIC RELEVANCE: How this value can guide future goal-setting, decision-making, and life planning

Write in second person ("Your value of..."). Be insightful, connecting the dots between their answers to reveal deeper patterns. This summary will be used to inform future strategic planning and goal development.

Return only the summary text, no JSON or additional formatting.
''';

    try {
      final response = await _makeOpenAIRequest(
        model: AIConfig.defaultModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.7,
        maxTokens: 600,
      );
      
      return _extractContent(response);
    } catch (e) {
      print('Error generating value summary: $e');
      // Return fallback summary
      return '''Your value of $refinedLabel represents a core principle that guides your decisions and actions. Through your exploration, you've identified specific ways this value manifests in your daily life and the boundaries within which it operates.

Your commitment to $refinedLabel reflects a deeper understanding of what matters most to you. You've considered the trade-offs and sacrifices you're willing to make to honor this value, demonstrating genuine conviction.

The concrete behaviors and measures you've identified will help you track alignment with $refinedLabel over time. This operational clarity transforms an abstract principle into actionable guidance.

As you move forward with strategic planning, $refinedLabel can serve as a filter for opportunities and a compass for difficult decisions, ensuring your goals and actions remain authentic to who you are.''';
    }
  }

  /// Generate final value statement options
  /// Creates 3 distinct statement styles for user selection
  Future<List<Map<String, dynamic>>> generateFinalValueStatements({
    required String seedValue,
    required String refinedLabel,
    required List<String> phase2Questions,
    required List<String> phase2Answers,
    required List<String> phase3Questions,
    required List<String> phase3Answers,
    required List<String> phase4Questions,
    required List<String> phase4Answers,
    required List<String> phase5Questions,
    required List<String> phase5Answers,
  }) async {
    final phase2Context = StringBuffer();
    for (int i = 0; i < phase2Questions.length; i++) {
      phase2Context.writeln('Q: ${phase2Questions[i]}');
      phase2Context.writeln('A: ${phase2Answers[i]}');
      phase2Context.writeln();
    }

    final phase3Context = StringBuffer();
    for (int i = 0; i < phase3Questions.length; i++) {
      phase3Context.writeln('Q: ${phase3Questions[i]}');
      phase3Context.writeln('A: ${phase3Answers[i]}');
      phase3Context.writeln();
    }

    final phase4Context = StringBuffer();
    for (int i = 0; i < phase4Questions.length; i++) {
      phase4Context.writeln('Q: ${phase4Questions[i]}');
      phase4Context.writeln('A: ${phase4Answers[i]}');
      phase4Context.writeln();
    }

    final phase5Context = StringBuffer();
    for (int i = 0; i < phase5Questions.length; i++) {
      phase5Context.writeln('Q: ${phase5Questions[i]}');
      phase5Context.writeln('A: ${phase5Answers[i]}');
      phase5Context.writeln();
    }

    final prompt = '''
You are helping a user finalize their personal value statement.

Original Value Seed: "$seedValue"
Refined Label: "$refinedLabel"

They have completed a comprehensive 5-phase value clarification process:

=== PHASE 2: CLARIFICATION ===
$phase2Context
=== PHASE 3: SCOPE NARROWING ===
$phase3Context
=== PHASE 4: FRICTION & SACRIFICE ===
$phase4Context
=== PHASE 5: OPERATIONALIZATION ===
$phase5Context
Now generate 3 DISTINCT value statement options. Each should:
- Capture the essence of "$refinedLabel"
- Reflect their journey through all 5 phases
- Be authentic to their answers and choices
- Be memorable and actionable
- Be 1-3 sentences long

Create 3 different STYLES:
1. DIRECT: Clear, straightforward statement of the value
2. PRINCIPLE: Frame as a guiding principle or commitment
3. MEANING: Connect to deeper purpose and life meaning

Return ONLY a JSON array with this exact structure:
[
  {
    "label": "Direct",
    "statement": "<direct value statement here>"
  },
  {
    "label": "Principle",
    "statement": "<principle-based value statement here>"
  },
  {
    "label": "Meaning",
    "statement": "<meaning-integrated value statement here>"
  }
]

No additional text, just the JSON array.
''';

    try {
      final response = await _makeOpenAIRequest(
        model: AIConfig.defaultModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.8,
        maxTokens: 800,
      );
      
      final content = _extractContent(response);
      final data = jsonDecode(content) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error generating final value statements: $e');
      // Return fallback options
      return [
        {
          'label': 'Direct',
          'statement': 'I value $refinedLabel and commit to living according to it every day.'
        },
        {
          'label': 'Principle',
          'statement': 'I am guided by $refinedLabel, using it as a compass for my decisions and actions.'
        },
        {
          'label': 'Meaning',
          'statement': 'Through $refinedLabel, I find deeper meaning and purpose in my life.'
        }
      ];
    }
  }

  /// Generate vision statement options
  /// Creates 3 distinct vision statements based on user's purpose, values, and vision inputs
  Future<List<Map<String, dynamic>>> generateVisionStatements({
    required int timeframeYears,
    required String purposeStatement,
    required List<String> coreValues,
    required String meaningfulChange,
    required String influenceScale,
    required String roleDescription,
  }) async {
    final valuesContext = coreValues.join(', ');

    final prompt = '''
You are a Vision Synthesis Agent.

You have received the following context:

**Timeframe:** $timeframeYears years
**Purpose Statement:** "$purposeStatement"
**Core Values:** $valuesContext

**User Responses:**
1. Meaningful Change: "$meaningfulChange"
2. Influence Scale: $influenceScale
3. Role: "$roleDescription"

Your task:
1. Identify consistent patterns in desired impact
2. Confirm alignment with core values
3. Detect unrealistic or goal-based framing and correct it
4. Generate exactly 3 differentiated Vision statement options

Each Vision statement must:
- Be written in present tense as if already true
- Describe changed conditions, not tasks or goals
- Reflect the scale ($influenceScale) and domain
- Remain aligned with Purpose
- Remain constrained by Values
- Avoid listing metrics or milestones
- Paint a picture of the world that exists because they lived their purpose

Generate 3 options with these specific styles:

**Option 1 — Clear & Strategic**
Straightforward, concrete description of changed conditions. Focus on observable outcomes and tangible shifts.

**Option 2 — Systems & Institutional**
Emphasize structural changes, institutional transformation, or systemic patterns. Focus on how systems and organizations function differently.

**Option 3 — Meaning & Human Impact Integrated**
Connect changed conditions to deeper meaning and human experience. Focus on how people's lives and relationships are different.

Return ONLY a JSON array with this exact structure:
[
  {
    "label": "Clear & Strategic",
    "statement": "<clear strategic vision statement here>"
  },
  {
    "label": "Systems & Institutional",
    "statement": "<systems and institutional vision statement here>"
  },
  {
    "label": "Meaning & Human Impact",
    "statement": "<meaning and human impact vision statement here>"
  }
]

No additional text, just the JSON array.
''';

    try {
      final response = await _makeOpenAIRequest(
        model: AIConfig.defaultModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.8,
        maxTokens: 1000,
      );
      
      final content = _extractContent(response);
      final data = jsonDecode(content) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error generating vision statements: $e');
      // Return fallback options
      return [
        {
          'label': 'Clear & Strategic',
          'statement': 'In $timeframeYears years, meaningful change exists in the $influenceScale level because of my commitment to $purposeStatement.'
        },
        {
          'label': 'Systems & Institutional',
          'statement': 'Systems and institutions operate differently in $timeframeYears years, reflecting the values of $valuesContext through my sustained focus on $purposeStatement.'
        },
        {
          'label': 'Meaning & Human Impact',
          'statement': 'People experience greater meaning and connection in $timeframeYears years as a result of my dedication to $purposeStatement, guided by $valuesContext.'
        }
      ];
    }
  }

  /// Generate a strategic mission map that bridges current state to vision state
  /// This implements the "Strategic Mission Mapping Agent"
  Future<List<Map<String, dynamic>>> generateMissionMap({
    // Context from user profile
    required String purposeStatement,
    required List<String> coreValues,
    required String visionStatement,
    required int visionTimeframeYears,
    // Step 1: Current Mission State
    required String currentBuilding,
    required String currentScale,
    required String currentAuthority,
    // Step 2: Vision State
    required String visionInfluenceScale,
    required String visionEnvironment,
    required String visionResponsibility,
    required String visionMeasurableChange,
    // Step 3: Constraints
    required List<String> constraintValues,
    required String nonNegotiableCommitments,
    required String riskTolerance,
  }) async {
    final valuesContext = coreValues.join(', ');
    final constraintValuesContext = constraintValues.join(', ');

    final prompt = '''
You are a **Strategic Mission Mapping Agent**.

Your role is to analyze the gap between a user's current state and their vision state, then generate a sequential set of 3–5 missions that bridge this gap. These missions represent structural and capability evolution, not tactical task lists.

---

## CONTEXT PROVIDED

**Purpose Statement:**
"$purposeStatement"

**Core Values:**
$valuesContext

**Vision Statement ($visionTimeframeYears years):**
"$visionStatement"

**Current Mission State:**
- Currently building or leading: "$currentBuilding"
- Current scale of operation: "$currentScale"
- Current authority held: "$currentAuthority"

**Vision End State:**
- Desired scale of influence: "$visionInfluenceScale"
- Desired environment: "$visionEnvironment"
- Desired level of responsibility: "$visionResponsibility"
- Measurable change that will exist: "$visionMeasurableChange"

**Constraints:**
- Values that cannot be violated: $constraintValuesContext
- Non-negotiable commitments: "$nonNegotiableCommitments"
- Risk tolerance: "$riskTolerance"

---

## YOUR TASKS (Complete All 10)

1. **Identify structural differences** between current state and vision state
   - What fundamental shifts in operating model, organization, or influence are required?

2. **Identify capability gaps**
   - What skills, capacities, or competencies must be developed?

3. **Identify authority and scale gaps**
   - What levels of influence, responsibility, or operational scale must be reached?

4. **Define 3–5 sequential missions**
   - Each mission is a distinct phase in the journey from current to vision
   - Missions build on each other in logical progression
   - Each mission represents a significant structural or capability milestone

5. **Describe what becomes true in each mission**
   - Focus on end states, not processes
   - Describe conditions that exist when the mission is complete

6. **Ensure alignment with Purpose and Values**
   - Every mission must advance the purpose: "$purposeStatement"
   - No mission should violate: $constraintValuesContext
   - Respect: "$nonNegotiableCommitments"

7. **Avoid generating tactical task lists**
   - Do NOT list specific tasks or action items
   - Focus on structural evolution and capability development
   - Describe phases of transformation, not to-do items

8. **Focus on structural and capability evolution**
   - Each mission should represent a leap in structure or capability
   - Describe shifts in scale, authority, influence, or organizational capacity

9. **Present achievable time periods for each mission**
   - Time horizons should be realistic given "$riskTolerance"
   - All mission timeframes must add up to approximately $visionTimeframeYears years
   - Use ranges like "0-2 years", "2-4 years", "4-7 years", etc.

10. **Provide risk assessment for each mission**
    - Assess risk as Low, Medium, or High
    - Consider user's risk tolerance: "$riskTolerance"
    - Account for constraints: "$nonNegotiableCommitments"

---

## OUTPUT FORMAT

Return ONLY a JSON object with this exact structure (no additional text):

{
  "mission_map": [
    {
      "mission": "Mission 1 — [Descriptive Title]",
      "mission_sequence": "1",
      "focus": "[What this mission focuses on achieving]",
      "structural_shift": "[What structural change occurs - scale, authority, influence, organization]",
      "capability_required": "[What capabilities must be developed or demonstrated]",
      "risk_or_value_guardrail": "[Risk assessment (Low/Medium/High) and key value constraints to maintain]",
      "time_horizon": "[Time period, e.g., 0-2 years]"
    },
    {
      "mission": "Mission 2 — [Descriptive Title]",
      "mission_sequence": "2",
      "focus": "[What this mission focuses on achieving]",
      "structural_shift": "[What structural change occurs]",
      "capability_required": "[What capabilities must be developed]",
      "risk_or_value_guardrail": "[Risk assessment and constraints]",
      "time_horizon": "[Time period, e.g., 2-4 years]"
    }
    // Continue for 3-5 missions total
  ]
}

**Rules:**
- Generate between 3 and 5 missions (use your judgment based on complexity and timeframe)
- Use mission_sequence as "1", "2", "3", etc.
- In risk_or_value_guardrail, explicitly state risk level (Low, Medium, or High)
- Ensure time horizons are sequential and sum to approximately $visionTimeframeYears years
- Each mission must represent a meaningful structural or capability milestone
- No mission titles should be generic - make them specific to the user's context

Generate the mission map now.
''';

    try {
      final response = await _makeOpenAIRequest(
        model: AIConfig.defaultModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.7,
        maxTokens: 2000,
      );
      
      final content = _extractContent(response);
      final data = jsonDecode(content) as Map<String, dynamic>;
      final missionMap = data['mission_map'] as List<dynamic>;
      return missionMap.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error generating mission map: $e');
      // Return fallback missions based on user input
      final fallbackMissions = _generateFallbackMissions(
        visionTimeframeYears: visionTimeframeYears,
        currentBuilding: currentBuilding,
        visionInfluenceScale: visionInfluenceScale,
      );
      return fallbackMissions;
    }
  }

  /// Generate fallback missions if AI call fails
  List<Map<String, dynamic>> _generateFallbackMissions({
    required int visionTimeframeYears,
    required String currentBuilding,
    required String visionInfluenceScale,
  }) {
    // Divide timeframe into 3 missions
    final timePerMission = (visionTimeframeYears / 3).ceil();
    
    return [
      {
        'mission': 'Mission 1 — Foundation Building',
        'mission_sequence': '1',
        'focus': 'Establish foundational capabilities and expand from current operations',
        'structural_shift': 'Transition from $currentBuilding to a more scalable operational model',
        'capability_required': 'Core competencies in execution, team building, and resource management',
        'risk_or_value_guardrail': 'Low risk - Focus on building strong foundations without overextending',
        'time_horizon': '0-$timePerMission years'
      },
      {
        'mission': 'Mission 2 — Scale Expansion',
        'mission_sequence': '2',
        'focus': 'Scale operations and influence to reach broader impact',
        'structural_shift': 'Expand scope and scale toward $visionInfluenceScale level influence',
        'capability_required': 'Systems thinking, strategic partnerships, and resource mobilization',
        'risk_or_value_guardrail': 'Medium risk - Balance growth with sustainability and core values',
        'time_horizon': '$timePerMission-${timePerMission * 2} years'
      },
      {
        'mission': 'Mission 3 — Vision Realization',
        'mission_sequence': '3',
        'focus': 'Achieve vision-level influence and impact',
        'structural_shift': 'Operating at $visionInfluenceScale scale with established authority',
        'capability_required': 'Strategic leadership, influence management, and legacy building',
        'risk_or_value_guardrail': 'Medium risk - Maintain alignment with purpose while achieving vision',
        'time_horizon': '${timePerMission * 2}-$visionTimeframeYears years'
      }
    ];
  }

  /// Generate a goal suggestion for a specific mission
  /// Takes into account the mission context and existing goals
  Future<Map<String, dynamic>> generateGoalSuggestion({
    required String missionTitle,
    required String missionFocus,
    required String structuralShift,
    required String capabilityRequired,
    required List<Map<String, dynamic>> existingGoals,
  }) async {
    final prompt = _buildGoalSuggestionPrompt(
      missionTitle: missionTitle,
      missionFocus: missionFocus,
      structuralShift: structuralShift,
      capabilityRequired: capabilityRequired,
      existingGoals: existingGoals,
    );

    try {
      final response = await _makeOpenAIRequest(
        model: AIConfig.proModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.7,
        maxTokens: 800,
        responseFormat: {'type': 'json_object'},
      );

      final content = _extractContent(response);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error generating goal suggestion: $e');
      rethrow;
    }
  }

  /// Build the prompt for goal suggestion
  String _buildGoalSuggestionPrompt({
    required String missionTitle,
    required String missionFocus,
    required String structuralShift,
    required String capabilityRequired,
    required List<Map<String, dynamic>> existingGoals,
  }) {
    final existingGoalsText = existingGoals.isEmpty
        ? 'No existing goals yet.'
        : existingGoals.map((g) {
            final achieved = g['achieved'] == true ? '✓ Achieved' : '○ Not yet achieved';
            return '- ${g['title']}: ${g['description']} [$achieved]';
          }).join('\n');

    return '''
You are a strategic goal planning assistant. Your task is to suggest ONE specific, actionable goal for the following mission.

MISSION CONTEXT:
Title: $missionTitle
Focus: $missionFocus
Structural Shift Required: $structuralShift
Capability Required: $capabilityRequired

EXISTING GOALS FOR THIS MISSION:
$existingGoalsText

INSTRUCTIONS:
1. Suggest ONE new goal that is:
   - Specific and clearly defined
   - Achievable within the mission's scope
   - Directly relevant to the mission's focus and structural shift
   - Different from existing goals (avoid duplication)
   - A key milestone toward completing this mission

2. The goal should be strategic and outcome-focused

3. DO NOT include:
   - Measurable requirements (those belong in objectives)
   - Time constraints or deadlines (those belong in objectives)
   - Budget estimates
   - Implementation details

4. Focus on WHAT should be achieved, not HOW or WHEN

5. Respond with valid JSON in this format:
{
  "title": "Clear, concise goal title (5-10 words)",
  "description": "Detailed description of what this goal aims to achieve and why it matters for this mission (2-3 sentences)",
  "reasoning": "Brief explanation of why this goal is important for this mission right now (1-2 sentences)"
}

Think strategically about what key milestone would most advance this mission toward its focus and structural shift.
''';
  }

  /// Generate a single objective suggestion for a goal
  Future<Map<String, dynamic>> generateObjectiveSuggestion({
    required String missionTitle,
    required String missionFocus,
    required String goalTitle,
    required String goalDescription,
    required List<Map<String, dynamic>> existingObjectives,
  }) async {
    try {
      final prompt = _buildObjectiveSuggestionPrompt(
        missionTitle: missionTitle,
        missionFocus: missionFocus,
        goalTitle: goalTitle,
        goalDescription: goalDescription,
        existingObjectives: existingObjectives,
      );

      final response = await _makeOpenAIRequest(
        model: AIConfig.proModel,
        messages: [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        temperature: 0.7,
        maxTokens: 800,
        responseFormat: {'type': 'json_object'},
      );

      final content = _extractContent(response);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error generating objective suggestion: $e');
      rethrow;
    }
  }

  /// Build the prompt for objective suggestion
  String _buildObjectiveSuggestionPrompt({
    required String missionTitle,
    required String missionFocus,
    required String goalTitle,
    required String goalDescription,
    required List<Map<String, dynamic>> existingObjectives,
  }) {
    final existingObjectivesText = existingObjectives.isEmpty
        ? 'No existing objectives yet.'
        : existingObjectives.map((o) {
            final achieved = o['achieved'] == true ? '✓ Achieved' : '○ Not yet achieved';
            return '- ${o['title']}: ${o['description']}\n  Measurable: ${o['measurableRequirement']} [$achieved]';
          }).join('\n');

    return '''
You are a tactical planning assistant. Your task is to suggest ONE specific, measurable objective for the following goal.

MISSION CONTEXT:
Title: $missionTitle
Focus: $missionFocus

GOAL CONTEXT:
Title: $goalTitle
Description: $goalDescription

EXISTING OBJECTIVES FOR THIS GOAL:
$existingObjectivesText

INSTRUCTIONS:
1. Suggest ONE new objective that is:
   - Specific and actionable
   - Directly contributes to achieving the goal
   - Measurable with clear success criteria
   - Different from existing objectives (avoid duplication)
   - A concrete step toward completing this goal

2. The objective should be tactical and action-focused

3. MUST include:
   - A clear, measurable requirement (the metric/criteria for success)
   - A specific description of what needs to be done
   - How achievement will be measured or verified

4. DO NOT include:
   - Due dates or time constraints (user will add these)
   - Cost estimates (user will add these)
   - Time/hour estimates (user will add these)
   - Vague or subjective measures

5. The measurable requirement should be:
   - Quantifiable where possible (numbers, percentages, specific outcomes)
   - Verifiable (can be checked objectively)
   - Closely aligned with the description
   - Clear enough that anyone could determine if it's achieved

6. Respond with valid JSON in this format:
{
  "title": "Clear, action-oriented objective title (5-10 words)",
  "description": "Detailed description of what needs to be done and what achievement looks like (2-3 sentences)",
  "measurableRequirement": "Specific, quantifiable metric or criteria that defines success (e.g., 'Increase conversion rate from 2% to 5%', 'Complete onboarding for 50 users', 'Reduce load time to under 2 seconds')",
  "reasoning": "Brief explanation of why this objective is important for achieving the goal (1-2 sentences)"
}

Focus on creating a measurable requirement that directly corresponds to the objective's description and provides clear success criteria.
''';
  }
}
