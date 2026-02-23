import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/core/models/value_creation_session.dart';
import 'package:purpose/core/models/user_value.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Provider for streaming value seeds
final valueSeedsProvider = StreamProvider<List<String>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.valueSeedsStream();
});

/// Page for creating a refined value through the 5-phase process
class ValueCreationFlowPage extends ConsumerStatefulWidget {
  const ValueCreationFlowPage({super.key});

  @override
  ConsumerState<ValueCreationFlowPage> createState() => _ValueCreationFlowPageState();
}

class _ValueCreationFlowPageState extends ConsumerState<ValueCreationFlowPage> {
  ValueCreationSession? _session;
  bool _isLoading = false;

  // Phase 2 selected answers (indices of selected options)
  String? _phase2Answer1;
  String? _phase2Answer2;
  String? _phase2Answer3;

  // Phase 3 selected answers
  String? _phase3Answer1;
  String? _phase3Answer2;
  String? _phase3Answer3;

  // Phase 4 selected answers
  String? _phase4Answer1;
  String? _phase4Answer2;
  String? _phase4Answer3;

  // Phase 5 selected answers
  String? _phase5Answer1;
  String? _phase5Answer2;
  String? _phase5Answer3;

  // Final selection
  int? _selectedOptionIndex;
  TextEditingController? _customStatementController;
  bool _isEditingStatement = false;

  @override
  void initState() {
    super.initState();
    _customStatementController = TextEditingController();
    // Initialize with Phase 1
    _initializeSession();
  }

  void _initializeSession() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() {
      _session = ValueCreationSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        seedValue: '', // Will be set when user selects
        startedAt: DateTime.now(),
        currentPhase: 1,
      );
    });
  }

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Value Creation'),
        content: const Text(
          'Are you sure you want to cancel? Your progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Creating'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.go('/');
    }
  }

  void _selectSeedValue(String seedValue) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Generate Phase 2 clarification questions
      final geminiService = await ref.read(geminiServiceProvider.future);
      final questionsData = await geminiService.generateValueClarificationQuestions(
        seedValue: seedValue,
      );

      // Convert to MultipleChoiceQuestion objects
      final questions = questionsData.map((q) {
        return MultipleChoiceQuestion(
          question: q['question'] as String,
          options: (q['options'] as List).cast<String>(),
        );
      }).toList();

      setState(() {
        _session = _session?.copyWith(
          seedValue: seedValue,
          currentPhase: 2,
          phase2Questions: questions,
        );
        _isLoading = false;
      });

      // Save session to Firestore
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.saveValueCreationSession(_session!);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating questions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Text('Create Value - Phase ${_session!.currentPhase}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmCancel,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPhaseContent(),
    );
  }

  Widget _buildPhaseContent() {
    switch (_session!.currentPhase) {
      case 1:
        return _buildPhase1SeedSelection();
      case 2:
        return _buildPhase2Clarification();
      case 3:
        return _buildPhase3ScopeNarrowing();
      case 4:
        return _buildPhase4FrictionSacrifice();
      case 5:
        return _buildPhase5Operationalization();
      case 6:
        return _buildFinalSelection();
      default:
        return const Center(child: Text('Invalid phase'));
    }
  }

  /// Phase 1: Seed Value Selection
  Widget _buildPhase1SeedSelection() {
    final valueSeedsAsync = ref.watch(valueSeedsProvider);

    return valueSeedsAsync.when(
      data: (seeds) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              color: AppTheme.primaryTintLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Select a Seed Value',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.graphite,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose a broad value that resonates with you. We\'ll help you refine it into a precise personal value through guided questions.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppTheme.graphite,
                    ),
                  ),
                ],
              ),
            ),

            // Seeds list
            Padding(
              padding: const EdgeInsets.all(16),
              child: seeds.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 48),
                          Icon(
                            Icons.lightbulb_outline,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No seed values available',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please contact an administrator',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.5,
                      ),
                      itemCount: seeds.length,
                      itemBuilder: (context, index) {
                        final seed = seeds[index];
                        return Card(
                          elevation: 2,
                          child: InkWell(
                            onTap: () => _selectSeedValue(seed),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  seed,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading values: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(valueSeedsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Phase 2: Clarification
  Widget _buildPhase2Clarification() {
    if (_session!.phase2Questions == null || _session!.phase2Questions!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final questions = _session!.phase2Questions!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.primaryTintLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PHASE 2',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Clarify: ${_session!.seedValue}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Let\'s explore what this value means to you personally. '
                  'Select the answer that resonates most with you.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),

          // Questions
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMultipleChoiceQuestion(
                  questionNumber: 1,
                  question: questions[0],
                  selectedAnswer: _phase2Answer1,
                  onChanged: (value) => setState(() => _phase2Answer1 = value),
                ),
                const SizedBox(height: 24),
                _buildMultipleChoiceQuestion(
                  questionNumber: 2,
                  question: questions[1],
                  selectedAnswer: _phase2Answer2,
                  onChanged: (value) => setState(() => _phase2Answer2 = value),
                ),
                const SizedBox(height: 24),
                _buildMultipleChoiceQuestion(
                  questionNumber: 3,
                  question: questions[2],
                  selectedAnswer: _phase2Answer3,
                  onChanged: (value) => setState(() => _phase2Answer3 = value),
                ),
                const SizedBox(height: 32),
                
                // Next button
                ElevatedButton(
                  onPressed: (_phase2Answer1 != null && 
                             _phase2Answer2 != null && 
                             _phase2Answer3 != null)
                      ? _submitPhase2Answers
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue to Next Phase',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildMultipleChoiceQuestion({
    required int questionNumber,
    required MultipleChoiceQuestion question,
    required String? selectedAnswer,
    required ValueChanged<String?> onChanged,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$questionNumber',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.question,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...question.options.map((option) {
              return RadioListTile<String>(
                title: Text(
                  option,
                  style: const TextStyle(fontSize: 14),
                ),
                value: option,
                groupValue: selectedAnswer,
                onChanged: onChanged,
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _submitPhase2Answers() async {
    // Validate all answers are selected
    if (_phase2Answer1 == null || _phase2Answer2 == null || _phase2Answer3 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions')),
      );
      return;
    }

    final answers = [_phase2Answer1!, _phase2Answer2!, _phase2Answer3!];

    // Build context with questions and answers
    final questionsText = _session!.phase2Questions!.map((q) => q.question).toList();

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate Phase 3 questions and refined label
      final geminiService = await ref.read(geminiServiceProvider.future);
      final result = await geminiService.generateValueScopeNarrowing(
        seedValue: _session!.seedValue,
        phase2Questions: questionsText,
        phase2Answers: answers,
      );

      final refinedLabel = result['refinedLabel'] as String;
      final questionsData = result['questions'] as List;

      // Convert to MultipleChoiceQuestion objects
      final questions = questionsData.map((q) {
        return MultipleChoiceQuestion(
          question: q['question'] as String,
          options: (q['options'] as List).cast<String>(),
        );
      }).toList();

      setState(() {
        _session = _session?.copyWith(
          phase2Answers: answers,
          currentPhase: 3,
          refinedValuePhase3: refinedLabel,
          phase3Questions: questions,
        );
        _isLoading = false;
      });

      // Save session to Firestore
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.saveValueCreationSession(_session!);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating Phase 3: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Phase 3: Scope Narrowing
  Widget _buildPhase3ScopeNarrowing() {
    if (_session!.phase3Questions == null || _session!.phase3Questions!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final questions = _session!.phase3Questions!;
    final refinedLabel = _session!.refinedValuePhase3 ?? _session!.seedValue;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.primaryTintLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PHASE 3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Narrow the Scope',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Show refined label
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Refined Value:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        refinedLabel,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Let\'s narrow down the specific ways this value applies to your life. '
                  'Select the answer that best describes your situation.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),

          // Questions
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMultipleChoiceQuestion(
                  questionNumber: 1,
                  question: questions[0],
                  selectedAnswer: _phase3Answer1,
                  onChanged: (value) => setState(() => _phase3Answer1 = value),
                ),
                const SizedBox(height: 24),
                _buildMultipleChoiceQuestion(
                  questionNumber: 2,
                  question: questions[1],
                  selectedAnswer: _phase3Answer2,
                  onChanged: (value) => setState(() => _phase3Answer2 = value),
                ),
                const SizedBox(height: 24),
                _buildMultipleChoiceQuestion(
                  questionNumber: 3,
                  question: questions[2],
                  selectedAnswer: _phase3Answer3,
                  onChanged: (value) => setState(() => _phase3Answer3 = value),
                ),
                const SizedBox(height: 32),
                
                // Next button
                ElevatedButton(
                  onPressed: (_phase3Answer1 != null && 
                             _phase3Answer2 != null && 
                             _phase3Answer3 != null)
                      ? _submitPhase3Answers
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue to Next Phase',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  void _submitPhase3Answers() async {
    // Validate all answers are selected
    if (_phase3Answer1 == null || _phase3Answer2 == null || _phase3Answer3 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions')),
      );
      return;
    }

    final answers = [_phase3Answer1!, _phase3Answer2!, _phase3Answer3!];

    // Build context with questions
    final questionsText = _session!.phase3Questions!.map((q) => q.question).toList();

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate Phase 4 questions and refined label
      final geminiService = await ref.read(geminiServiceProvider.future);
      final result = await geminiService.generateValueFrictionSacrifice(
        seedValue: _session!.seedValue,
        refinedLabel: _session!.refinedValuePhase3 ?? _session!.seedValue,
        phase3Questions: questionsText,
        phase3Answers: answers,
      );

      final refinedLabel = result['refinedLabel'] as String;
      final questionsData = result['questions'] as List;

      // Convert to MultipleChoiceQuestion objects
      final questions = questionsData.map((q) {
        return MultipleChoiceQuestion(
          question: q['question'] as String,
          options: (q['options'] as List).cast<String>(),
        );
      }).toList();

      setState(() {
        _session = _session?.copyWith(
          phase3Answers: answers,
          currentPhase: 4,
          refinedValuePhase4: refinedLabel,
          phase4Questions: questions,
        );
        _isLoading = false;
      });

      // Save session to Firestore
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.saveValueCreationSession(_session!);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating Phase 4: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Phase 4: Friction & Sacrifice
  Widget _buildPhase4FrictionSacrifice() {
    if (_session!.phase4Questions == null || _session!.phase4Questions!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final questions = _session!.phase4Questions!;
    final refinedLabel = _session!.refinedValuePhase4 ?? 
                         _session!.refinedValuePhase3 ?? 
                         _session!.seedValue;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.primaryTintLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PHASE 4',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Test Your Commitment',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Show refined label
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Value:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        refinedLabel,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Let\'s test this value against real challenges. '
                  'Select the option that best reflects your true commitment.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),

          // Questions
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMultipleChoiceQuestion(
                  questionNumber: 1,
                  question: questions[0],
                  selectedAnswer: _phase4Answer1,
                  onChanged: (value) => setState(() => _phase4Answer1 = value),
                ),
                const SizedBox(height: 24),
                _buildMultipleChoiceQuestion(
                  questionNumber: 2,
                  question: questions[1],
                  selectedAnswer: _phase4Answer2,
                  onChanged: (value) => setState(() => _phase4Answer2 = value),
                ),
                const SizedBox(height: 24),
                _buildMultipleChoiceQuestion(
                  questionNumber: 3,
                  question: questions[2],
                  selectedAnswer: _phase4Answer3,
                  onChanged: (value) => setState(() => _phase4Answer3 = value),
                ),
                const SizedBox(height: 32),
                
                // Next button
                ElevatedButton(
                  onPressed: (_phase4Answer1 != null && 
                             _phase4Answer2 != null && 
                             _phase4Answer3 != null)
                      ? _submitPhase4Answers
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue to Next Phase',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Future<void> _submitPhase4Answers() async {
    // Validate all answers are selected
    if (_phase4Answer1 == null || _phase4Answer2 == null || _phase4Answer3 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions')),
      );
      return;
    }

    final answers = [_phase4Answer1!, _phase4Answer2!, _phase4Answer3!];

    // Store Phase 4 answers first
    setState(() {
      _session = _session?.copyWith(
        phase4Answers: answers,
      );
    });

    // Generate Phase 5 questions via AI
    try {
      final geminiService = ref.read(geminiServiceProvider).value;
      if (geminiService == null) {
        throw Exception('AI service not available');
      }

      // Convert phase4Questions to List<String>
      final phase4QuestionStrings = _session!.phase4Questions!.map((q) => q.question).toList();

      final response = await geminiService.generateValueOperationalization(
        seedValue: _session!.seedValue,
        refinedLabel: _session!.refinedValuePhase4!,
        phase4Questions: phase4QuestionStrings,
        phase4Answers: answers,
      );

      // Convert response to MultipleChoiceQuestion objects
      final questions = (response['questions'] as List)
          .map((q) => MultipleChoiceQuestion(
                question: q['question'] as String,
                options: (q['options'] as List).cast<String>(),
              ))
          .toList();

      setState(() {
        _session = _session?.copyWith(
          phase5Questions: questions,
          refinedValuePhase5: response['refinedLabel'] as String?,
          currentPhase: 5,
        );
      });

      // Save session to Firestore
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.saveValueCreationSession(_session!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating Phase 5 questions: $e')),
        );
      }
    }
  }

  /// Phase 5: Operationalization
  Widget _buildPhase5Operationalization() {
    if (_session!.phase5Questions?.isEmpty ?? true) {
      return const Center(child: CircularProgressIndicator());
    }

    final refinedLabel = _session!.refinedValuePhase5 ?? _session!.refinedValuePhase4 ?? _session!.seedValue;
    final allAnswered = _phase5Answer1 != null &&
        _phase5Answer2 != null &&
        _phase5Answer3 != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'PHASE 5',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Make It Operational',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Show refined value
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Value:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  refinedLabel,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Helper text
          const Text(
            'Now let\'s translate this commitment into concrete, measurable action. Answer these questions to operationalize your value:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Questions
          _buildMultipleChoiceQuestion(
            questionNumber: 1,
            question: _session!.phase5Questions![0],
            selectedAnswer: _phase5Answer1,
            onChanged: (value) {
              setState(() {
                _phase5Answer1 = value;
              });
            },
          ),
          const SizedBox(height: 32),

          _buildMultipleChoiceQuestion(
            questionNumber: 2,
            question: _session!.phase5Questions![1],
            selectedAnswer: _phase5Answer2,
            onChanged: (value) {
              setState(() {
                _phase5Answer2 = value;
              });
            },
          ),
          const SizedBox(height: 32),

          _buildMultipleChoiceQuestion(
            questionNumber: 3,
            question: _session!.phase5Questions![2],
            selectedAnswer: _phase5Answer3,
            onChanged: (value) {
              setState(() {
                _phase5Answer3 = value;
              });
            },
          ),
          const SizedBox(height: 48),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: allAnswered ? _submitPhase5Answers : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Complete Value Creation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: allAnswered ? Colors.white : Colors.grey[500],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _submitPhase5Answers() async {
    if (_phase5Answer1 == null ||
        _phase5Answer2 == null ||
        _phase5Answer3 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions')),
      );
      return;
    }

    final answers = [_phase5Answer1!, _phase5Answer2!, _phase5Answer3!];

    // Store Phase 5 answers first
    setState(() {
      _session = _session!.copyWith(
        phase5Answers: answers,
      );
    });

    // Generate final value statement options via AI
    try {
      final geminiService = ref.read(geminiServiceProvider).value;
      if (geminiService == null) {
        throw Exception('AI service not available');
      }

      // Convert all questions to List<String>
      final phase2QuestionStrings = _session!.phase2Questions!.map((q) => q.question).toList();
      final phase3QuestionStrings = _session!.phase3Questions!.map((q) => q.question).toList();
      final phase4QuestionStrings = _session!.phase4Questions!.map((q) => q.question).toList();
      final phase5QuestionStrings = _session!.phase5Questions!.map((q) => q.question).toList();

      final response = await geminiService.generateFinalValueStatements(
        seedValue: _session!.seedValue,
        refinedLabel: _session!.refinedValuePhase5 ?? _session!.refinedValuePhase4 ?? _session!.seedValue,
        phase2Questions: phase2QuestionStrings,
        phase2Answers: _session!.phase2Answers!,
        phase3Questions: phase3QuestionStrings,
        phase3Answers: _session!.phase3Answers!,
        phase4Questions: phase4QuestionStrings,
        phase4Answers: _session!.phase4Answers!,
        phase5Questions: phase5QuestionStrings,
        phase5Answers: answers,
      );

      // Convert response to ValueOption objects
      final options = response
          .map((opt) => ValueOption(
                label: opt['label'] as String,
                statement: opt['statement'] as String,
              ))
          .toList();

      setState(() {
        _session = _session!.copyWith(
          finalValueOptions: options,
          currentPhase: 6,
        );
      });

      // Save session to Firestore
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.saveValueCreationSession(_session!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating value statements: $e')),
        );
      }
    }
  }

  /// Final: Value Selection
  Widget _buildFinalSelection() {
    if (_session!.finalValueOptions?.isEmpty ?? true) {
      return const Center(child: CircularProgressIndicator());
    }

    final refinedLabel = _session!.refinedValuePhase5 ?? _session!.refinedValuePhase4 ?? _session!.seedValue;
    final options = _session!.finalValueOptions!;
    final hasSelection = _selectedOptionIndex != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Completion badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'FINAL STEP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Choose Your Value Statement',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Show refined value
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR VALUE:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  refinedLabel,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Helper text
          const Text(
            'Based on your responses, here are 3 ways to express your value. Choose one or edit it to make it your own:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Value statement options
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _selectedOptionIndex == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: isSelected ? 4 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : Colors.grey[300]!,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOptionIndex = index;
                      _isEditingStatement = false;
                      _customStatementController?.text = option.statement;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<int>(
                              value: index,
                              groupValue: _selectedOptionIndex,
                              onChanged: (value) {
                                setState(() {
                                  _selectedOptionIndex = value;
                                  _isEditingStatement = false;
                                  _customStatementController?.text = option.statement;
                                });
                              },
                              activeColor: AppTheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            option.statement,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: isSelected ? Colors.black87 : Colors.black54,
                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 24),

          // Edit option
          if (hasSelection) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Want to personalize it?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isEditingStatement = !_isEditingStatement;
                    });
                  },
                  child: Text(
                    _isEditingStatement ? 'Cancel Edit' : 'Edit Statement',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isEditingStatement) ...[
              TextField(
                controller: _customStatementController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Edit your value statement here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
            ],
          ],

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasSelection ? _confirmValueSelection : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Confirm My Value',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: hasSelection ? Colors.white : Colors.grey[500],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmValueSelection() async {
    if (_selectedOptionIndex == null) return;

    final selectedOption = _session!.finalValueOptions![_selectedOptionIndex!];
    final finalStatement = _isEditingStatement && _customStatementController!.text.isNotEmpty
        ? _customStatementController!.text
        : selectedOption.statement;
    final refinedLabel = _session!.refinedValuePhase5 ?? _session!.refinedValuePhase4 ?? _session!.seedValue;

    setState(() {
      _session = _session!.copyWith(
        selectedOptionIndex: _selectedOptionIndex,
        customStatement: _isEditingStatement ? finalStatement : null,
        completedAt: DateTime.now(),
      );
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final user = ref.read(currentUserProvider).value;
      
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create UserValue document
      final userValue = UserValue(
        id: 'value_${DateTime.now().millisecondsSinceEpoch}',
        userId: user.uid,
        seedValue: _session!.seedValue,
        refinedLabel: refinedLabel,
        statement: finalStatement,
        createdAt: DateTime.now(),
        sessionId: _session!.id,
        creationContext: {
          'selectedOptionLabel': selectedOption.label,
          'wasEdited': _isEditingStatement,
        },
      );

      // Save the final value
      await firestoreService.saveUserValue(userValue);

      // Update session with completion timestamp
      await firestoreService.saveValueCreationSession(_session!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Value "$refinedLabel" created successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Schedule navigation after current frame to avoid Navigator lock
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving value: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _customStatementController?.dispose();
    super.dispose();
  }
}
