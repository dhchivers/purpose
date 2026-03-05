import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/question_module.dart';
import 'package:purpose/core/models/module_type.dart';
import 'package:purpose/core/models/strategy_type.dart';
import 'package:purpose/core/models/user_answer.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/features/admin/admin_strategy_types_page.dart';
import 'identity_analysis_page.dart';

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
  
  // print('🔍 moduleCompletionProvider START for module: ${params.moduleId}, strategy: ${params.strategyId}, user: ${params.userId}');
  
  // Stream answers and check completion on each update
  final answersStream = firestoreService.userAnswersStream(
    userId: params.userId,
    strategyId: null, // Load all answers to see what we have
    questionModuleId: params.moduleId,
  );
  
  // print('🔍 About to listen to answersStream...');
  
  await for (final allAnswers in answersStream) {
    // print('📊 Total answers for module ${params.moduleId}: ${allAnswers.length}');
    
    // Log all answer strategyIds for debugging
    // for (var answer in allAnswers) {
    //   print('  Answer ${answer.id}: questionId=${answer.questionId}, strategyId=${answer.strategyId}');
    // }
    
    // STRICT FILTERING: Only show answers that match the current strategyId
    // This ensures each strategy has its own isolated set of answers
    final answers = allAnswers.where((answer) {
      final matches = answer.strategyId == params.strategyId;
      // if (!matches && answer.strategyId == null) {
      //   print('  ⚠️ Ignoring null-strategyId answer ${answer.id} for questionId ${answer.questionId}');
      // } else if (!matches && answer.strategyId != null) {
      //   print('  ⚠️ Ignoring answer ${answer.id} with different strategyId: ${answer.strategyId}');
      // }
      return matches;
    }).toList();
    
    // print('  Filtered to answers with strategyId=${params.strategyId}: ${answers.length}');
    
    // Get current active questions
    final questions = await firestoreService.getQuestionsByModule(params.moduleId);
    // print('  Total questions in module: ${questions.length}');
    
    if (questions.isEmpty) {
      // print('  ⚠️ No questions found, yielding false');
      yield false;
      continue;
    }
    
    // Check if all questions have answers
    final answeredQuestionIds = answers.map((a) => a.questionId).toSet();
    final isComplete = questions.every((q) => answeredQuestionIds.contains(q.id));
    
    // print('  ✅ Module completion status: $isComplete');
    // print('  Answered questions: ${answeredQuestionIds.length}/${questions.length}');
    
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

  // Debug function - DISABLED
  // Future<void> _debugCheckAnswers(WidgetRef ref, String userId, String strategyId) async {
  //   final firestoreService = ref.read(firestoreServiceProvider);
  //   final modules = await ref.read(purposeModulesProvider.future);
  //   
  //   for (var module in modules) {
  //     final allAnswers = await firestoreService.getUserAnswersByModule(
  //       userId: userId,
  //       questionModuleId: module.id,
  //     );
  //   }
  // }

  Future<void> _migrateNullAnswersToStrategy(WidgetRef ref, String userId, String strategyId) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final modules = await ref.read(purposeModulesProvider.future);
    
    // print('\n=== MIGRATING NULL-STRATEGYID ANSWERS ===');
    // print('Target strategyId: $strategyId');
    
    // int totalMigrated = 0;
    
    for (var module in modules) {
      final allAnswers = await firestoreService.getUserAnswersByModule(
        userId: userId,
        questionModuleId: module.id,
      );
      
      final nullAnswers = allAnswers.where((a) => a.strategyId == null).toList();
      
      if (nullAnswers.isNotEmpty) {
        // print('\n📦 Module: ${module.name}');
        // print('   Migrating ${nullAnswers.length} answers...');
        
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
          // totalMigrated++;
          // print('   ✅ Migrated answer ${answer.id}');
        }
      }
    }
    
    // print('\n=== MIGRATION COMPLETE ===');
    // print('Total answers migrated: $totalMigrated');
    // print('=========================\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final modulesAsync = ref.watch(purposeModulesProvider);
    final activeStrategy = ref.watch(activeStrategyProvider);
    final strategyTypesAsync = ref.watch(strategyTypesStreamProvider);

    // print('🎯 PurposeModulesPage build: activeStrategy = ${activeStrategy?.id} (${activeStrategy?.name})');
    
    // Auto-migrate null-strategyId answers on page load
    if (activeStrategy != null) {
      currentUserAsync.whenData((user) {
        if (user != null) {
          Future.microtask(() async {
            // await _debugCheckAnswers(ref, user.uid, activeStrategy.id);
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

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: Purpose Statement
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
                            'Your Purpose',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            activeStrategy.purpose ?? 'Complete the modules below to discover your purpose.',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // SECTION 2: Module Cards (Horizontal)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Question Modules',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.graphite,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: filteredModules.length,
                              itemBuilder: (context, index) {
                                final module = filteredModules[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: index < filteredModules.length - 1 ? 12 : 0,
                                  ),
                                  child: _CompactModuleCard(
                                    module: module,
                                    moduleNumber: index + 1,
                                    userId: user.uid,
                                    strategyId: activeStrategy.id,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // SECTION 3: Integrated Identity Analysis
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

                            return _IntegratedIdentitySection(
                              userId: user.uid,
                              strategyId: activeStrategy.id,
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                  ],
                ),
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

/// Compact horizontal module card for the new layout
class _CompactModuleCard extends ConsumerWidget {
  final QuestionModule module;
  final int moduleNumber;
  final String userId;
  final String strategyId;

  const _CompactModuleCard({
    required this.module,
    required this.moduleNumber,
    required this.userId,
    required this.strategyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionAsync = ref.watch(moduleCompletionProvider(
      (userId: userId, strategyId: strategyId, moduleId: module.id),
    ));
    
    final questionCountAsync = ref.watch(moduleQuestionCountProvider(module.id));

    return completionAsync.when(
      data: (isCompleted) {
        return SizedBox(
          width: 280,
          child: Card(
            elevation: 2,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with number/check and re-run icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Badge
                          Container(
                            width: 40,
                            height: 40,
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
                                      size: 24,
                                      color: Colors.green.shade700,
                                    )
                                  : Text(
                                      '$moduleNumber',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                            ),
                          ),
                          // Re-run icon button
                          if (isCompleted)
                            IconButton(
                              icon: Icon(
                                Icons.refresh,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () => context.go('/purpose/module/${module.id}'),
                              tooltip: 'Re-run module',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Module title
                      Text(
                        module.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? Colors.green.shade900 : AppTheme.graphite,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Bottom row with question count and completion chip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Question count
                          questionCountAsync.when(
                            data: (count) => Row(
                              children: [
                                Icon(
                                  Icons.quiz_outlined,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            loading: () => Row(
                              children: [
                                Icon(
                                  Icons.quiz_outlined,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${module.totalQuestions}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            error: (_, __) => Row(
                              children: [
                                Icon(
                                  Icons.quiz_outlined,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${module.totalQuestions}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Completion chip
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () {
        return SizedBox(
          width: 280,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    module.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      error: (_, __) {
        return SizedBox(
          width: 280,
          child: Card(
            child: InkWell(
              onTap: () => context.go('/purpose/module/${module.id}'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTintLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$moduleNumber',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      module.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Integrated Identity Analysis Section
class _IntegratedIdentitySection extends ConsumerWidget {
  final String userId;
  final String strategyId;

  const _IntegratedIdentitySection({
    required this.userId,
    required this.strategyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the same provider from identity_analysis_page
    final synthesisAsync = ref.watch(identitySynthesisResultProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryTintLight,
        border: Border(
          top: BorderSide(color: AppTheme.primaryLight, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.psychology,
                color: AppTheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Integrated Identity Analysis',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.graphite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          synthesisAsync.when(
            data: (result) {
              if (result == null) {
                return Column(
                  children: [
                    const Text(
                      'Analysis not yet available. Click below to generate.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/purpose/analysis'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.analytics),
                      label: const Text('Generate Analysis'),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Integrated Identity
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Integrated Identity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          result.integratedIdentity.summary,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppTheme.graphite,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tier Analysis Summary
                  if (result.tierAnalysis.isNotEmpty) ...[
                    const Text(
                      'Analysis by Module',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.graphite,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...result.tierAnalysis.map((tier) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier.tierName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tier.summary,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // View Full Analysis Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/purpose/analysis'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.description),
                      label: const Text('View Full Analysis'),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) {
              return Column(
                children: [
                  Text(
                    'Error loading analysis: ${error.toString()}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/purpose/analysis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.analytics),
                    label: const Text('View Identity Analysis'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
