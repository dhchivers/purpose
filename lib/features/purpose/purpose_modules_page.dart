import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/question_module.dart';
import 'package:purpose/core/models/module_type.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';import 'package:purpose/core/theme/app_theme.dart';import 'dart:convert';

/// Provider for streaming Purpose modules
final purposeModulesProvider = StreamProvider<List<QuestionModule>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.questionModulesStream(ModuleType.purpose);
});

/// Provider to check if a module is completed by a user
final moduleCompletionProvider = StreamProvider.family<bool, ({String userId, String moduleId})>((ref, params) async* {
  final firestoreService = ref.watch(firestoreServiceProvider);
  
  // Stream answers and check completion on each update
  final answersStream = firestoreService.userAnswersStream(
    userId: params.userId,
    questionModuleId: params.moduleId,
  );
  
  await for (final answers in answersStream) {
    // Get current active questions (they rarely change, so fetching is fine)
    final questions = await firestoreService.getQuestionsByModule(params.moduleId);
    
    if (questions.isEmpty) {
      yield false;
      continue;
    }
    
    // Check if all questions have answers
    final answeredQuestionIds = answers.map((a) => a.questionId).toSet();
    final isComplete = questions.every((q) => answeredQuestionIds.contains(q.id));
    yield isComplete;
  }
});

/// Provider to check if all purpose modules are completed
final allPurposeModulesCompleteProvider = StreamProvider.family<bool, String>((ref, userId) async* {
  final modulesAsync = await ref.watch(purposeModulesProvider.future);
  
  if (modulesAsync.isEmpty) {
    yield false;
    return;
  }
  
  // Create streams for each module completion and combine them
  await for (final _ in Stream.periodic(const Duration(milliseconds: 500))) {
    // Get current completion status for all modules
    final completionStates = modulesAsync.map((module) {
      final completionAsync = ref.read(
        moduleCompletionProvider((userId: userId, moduleId: module.id))
      );
      return completionAsync.whenOrNull(data: (isComplete) => isComplete) ?? false;
    }).toList();
    
    // Check if all are complete
    final allComplete = completionStates.isNotEmpty && 
                        completionStates.every((isComplete) => isComplete);
    
    yield allComplete;
  }
});

class PurposeModulesPage extends ConsumerWidget {
  const PurposeModulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final modulesAsync = ref.watch(purposeModulesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Purpose - Context Collection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          // Temporary debug button
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'View JSON Data',
            onPressed: () => _showJsonDialog(context, ref, currentUserAsync.value?.uid),
          ),
        ],
      ),
      body: currentUserAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please log in'));
          }

          return modulesAsync.when(
            data: (modules) {
              if (modules.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_outline,
                        size: 80,
                        color: AppTheme.primaryLight,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Purpose Modules Available',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check back soon for context collection modules',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Header section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Discover Your Purpose',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete ${modules.length} module${modules.length != 1 ? 's' : ''} to uncover what drives you',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress indicator
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.primaryTintLight,
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Answer questions in each module sequentially. Your responses will help shape your purpose statement.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.graphite,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Modules list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        final module = modules[index];
                        
                        return _ModuleCard(
                          module: module,
                          userId: user.uid,
                        );
                      },
                    ),
                  ),

                  // Analysis button
                  Consumer(
                    builder: (context, ref, child) {
                      final allCompleteAsync = ref.watch(
                        allPurposeModulesCompleteProvider(user.uid),
                      );

                      return allCompleteAsync.when(
                        data: (isComplete) {
                          if (!isComplete) return const SizedBox.shrink();

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTintLight,
                              border: Border(
                                top: BorderSide(color: AppTheme.primaryLight),
                              ),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => context.go('/purpose/analysis'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              icon: const Icon(Icons.analytics),
                              label: const Text(
                                'View Identity Analysis',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              print('=== PURPOSE MODULES ERROR ===');
              print('Error: $error');
              print('Stack trace: $stack');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading modules: $error'),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  /// Show dialog with JSON data for debugging
  void _showJsonDialog(BuildContext context, WidgetRef ref, String? userId) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading data...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      
      // Fetch all purpose modules
      final modules = await firestoreService.getAllQuestionModules();
      final purposeModules = modules.where((m) => m.parentModule == ModuleType.purpose).toList();
      
      // Build hierarchy
      final List<Map<String, dynamic>> hierarchy = [];
      
      for (final module in purposeModules) {
        // Get questions for this module
        final questions = await firestoreService.getQuestionsByModule(module.id);
        
        // Get user answers for this module
        final answers = await firestoreService.getUserAnswersByModule(
          userId: userId,
          questionModuleId: module.id,
        );
        
        // Create answer map for quick lookup
        final answerMap = {for (var a in answers) a.questionId: a};
        
        // Build questions with answers
        final questionsData = questions.map((q) {
          final answer = answerMap[q.id];
          return {
            'id': q.id,
            'questionText': q.questionText,
            'helperText': q.helperText,
            'questionType': q.questionType.value,
            'order': q.order,
            'isRequired': q.isRequired,
            'answer': answer != null ? {
              'id': answer.id,
              'textAnswer': answer.textAnswer,
              'numericAnswer': answer.numericAnswer,
              'selectedOption': answer.selectedOption,
              'booleanAnswer': answer.booleanAnswer,
              'notes': answer.notes,
              'createdAt': answer.createdAt.toIso8601String(),
              'updatedAt': answer.updatedAt.toIso8601String(),
            } : null,
          };
        }).toList();
        
        // Add module with questions and answers
        hierarchy.add({
          'id': module.id,
          'name': module.name,
          'description': module.description,
          'questions': questionsData,
        });
      }
      
      final jsonData = {
        'userId': userId,
        'moduleType': 'purpose',
        'exportedAt': DateTime.now().toIso8601String(),
        'modules': hierarchy,
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show JSON dialog
        showDialog(
          context: context,
          builder: (context) => _JsonDataDialog(jsonString: jsonString),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }
}

/// Dialog to display JSON data with copy functionality
class _JsonDataDialog extends StatelessWidget {
  final String jsonString;

  const _JsonDataDialog({required this.jsonString});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Purpose Data (JSON)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF4A148C), // Dark purple
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy to Clipboard'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: jsonString));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('JSON copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Module card widget with completion status
class _ModuleCard extends ConsumerWidget {
  final QuestionModule module;
  final String userId;

  const _ModuleCard({
    required this.module,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionAsync = ref.watch(moduleCompletionProvider(
      (userId: userId, moduleId: module.id),
    ));

    return completionAsync.when(
      data: (isCompleted) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: isCompleted ? 1 : 2,
          child: InkWell(
            onTap: () => context.go('/purpose/module/${module.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isCompleted
                    ? Border.all(color: Colors.green.shade300, width: 2)
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Order badge or completion checkmark
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.shade100
                            : AppTheme.primaryTintLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(
                                Icons.check_circle,
                                size: 32,
                                color: Colors.green.shade700,
                              )
                            : Text(
                                '${module.order}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Module info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  module.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted
                                        ? Colors.green.shade900
                                        : null,
                                  ),
                                ),
                              ),
                              if (isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Completed',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            module.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.quiz_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${module.totalQuestions} questions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isCompleted ? Icons.refresh : Icons.arrow_forward_ios,
                      size: 20,
                      color: isCompleted ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      module.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () => context.go('/purpose/module/${module.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTintLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${module.order}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        module.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${module.totalQuestions} questions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
