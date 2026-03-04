import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/mission_document.dart';
import 'package:purpose/core/models/mission_creation_session.dart';
import 'package:purpose/core/models/goal.dart';
import 'package:purpose/core/models/objective.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/goal_provider.dart';
import 'package:purpose/core/services/gemini_provider.dart';
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

  const MissionDetailPage({
    super.key,
    required this.missionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionAsync = ref.watch(missionDocumentProvider(missionId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Mission Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mission'),
        ),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Mission ${mission.sequenceNumber + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        mission.mission,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Info chips row
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip(
                            icon: Icons.schedule,
                            label: mission.timeHorizon,
                          ),
                          _buildInfoChip(
                            icon: Icons.calendar_month,
                            label: '${mission.durationMonths} months',
                          ),
                          if (mission.riskLevel != null)
                            _buildRiskChip(mission.riskLevel!),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Compact cards in full-width grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate card width to fit nicely
                          final availableWidth = constraints.maxWidth;
                          final cardWidth = (availableWidth - 36) / 4; // 4 cards with 12px gaps
                          
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildCompactCard(
                                title: 'Focus',
                                icon: Icons.track_changes,
                                content: mission.focus,
                                color: AppTheme.primary,
                                width: cardWidth,
                              ),
                              _buildCompactCard(
                                title: 'Structural Shift',
                                icon: Icons.transform,
                                content: mission.structuralShift,
                                color: AppTheme.primaryLight,
                                width: cardWidth,
                              ),
                              _buildCompactCard(
                                title: 'Capability Required',
                                icon: Icons.military_tech,
                                content: mission.capabilityRequired,
                                color: AppTheme.success,
                                width: cardWidth,
                              ),
                              _buildCompactCard(
                                title: 'Risk & Value Guardrail',
                                icon: Icons.security,
                                content: mission.riskOrValueGuardrail,
                                color: AppTheme.warning,
                                width: cardWidth,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Goals Section
                _GoalsSection(
                  missionId: missionId,
                  strategyId: mission.strategyId,
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

  Widget _buildRiskChip(RiskLevel riskLevel) {
    Color color;
    String label;
    
    switch (riskLevel) {
      case RiskLevel.low:
        color = AppTheme.success;
        label = 'Low Risk';
        break;
      case RiskLevel.medium:
        color = AppTheme.warning;
        label = 'Medium Risk';
        break;
      case RiskLevel.high:
        color = AppTheme.error;
        label = 'High Risk';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCard({
    required String title,
    required IconData icon,
    required String content,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.graphite,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Goals Section Widget with CRUD operations
class _GoalsSection extends ConsumerWidget {
  final String missionId;
  final String strategyId;

  const _GoalsSection({
    required this.missionId,
    required this.strategyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsForMissionStreamProvider(missionId));

    return Padding(
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
                    onEdit: () => _showGoalDialog(context, ref, goal),
                    onDelete: () => _confirmDelete(context, ref, goal),
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
    );
  }

  void _showGoalDialog(BuildContext context, WidgetRef ref, Goal? goal) {
    showDialog(
      context: context,
      builder: (context) => _GoalDialog(
        missionId: missionId,
        strategyId: strategyId,
        goal: goal,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Goal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text(
          'Are you sure you want to delete "${goal.title}"? This will also delete all associated objectives.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Goal Card Widget
class _GoalCard extends ConsumerStatefulWidget {
  final Goal goal;
  final String missionId;
  final String strategyId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.missionId,
    required this.strategyId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ConsumerState<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<_GoalCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final objectivesAsync = ref.watch(objectivesForGoalStreamProvider(widget.goal.id));

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (widget.goal.achieved)
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
                      ),
                      if (widget.goal.achieved) const SizedBox(height: 8),
                      Text(
                        widget.goal.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.graphite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.goal.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.grayMedium,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onEdit,
                      icon: Icon(Icons.edit_outlined, size: 20),
                      color: AppTheme.primary,
                      tooltip: 'Edit Goal',
                    ),
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: Icon(Icons.delete_outline, size: 20),
                      color: AppTheme.error,
                      tooltip: 'Delete Goal',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Budget and Objectives Info
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  icon: Icons.attach_money,
                  label: 'Budget: \$${widget.goal.budgetMonetary.toStringAsFixed(0)} / \$${widget.goal.actualMonetary.toStringAsFixed(0)}',
                  color: widget.goal.budgetVarianceMonetary >= 0 
                    ? AppTheme.success 
                    : AppTheme.error,
                ),
                _buildInfoChip(
                  icon: Icons.schedule,
                  label: 'Time: ${widget.goal.budgetTime.toStringAsFixed(0)}h / ${widget.goal.actualTime.toStringAsFixed(0)}h',
                  color: widget.goal.budgetVarianceTime >= 0 
                    ? AppTheme.success 
                    : AppTheme.error,
                ),
                objectivesAsync.when(
                  data: (objectives) {
                    final achieved = objectives.where((o) => o.achieved).length;
                    return _buildInfoChip(
                      icon: Icons.checklist,
                      label: 'Objectives: $achieved/${objectives.length}',
                      color: AppTheme.primary,
                    );
                  },
                  loading: () => _buildInfoChip(
                    icon: Icons.checklist,
                    label: 'Objectives: ...',
                    color: AppTheme.grayMedium,
                  ),
                  error: (_, __) => _buildInfoChip(
                    icon: Icons.checklist,
                    label: 'Objectives: -',
                    color: AppTheme.grayMedium,
                  ),
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
                                      onEdit: () => _showObjectiveDialog(context, objective),
                                      onDelete: () => _confirmDeleteObjective(context, objective),
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
        objective: objective,
      ),
    );
  }

  Future<void> _confirmDeleteObjective(BuildContext context, Objective objective) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Objective'),
        content: Text('Are you sure you want to delete "${objective.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
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
              content: Text('Error deleting objective: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Objective Card Widget
class _ObjectiveCard extends StatelessWidget {
  final Objective objective;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ObjectiveCard({
    required this.objective,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isOverdue = objective.isOverdue;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: objective.achieved 
            ? AppTheme.success 
            : (isOverdue ? AppTheme.error : AppTheme.grayLight),
          width: objective.achieved || isOverdue ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (objective.achieved)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: AppTheme.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 12,
                                  color: AppTheme.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Overdue',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (objective.achieved || isOverdue) const SizedBox(height: 6),
                    Text(
                      objective.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.graphite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      objective.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.grayMedium,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, size: 18),
                    color: AppTheme.primary,
                    tooltip: 'Edit Objective',
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 18),
                    color: AppTheme.error,
                    tooltip: 'Delete Objective',
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (objective.dueDate != null)
                _buildDetailChip(
                  icon: Icons.calendar_today,
                  label: 'Due: ${dateFormat.format(objective.dueDate!)}',
                  color: isOverdue ? AppTheme.error : AppTheme.grayMedium,
                ),
              if (objective.costMonetary > 0)
                _buildDetailChip(
                  icon: Icons.attach_money,
                  label: '\$${objective.costMonetary.toStringAsFixed(0)}',
                  color: AppTheme.grayMedium,
                ),
              if (objective.costTime > 0)
                _buildDetailChip(
                  icon: Icons.schedule,
                  label: '${objective.costTime.toStringAsFixed(0)}h',
                  color: AppTheme.grayMedium,
                ),
            ],
          ),
        ],
      ),
    );
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
  final Objective? objective;

  const _ObjectiveDialog({
    required this.goalId,
    required this.missionId,
    required this.strategyId,
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
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter objective title',
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
                  hintText: 'Enter objective description',
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _measurableRequirementController,
                decoration: const InputDecoration(
                  labelText: 'Measurable Requirement',
                  hintText: 'e.g., "Increase sales by 20%"',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
                      color: _dueDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costMonetaryController,
                      decoration: const InputDecoration(
                        labelText: 'Cost \$ (Optional)',
                        hintText: '0',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Time Hours (Optional)',
                        hintText: '0',
                        border: OutlineInputBorder(),
                        suffixText: 'h',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
      actions: [
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
    );
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
  final Goal? goal;

  const _GoalDialog({
    required this.missionId,
    required this.strategyId,
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
            ),
          ),
        ),
      ),
      actions: [
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
    );
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
