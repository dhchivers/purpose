import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:purpose/core/models/mission_document.dart';
import 'package:purpose/core/models/user_comment.dart';
import 'package:purpose/core/models/user_model.dart';
import 'package:purpose/core/models/user_value.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/goal_provider.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/services/user_comment_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/shared/widgets/strategy_selector.dart';

final _dashValueByIdProvider =
    FutureProvider.autoDispose.family<UserValue?, String>((ref, id) async {
  return ref.read(firestoreServiceProvider).getUserValue(id);
});

final _dashMissionByIdProvider =
    FutureProvider.autoDispose.family<MissionDocument?, String>((ref, id) async {
  return ref.read(firestoreServiceProvider).getMissionDocument(id);
});

final _dashUserByIdProvider =
    FutureProvider.autoDispose.family<UserModel?, String>((ref, uid) async {
  return ref.read(firestoreServiceProvider).getUser(uid);
});

final _dashMissionMapStrategyIdProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, missionMapId) async {
  return ref.read(firestoreServiceProvider).getUserMissionMapStrategyId(missionMapId);
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: currentUserAsync.when(
          data: (user) {
            if (user == null) {
              return Row(
                children: [
                  // App logo
                  Image.asset(
                    'assets/images/purpose_logo_dark.png',
                    height: 40,
                  ),
                ],
              );
            }
            return Row(
              children: [
                // App logo
                Image.asset(
                  'assets/images/purpose_logo_dark.png',
                  height: 40,
                ),
                const SizedBox(width: 24),
                // User info
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF1E6BFF).withOpacity(0.3),
                  child: Text(
                    user.fullName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (user.isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E6BFF),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
          loading: () => Row(
            children: [
              Image.asset(
                'assets/images/purpose_logo_dark.png',
                height: 40,
              ),
            ],
          ),
          error: (error, stack) => Row(
            children: [
              Image.asset(
                'assets/images/purpose_logo_dark.png',
                height: 40,
              ),
            ],
          ),
        ),
        leading: currentUserAsync.when(
          data: (user) {
            // Show settings icon for admin users
            if (user?.isAdmin == true) {
              return IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Admin Settings',
                onPressed: () {
                  context.go('/admin');
                },
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () {
              ref.read(authStateProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: currentUserAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    'No user data available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please check the browser console for error details.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Firestore connection warning (if user has no data from Firestore)
                if (user.purpose == null && user.vision == null && user.mission == null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Limited Connectivity',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Using temporary profile. Your custom domain may still be provisioning. Try refreshing in a few minutes.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Email verification banner (if needed)
                if (!user.emailVerified)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Email not verified',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Please check your inbox and verify',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await ref.read(authStateProvider.notifier).refreshUser();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Status refreshed')),
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Check'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(authStateProvider.notifier).sendEmailVerification();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Verification email sent!')),
                            );
                          },
                          child: const Text('Resend'),
                        ),
                      ],
                    ),
                  ),

                // Quick Action Buttons
                Consumer(
                  builder: (context, ref, child) {
                    final activeStrategy = ref.watch(activeStrategyProvider);
                    return _QuickActionButtonsBar(
                      user: user,
                      activeStrategy: activeStrategy,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Strategy Selector
                const StrategySelector(
                  showCreateButton: true,
                  compact: false,
                ),
                const SizedBox(height: 24),

                // Current Objectives
                const _CurrentObjectivesSection(),
                const SizedBox(height: 24),

                // Comments
                const _CommentsSection(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          print('❌ Error loading user on dashboard: $error');
          print('Stack trace: $stack');
          return Center(
            child: Text('Error: $error'),
          );
        },
      ),
    );
  }
}

// Current Objectives Section
class _CurrentObjectivesSection extends ConsumerWidget {
  const _CurrentObjectivesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStrategy = ref.watch(activeStrategyProvider);
    if (activeStrategy == null) return const SizedBox.shrink();

    final missionMapAsync = ref.watch(missionMapStreamProvider(activeStrategy.id));
    return missionMapAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (missionMap) {
        if (missionMap == null) return const SizedBox.shrink();

        final missionsAsync = ref.watch(missionsForMapStreamProvider(missionMap.id));
        return missionsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (missions) {
            if (missions.isEmpty) return const SizedBox.shrink();
            final currentIndex = missionMap.currentMissionIndex ?? 0;
            if (currentIndex >= missions.length) return const SizedBox.shrink();
            final currentMission = missions[currentIndex];
            return _CurrentObjectivesSectionContent(mission: currentMission);
          },
        );
      },
    );
  }
}

class _CurrentObjectivesSectionContent extends ConsumerWidget {
  final MissionDocument mission;

  const _CurrentObjectivesSectionContent({required this.mission});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectivesAsync = ref.watch(objectivesForMissionStreamProvider(mission.id));
    return objectivesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (allObjectives) {
        final objectives = allObjectives.where((o) => !o.achieved).toList()
          ..sort((a, b) {
            if (a.dueDate == null && b.dueDate == null) return 0;
            if (a.dueDate == null) return 1;
            if (b.dueDate == null) return -1;
            return a.dueDate!.compareTo(b.dueDate!);
          });
        if (objectives.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.grayLight),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Row(
              children: [
                const Icon(Icons.flag_outlined, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Current Objectives',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.graphite,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${objectives.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: GestureDetector(
              onTap: () => context.go('/mission/${mission.id}'),
              child: Text(
                mission.mission,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.grayMedium,
                ),
              ),
            ),
            children: objectives.map((objective) {
              final isOverdue = objective.dueDate != null &&
                  objective.dueDate!.isBefore(now);
              final dueDateColor = isOverdue ? AppTheme.error : AppTheme.grayMedium;

              return ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                onExpansionChanged: (_) {},
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (objective.dueDate != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOverdue)
                            Icon(Icons.warning_amber_rounded,
                                size: 12, color: dueDateColor),
                          if (isOverdue) const SizedBox(width: 2),
                          Text(
                            'Due: ${DateFormat('MMM d, yyyy').format(objective.dueDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: dueDateColor,
                              fontWeight: isOverdue
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    GestureDetector(
                      onTap: () => context.go(
                          '/mission/${mission.id}?objectiveId=${objective.id}'),
                      child: Text(
                        objective.title,
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.graphite),
                      ),
                    ),
                  ],
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      objective.description,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.grayMedium,
                          height: 1.5),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// Quick Action Buttons Bar Widget
class _QuickActionButtonsBar extends ConsumerWidget {
  final dynamic user;
  final dynamic activeStrategy;

  const _QuickActionButtonsBar({
    required this.user,
    required this.activeStrategy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = !kIsWeb && Platform.isIOS;

    final purposeComplete = activeStrategy?.purpose != null;
    final visionComplete = activeStrategy?.currentVision != null;

    // Reactively watch values and mission map so status updates without re-selecting
    final valuesComplete = activeStrategy == null
        ? false
        : ref.watch(strategyValuesProvider(activeStrategy.id)).when(
            data: (values) => values.length >= 3,
            loading: () => false,
            error: (_, __) => false,
          );

    final missionComplete = activeStrategy == null
        ? false
        : ref.watch(strategyMissionMapStreamProvider(activeStrategy.id)).when(
            data: (missionMap) => missionMap != null && missionMap.missions.isNotEmpty,
            loading: () => false,
            error: (_, __) => false,
          );

    if (isIOS) {
      // iOS: Icon-only buttons spanning full width
      return Row(
        children: [
          Expanded(
            child: _CompletableIconButton(
              icon: Icons.psychology,
              tooltip: 'Purpose',
              isComplete: purposeComplete,
              onPressed: () => context.go('/purpose'),
            ),
          ),
          Expanded(
            child: _CompletableIconButton(
              icon: Icons.diamond_outlined,
              tooltip: 'Values',
              isComplete: valuesComplete,
              onPressed: () => context.go('/values'),
            ),
          ),
          Expanded(
            child: _CompletableIconButton(
              icon: Icons.visibility,
              tooltip: 'Vision',
              isComplete: visionComplete,
              onPressed: () {
                if (user.vision != null) {
                  context.go('/vision');
                } else {
                  context.go('/vision/create');
                }
              },
            ),
          ),
          Expanded(
            child: _CompletableIconButton(
              icon: Icons.track_changes,
              tooltip: 'Mission',
              isComplete: missionComplete,
              onPressed: () => context.go('/mission'),
            ),
          ),
        ],
      );
    } else {
      // Web: Buttons with labels spanning full width
      return Row(
        children: [
          Expanded(
            child: _CompletableElevatedButton(
              icon: Icons.psychology,
              label: 'Purpose',
              isComplete: purposeComplete,
              onPressed: () => context.go('/purpose'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompletableElevatedButton(
              icon: Icons.diamond_outlined,
              label: 'Values',
              isComplete: valuesComplete,
              onPressed: () => context.go('/values'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompletableElevatedButton(
              icon: Icons.visibility,
              label: 'Vision',
              isComplete: visionComplete,
              onPressed: () {
                if (user.vision != null) {
                  context.go('/vision');
                } else {
                  context.go('/vision/create');
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompletableElevatedButton(
              icon: Icons.track_changes,
              label: 'Mission',
              isComplete: missionComplete,
              onPressed: () => context.go('/mission'),
            ),
          ),
        ],
      );
    }
  }
}

// Helper widget for iOS icon buttons with completion highlighting
class _CompletableIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isComplete;
  final VoidCallback onPressed;

  const _CompletableIconButton({
    required this.icon,
    required this.tooltip,
    required this.isComplete,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isComplete
          ? BoxDecoration(
              color: const Color(0xFF1E6BFF).withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF1E6BFF),
                  width: 3,
                ),
              ),
            )
          : null,
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 28,
        color: isComplete ? const Color(0xFF1E6BFF) : null,
      ),
    );
  }
}

// Helper widget for web elevated buttons with completion highlighting
class _CompletableElevatedButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isComplete;
  final VoidCallback onPressed;

  const _CompletableElevatedButton({
    required this.icon,
    required this.label,
    required this.isComplete,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isComplete) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check_circle, size: 16),
          ],
        ],
      ),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isComplete ? const Color(0xFF1E6BFF) : null,
        foregroundColor: isComplete ? Colors.white : null,
      ),
    );
  }
}

const _kDashEntityLabels = {
  'purpose': 'PURPOSE',
  'vision': 'VISION',
  'mission': 'MISSION',
  'mission_map': 'MISSION MAP',
  'goal': 'GOAL',
  'objective': 'OBJECTIVE',
  'value': 'VALUE',
};

class _CommentsSection extends ConsumerWidget {
  const _CommentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) return const SizedBox.shrink();

    final commentsAsync = ref.watch(commentsForUserStreamProvider(currentUser.uid));
    final cutoff = DateTime.now().subtract(const Duration(days: 14));

    final allComments = commentsAsync.maybeWhen(
      data: (all) => all,
      orElse: () => <UserComment>[],
    );

    final activeStrategy = ref.watch(activeStrategyProvider);
    final activeStrategyId = activeStrategy?.id;

    // Resolve strategy ID for a parent comment from cached provider values.
    // Returns null if not yet loaded — in that case, include the comment.
    String? _strategyIdFor(UserComment c) {
      final id = c.entityId;
      switch (c.entityType) {
        case 'purpose':
        case 'vision':
          return id; // entityId IS the strategyId
        case 'goal':
          return ref.watch(goalProvider(id)).value?.strategyId;
        case 'objective':
          return ref.watch(objectiveProvider(id)).value?.strategyId;
        case 'mission':
          return ref.watch(_dashMissionByIdProvider(id)).value?.strategyId;
        case 'mission_map':
          return ref.watch(_dashMissionMapStrategyIdProvider(id)).value;
        case 'value':
          return ref.watch(_dashValueByIdProvider(id)).value?.strategyId;
        default:
          return null;
      }
    }

    bool _parentBelongsToStrategy(UserComment parent) {
      if (activeStrategyId == null) return true; // no filter when no strategy selected
      final resolved = _strategyIdFor(parent);
      return resolved == null || resolved == activeStrategyId;
    }

    // Build ordered list: each recent parent followed by its recent replies.
    // A parent qualifies if it or any of its replies were updated within cutoff.
    final topLevelAll = allComments.where((c) => c.parentCommentId == null).toList();
    final orderedRecent = <UserComment>[];
    for (final parent in topLevelAll) {
      if (!_parentBelongsToStrategy(parent)) continue;
      final replies = allComments
          .where((c) => c.parentCommentId == parent.id)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final recentReplies = replies.where((r) => r.updatedAt.isAfter(cutoff)).toList();
      final parentRecent = parent.updatedAt.isAfter(cutoff);
      if (parentRecent || recentReplies.isNotEmpty) {
        if (parentRecent) orderedRecent.add(parent);
        orderedRecent.addAll(recentReplies);
      }
    }

    if (orderedRecent.isEmpty) return const SizedBox.shrink();

    final topLevelCount =
        topLevelAll.where(_parentBelongsToStrategy).length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grayLight),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: GestureDetector(
          onTap: () => context.go('/comments'),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/comments'),
                child: const Icon(Icons.forum_outlined,
                    size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recent Comments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.graphite,
                ),
              ),
              if (topLevelCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$topLevelCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        children: orderedRecent.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No comments in the past 14 days.',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.grayMedium),
                  ),
                ),
              ]
            : orderedRecent
                .map((comment) => _DashCommentTile(
                      key: ValueKey(comment.id),
                      comment: comment,
                    ))
                .toList(),
      ),
    );
  }
}

class _DashCommentTile extends ConsumerWidget {
  final UserComment comment;
  const _DashCommentTile({super.key, required this.comment});

  String _resolveTitle(WidgetRef ref) {
    final id = comment.entityId;
    switch (comment.entityType) {
      case 'purpose':
        return ref.watch(strategyProvider(id)).value?.purpose ?? '';
      case 'vision':
        return ref.watch(strategyVisionProvider(id)).value?.visionStatement ?? '';
      case 'mission':
        return ref.watch(_dashMissionByIdProvider(id)).value?.mission ?? '';
      case 'goal':
        return ref.watch(goalProvider(id)).value?.title ?? '';
      case 'objective':
        return ref.watch(objectiveProvider(id)).value?.title ?? '';
      case 'value':
        return ref.watch(_dashValueByIdProvider(id)).value?.refinedLabel ?? '';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReply = comment.parentCommentId != null;
    final entityLabel =
        _kDashEntityLabels[comment.entityType] ?? comment.entityType.toUpperCase();
    final entityTitle = isReply ? '' : _resolveTitle(ref);

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 12 : 0, bottom: 8, top: 4),
      child: GestureDetector(
        onTap: () => context.go('/comments'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReply)
              Container(
                width: 2,
                height: 36,
                margin: const EdgeInsets.only(right: 8, top: 2),
                color: AppTheme.primary.withOpacity(0.35),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isReply) ...[
                    Text(
                      entityLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (entityTitle.isNotEmpty)
                      Text(
                        entityTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.graphite,
                        ),
                      ),
                  ],
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM d · h:mm a').format(comment.updatedAt),
                        style: const TextStyle(fontSize: 11, color: AppTheme.grayMedium),
                      ),
                      if (ref.watch(_dashUserByIdProvider(comment.userId)).value?.fullName case final String name)
                        Text(
                          ' · $name',
                          style: const TextStyle(fontSize: 11, color: AppTheme.grayMedium),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.commentText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppTheme.graphite),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

