import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/mission_document.dart';
import 'package:purpose/core/models/mission_creation_session.dart';
import 'package:purpose/core/models/goal.dart';
import 'package:purpose/core/models/objective.dart';
import 'package:purpose/core/models/user_model.dart';
import 'package:purpose/core/models/user_comment.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/goal_provider.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/user_comment_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Provider for a specific mission document
final missionDocumentProvider =
    FutureProvider.family<MissionDocument?, String>((ref, missionId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getMissionDocument(missionId);
});

class MissionDetailPage extends ConsumerWidget {
  final String missionId;
  final String? initialObjectiveId;
  final String? initialGoalId;

  const MissionDetailPage({
    super.key,
    required this.missionId,
    this.initialObjectiveId,
    this.initialGoalId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionAsync = ref.watch(missionDocumentProvider(missionId));
    final activeStrategy = ref.watch(activeStrategyProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.graphite,
        foregroundColor: Colors.white,
        title: Text(
          activeStrategy?.name ?? 'Mission Details',
          style: const TextStyle(fontSize: 21),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mission'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => context.go('/comments'),
            tooltip: 'Comments',
          ),
        ],
      ),
      body: missionAsync.when(
        data: (mission) {
          if (mission == null) {
            return const Center(child: Text('Mission not found'));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mission Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary,
                        AppTheme.primary.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mission title — full width
                      Text(
                        mission.mission,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Info chips row with comment button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => _FeedbackDialog(
                                  entityId: missionId,
                                  entityType: 'mission',
                                  entityTitle: mission.mission,
                                ),
                              );
                            },
                            icon: const Icon(Icons.forum_outlined, size: 20),
                            color: Colors.white70,
                            tooltip: 'Provide Comment',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _buildInfoChip(
                                  icon: Icons.schedule,
                                  label: mission.timeHorizon,
                                ),
                                _buildInfoChip(
                                  icon: Icons.calendar_month,
                                  label: '${mission.durationMonths} months',
                                ),
                                if (mission.useBudgets)
                                  _buildBudgetingChip(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Mission Accomplished checkbox
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: mission.completed,
                              onChanged: (value) async {
                                if (value == true) {
                                  final goalsAsync = ref.read(goalsForMissionStreamProvider(missionId));
                                  final goals = goalsAsync.value ?? [];
                                  final incomplete = goals.where((g) => !g.achieved).length;
                                  if (incomplete > 0) {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Incomplete Goals'),
                                        content: Text(
                                          '$incomplete goal${incomplete == 1 ? '' : 's'} ${incomplete == 1 ? 'has' : 'have'} not been achieved yet. '
                                          'Consider completing your goals before marking this mission as accomplished.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: const Text('Go Back'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: AppTheme.success,
                                            ),
                                            child: const Text('Mark Accomplished Anyway'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                  }
                                }
                                final firestoreService = ref.read(firestoreServiceProvider);
                                await firestoreService.updateMissionDocument(
                                  mission.copyWith(
                                    completed: value ?? false,
                                    updatedAt: DateTime.now(),
                                  ),
                                );
                                ref.invalidate(missionDocumentProvider(missionId));
                              },
                              activeColor: Colors.white,
                              checkColor: AppTheme.primary,
                              side: const BorderSide(color: Colors.white70, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Mission Accomplished',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ),
                        ],
                      ),
                      // Mission Descriptors (expandable, inside blue header)
                      _MissionDescriptorsSection(
                        mission: mission,
                        missionId: missionId,
                      ),
                    ],
                  ),
                ),

                // Goals Section
                _GoalsSection(
                  missionId: missionId,
                  strategyId: mission.strategyId,
                  useBudgets: mission.useBudgets,
                  initialObjectiveId: initialObjectiveId,
                  initialGoalId: initialGoalId,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading mission',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.grayMedium,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.white.withOpacity(0.9),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }



  Widget _buildBudgetingChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'Budgeting',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable section showing mission descriptors with inline editing
class _MissionDescriptorsSection extends ConsumerStatefulWidget {
  final MissionDocument mission;
  final String missionId;

  const _MissionDescriptorsSection({
    required this.mission,
    required this.missionId,
  });

  @override
  ConsumerState<_MissionDescriptorsSection> createState() =>
      _MissionDescriptorsSectionState();
}

class _MissionDescriptorsSectionState
    extends ConsumerState<_MissionDescriptorsSection> {
  bool _isExpanded = false;
  bool _isEditing = false;
  bool _isSaving = false;

  late final TextEditingController _focusController;
  late final TextEditingController _structuralShiftController;
  late final TextEditingController _capabilityController;
  late final TextEditingController _riskGuardrailController;

  @override
  void initState() {
    super.initState();
    _focusController =
        TextEditingController(text: widget.mission.focus);
    _structuralShiftController =
        TextEditingController(text: widget.mission.structuralShift);
    _capabilityController =
        TextEditingController(text: widget.mission.capabilityRequired);
    _riskGuardrailController =
        TextEditingController(text: widget.mission.riskOrValueGuardrail);
  }

  @override
  void dispose() {
    _focusController.dispose();
    _structuralShiftController.dispose();
    _capabilityController.dispose();
    _riskGuardrailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.updateMissionDocument(
        widget.mission.copyWith(
          focus: _focusController.text.trim(),
          structuralShift: _structuralShiftController.text.trim(),
          capabilityRequired: _capabilityController.text.trim(),
          riskOrValueGuardrail: _riskGuardrailController.text.trim(),
          updatedAt: DateTime.now(),
        ),
      );
      ref.invalidate(missionDocumentProvider(widget.missionId));
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancelEditing() {
    setState(() {
      _focusController.text = widget.mission.focus;
      _structuralShiftController.text = widget.mission.structuralShift;
      _capabilityController.text = widget.mission.capabilityRequired;
      _riskGuardrailController.text = widget.mission.riskOrValueGuardrail;
      _isEditing = false;
    });
  }

  Widget _buildDescriptorSection(
      String title, String content, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.graphite,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableDescriptorSection(
      String title, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            height: 1.4,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white38),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white38),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white, width: 1.5),
            ),
            fillColor: Colors.white.withOpacity(0.1),
            filled: true,
            isDense: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider between accomplished row and this section
        Divider(height: 20, color: Colors.white24),

        // Expand/collapse row
        InkWell(
          onTap: () => setState(() {
            _isExpanded = !_isExpanded;
            if (!_isExpanded) _isEditing = false;
          }),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'Mission Descriptors',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const Spacer(),
              if (_isExpanded && !_isEditing) ...[
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () => setState(() => _isEditing = true),
                  tooltip: 'Edit',
                  color: Colors.white70,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: Colors.white70,
              ),
            ],
          ),
        ),

        // Expandable content
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          if (_isEditing) ...[
            _buildEditableDescriptorSection(
              'Mission Focus',
              _focusController,
              Icons.track_changes,
            ),
            const SizedBox(height: 16),
            _buildEditableDescriptorSection(
              'Structural Shift',
              _structuralShiftController,
              Icons.transform,
            ),
            const SizedBox(height: 16),
            _buildEditableDescriptorSection(
              'Capability Required',
              _capabilityController,
              Icons.psychology,
            ),
            const SizedBox(height: 16),
            _buildEditableDescriptorSection(
              'Risk & Value Guardrails',
              _riskGuardrailController,
              Icons.security,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : _cancelEditing,
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primary),
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ] else ...[
            _buildDescriptorSection(
              'Mission Focus',
              widget.mission.focus,
              Icons.track_changes,
            ),
            const SizedBox(height: 16),
            _buildDescriptorSection(
              'Structural Shift',
              widget.mission.structuralShift,
              Icons.transform,
            ),
            const SizedBox(height: 16),
            _buildDescriptorSection(
              'Capability Required',
              widget.mission.capabilityRequired,
              Icons.psychology,
            ),
            const SizedBox(height: 16),
            _buildDescriptorSection(
              'Risk & Value Guardrails',
              widget.mission.riskOrValueGuardrail,
              Icons.security,
            ),
          ],
        ],
      ],
    );
  }
}

/// Goals Section Widget with CRUD operations
class _GoalsSection extends ConsumerWidget {
  final String missionId;
  final String strategyId;
  final bool useBudgets;
  final String? initialObjectiveId;
  final String? initialGoalId;

  const _GoalsSection({
    required this.missionId,
    required this.strategyId,
    required this.useBudgets,
    this.initialObjectiveId,
    this.initialGoalId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsForMissionStreamProvider(missionId));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main goals content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.flag,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Goals',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.graphite,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showGoalDialog(context, ref, null),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Goal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                goalsAsync.when(
                  data: (goals) {
                    if (goals.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: AppTheme.grayLight.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.grayLight,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 48,
                                color: AppTheme.grayMedium,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No goals yet. Click "Add Goal" to get started.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.grayMedium,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: goals.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        return _GoalCard(
                          goal: goal,
                          missionId: missionId,
                          strategyId: strategyId,
                          useBudgets: useBudgets,
                          initialObjectiveId: initialObjectiveId,
                          initialGoalId: initialGoalId,
                          onEdit: () => _showGoalDialog(context, ref, goal),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Error loading goals: ${error.toString()}',
                            style: TextStyle(color: AppTheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Log sidebar
        // _LogSidebar(missionId: missionId),
      ],
    );
  }

  void _showGoalDialog(BuildContext context, WidgetRef ref, Goal? goal) {
    showDialog(
      context: context,
      builder: (context) => _GoalDialog(
        missionId: missionId,
        strategyId: strategyId,
        useBudgets: useBudgets,
        goal: goal,
      ),
    );
  }
}

/// Goal Card Widget
class _GoalCard extends ConsumerStatefulWidget {
  final Goal goal;
  final String missionId;
  final String strategyId;
  final bool useBudgets;
  final String? initialObjectiveId;
  final String? initialGoalId;
  final VoidCallback onEdit;

  const _GoalCard({
    required this.goal,
    required this.missionId,
    required this.strategyId,
    required this.useBudgets,
    this.initialObjectiveId,
    this.initialGoalId,
    required this.onEdit,
  });

  @override
  ConsumerState<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<_GoalCard> {
  bool _isExpanded = false;
  bool _hasAutoExpanded = false;

  @override
  Widget build(BuildContext context) {
    final objectivesAsync = ref.watch(objectivesForGoalStreamProvider(widget.goal.id));

    if (!_hasAutoExpanded) {
      final matchesGoal = widget.initialGoalId == widget.goal.id;
      if (matchesGoal) {
        _hasAutoExpanded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isExpanded = true);
        });
      } else if (widget.initialObjectiveId != null) {
        objectivesAsync.whenData((objectives) {
          if (objectives.any((o) => o.id == widget.initialObjectiveId)) {
            _hasAutoExpanded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isExpanded = true);
            });
          }
        });
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.goal.achieved ? AppTheme.success : AppTheme.grayLight,
          width: widget.goal.achieved ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: action buttons (left) + achieved badge (right if any)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => _FeedbackDialog(
                        entityId: widget.goal.id,
                        entityType: 'goal',
                        entityTitle: widget.goal.title,
                      ),
                    );
                  },
                  icon: Icon(Icons.forum_outlined, size: 20),
                  color: AppTheme.grayMedium,
                  tooltip: 'Provide Feedback',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onEdit,
                  icon: Icon(Icons.edit_outlined, size: 20),
                  color: AppTheme.primary,
                  tooltip: 'Edit Goal',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                if (widget.goal.achieved) ...
                  [
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppTheme.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Achieved',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                const Spacer(),
                objectivesAsync.when(
                  data: (objectives) {
                    final achieved = objectives.where((o) => o.achieved).length;
                    return _buildInfoChip(
                      icon: Icons.checklist,
                      label: 'Objectives: $achieved/${objectives.length}',
                      color: AppTheme.grayLight,
                      textColor: AppTheme.grayMedium,
                    );
                  },
                  loading: () => _buildInfoChip(
                    icon: Icons.checklist,
                    label: 'Objectives: ...',
                    color: AppTheme.grayLight,
                    textColor: AppTheme.grayMedium,
                  ),
                  error: (_, __) => _buildInfoChip(
                    icon: Icons.checklist,
                    label: 'Objectives: -',
                    color: AppTheme.grayLight,
                    textColor: AppTheme.grayMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Goal title — full width
            Text(
              widget.goal.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.graphite,
              ),
            ),
            const SizedBox(height: 6),
            // Goal Achieved checkbox
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: widget.goal.achieved,
                    onChanged: (value) async {
                      // Only show warning when checking (not unchecking)
                      if (value == true) {
                        final objectives = objectivesAsync.value ?? [];
                        final incomplete = objectives.where((o) => !o.achieved).length;
                        if (incomplete > 0) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Incomplete Objectives'),
                              content: Text(
                                '$incomplete objective${incomplete == 1 ? '' : 's'} ${incomplete == 1 ? 'has' : 'have'} not been completed yet. '
                                'Consider completing your objectives before marking this goal as achieved.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Go Back'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                  ),
                                  child: const Text('Mark Achieved Anyway'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                        }
                      }
                      final firestoreService = ref.read(firestoreServiceProvider);
                      await firestoreService.updateGoal(
                        widget.goal.copyWith(
                          achieved: value ?? false,
                          dateAchieved: (value ?? false) ? DateTime.now() : null,
                          updatedAt: DateTime.now(),
                        ),
                      );
                    },
                    activeColor: AppTheme.success,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Goal Achieved',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Goal description — full width
            Text(
              widget.goal.description,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.grayMedium,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Budget and Objectives Info
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                // Calculate planned costs from objectives
                objectivesAsync.when(
                  data: (objectives) {
                    final plannedMonetary = objectives.fold<double>(
                      0.0, 
                      (sum, obj) => sum + obj.costMonetary,
                    );
                    final plannedTime = objectives.fold<double>(
                      0.0, 
                      (sum, obj) => sum + obj.costTime,
                    );
                    
                    return Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        // Monetary chips - Green (only when budgeting enabled)
                        if (widget.useBudgets) ...[
                          _buildInfoChip(
                            icon: Icons.attach_money,
                            label: 'Budgeted: \$${widget.goal.actualMonetary.toStringAsFixed(0)} / \$${widget.goal.budgetMonetary.toStringAsFixed(0)}',
                            color: AppTheme.success,
                          ),
                          _buildInfoChip(
                            icon: Icons.price_change,
                            label: 'Planned: \$${plannedMonetary.toStringAsFixed(0)} / \$${widget.goal.budgetMonetary.toStringAsFixed(0)}',
                            color: AppTheme.success,
                          ),
                          // Time chips - Blue
                          _buildInfoChip(
                            icon: Icons.schedule,
                            label: 'Budgeted: ${widget.goal.actualTime.toStringAsFixed(0)}h / ${widget.goal.budgetTime.toStringAsFixed(0)}h',
                            color: AppTheme.primary,
                          ),
                          _buildInfoChip(
                            icon: Icons.access_time,
                            label: 'Planned: ${plannedTime.toStringAsFixed(0)}h / ${widget.goal.budgetTime.toStringAsFixed(0)}h',
                            color: AppTheme.primary,
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Expand/Collapse Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(_isExpanded ? 'Hide Objectives' : 'Show Objectives'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
            // Expandable Objectives Section
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.grayLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Objectives',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.graphite,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showObjectiveDialog(context, null),
                          icon: Icon(Icons.add, size: 18),
                          label: const Text('Add Objective'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    objectivesAsync.when(
                      data: (objectives) {
                        if (objectives.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No objectives yet. Add one to get started!',
                                style: TextStyle(
                                  color: AppTheme.grayMedium,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: objectives
                              .map((objective) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _ObjectiveCard(
                                      objective: objective,
                                      useBudgets: widget.useBudgets,
                                      highlighted: objective.id == widget.initialObjectiveId,
                                      onEdit: () => _showObjectiveDialog(context, objective),
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                      loading: () => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Error loading objectives',
                            style: TextStyle(color: AppTheme.error),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showObjectiveDialog(BuildContext context, Objective? objective) {
    showDialog(
      context: context,
      builder: (context) => _ObjectiveDialog(
        goalId: widget.goal.id,
        missionId: widget.missionId,
        strategyId: widget.strategyId,
        useBudgets: widget.useBudgets,
        objective: objective,
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    Color? textColor,
  }) {
    final effectiveTextColor = textColor ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveTextColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: effectiveTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Objective Card Widget
class _ObjectiveCard extends ConsumerStatefulWidget {
  final Objective objective;
  final bool useBudgets;
  final bool highlighted;
  final VoidCallback onEdit;

  const _ObjectiveCard({
    required this.objective,
    required this.useBudgets,
    this.highlighted = false,
    required this.onEdit,
  });

  @override
  ConsumerState<_ObjectiveCard> createState() => _ObjectiveCardState();
}

class _ObjectiveCardState extends ConsumerState<_ObjectiveCard> {
  @override
  void initState() {
    super.initState();
    if (widget.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.3,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final objective = widget.objective;
    final useBudgets = widget.useBudgets;
    final onEdit = widget.onEdit;
    final isOverdue = objective.isOverdue;
    
    return Container(
      decoration: BoxDecoration(
        color: widget.highlighted ? AppTheme.primary.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.highlighted
              ? AppTheme.primary
              : objective.achieved
                  ? AppTheme.success
                  : (isOverdue ? AppTheme.error : AppTheme.grayLight),
          width: widget.highlighted || objective.achieved || isOverdue ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: action buttons (left) + status badges inline
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _FeedbackDialog(
                      entityId: objective.id,
                      entityType: 'objective',
                      entityTitle: objective.title,
                    ),
                  );
                },
                icon: Icon(Icons.forum_outlined, size: 18),
                color: AppTheme.grayMedium,
                tooltip: 'Provide Feedback',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 18),
                color: AppTheme.primary,
                tooltip: 'Edit Objective',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (useBudgets) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showAddSpendDialog(context, ref, isMonetary: true),
                  icon: Icon(Icons.attach_money, size: 18),
                  color: AppTheme.success,
                  tooltip: 'Add Spend \$',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _showAddSpendDialog(context, ref, isMonetary: false),
                  icon: Icon(Icons.schedule, size: 18),
                  color: AppTheme.primary,
                  tooltip: 'Add Time (hr)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
              if (objective.achieved) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: AppTheme.success),
                      const SizedBox(width: 4),
                      Text('Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.success)),
                    ],
                  ),
                ),
              ],
              if (isOverdue) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, size: 12, color: AppTheme.error),
                      const SizedBox(width: 4),
                      Text('Overdue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.error)),
                    ],
                  ),
                ),
              ],
              if (objective.dueDate != null) ...[
                const Spacer(),
                _buildDetailChip(
                  icon: Icons.calendar_today,
                  label: 'Due: ${DateFormat('MMM d').format(objective.dueDate!)}',
                  color: isOverdue ? AppTheme.error : AppTheme.grayMedium,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Title — full width
          Text(
            objective.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.graphite,
            ),
          ),
          const SizedBox(height: 6),
          // Objective Completed checkbox
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: objective.achieved,
                  onChanged: (value) async {
                    final firestoreService = ref.read(firestoreServiceProvider);
                    await firestoreService.updateObjective(
                      objective.copyWith(
                        achieved: value ?? false,
                        dateAchieved: (value ?? false) ? DateTime.now() : null,
                        updatedAt: DateTime.now(),
                      ),
                    );
                  },
                  activeColor: AppTheme.success,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Objective Completed',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.graphite,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Description — full width
          Text(
            objective.description,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.grayMedium,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          // Measurable requirement
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '📊 ${objective.measurableRequirement}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (objective.costMonetary > 0 || objective.spendMonetary > 0)
                      if (useBudgets)
                        _buildDetailChip(
                          icon: Icons.attach_money,
                          label: 'Cost: \$${objective.costMonetary.toStringAsFixed(0)} | Spend: \$${objective.spendMonetary.toStringAsFixed(0)}',
                          color: AppTheme.success,
                        ),
                    if (objective.costTime > 0 || objective.spendTime > 0)
                      if (useBudgets)
                        _buildDetailChip(
                          icon: Icons.schedule,
                          label: 'Cost: ${objective.costTime.toStringAsFixed(0)}h | Spend: ${objective.spendTime.toStringAsFixed(0)}h',
                          color: AppTheme.primary,
                        ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSpendDialog(BuildContext context, WidgetRef ref, {required bool isMonetary}) async {
    final controller = TextEditingController();
    final noteController = TextEditingController();
    
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(isMonetary ? 'Add Spend (\$)' : 'Add Time (hours)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: isMonetary ? 'Amount (\$)' : 'Hours',
                hintText: isMonetary ? '0.00' : '0.0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note *',
                hintText: 'What was this for?',
                border: OutlineInputBorder(),
                helperText: 'Required',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isEmpty || noteController.text.trim().isEmpty) {
                return;
              }
              
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) {
                return;
              }
              
              Navigator.pop(dialogContext, {
                'amount': amount,
                'note': noteController.text.trim(),
              });
            },
            child: Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();
    noteController.dispose();

    // Process the result after dialog is closed
    if (result != null) {
      await _addSpend(ref, result['amount'] as double, result['note'] as String, isMonetary);
    }
  }

  Future<void> _addSpend(WidgetRef ref, double amount, String note, bool isMonetary) async {
    final objective = widget.objective;
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      final userId = currentUser?.uid ?? 'system';
      
      // Create log entry
      final logMessage = isMonetary 
        ? 'Added \$${amount.toStringAsFixed(2)}: $note'
        : 'Added ${amount.toStringAsFixed(1)}h: $note';
      
      final newLogEntry = LogEntry(
        timestamp: DateTime.now(),
        message: logMessage,
        author: userId,
      );

      // Update objective with new spend and log entry
      final updatedObjective = objective.copyWith(
        spendMonetary: isMonetary ? objective.spendMonetary + amount : objective.spendMonetary,
        spendTime: !isMonetary ? objective.spendTime + amount : objective.spendTime,
        log: [...objective.log, newLogEntry],
      );

      await firestoreService.updateObjective(updatedObjective);
      print('✅ Added ${isMonetary ? "monetary" : "time"} spend to objective');
    } catch (e) {
      print('❌ Error adding spend: $e');
    }
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Objective Add/Edit Dialog
class _ObjectiveDialog extends ConsumerStatefulWidget {
  final String goalId;
  final String missionId;
  final String strategyId;
  final bool useBudgets;
  final Objective? objective;

  const _ObjectiveDialog({
    required this.goalId,
    required this.missionId,
    required this.strategyId,
    required this.useBudgets,
    this.objective,
  });

  @override
  ConsumerState<_ObjectiveDialog> createState() => _ObjectiveDialogState();
}

class _ObjectiveDialogState extends ConsumerState<_ObjectiveDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _measurableRequirementController;
  late final TextEditingController _costMonetaryController;
  late final TextEditingController _costTimeController;
  final _formKey = GlobalKey<FormState>();
  DateTime? _dueDate;
  bool _isLoadingSuggestion = false;
  Map<String, dynamic>? _aiSuggestion;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.objective?.title ?? '');
    _descriptionController = TextEditingController(text: widget.objective?.description ?? '');
    _measurableRequirementController = TextEditingController(
      text: widget.objective?.measurableRequirement ?? '',
    );
    _costMonetaryController = TextEditingController(
      text: widget.objective?.costMonetary != null && widget.objective!.costMonetary > 0
          ? widget.objective!.costMonetary.toString()
          : '',
    );
    _costTimeController = TextEditingController(
      text: widget.objective?.costTime != null && widget.objective!.costTime > 0
          ? widget.objective!.costTime.toString()
          : '',
    );
    _dueDate = widget.objective?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _measurableRequirementController.dispose();
    _costMonetaryController.dispose();
    _costTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.objective != null;
    final dateFormat = DateFormat('MMM d, yyyy');

    return AlertDialog(
      title: Text(isEditing ? 'Edit Objective' : 'Add Objective'),
      content: SizedBox(
        width: 500, // Same width as goal dialog
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Objective Agent Button
              if (!isEditing)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingSuggestion ? null : _askObjectiveAgent,
                    icon: _isLoadingSuggestion
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryLight,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.auto_awesome,
                            size: 20,
                            color: AppTheme.primaryLight,
                          ),
                    label: Text(
                      _isLoadingSuggestion
                          ? 'Thinking...'
                          : 'Ask Objective Agent for Suggestions',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      side: BorderSide(
                        color: AppTheme.primaryLight.withOpacity(0.5),
                        width: 1.5,
                      ),
                      foregroundColor: AppTheme.primaryLight,
                    ),
                  ),
                ),
              // AI Suggestion Display
              if (!isEditing && _aiSuggestion != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryLight.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 20,
                            color: AppTheme.primaryLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AI Suggestion',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                _aiSuggestion = null;
                              });
                            },
                            tooltip: 'Dismiss suggestion',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _aiSuggestion!['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.graphite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _aiSuggestion!['description'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.grayMedium,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.track_changes,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _aiSuggestion!['measurableRequirement'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_aiSuggestion!['reasoning'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '💡 ${_aiSuggestion!['reasoning']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.grayMedium,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _applySuggestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryLight,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Use This Suggestion'),
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _titleController,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter objective title',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(fontSize: 13),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter objective description',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(fontSize: 13),
                ),
                style: const TextStyle(fontSize: 13),
                minLines: 4,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _measurableRequirementController,
                decoration: const InputDecoration(
                  labelText: 'Measurable Requirement',
                  hintText: 'e.g., "Increase sales by 20%"',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(fontSize: 13),
                ),
                style: const TextStyle(fontSize: 13),
                minLines: 4,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a measurable requirement';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) {
                    setState(() => _dueDate = date);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due Date (Optional)',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _dueDate != null ? dateFormat.format(_dueDate!) : 'Select a date',
                    style: TextStyle(
                      fontSize: 13,
                      color: _dueDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
              if (widget.useBudgets) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costMonetaryController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Cost \$ (Optional)',
                          hintText: '0',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                          labelStyle: TextStyle(fontSize: 13),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costTimeController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Time Hours (Optional)',
                          hintText: '0',
                          border: OutlineInputBorder(),
                          suffixText: 'h',
                          labelStyle: TextStyle(fontSize: 13),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      ),
      actions: [
        Row(
          children: [
            if (isEditing)
              TextButton(
                onPressed: () => _confirmDelete(context),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _saveObjective,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final objective = widget.objective!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Objective'),
        content: Text('Are you sure you want to delete "${objective.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(); // close edit dialog
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        await firestoreService.deleteObjective(objective.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Objective "${objective.title}" deleted'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting objective: \$e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _askObjectiveAgent() async {
    setState(() => _isLoadingSuggestion = true);
    
    try {
      // Get mission document
      final firestoreService = ref.read(firestoreServiceProvider);
      final mission = await firestoreService.getMissionDocument(widget.missionId);
      
      if (mission == null) {
        throw Exception('Mission not found');
      }

      // Get goal to understand context
      final goal = await firestoreService.getGoal(widget.goalId);
      
      if (goal == null) {
        throw Exception('Goal not found');
      }

      // Get existing objectives for this goal
      final existingObjectives = await firestoreService.getObjectivesForGoal(widget.goalId);
      final objectivesList = existingObjectives.map((obj) => {
        'title': obj.title,
        'description': obj.description,
        'measurableRequirement': obj.measurableRequirement,
        'achieved': obj.achieved,
      }).toList();

      // Call Gemini service
      final geminiService = await ref.read(geminiServiceProvider.future);
      final suggestion = await geminiService.generateObjectiveSuggestion(
        missionTitle: mission.mission,
        missionFocus: mission.focus,
        goalTitle: goal.title,
        goalDescription: goal.description,
        existingObjectives: objectivesList,
      );

      if (mounted) {
        setState(() {
          _aiSuggestion = suggestion;
          _isLoadingSuggestion = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSuggestion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting suggestion: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _applySuggestion() {
    if (_aiSuggestion == null) return;
    
    _titleController.text = _aiSuggestion!['title'] ?? '';
    _descriptionController.text = _aiSuggestion!['description'] ?? '';
    _measurableRequirementController.text = _aiSuggestion!['measurableRequirement'] ?? '';
    
    setState(() {
      _aiSuggestion = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Suggestion applied!'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveObjective() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final objectiveId = widget.objective?.id ?? 
        FirebaseFirestore.instance.collection('objectives').doc().id;

      final objective = Objective(
        id: objectiveId,
        goalId: widget.goalId,
        missionId: widget.missionId,
        strategyId: widget.strategyId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        measurableRequirement: _measurableRequirementController.text.trim(),
        dueDate: _dueDate,
        costMonetary: double.tryParse(_costMonetaryController.text) ?? 0.0,
        costTime: double.tryParse(_costTimeController.text) ?? 0.0,
        // Preserve existing values when editing
        achieved: widget.objective?.achieved ?? false,
        dateAchieved: widget.objective?.dateAchieved,
        dateCreated: widget.objective?.dateCreated ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestoreService.saveObjective(objective);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Objective ${widget.objective != null ? "updated" : "created"}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving objective: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

/// Goal Add/Edit Dialog
class _GoalDialog extends ConsumerStatefulWidget {
  final String missionId;
  final String strategyId;
  final bool useBudgets;
  final Goal? goal;

  const _GoalDialog({
    required this.missionId,
    required this.strategyId,
    required this.useBudgets,
    this.goal,
  });

  @override
  ConsumerState<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends ConsumerState<_GoalDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _budgetMonetaryController;
  late final TextEditingController _budgetTimeController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoadingSuggestion = false;
  Map<String, dynamic>? _aiSuggestion;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _descriptionController = TextEditingController(text: goal?.description ?? '');
    _budgetMonetaryController = TextEditingController(
      text: goal?.budgetMonetary != null && goal!.budgetMonetary > 0 
        ? goal.budgetMonetary.toString() 
        : '',
    );
    _budgetTimeController = TextEditingController(
      text: goal?.budgetTime != null && goal!.budgetTime > 0 
        ? goal.budgetTime.toString() 
        : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetMonetaryController.dispose();
    _budgetTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.goal != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Goal' : 'Add Goal'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Goal Agent Button
                if (!isEditing)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingSuggestion ? null : _askGoalAgent,
                      icon: _isLoadingSuggestion
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryLight,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.auto_awesome,
                              size: 20,
                              color: AppTheme.primaryLight,
                            ),
                      label: Text(
                        _isLoadingSuggestion
                            ? 'Thinking...'
                            : 'Ask Goal Agent for Suggestions',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        side: BorderSide(
                          color: AppTheme.primaryLight.withOpacity(0.5),
                          width: 1.5,
                        ),
                        foregroundColor: AppTheme.primaryLight,
                      ),
                    ),
                  ),
                // AI Suggestion Display
                if (!isEditing && _aiSuggestion != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryLight.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 20,
                              color: AppTheme.primaryLight,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'AI Suggestion',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryLight,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setState(() {
                                  _aiSuggestion = null;
                                });
                              },
                              tooltip: 'Dismiss suggestion',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _aiSuggestion!['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.graphite,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _aiSuggestion!['description'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.grayMedium,
                            height: 1.4,
                          ),
                        ),
                        if (_aiSuggestion!['reasoning'] != null)
                          const SizedBox(height: 8),
                        if (_aiSuggestion!['reasoning'] != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: AppTheme.grayMedium,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _aiSuggestion!['reasoning'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.grayMedium,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _applySuggestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Use This Suggestion'),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                if (widget.useBudgets) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _budgetMonetaryController,
                    decoration: const InputDecoration(
                      labelText: 'Budget (\$)',
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (double.tryParse(value) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _budgetTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Budget (hours)',
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (double.tryParse(value) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            if (isEditing)
              TextButton(
                onPressed: () => _confirmDelete(context),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _saveGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final goal = widget.goal!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text(
          'Are you sure you want to delete "${goal.title}"? This will also delete all associated objectives.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(); // close edit dialog
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        await firestoreService.deleteGoal(goal.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Goal "${goal.title}" deleted'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting goal: \$e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _askGoalAgent() async {
    setState(() {
      _isLoadingSuggestion = true;
      _aiSuggestion = null;
    });

    try {
      // Fetch mission document
      final firestoreService = ref.read(firestoreServiceProvider);
      final mission = await firestoreService.getMissionDocument(widget.missionId);

      if (mission == null) {
        throw Exception('Mission not found');
      }

      // Fetch existing goals
      final goals = await firestoreService.getGoalsForMission(widget.missionId);
      final existingGoals = goals.map((g) => {
        'title': g.title,
        'description': g.description,
        'achieved': g.achieved,
      }).toList();

      // Call Gemini service
      final geminiService = await ref.read(geminiServiceProvider.future);
      final suggestion = await geminiService.generateGoalSuggestion(
        missionTitle: mission.mission,
        missionFocus: mission.focus,
        structuralShift: mission.structuralShift,
        capabilityRequired: mission.capabilityRequired,
        existingGoals: existingGoals,
      );

      if (mounted) {
        setState(() {
          _aiSuggestion = suggestion;
          _isLoadingSuggestion = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestion = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting suggestion: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _applySuggestion() {
    if (_aiSuggestion != null) {
      _titleController.text = _aiSuggestion!['title'] ?? '';
      _descriptionController.text = _aiSuggestion!['description'] ?? '';
      setState(() {
        _aiSuggestion = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Suggestion applied! You can edit it before saving.'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final firestoreService = ref.read(firestoreServiceProvider);
    final now = DateTime.now();

    // Generate new ID using Firestore if creating a new goal
    final goalId = widget.goal?.id ?? 
      FirebaseFirestore.instance.collection('goals').doc().id;

    final goal = Goal(
      id: goalId,
      missionId: widget.missionId,
      strategyId: widget.strategyId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      budgetMonetary: double.tryParse(_budgetMonetaryController.text) ?? 0.0,
      budgetTime: double.tryParse(_budgetTimeController.text) ?? 0.0,
      actualMonetary: widget.goal?.actualMonetary ?? 0.0,
      actualTime: widget.goal?.actualTime ?? 0.0,
      achieved: widget.goal?.achieved ?? false,
      dateAchieved: widget.goal?.dateAchieved,
      dateCreated: widget.goal?.dateCreated ?? now,
      updatedAt: now,
    );

    await firestoreService.saveGoal(goal);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.goal != null
                ? 'Goal updated successfully'
                : 'Goal created successfully',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }
}

/// Expandable sidebar showing all log entries for goals and objectives
class _LogSidebar extends ConsumerStatefulWidget {
  final String missionId;

  const _LogSidebar({
    required this.missionId,
  });

  @override
  ConsumerState<_LogSidebar> createState() => _LogSidebarState();
}

class _LogSidebarState extends ConsumerState<_LogSidebar> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsForMissionStreamProvider(widget.missionId));
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight - 200; // Account for app bar and padding

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isExpanded ? 400 : 48,
      height: maxHeight,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(
            color: AppTheme.grayLight,
            width: 1,
          ),
        ),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(-2, 0),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          // Sidebar header
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.grayLight,
                  width: 1,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hasSpace = constraints.maxWidth > 200;
                return hasSpace
                    ? Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            },
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                            tooltip: 'Collapse Log',
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.history,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Activity Log',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
                          tooltip: 'Expand Log',
                        ),
                      );
              },
            ),
          ),
          // Sidebar content
          if (_isExpanded)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Only show content if we have reasonable width
                  if (constraints.maxWidth < 100) {
                    return const SizedBox();
                  }
                  return goalsAsync.when(
                    data: (goals) {
                      return _buildLogEntries(goals);
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error loading logs',
                          style: TextStyle(
                            color: AppTheme.error,
                            fontSize: 14,
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
    );
  }

  Widget _buildLogEntries(List<Goal> goals) {
    // Collect all log entries from goals
    final allEntries = <_LogEntryData>[];

    // Add mission comments
    final missionCommentsAsync = ref.watch(
      commentsForEntityStreamProvider((widget.missionId, 'mission'))
    );
    missionCommentsAsync.whenOrNull(
      data: (comments) {
        print('📊 Processing ${comments.length} mission comments');
        for (final comment in comments) {
          print('  Comment ID: ${comment.id}, parentId: ${comment.parentCommentId}');
          // Only add parent comments (replies will be shown nested within parents)
          if (comment.parentCommentId == null) {
            print('    ✓ Adding as parent comment');
            allEntries.add(_LogEntryData(
              timestamp: comment.createdAt,
              author: comment.userId,
              entityType: 'Comment',
              entityTitle: 'Mission',
              message: comment.commentText,
              commentId: comment.id,
              entityId: comment.entityId,
              originalEntityType: comment.entityType,
            ));
          } else {
            print('    ✗ Skipping reply (will be shown nested)');
          }
        }
      },
    );

    // Add goal log entries
    for (final goal in goals) {
      for (final entry in goal.log) {
        allEntries.add(_LogEntryData(
          timestamp: entry.timestamp,
          author: entry.author,
          entityType: 'Goal',
          entityTitle: goal.title,
          message: entry.message,
        ));
      }

      // Add goal comments
      final goalCommentsAsync = ref.watch(
        commentsForEntityStreamProvider((goal.id, 'goal'))
      );
      goalCommentsAsync.whenOrNull(
        data: (comments) {
          print('📊 Processing ${comments.length} comments for goal "${goal.title}"');
          for (final comment in comments) {
            print('  Comment ID: ${comment.id}, parentId: ${comment.parentCommentId}');
            // Only add parent comments (replies will be shown nested within parents)
            if (comment.parentCommentId == null) {
              print('    ✓ Adding as parent comment');
              allEntries.add(_LogEntryData(
                timestamp: comment.createdAt,
                author: comment.userId,
                entityType: 'Comment',
                entityTitle: goal.title,
                message: comment.commentText,
                commentId: comment.id,
                entityId: comment.entityId,
                originalEntityType: comment.entityType,
              ));
            } else {
              print('    ✗ Skipping reply (will be shown nested)');
            }
          }
        },
      );

      // Add objective log entries for this goal
      // Watch objectives for each goal
      final objectivesAsync = ref.watch(objectivesForGoalStreamProvider(goal.id));
      objectivesAsync.whenOrNull(
        data: (objectives) {
          for (final objective in objectives) {
            for (final entry in objective.log) {
              allEntries.add(_LogEntryData(
                timestamp: entry.timestamp,
                author: entry.author,
                entityType: 'Objective',
                entityTitle: objective.title,
                message: entry.message,
              ));
            }

            // Add objective comments
            final objectiveCommentsAsync = ref.watch(
              commentsForEntityStreamProvider((objective.id, 'objective'))
            );
            objectiveCommentsAsync.whenOrNull(
              data: (comments) {
                for (final comment in comments) {
                  // Only add parent comments (replies will be shown nested within parents)
                  if (comment.parentCommentId == null) {
                    allEntries.add(_LogEntryData(
                      timestamp: comment.createdAt,
                      author: comment.userId,
                      entityType: 'Comment',
                      entityTitle: objective.title,
                      message: comment.commentText,
                      commentId: comment.id,
                      entityId: comment.entityId,
                      originalEntityType: comment.entityType,
                    ));
                  }
                }
              },
            );
          }
        },
      );
    }

    // Sort by newest first
    allEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (allEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 48,
                color: AppTheme.grayMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'No activity yet',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.grayMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: allEntries.length,
      separatorBuilder: (context, index) => Divider(
        color: AppTheme.grayLight,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final entry = allEntries[index];
        return _buildLogEntryCard(entry);
      },
    );
  }

  Widget _buildLogEntryCard(_LogEntryData entry) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and time
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 12,
                color: AppTheme.grayMedium,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${dateFormat.format(entry.timestamp)} at ${timeFormat.format(entry.timestamp)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.grayMedium,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Author
              _AuthorWidget(authorId: entry.author),
            ],
          ),
          const SizedBox(height: 6),
          // Entity type and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.entityType == 'Goal'
                      ? AppTheme.primary.withOpacity(0.1)
                      : entry.entityType == 'Objective'
                          ? AppTheme.success.withOpacity(0.1)
                          : AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.entityType == 'Comment')
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          Icons.comment,
                          size: 10,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    Text(
                      entry.entityType,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: entry.entityType == 'Goal'
                            ? AppTheme.primary
                            : entry.entityType == 'Objective'
                                ? AppTheme.success
                                : AppTheme.primaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.entityTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.graphite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Message
          Text(
            entry.message,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.graphite.withOpacity(0.8),
              height: 1.4,
            ),
            softWrap: true,
          ),
          // Reply button for comments
          if (entry.entityType == 'Comment' && 
              entry.commentId != null && 
              entry.entityId != null && 
              entry.originalEntityType != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => _ReplyDialog(
                          parentCommentId: entry.commentId!,
                          parentCommentText: entry.message,
                          entityId: entry.entityId!,
                          entityType: entry.originalEntityType!,
                          entityTitle: entry.entityTitle,
                        ),
                      );
                    },
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text('Reply'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryLight,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          // Display replies for parent comments
          if (entry.entityType == 'Comment' && 
              entry.commentId != null && 
              entry.entityId != null && 
              entry.originalEntityType != null) ...[
            Builder(
              builder: (context) {
                print('📌 Rendering _CommentRepliesWidget for commentId: ${entry.commentId}, entityId: ${entry.entityId}, entityType: ${entry.originalEntityType}');
                return _CommentRepliesWidget(
                  parentCommentId: entry.commentId!,
                  entityId: entry.entityId!,
                  entityType: entry.originalEntityType!,
                  entityTitle: entry.entityTitle,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget to display replies to a comment
class _CommentRepliesWidget extends ConsumerWidget {
  final String parentCommentId;
  final String entityId;
  final String entityType;
  final String entityTitle;

  const _CommentRepliesWidget({
    required this.parentCommentId,
    required this.entityId,
    required this.entityType,
    required this.entityTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('🔍 _CommentRepliesWidget building for parent: $parentCommentId');
    final repliesAsync = ref.watch(repliesForCommentProvider(parentCommentId));

    return repliesAsync.when(
      data: (replies) {
        print('✅ Found ${replies.length} replies for comment $parentCommentId');
        if (replies.isEmpty) {
          print('   ↪ Returning SizedBox.shrink() because no replies');
          return const SizedBox.shrink();
        }

        print('   ↪ Building reply container with ${replies.length} replies');
        return Container(
          margin: const EdgeInsets.only(left: 16, top: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppTheme.primaryLight.withOpacity(0.3),
                width: 2,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: replies.map((reply) {
              print('   📝 Reply: ${reply.commentText.substring(0, reply.commentText.length > 20 ? 20 : reply.commentText.length)}...');
              return _buildReplyCard(context, ref, reply);
            }).toList(),
          ),
        );
      },
      loading: () {
        print('⏳ Loading replies for comment $parentCommentId...');
        return Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryLight),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading replies...',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.grayMedium,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
      error: (error, stack) {
        print('❌ Error loading replies for comment $parentCommentId: $error');
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildReplyCard(BuildContext context, WidgetRef ref, UserComment reply) {
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      margin: const EdgeInsets.only(left: 8, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryLight.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reply header with icon and timestamp
          Row(
            children: [
              Icon(
                Icons.subdirectory_arrow_right,
                size: 12,
                color: AppTheme.primaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                'Reply',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${dateFormat.format(reply.createdAt)} at ${timeFormat.format(reply.createdAt)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.grayMedium,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Reply author
              _AuthorWidget(authorId: reply.userId),
            ],
          ),
          const SizedBox(height: 6),
          // Reply text
          Text(
            reply.commentText,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.graphite.withOpacity(0.9),
              height: 1.4,
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}

/// Widget to display author name, fetching from Firestore if needed
class _AuthorWidget extends ConsumerWidget {
  final String authorId;

  const _AuthorWidget({required this.authorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (authorId.toLowerCase() == 'system') {
      return Text(
        'by System',
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.grayMedium,
          fontStyle: FontStyle.italic,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    }

    // Fetch user from Firestore
    final firestoreService = ref.watch(firestoreServiceProvider);
    
    return FutureBuilder<UserModel?>(
      future: firestoreService.getUser(authorId),
      builder: (context, snapshot) {
        String displayName;
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          displayName = 'Loading...';
        } else if (snapshot.hasError || snapshot.data == null) {
          displayName = authorId; // Fallback to ID if error
        } else {
          displayName = snapshot.data!.fullName;
        }
        
        return Text(
          'by $displayName',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.grayMedium,
            fontStyle: FontStyle.italic,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        );
      },
    );
  }
}

/// Helper class to hold log entry data with entity information
class _LogEntryData {
  final DateTime timestamp;
  final String author;
  final String entityType;
  final String entityTitle;
  final String message;
  final String? commentId; // For comment entries that support replies
  final String? entityId; // The ID of the entity (goal/objective/mission) for comments
  final String? originalEntityType; // The type of entity ('goal', 'objective', 'mission') for comments

  _LogEntryData({
    required this.timestamp,
    required this.author,
    required this.entityType,
    required this.entityTitle,
    required this.message,
    this.commentId,
    this.entityId,
    this.originalEntityType,
  });
}

/// Feedback Dialog for collecting user comments on entities
class _FeedbackDialog extends ConsumerStatefulWidget {
  final String entityId;
  final String entityType;
  final String entityTitle;

  const _FeedbackDialog({
    required this.entityId,
    required this.entityType,
    required this.entityTitle,
  });

  @override
  ConsumerState<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<_FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  bool _isSaving = false;
  bool _composing = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _saveComment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate new comment ID
      final commentId = FirebaseFirestore.instance
          .collection('user_comments')
          .doc()
          .id;

      final comment = UserComment(
        id: commentId,
        userId: currentUser.uid,
        entityId: widget.entityId,
        entityType: widget.entityType,
        commentText: _commentController.text.trim(),
        parentCommentId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestoreService.saveUserComment(comment);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💬 Feedback saved successfully!'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving feedback: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
              // Entity info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grayLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.grayLight,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.entityType == 'goal' 
                          ? Icons.flag_outlined 
                          : Icons.check_circle_outline,
                      size: 16,
                      color: AppTheme.grayMedium,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.entityType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grayMedium,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.entityTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.graphite,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                      return 'Feedback must be at least 5 characters';
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
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.grayMedium,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveComment,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, size: 16),
                      label: Text(_isSaving ? 'Saving...' : 'Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
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
                        (widget.entityId, widget.entityType)),
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

/// Reply Dialog for replying to existing comments
class _ReplyDialog extends ConsumerStatefulWidget {
  final String parentCommentId;
  final String parentCommentText;
  final String entityId;
  final String entityType;
  final String entityTitle;

  const _ReplyDialog({
    required this.parentCommentId,
    required this.parentCommentText,
    required this.entityId,
    required this.entityType,
    required this.entityTitle,
  });

  @override
  ConsumerState<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends ConsumerState<_ReplyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _replyController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _saveReply() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate new comment ID for the reply
      final replyId = FirebaseFirestore.instance
          .collection('user_comments')
          .doc()
          .id;

      final reply = UserComment(
        id: replyId,
        userId: currentUser.uid,
        entityId: widget.entityId,
        entityType: widget.entityType,
        commentText: _replyController.text.trim(),
        parentCommentId: widget.parentCommentId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestoreService.saveUserComment(reply);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💬 Reply saved successfully!'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving reply: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.reply,
            color: AppTheme.primaryLight,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Reply to Comment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.graphite,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entity info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grayLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.grayLight,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.entityType == 'goal' 
                          ? Icons.flag_outlined 
                          : widget.entityType == 'objective'
                              ? Icons.check_circle_outline
                              : Icons.rocket_launch_outlined,
                      size: 16,
                      color: AppTheme.grayMedium,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.entityType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grayMedium,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.entityTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.graphite,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Original comment
              Text(
                'Replying to:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grayMedium,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryLight.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.parentCommentText,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.graphite.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 20),
              // Reply field
              TextFormField(
                controller: _replyController,
                decoration: InputDecoration(
                  labelText: 'Your Reply',
                  hintText: 'Type your reply...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.primaryLight,
                      width: 2,
                    ),
                  ),
                ),
                maxLines: 4,
                maxLength: 1000,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your reply';
                  }
                  if (value.trim().length < 3) {
                    return 'Reply must be at least 3 characters';
                  }
                  return null;
                },
                autofocus: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: AppTheme.grayMedium,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveReply,
          icon: _isSaving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.send, size: 18),
          label: Text(_isSaving ? 'Saving...' : 'Submit Reply'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryLight,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
