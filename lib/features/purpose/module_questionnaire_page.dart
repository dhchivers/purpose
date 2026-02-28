import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/question_module.dart';
import 'package:purpose/core/models/question.dart';
import 'package:purpose/core/models/user_answer.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Provider for a specific question module
final moduleProvider =
    FutureProvider.family<QuestionModule?, String>((ref, moduleId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getQuestionModule(moduleId);
});

/// Provider for active questions in a module
final moduleActiveQuestionsProvider =
    StreamProvider.family<List<Question>, String>((ref, moduleId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.questionsStream(moduleId);
});

/// Provider for user's answers to a module
final userModuleAnswersProvider = StreamProvider.family<List<UserAnswer>, 
    ({String userId, String strategyId, String moduleId})>((ref, params) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  // Load all answers for this module to determine filtering strategy
  return firestoreService.userAnswersStream(
    userId: params.userId,
    strategyId: null, // Load all answers, then filter based on context
    questionModuleId: params.moduleId,
  ).map((allAnswers) {
    // Check if there are ANY answers with a strategyId set (not null)
    final hasStrategySpecificAnswers = allAnswers.any((answer) => answer.strategyId != null);
    
    // Filter answers based on whether strategy-specific answers exist
    if (hasStrategySpecificAnswers) {
      // If strategy-specific answers exist, ONLY show answers for current strategy
      return allAnswers.where((answer) => answer.strategyId == params.strategyId).toList();
    } else {
      // If all answers have null strategyId (true legacy), show them for all strategies
      return allAnswers.where((answer) => answer.strategyId == null).toList();
    }
  });
});

class ModuleQuestionnairePage extends ConsumerStatefulWidget {
  final String moduleId;

  const ModuleQuestionnairePage({
    super.key,
    required this.moduleId,
  });

  @override
  ConsumerState<ModuleQuestionnairePage> createState() =>
      _ModuleQuestionnairePageState();
}

class _ModuleQuestionnairePageState
    extends ConsumerState<ModuleQuestionnairePage> {
  int _currentQuestionIndex = 0;
  int? _lastPrefilledQuestionIndex; // Track which question was last prefilled
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for different question types
  final _textController = TextEditingController();
  String? _selectedOption;
  int? _scaleValue;
  bool? _booleanValue;
  List<String> _selectedMultipleOptions = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final activeStrategy = ref.watch(activeStrategyProvider);
    final moduleAsync = ref.watch(moduleProvider(widget.moduleId));
    final questionsAsync = ref.watch(moduleActiveQuestionsProvider(widget.moduleId));

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }
    
    if (activeStrategy == null) {
      return const Scaffold(
        body: Center(child: Text('No active strategy')),
      );
    }

    final answersAsync = ref.watch(userModuleAnswersProvider(
      (userId: user.uid, strategyId: activeStrategy.id, moduleId: widget.moduleId),
    ));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: moduleAsync.when(
          data: (module) => Text(module?.name ?? 'Questions'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/purpose'),
        ),
      ),
      body: moduleAsync.when(
        data: (module) {
          if (module == null) {
            return const Center(child: Text('Module not found'));
          }

          return questionsAsync.when(
            data: (questions) {
              if (questions.isEmpty) {
                return const Center(
                  child: Text('No questions available in this module'),
                );
              }

              return answersAsync.when(
                data: (answers) => _buildQuestionnaire(
                  context,
                  user,
                  activeStrategy.id,
                  module,
                  questions,
                  answers,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) {
                  // Log error to console
                  print('=== ANSWERS ERROR ===');
                  print('Error: $error');
                  print('Stack: $stack');
                  return const Center(
                    child: Text('Unable to load answers. Check console for details.'),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              // Log error to console
              print('=== PURPOSE QUESTIONNAIRE ERROR ===');
              print('Error: $error');
              print('Stack: $stack');
              // Return simple error message without displaying full details
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Unable to load questions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Check the console for error details',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          // Log error to console
          print('=== MODULE ERROR ===');
          print('Error: $error');
          print('Stack: $stack');
          return const Center(
            child: Text('Unable to load module. Check console for details.'),
          );
        },
      ),
    );
  }

  Widget _buildQuestionnaire(
    BuildContext context,
    dynamic user,
    String strategyId,
    QuestionModule module,
    List<Question> questions,
    List<UserAnswer> answers,
  ) {
    // Check if all questions are answered
    final totalQuestions = questions.length;

    // Show completion screen if we're past the last question
    // This allows users to re-enter answers even after completing the module
    if (_currentQuestionIndex >= questions.length) {
      return _buildCompletionScreen(context, module, totalQuestions);
    }

    // Get current question
    final currentQuestion = questions[_currentQuestionIndex];
    final existingAnswer = answers.firstWhere(
      (a) => a.questionId == currentQuestion.id,
      orElse: () => UserAnswer(
        id: '',
        userId: user.uid,
        strategyId: strategyId,
        questionId: currentQuestion.id,
        questionModuleId: widget.moduleId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Pre-fill controllers with existing answer only when question changes
    if (_lastPrefilledQuestionIndex != _currentQuestionIndex) {
      _lastPrefilledQuestionIndex = _currentQuestionIndex; // Mark as handled immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (existingAnswer.id.isNotEmpty) {
            _prefillAnswer(currentQuestion, existingAnswer);
          } else {
            // Clear fields for new question with no saved answer
            _clearFieldsForNewQuestion();
          }
        }
      });
    }

    // Calculate progress based on current question position
    final progress = ((_currentQuestionIndex + 1) / totalQuestions * 100).toInt();

    return Column(
      children: [
        // Progress bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppTheme.primaryTintLight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1} of $totalQuestions',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$progress% Complete',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / totalQuestions,
                  minHeight: 8,
                  backgroundColor: AppTheme.primaryTintLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ],
          ),
        ),

        // Question content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentQuestion.questionText,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (currentQuestion.helperText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      currentQuestion.helperText!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _buildQuestionInput(currentQuestion),
                ],
              ),
            ),
          ),
        ),

        // Navigation buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Cancel and go back without saving
                    context.go('/purpose');
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentQuestionIndex--;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
                    child: const Text('Previous'),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _saveAndContinue(user, currentQuestion, questions),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _currentQuestionIndex < questions.length - 1
                        ? 'Next'
                        : 'Complete',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionInput(Question question) {
    switch (question.questionType) {
      case QuestionType.shortText:
        return TextFormField(
          controller: _textController,
          decoration: const InputDecoration(
            labelText: 'Your answer',
            border: OutlineInputBorder(),
          ),
          maxLength: question.answerCharacterLimit,
          validator: (value) {
            if (question.isRequired && (value == null || value.isEmpty)) {
              return 'This question is required';
            }
            return null;
          },
        );

      case QuestionType.longText:
        return TextFormField(
          controller: _textController,
          decoration: const InputDecoration(
            labelText: 'Your answer',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 5,
          maxLength: question.answerCharacterLimit,
          validator: (value) {
            if (question.isRequired && (value == null || value.isEmpty)) {
              return 'This question is required';
            }
            return null;
          },
        );

      case QuestionType.multipleChoice:
        if (question.options == null || question.options!.isEmpty) {
          return const Text('No options available');
        }

        if (question.allowMultipleSelections == true) {
          // Checkboxes for multiple selection
          return Column(
            children: question.options!.map((option) {
              return CheckboxListTile(
                title: Text(option),
                value: _selectedMultipleOptions.contains(option),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedMultipleOptions.add(option);
                    } else {
                      _selectedMultipleOptions.remove(option);
                    }
                  });
                },
              );
            }).toList(),
          );
        } else {
          // Radio buttons for single selection
          return Column(
            children: question.options!.map((option) {
              return RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: _selectedOption,
                onChanged: (value) {
                  setState(() {
                    _selectedOption = value;
                  });
                },
              );
            }).toList(),
          );
        }

      case QuestionType.scale:
        final min = question.scaleMin ?? 1;
        final max = question.scaleMax ?? 10;
        final labels = question.scaleLabels;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (labels != null && labels.isNotEmpty)
                  Text(
                    labels[0],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                Text(
                  _scaleValue?.toString() ?? 'Select',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (labels != null && labels.length > 1)
                  Text(
                    labels[1],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Slider(
              value: (_scaleValue ?? min).toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              label: _scaleValue?.toString(),
              onChanged: (value) {
                setState(() {
                  _scaleValue = value.toInt();
                });
              },
            ),
          ],
        );

      case QuestionType.yesNo:
        return Column(
          children: [
            RadioListTile<bool>(
              title: const Text('Yes'),
              value: true,
              groupValue: _booleanValue,
              onChanged: (value) {
                setState(() {
                  _booleanValue = value;
                });
              },
            ),
            RadioListTile<bool>(
              title: const Text('No'),
              value: false,
              groupValue: _booleanValue,
              onChanged: (value) {
                setState(() {
                  _booleanValue = value;
                });
              },
            ),
          ],
        );
    }
  }

  void _prefillAnswer(Question question, UserAnswer answer) {
    if (answer.id.isEmpty) return;

    setState(() {
      switch (question.questionType) {
        case QuestionType.shortText:
        case QuestionType.longText:
          _textController.text = answer.textAnswer ?? '';
          break;
        case QuestionType.multipleChoice:
          if (question.allowMultipleSelections == true) {
            // Handle multiple selections stored in textAnswer as comma-separated
            _selectedMultipleOptions = answer.textAnswer?.split(',') ?? [];
          } else {
            _selectedOption = answer.selectedOption;
          }
          break;
        case QuestionType.scale:
          _scaleValue = answer.numericAnswer;
          break;
        case QuestionType.yesNo:
          _booleanValue = answer.booleanAnswer;
          break;
      }
    });
  }

  void _clearFieldsForNewQuestion() {
    setState(() {
      _textController.clear();
      _selectedOption = null;
      _scaleValue = null;
      _booleanValue = null;
      _selectedMultipleOptions = [];
    });
  }

  Future<void> _saveAndContinue(
    dynamic user,
    Question question,
    List<Question> questions,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final activeStrategy = ref.read(activeStrategyProvider);
      
      if (activeStrategy == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active strategy')),
        );
        return;
      }
      
      // Check if an answer already exists for this question
      final existingAnswer = await firestoreService.getUserAnswer(
        userId: user.uid,
        strategyId: activeStrategy.id,
        questionId: question.id,
      );

      // Create answer based on question type
      UserAnswer answer;
      final now = DateTime.now();

      switch (question.questionType) {
        case QuestionType.shortText:
        case QuestionType.longText:
          if (question.isRequired && _textController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please provide an answer')),
            );
            return;
          }
          answer = UserAnswer(
            id: existingAnswer?.id ?? '', // Use existing ID or empty for new
            userId: user.uid,
            strategyId: activeStrategy.id,
            questionId: question.id,
            questionModuleId: widget.moduleId,
            textAnswer: _textController.text.trim(),
            createdAt: existingAnswer?.createdAt ?? now,
            updatedAt: now,
          );
          break;

        case QuestionType.multipleChoice:
          if (question.allowMultipleSelections == true) {
            if (question.isRequired && _selectedMultipleOptions.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select at least one option')),
              );
              return;
            }
            // Store multiple selections as comma-separated text
            answer = UserAnswer(
              id: existingAnswer?.id ?? '',
              userId: user.uid,
              strategyId: activeStrategy.id,
              questionId: question.id,
              questionModuleId: widget.moduleId,
              textAnswer: _selectedMultipleOptions.join(','),
              createdAt: existingAnswer?.createdAt ?? now,
              updatedAt: now,
            );
          } else {
            if (question.isRequired && _selectedOption == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select an option')),
              );
              return;
            }
            answer = UserAnswer(
              id: existingAnswer?.id ?? '',
              userId: user.uid,
              strategyId: activeStrategy.id,
              questionId: question.id,
              questionModuleId: widget.moduleId,
              selectedOption: _selectedOption,
              createdAt: existingAnswer?.createdAt ?? now,
              updatedAt: now,
            );
          }
          break;

        case QuestionType.scale:
          if (question.isRequired && _scaleValue == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a value')),
            );
            return;
          }
          answer = UserAnswer(
            id: existingAnswer?.id ?? '',
            userId: user.uid,
            strategyId: activeStrategy.id,
            questionId: question.id,
            questionModuleId: widget.moduleId,
            numericAnswer: _scaleValue,
            createdAt: existingAnswer?.createdAt ?? now,
            updatedAt: now,
          );
          break;

        case QuestionType.yesNo:
          if (question.isRequired && _booleanValue == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select Yes or No')),
            );
            return;
          }
          answer = UserAnswer(
            id: existingAnswer?.id ?? '',
            userId: user.uid,
            strategyId: activeStrategy.id,
            questionId: question.id,
            questionModuleId: widget.moduleId,
            booleanAnswer: _booleanValue,
            createdAt: existingAnswer?.createdAt ?? now,
            updatedAt: now,
          );
          break;
      }

      // Debug logging
      print('=== SAVING ANSWER ===');
      print('User ID: ${answer.userId}');
      print('Question ID: ${answer.questionId}');
      print('Module ID: ${answer.questionModuleId}');
      print('Answer ID: ${answer.id}');
      print('Is Update: ${existingAnswer != null}');
      
      await firestoreService.saveUserAnswer(answer);
      
      print('Answer saved successfully');

      // Move to next question or finish
      if (_currentQuestionIndex < questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
        });
      } else {
        // All questions answered - trigger backend AI processing and show completion
        _triggerBackendAIProcessing(user.uid, widget.moduleId);
        setState(() {
          _currentQuestionIndex++; // Move past last question to show completion screen
        });
      }
    } catch (e, stack) {
      print('=== ERROR SAVING ANSWER ===');
      print('Error: $e');
      print('Stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving answer: $e')),
        );
      }
    }
  }

  /// Triggers backend AI processing for the completed module
  /// This is a hook for backend Cloud Functions or Firebase Extensions
  /// to process the user's answers and generate AI insights
  Future<void> _triggerBackendAIProcessing(String userId, String moduleId) async {
    try {
      print('=== BACKEND AI PROCESSING TRIGGER ===');
      print('User ID: $userId');
      print('Module ID: $moduleId');
      print('Timestamp: ${DateTime.now().toIso8601String()}');
      
      // TODO: Implement backend trigger
      // This could be:
      // 1. Writing a document to a Firestore collection that triggers a Cloud Function
      // 2. Calling a Firebase Extension
      // 3. Making an HTTP request to a backend API
      // 4. Adding a document to a processing queue
      
      // Example placeholder for Firestore trigger:
      // await firestoreService.createAIProcessingRequest(
      //   userId: userId,
      //   moduleId: moduleId,
      //   status: 'pending',
      //   createdAt: DateTime.now(),
      // );
      
      print('Backend AI processing trigger completed (placeholder)');
    } catch (e) {
      print('Error triggering backend AI processing: $e');
      // Don't show error to user - this should happen in the background
    }
  }

  Widget _buildCompletionScreen(
    BuildContext context,
    QuestionModule module,
    int totalQuestions,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Module Complete!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You\'ve answered all $totalQuestions questions in "${module.name}"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Your responses have been saved and will be analyzed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You can revisit and update your answers anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/purpose'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text(
                'Back to Purpose Modules',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentQuestionIndex = 0;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              icon: const Icon(Icons.edit),
              label: const Text(
                'Review My Answers',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
