import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/question_module.dart';
import 'package:purpose/core/models/module_type.dart';
import 'package:purpose/core/models/strategy_type.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/features/admin/admin_strategy_types_page.dart';

/// Provider for streaming Purpose modules
final purposeModulesProvider = StreamProvider<List<QuestionModule>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.questionModulesStream(ModuleType.purpose);
});

/// Provider to get the actual question count for a module
final moduleQuestionCountProvider = FutureProvider.family<int, String>((ref, moduleId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final questions = await firestoreService.getQuestionsByModule(moduleId);
  return questions.length;
});

/// Provider to check if a module is completed by a user
final moduleCompletionProvider = StreamProvider.family<bool, ({String userId, String strategyId, String moduleId})>((ref, params) async* {
  final firestoreService = ref.watch(firestoreServiceProvider);
  
  print('🔍 moduleCompletionProvider START for module: ${params.moduleId}, strategy: ${params.strategyId}, user: ${params.userId}');
  
  // Stream answers and check completion on each update
  final answersStream = firestoreService.userAnswersStream(
    userId: params.userId,
    strategyId: null, // Load all answers to see what we have
    questionModuleId: params.moduleId,
  );
  
  print('🔍 About to listen to answersStream...');
  
  await for (final allAnswers in answersStream) {
    print('📊 Total answers for module ${params.moduleId}: ${allAnswers.length}');
    
    // Log all answer strategyIds for debugging
    for (var answer in allAnswers) {
      print('  Answer ${answer.id}: questionId=${answer.questionId}, strategyId=${answer.strategyId}');
    }
    
    // STRICT FILTERING: Only show answers that match the current strategyId
    // This ensures each strategy has its own isolated set of answers
    final answers = allAnswers.where((answer) {
      final matches = answer.strategyId == params.strategyId;
      if (!matches && answer.strategyId == null) {
        print('  ⚠️ Ignoring null-strategyId answer ${answer.id} for questionId ${answer.questionId}');
      } else if (!matches && answer.strategyId != null) {
        print('  ⚠️ Ignoring answer ${answer.id} with different strategyId: ${answer.strategyId}');
      }
      return matches;
    }).toList();
    
    print('  Filtered to answers with strategyId=${params.strategyId}: ${answers.length}');
    
    // Get current active questions
    final questions = await firestoreService.getQuestionsByModule(params.moduleId);
    print('  Total questions in module: ${questions.length}');
    
    if (questions.isEmpty) {
      print('  ⚠️ No questions found, yielding false');
      yield false;
      continue;
    }
    
    // Check if all questions have answers
    final answeredQuestionIds = answers.map((a) => a.questionId).toSet();
    final isComplete = questions.every((q) => answeredQuestionIds.contains(q.id));
    
    print('  ✅ Module completion status: $isComplete');
    print('  Answered questions: ${answeredQuestionIds.length}/${questions.length}');
    
    yield isComplete;
  }
});

/// Provider to check if all purpose modules are completed
final allPurposeModulesCompleteProvider = StreamProvider.family<bool, ({String userId, String strategyId, String strategyTypeId})>((ref, params) async* {
  final modulesAsync = await ref.watch(purposeModulesProvider.future);
  
  // Filter modules by strategy type (including modules with null strategyTypeId)
  final filteredModules = modulesAsync.where((module) => 
    module.strategyTypeId == params.strategyTypeId ||
    module.strategyTypeId == null
  ).toList();
  
  if (filteredModules.isEmpty) {
    yield false;
    return;
  }
  
  // Create streams for each module completion and combine them
  await for (final _ in Stream.periodic(const Duration(milliseconds: 500))) {
    // Get current completion status for all filtered modules
    final completionStates = filteredModules.map((module) {
      final completionAsync = ref.read(
        moduleCompletionProvider((userId: params.userId, strategyId: params.strategyId, moduleId: module.id))
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

  Future<void> _debugCheckAnswers(WidgetRef ref, String userId, String strategyId) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final modules = await ref.read(purposeModulesProvider.future);
    
    print('\n=== DEBUG: Checking answers for strategyId=$strategyId ===');
    
    for (var module in modules) {
      // Get all answers for this module (no strategy filter)
      final allAnswers = await firestoreService.getUserAnswersByModule(
        userId: userId,
        questionModuleId: module.id,
      );
      
      print('\n📦 Module: ${module.name} (${module.id})');
      print('   Total answers in DB: ${allAnswers.length}');
      
      if (allAnswers.isNotEmpty) {
        for (var answer in allAnswers) {
          print('   - Answer ${answer.id}: questionId=${answer.questionId}, strategyId=${answer.strategyId}');
        }
      }
      
      // Check strategy-specific answers
      final strategyAnswers = allAnswers.where((a) => a.strategyId == strategyId).toList();
      print('   Answers matching strategyId=$strategyId: ${strategyAnswers.length}');
      
      // Check questions
      final questions = await firestoreService.getQuestionsByModule(module.id);
      print('   Total questions: ${questions.length}');
    }
    
    print('\n=== END DEBUG ===\n');
  }

  Future<void> _migrateNullAnswersToStrategy(WidgetRef ref, String userId, String strategyId) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final modules = await ref.read(purposeModulesProvider.future);
    
    print('\n=== MIGRATING NULL-STRATEGYID ANSWERS ===');
    print('Target strategyId: $strategyId');
    
    int totalMigrated = 0;
    
    for (var module in modules) {
      final allAnswers = await firestoreService.getUserAnswersByModule(
        userId: userId,
        questionModuleId: module.id,
      );
      
      final nullAnswers = allAnswers.where((a) => a.strategyId == null).toList();
      
      if (nullAnswers.isNotEmpty) {
        print('\n📦 Module: ${module.name}');
        print('   Migrating ${nullAnswers.length} answers...');
        
        for (var answer in nullAnswers) {
          // Create updated answer with strategyId
          final updatedAnswer = UserAnswer(
            id: answer.id,
            userId: answer.userId,
            strategyId: strategyId, // Set the strategy ID
            questionId: answer.questionId,
            questionModuleId: answer.questionModuleId,
            textAnswer: answer.textAnswer,
            selectedOption: answer.selectedOption,
            numericAnswer: answer.numericAnswer,
            booleanAnswer: answer.booleanAnswer,
            createdAt: answer.createdAt,
            updatedAt: DateTime.now(),
          );
          
          await firestoreService.saveUserAnswer(updatedAnswer);
          totalMigrated++;
          print('   ✅ Migrated answer ${answer.id}');
        }
      }
    }
    
    print('\n=== MIGRATION COMPLETE ===');
    print('Total answers migrated: $totalMigrated');
    print('=========================\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final modulesAsync = ref.watch(purposeModulesProvider);
    final activeStrategy = ref.watch(activeStrategyProvider);
    final strategyTypesAsync = ref.watch(strategyTypesStreamProvider);

    print('🎯 PurposeModulesPage build: activeStrategy = ${activeStrategy?.id} (${activeStrategy?.name})');
    
    // Auto-migrate null-strategyId answers on page load
    if (activeStrategy != null) {
      currentUserAsync.whenData((user) {
        if (user != null) {
          Future.microtask(() async {
            await _debugCheckAnswers(ref, user.uid, activeStrategy.id);
            // Auto-migrate null answers to current strategy
            await _migrateNullAnswersToStrategy(ref, user.uid, activeStrategy.id);
          });
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.graphite,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Text(activeStrategy?.name ?? 'Purpose'),
            if (activeStrategy != null) ...[
              const SizedBox(width: 12),
              strategyTypesAsync.when(
                data: (types) {
                  final strategyType = types.firstWhere(
                    (type) => type.id == activeStrategy.strategyTypeId,
                    orElse: () => StrategyType(
                      id: '',
                      name: 'Unknown',
                      enabled: true,
                      order: 0,
                      color: 0xFF2196F3,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  return Chip(
                    label: Text(
                      strategyType.name,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Color(strategyType.color),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: currentUserAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please log in'));
          }
          
          if (activeStrategy == null) {
            return const Center(child: Text('No active strategy'));
          }

          return modulesAsync.when(
            data: (modules) {
              // Filter modules to show those matching the active strategy type
              // OR modules without a strategy type (legacy modules)
              final filteredModules = modules.where((module) => 
                module.strategyTypeId == activeStrategy.strategyTypeId ||
                module.strategyTypeId == null
              ).toList();
              
              if (filteredModules.isEmpty) {
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
                        'No modules found for this strategy type',
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
                      color: AppTheme.primary,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Purpose',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Modules list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredModules.length,
                      itemBuilder: (context, index) {
                        final module = filteredModules[index];
                        
                        return _ModuleCard(
                          module: module,
                          userId: user.uid,
                          strategyId: activeStrategy.id,
                        );
                      },
                    ),
                  ),

                  // Analysis button
                  Consumer(
                    builder: (context, ref, child) {
                      final allCompleteAsync = ref.watch(
                        allPurposeModulesCompleteProvider((
                          userId: user.uid, 
                          strategyId: activeStrategy.id,
                          strategyTypeId: activeStrategy.strategyTypeId,
                        )),
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
}

/// Module card widget with completion status
class _ModuleCard extends ConsumerWidget {
  final QuestionModule module;
  final String userId;
  final String strategyId;

  const _ModuleCard({
    required this.module,
    required this.userId,
    required this.strategyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('🃏 _ModuleCard build: module=${module.name}, strategyId=$strategyId');
    
    final completionAsync = ref.watch(moduleCompletionProvider(
      (userId: userId, strategyId: strategyId, moduleId: module.id),
    ));

    return completionAsync.when(
      data: (isCompleted) {
        print('  ✅ Module ${module.name}: isCompleted=$isCompleted');
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
                          Consumer(
                            builder: (context, ref, child) {
                              final questionCountAsync = ref.watch(moduleQuestionCountProvider(module.id));
                              return Row(
                                children: [
                                  Icon(
                                    Icons.quiz_outlined,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  questionCountAsync.when(
                                    data: (count) => Text(
                                      '$count questions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    loading: () => Text(
                                      '${module.totalQuestions} questions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    error: (_, __) => Text(
                                      '${module.totalQuestions} questions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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
      loading: () {
        print('  ⏳ Module ${module.name}: LOADING completion status');
        return Card(
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
      );
      },
      error: (error, stack) {
        print('  ❌ Module ${module.name}: ERROR - $error');
        return Card(
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
                      Consumer(
                        builder: (context, ref, child) {
                          final questionCountAsync = ref.watch(moduleQuestionCountProvider(module.id));
                          return Row(
                            children: [
                              Icon(
                                Icons.quiz_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              questionCountAsync.when(
                                data: (count) => Text(
                                  '$count questions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                loading: () => Text(
                                  '${module.totalQuestions} questions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                error: (_, __) => Text(
                                  '${module.totalQuestions} questions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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
      );
      },
    );
  }
}
