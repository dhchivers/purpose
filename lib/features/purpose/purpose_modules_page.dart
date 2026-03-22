import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/question_module.dart';
import 'package:purpose/core/models/module_type.dart';
import 'package:purpose/core/models/user_answer.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/models/user_comment.dart';
import 'package:purpose/core/services/user_comment_provider.dart';
import 'package:intl/intl.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'identity_analysis_page.dart';

/// Provider for streaming Purpose modules
final purposeModulesProvider = StreamProvider<List<QuestionModule>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  // Add distinct to only emit when the list actually changes
  return firestoreService.questionModulesStream(ModuleType.purpose).distinct((prev, next) {
    // Only emit if the list length changed or the module IDs changed
    if (prev.length != next.length) return false;
    for (int i = 0; i < prev.length; i++) {
      if (prev[i].id != next[i].id) return false;
    }
    return true; // Lists are the same, don't emit
  });
});

/// Provider to check if a module is completed by a user
/// Changed from StreamProvider to FutureProvider to prevent constant rebuilds
/// Uses keepAlive to cache results and reduce refetches
final moduleCompletionProvider = FutureProvider.family.autoDispose<bool, ({String userId, String strategyId, String moduleId})>((ref, params) async {
  // Keep the provider alive to prevent refetching
  ref.keepAlive();
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  
  // Get current snapshot of answers (not a stream)
  final allAnswers = await firestoreService.getUserAnswersByModule(
    userId: params.userId,
    questionModuleId: params.moduleId,
  );
  
  // STRICT FILTERING: Only show answers that match the current strategyId
  final answers = allAnswers.where((answer) => answer.strategyId == params.strategyId).toList();
  
  // Get current active questions
  final questions = await firestoreService.getQuestionsByModule(params.moduleId);
  
  if (questions.isEmpty) {
    return false;
  }
  
  // Check if all questions have answers
  final answeredQuestionIds = answers.map((a) => a.questionId).toSet();
  final isComplete = questions.every((q) => answeredQuestionIds.contains(q.id));
  
  return isComplete;
});

/// Provider to check if all purpose modules are completed  
final allPurposeModulesCompleteProvider = FutureProvider.family<bool, ({String userId, String strategyId, String strategyTypeId})>((ref, params) async {
  final modulesAsync = await ref.watch(purposeModulesProvider.future);
  
  // Filter modules by strategy type (including modules with null strategyTypeId)
  final filteredModules = modulesAsync.where((module) => 
    module.strategyTypeId == params.strategyTypeId ||
    module.strategyTypeId == null
  ).toList();
  
  if (filteredModules.isEmpty) {
    return false;
  }
  
  // Check each module for completion
  for (final module in filteredModules) {
    // Use the module completion provider to check this specific module
    final completionAsync = await ref.watch(
      moduleCompletionProvider((
        userId: params.userId, 
        strategyId: params.strategyId, 
        moduleId: module.id
      )).future
    );
    
    if (!completionAsync) {
      return false;
    }
  }
  
  return true;
});

/// Provider to get completion status for all modules at once
/// This prevents N individual provider watches
final allModulesCompletionProvider = FutureProvider.family<Map<String, bool>, ({String userId, String strategyId, List<QuestionModule> modules})>((ref, params) async {
  final Map<String, bool> completionMap = {};
  
  for (final module in params.modules) {
    final isComplete = await ref.watch(
      moduleCompletionProvider((
        userId: params.userId,
        strategyId: params.strategyId,
        moduleId: module.id,
      )).future,
    );
    completionMap[module.id] = isComplete;
  }
  
  return completionMap;
});

class PurposeModulesPage extends ConsumerStatefulWidget {
  const PurposeModulesPage({super.key});

  @override
  ConsumerState<PurposeModulesPage> createState() => _PurposeModulesPageState();
}

class _PurposeModulesPageState extends ConsumerState<PurposeModulesPage> {
  
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
  Widget build(BuildContext context) {
    // Watch all providers normally - the key is stable widget trees, not avoiding rebuilds
    final activeStrategy = ref.watch(activeStrategyProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final modulesAsync = ref.watch(purposeModulesProvider);
    
    // Use valueOrNull to get data without triggering .when() rebuild cascade
    final user = currentUserAsync.valueOrNull;
    final modules = modulesAsync.valueOrNull;
    
    // DISABLED: Auto-migration was causing rebuild loops and semantics errors
    // Migration should be handled at a different lifecycle point or removed
    // if (activeStrategy != null) {
    //   currentUserAsync.whenData((user) {
    //     if (user != null) {
    //       Future.microtask(() async {
    //         await _migrateNullAnswersToStrategy(ref, user.uid, activeStrategy.id);
    //       });
    //     }
    //   });
    // }
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.graphite,
        foregroundColor: Colors.white,
        title: Text(
          activeStrategy?.name ?? 'Purpose',
          style: const TextStyle(fontSize: 21),
          overflow: !kIsWeb && Platform.isIOS ? TextOverflow.ellipsis : null,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => context.go('/comments'),
            tooltip: 'Comments',
          ),
        ],
      ),
      // RepaintBoundary isolates rebuilds to prevent semantics errors
      body: RepaintBoundary(
        child: Builder(
          builder: (context) {
            // Use cached values from state to avoid rapid rebuilds
            // user and modules are already defined in the parent scope
            
            // Show loading ONLY if we're still waiting for initial data
            // This prevents rapid rebuilds during page load
            final isInitialLoading = user == null || modules == null || activeStrategy == null;
            
            if (isInitialLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            
            // Show error states - removed since we're using snapshots
            // if (user == null) {
            //   return const Center(child: Text('Please log in'));
            // }
            
            // if (modules == null) {
            //   return const Center(child: Text('Error loading modules'));
            // }
            
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: Purpose Statement
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => _PurposeCommentDialog(
                                    strategyId: activeStrategy.id,
                                    strategyName: activeStrategy.name,
                                    purposeStatement: activeStrategy.purpose,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.forum_outlined, size: 22),
                              color: Colors.white70,
                              tooltip: 'Provide Comment',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const Expanded(
                              child: Center(
                                child: Text(
                                  'Purpose',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // Invisible placeholder to balance left icon
                            const SizedBox(width: 22),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            activeStrategy.purpose ?? 'Complete the modules below to discover your purpose.',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // SECTION 2 & 3: Module Cards and Identity Analysis (Expanded to fill remaining height)
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      // Get completion status for all modules at once
                      final completionMapAsync = ref.watch(
                        allModulesCompletionProvider((
                          userId: user.uid,
                          strategyId: activeStrategy.id,
                          modules: filteredModules,
                        )),
                      );
                      
                      final completionMap = completionMapAsync.valueOrNull ?? {};
                      
                      // Check if all modules are complete
                      final isAllComplete = completionMap.isNotEmpty && 
                        completionMap.values.every((isComplete) => isComplete);

                      // If all modules complete, show only Identity Analysis
                      if (isAllComplete) {
                        return _IntegratedIdentitySection(
                          userId: user.uid,
                          strategyId: activeStrategy.id,
                        );
                      }
                      
                      // Otherwise, show modules vertically filling available space
                      return Padding(
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
                            Expanded(
                              child: ListView.builder(
                                scrollDirection: Axis.vertical,
                                itemCount: filteredModules.length,
                                itemBuilder: (context, index) {
                                  final module = filteredModules[index];
                                  final isCompleted = completionMap[module.id] ?? false;
                                  
                                  // Determine if this module should be enabled
                                  // Enable if: completed OR is the next incomplete module
                                  bool isEnabled = isCompleted;
                                  if (!isCompleted) {
                                    // Check if all previous modules are complete
                                    bool allPreviousComplete = true;
                                    for (int i = 0; i < index; i++) {
                                      if (!(completionMap[filteredModules[i].id] ?? false)) {
                                        allPreviousComplete = false;
                                        break;
                                      }
                                    }
                                    isEnabled = allPreviousComplete;
                                  }
                                  
                                  return Padding(
                                    key: ValueKey('module-${module.id}'),
                                    padding: EdgeInsets.only(
                                      bottom: index < filteredModules.length - 1 ? 12 : 0,
                                    ),
                                    child: _CompactModuleCard(
                                      key: ValueKey('card-${module.id}'),
                                      module: module,
                                      moduleNumber: index + 1,
                                      userId: user.uid,
                                      strategyId: activeStrategy.id,
                                      totalModules: filteredModules.length,
                                      isCompleted: isCompleted,
                                      isEnabled: isEnabled,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
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
  final int totalModules;
  final bool isCompleted;
  final bool isEnabled;

  const _CompactModuleCard({
    super.key,
    required this.module,
    required this.moduleNumber,
    required this.userId,
    required this.strategyId,
    required this.totalModules,
    required this.isCompleted,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: isEnabled ? () => context.go('/purpose/module/${module.id}') : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isCompleted
                  ? Border.all(color: Colors.green.shade300, width: 2)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Badge: number or check icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.shade100
                          : AppTheme.primaryTintLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(Icons.check_circle, size: 22, color: Colors.green.shade700)
                          : Text(
                              '$moduleNumber',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + question count
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? Colors.green.shade900 : AppTheme.graphite,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.quiz_outlined, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Text(
                              '${module.totalQuestions} questions',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Re-run icon (only when completed)
                  Visibility(
                    visible: isCompleted,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: IconButton(
                      icon: Icon(Icons.refresh, size: 18, color: Colors.grey.shade500),
                      onPressed: () => context.go('/purpose/module/${module.id}'),
                      tooltip: 'Re-run module',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
          ),
        ),
      ),
      ),
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
      decoration: BoxDecoration(
        color: AppTheme.primaryTintLight,
        border: Border(
          top: BorderSide(color: AppTheme.primaryLight, width: 2),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.graphite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              // Use valueOrNull to avoid constant rebuilds from .when()
              final result = synthesisAsync.valueOrNull;
              final isLoading = synthesisAsync.isLoading && !synthesisAsync.hasValue;
              final hasError = synthesisAsync.hasError && !synthesisAsync.hasValue;

              if (isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (hasError) {
                return Column(
                  children: [
                    Text(
                      'Error loading analysis: ${synthesisAsync.error.toString()}',
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
              }

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
          ),
        ],
        ),
      ),
    );
  }
}

class _PurposeCommentDialog extends ConsumerStatefulWidget {
  final String strategyId;
  final String strategyName;
  final String? purposeStatement;

  const _PurposeCommentDialog({
    required this.strategyId,
    required this.strategyName,
    this.purposeStatement,
  });

  @override
  ConsumerState<_PurposeCommentDialog> createState() =>
      _PurposeCommentDialogState();
}

class _PurposeCommentDialogState
    extends ConsumerState<_PurposeCommentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  bool _isSaving = false;
  bool _composing = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('User not authenticated');

      final commentId = FirebaseFirestore.instance
          .collection('user_comments')
          .doc()
          .id;

      await firestoreService.saveUserComment(UserComment(
        id: commentId,
        userId: currentUser.uid,
        entityId: widget.strategyId,
        entityType: 'purpose',
        commentText: _commentController.text.trim(),
        parentCommentId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment saved successfully!'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving comment: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grayLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.grayLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PURPOSE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grayMedium,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.purposeStatement ?? widget.strategyName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.graphite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_composing) ...[                TextFormField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    labelText: 'Comment',
                    hintText:
                        'Share your thoughts, progress, or reflections...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 2),
                    ),
                    counterText: '',
                  ),
                  maxLines: 8,
                  maxLength: 1000,
                  style: const TextStyle(fontSize: 12),
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your comment';
                    }
                    if (value.trim().length < 5) {
                      return 'Comment must be at least 5 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    ListenableBuilder(
                      listenable: _commentController,
                      builder: (ctx, _) => Text(
                        '${_commentController.text.length}/1000',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grayMedium,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => setState(() {
                                _composing = false;
                                _commentController.clear();
                              }),
                      child: const Text('Cancel',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : const Text('Submit'),
                    ),
                  ],
                ),
              ] else
                GestureDetector(
                  onTap: () => setState(() => _composing = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.grayLight),
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.grayLight.withOpacity(0.2),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_comment_outlined,
                            size: 14, color: AppTheme.grayMedium),
                        SizedBox(width: 8),
                        Text(
                          'Add a comment...',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.grayMedium),
                        ),
                      ],
                    ),
                  ),
                ),
              Builder(
                builder: (ctx) {
                  final commentsAsync = ref.watch(
                    commentsForEntityStreamProvider(
                        (widget.strategyId, 'purpose')),
                  );
                  return commentsAsync.when(
                    data: (allComments) {
                      final parents = allComments
                          .where((c) => c.parentCommentId == null)
                          .toList()
                        ..sort(
                            (a, b) => b.createdAt.compareTo(a.createdAt));
                      if (parents.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Divider(height: 16),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxHeight: 240),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildCommentWidgets(
                                    allComments, parents),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCommentWidgets(
      List<UserComment> allComments, List<UserComment> parents) {
    final widgets = <Widget>[];
    for (final parent in parents) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _commentTile(parent),
      ));
      final replies = allComments
          .where((c) => c.parentCommentId == parent.id)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final reply in replies) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Container(
            padding: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
            child: _commentTile(reply),
          ),
        ));
      }
    }
    return widgets;
  }

  Widget _commentTile(UserComment comment) {
    final now = DateTime.now();
    final diff = now.difference(comment.createdAt);
    final String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'just now';
    } else if (diff.inHours < 1) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      timeAgo = '${diff.inHours}h ago';
    } else if (diff.inDays < 30) {
      timeAgo = '${diff.inDays}d ago';
    } else {
      timeAgo = DateFormat('MMM d').format(comment.createdAt);
    }
    final authorName = ref.watch(userByIdProvider(comment.userId)).value?.fullName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          authorName != null ? '$timeAgo · $authorName' : timeAgo,
          style: const TextStyle(fontSize: 10, color: AppTheme.grayMedium),
        ),
        Text(
          comment.commentText,
          style: const TextStyle(fontSize: 12, color: AppTheme.graphite),
        ),
      ],
    );
  }
}