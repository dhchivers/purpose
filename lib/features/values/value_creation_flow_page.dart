import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/core/models/value_creation_session.dart';
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

  // Phase 2 controllers
  final _phase2Answer1Controller = TextEditingController();
  final _phase2Answer2Controller = TextEditingController();
  final _phase2Answer3Controller = TextEditingController();
  final _phase2FormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Initialize with Phase 1
    _initializeSession();
  }

  @override
  void dispose() {
    _phase2Answer1Controller.dispose();
    _phase2Answer2Controller.dispose();
    _phase2Answer3Controller.dispose();
    super.dispose();
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
      final questions = await geminiService.generateValueClarificationQuestions(
        seedValue: seedValue,
      );

      setState(() {
        _session = _session?.copyWith(
          seedValue: seedValue,
          currentPhase: 2,
          phase2Questions: questions,
        );
        _isLoading = false;
      });
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
      child: Form(
        key: _phase2FormKey,
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
                    'Take your time with each question.',
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
                  _buildQuestionCard(
                    questionNumber: 1,
                    question: questions[0],
                    controller: _phase2Answer1Controller,
                  ),
                  const SizedBox(height: 24),
                  _buildQuestionCard(
                    questionNumber: 2,
                    question: questions[1],
                    controller: _phase2Answer2Controller,
                  ),
                  const SizedBox(height: 24),
                  _buildQuestionCard(
                    questionNumber: 3,
                    question: questions[2],
                    controller: _phase2Answer3Controller,
                  ),
                  const SizedBox(height: 32),
                  
                  // Next button
                  ElevatedButton(
                    onPressed: _submitPhase2Answers,
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
      ),
    );
  }

  Widget _buildQuestionCard({
    required int questionNumber,
    required String question,
    required TextEditingController controller,
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
                    question,
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
            TextFormField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Share your thoughts...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide an answer';
                }
                if (value.trim().length < 10) {
                  return 'Please provide a more detailed answer';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submitPhase2Answers() {
    if (!_phase2FormKey.currentState!.validate()) {
      return;
    }

    final answers = [
      _phase2Answer1Controller.text.trim(),
      _phase2Answer2Controller.text.trim(),
      _phase2Answer3Controller.text.trim(),
    ];

    setState(() {
      _session = _session?.copyWith(
        phase2Answers: answers,
        currentPhase: 3, // Move to Phase 3
      );
    });

    // TODO: Save session to Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Phase 2 complete! Moving to Phase 3...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Phase 3: Scope Narrowing (placeholder)
  Widget _buildPhase3ScopeNarrowing() {
    return const Center(
      child: Text(
        'Phase 3: Scope Narrowing\n(Coming next)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  /// Phase 4: Friction & Sacrifice (placeholder)
  Widget _buildPhase4FrictionSacrifice() {
    return const Center(
      child: Text(
        'Phase 4: Friction & Sacrifice\n(Coming next)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  /// Phase 5: Operationalization (placeholder)
  Widget _buildPhase5Operationalization() {
    return const Center(
      child: Text(
        'Phase 5: Operationalization\n(Coming next)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  /// Final: Value Selection (placeholder)
  Widget _buildFinalSelection() {
    return const Center(
      child: Text(
        'Final: Select Your Value Statement\n(Coming next)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}
