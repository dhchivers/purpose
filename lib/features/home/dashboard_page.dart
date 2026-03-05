import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/goal.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/services/goal_provider.dart';
import 'package:purpose/shared/widgets/strategy_selector.dart';
import 'package:intl/intl.dart';

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
            padding: const EdgeInsets.all(24.0),
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

                // Strategy Selector
                const SizedBox(height: 16),
                const StrategySelector(
                  showCreateButton: true,
                  compact: false,
                ),
                const SizedBox(height: 24),

                // Quick Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.psychology,
                        label: 'Purpose',
                        onTap: () => context.go('/purpose'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.diamond_outlined,
                        label: 'Values',
                        onTap: () => context.go('/values'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.visibility,
                        label: 'Vision',
                        onTap: () {
                          // Navigate to detail page if vision exists, otherwise to creation flow
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
                      child: _QuickActionButton(
                        icon: Icons.track_changes,
                        label: 'Mission',
                        onTap: () => context.go('/mission'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.flag_outlined,
                        label: 'Goals',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Goals module coming soon!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Progress section
                Text(
                  'Your Progress',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                // Two column layout: Left (Purpose/Vision/Mission/Values) and Right (Goals)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Purpose, Vision, Mission, Values
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Purpose Card - Strategy-scoped
                          Consumer(
                            builder: (context, ref, child) {
                              final activeStrategy = ref.watch(activeStrategyProvider);
                              
                              if (activeStrategy == null) {
                                return _PurposeCard(
                                  value: 'No active strategy',
                                  color: Colors.grey,
                                  onTap: () => context.go('/'),
                                );
                              }
                              
                              return _PurposeCard(
                                value: activeStrategy.purpose ?? 'Not set',
                                color: activeStrategy.purpose != null ? const Color(0xFF1E6BFF) : Colors.grey,
                                lastUpdated: activeStrategy.purpose != null ? activeStrategy.updatedAt : null,
                                onTap: () => context.go('/purpose'),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Vision Card - Strategy-scoped
                          Consumer(
                            builder: (context, ref, child) {
                              final activeStrategy = ref.watch(activeStrategyProvider);
                              
                              if (activeStrategy == null) {
                                return _PurposeCard(
                                  icon: Icons.visibility,
                                  label: 'Vision',
                                  value: 'No active strategy',
                                  color: Colors.grey,
                                  onTap: () => context.go('/'),
                                );
                              }
                              
                              return _PurposeCard(
                                icon: Icons.visibility,
                                label: 'Vision',
                                value: activeStrategy.currentVision ?? 'Not set',
                                color: activeStrategy.currentVision != null ? const Color(0xFF1E6BFF) : Colors.grey,
                                lastUpdated: activeStrategy.currentVision != null ? activeStrategy.updatedAt : null,
                                onTap: () {
                                  if (activeStrategy.currentVision != null) {
                                    context.go('/vision');
                                  } else {
                                    context.go('/vision/create');
                                  }
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Mission Card - Strategy-scoped
                          Consumer(
                            builder: (context, ref, child) {
                              // Get active strategy first
                              final activeStrategy = ref.watch(activeStrategyProvider);
                              
                              if (activeStrategy == null) {
                                return _PurposeCard(
                                  icon: Icons.track_changes,
                                  label: 'Mission',
                                  value: 'No active strategy',
                                  color: Colors.grey,
                                  onTap: () => context.go('/'),
                                );
                              }
                              
                              final missionMapAsync = ref.watch(strategyMissionMapStreamProvider(activeStrategy.id));
                              return missionMapAsync.when(
                                data: (missionMap) {
                                  final hasMissions = missionMap != null && missionMap.missions.isNotEmpty;
                                  final currentMission = missionMap?.currentMission;
                                  final currentIndex = missionMap?.currentMissionIndex ?? 0;
                                  
                                  // Calculate timeline for current mission
                                  String? timeline;
                                  if (hasMissions && currentMission != null && missionMap.strategyStartDate != null) {
                                    final startDate = _calculateMissionStartDate(missionMap, currentIndex);
                                    final endDate = _calculateMissionEndDate(missionMap, currentIndex);
                                    if (startDate != null && endDate != null) {
                                      timeline = '${_formatMonthYear(startDate)} - ${_formatMonthYear(endDate)} (${currentMission.durationMonths} months)';
                                    }
                                  }
                                  
                                  return _PurposeCard(
                                    icon: Icons.track_changes,
                                    label: 'Mission',
                                    value: hasMissions && currentMission != null
                                        ? currentMission.mission
                                        : 'Not set',
                                    subtitle: timeline,
                                    color: hasMissions ? const Color(0xFF1E6BFF) : Colors.grey,
                                    lastUpdated: hasMissions ? missionMap.updatedAt : null,
                                    onTap: () {
                                      if (hasMissions) {
                                        context.go('/mission');
                                      } else {
                                        context.go('/mission/create');
                                      }
                                    },
                                  );
                                },
                                loading: () => const _PurposeCard(
                                  icon: Icons.track_changes,
                                  label: 'Mission',
                                  value: 'Loading...',
                                  color: Colors.grey,
                                ),
                                error: (error, stack) {
                                  print('❌ Error loading mission map on dashboard: $error');
                                  print('Stack trace: $stack');
                                  return const _PurposeCard(
                                    icon: Icons.track_changes,
                                    label: 'Mission',
                                    value: 'Error loading',
                                    color: Colors.grey,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Load and display user values
                          Consumer(
                            builder: (context, ref, child) {
                              // Get active strategy first
                              final activeStrategy = ref.watch(activeStrategyProvider);
                              
                              if (activeStrategy == null) {
                                return const _ValuesCard(
                                  values: [],
                                );
                              }
                              
                              final userValuesAsync = ref.watch(strategyValuesProvider(activeStrategy.id));
                              return userValuesAsync.when(
                                data: (userValues) {
                                  // Find the most recently updated value
                                  DateTime? mostRecentUpdate;
                                  if (userValues.isNotEmpty) {
                                    for (final value in userValues) {
                                      final valueUpdated = value.updatedAt ?? value.createdAt;
                                      if (mostRecentUpdate == null || valueUpdated.isAfter(mostRecentUpdate)) {
                                        mostRecentUpdate = valueUpdated;
                                      }
                                    }
                                  }
                                  return _ValuesCard(
                                    values: userValues.map((v) => v.refinedLabel).toList(),
                                    lastUpdated: mostRecentUpdate,
                                  );
                                },
                                loading: () => const _ValuesCard(values: []),
                                error: (error, stack) {
                                  print('❌ Error loading values on dashboard: $error');
                                  print('Stack trace: $stack');
                                  return const _ValuesCard(values: []);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right Column: Goals
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Consumer(
                            builder: (context, ref, child) {
                              final activeStrategy = ref.watch(activeStrategyProvider);
                              
                              if (activeStrategy == null) {
                                return const _GoalsCard(goals: []);
                              }
                              
                              final goalsAsync = ref.watch(activeGoalsForStrategyProvider(activeStrategy.id));
                              return goalsAsync.when(
                                data: (goals) => _GoalsCard(goals: goals),
                                loading: () => const _GoalsCard(goals: []),
                                error: (error, stack) {
                                  print('❌ Error loading goals on dashboard: $error');
                                  return const _GoalsCard(goals: []);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

class _PurposeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final DateTime? lastUpdated;
  final VoidCallback? onTap;

  const _PurposeCard({
    this.icon = Icons.flag,
    this.label = 'Purpose',
    required this.value,
    this.subtitle,
    required this.color,
    this.lastUpdated,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left column: Icon and Label
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(icon, size: 32, color: color),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Right column: Text (centered)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        value,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: value == 'Not set' ? FontWeight.bold : FontWeight.normal,
                              color: color,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                subtitle!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (lastUpdated != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Updated ${DateFormat('MMM d, y').format(lastUpdated!)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}

class _ValuesCard extends StatelessWidget {
  final List<String> values;
  final DateTime? lastUpdated;

  const _ValuesCard({
    required this.values,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/values'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.diamond_outlined, size: 32, color: Color(0xFF1E6BFF)),
                const SizedBox(width: 8),
                Text(
                  'Values',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (values.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    children: [
                      Text(
                        '0',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No values defined yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: values.take(5).map((value) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Color(0xFF1E6BFF),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            if (values.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '+${values.length - 5} more',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            if (lastUpdated != null) ...[
              const SizedBox(height: 8),
              Text(
                'Updated ${DateFormat('MMM d, y').format(lastUpdated!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _GoalsCard extends ConsumerWidget {
  final List<Goal> goals;

  const _GoalsCard({
    required this.goals,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get mission ID for navigation from goals (since they have missionId)
    // or fallback to mission map page if no goals
    final activeStrategy = ref.watch(activeStrategyProvider);
    String? currentMissionId;
    bool canNavigate = false;
    
    if (goals.isNotEmpty) {
      // Use missionId from first goal (all goals in this list are for current mission)
      currentMissionId = goals.first.missionId;
      canNavigate = true;
    } else if (activeStrategy != null) {
      // No goals, but can navigate to mission map page
      canNavigate = true;
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: canNavigate
                ? () {
                    if (currentMissionId != null) {
                      context.go('/mission/$currentMissionId');
                    } else {
                      context.go('/mission');
                    }
                  }
                : null,
              child: Row(
                children: [
                  const Icon(Icons.checklist, size: 32, color: Color(0xFF1E6BFF)),
                  const SizedBox(width: 8),
                  Text(
                    'Goals',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      decoration: canNavigate ? TextDecoration.underline : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (goals.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No active goals',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ),
              )
            else
              ...goals.map((goal) => _GoalItem(goal: goal)),
          ],
        ),
      ),
    );
  }
}

class _GoalItem extends ConsumerWidget {
  final Goal goal;

  const _GoalItem({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectivesAsync = ref.watch(objectivesForGoalStreamProvider(goal.id));

    return objectivesAsync.when(
      data: (objectives) {
        final achieved = objectives.where((obj) => obj.achieved).length;
        final total = objectives.length;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Objectives Completed: $achieved/$total',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Objectives Completed: ...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            goal.title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper functions for mission timeline calculation
DateTime? _calculateMissionStartDate(dynamic missionMap, int missionIndex) {
  if (missionMap.strategyStartDate == null) return null;
  
  int cumulativeMonths = 0;
  for (int i = 0; i < missionIndex; i++) {
    cumulativeMonths += (missionMap.missions[i].durationMonths as num).toInt();
  }
  
  final startDate = missionMap.strategyStartDate!;
  return DateTime(startDate.year, startDate.month + cumulativeMonths, 1);
}

DateTime? _calculateMissionEndDate(dynamic missionMap, int missionIndex) {
  final startDate = _calculateMissionStartDate(missionMap, missionIndex);
  if (startDate == null) return null;
  
  final durationMonths = (missionMap.missions[missionIndex].durationMonths as num).toInt();
  return DateTime(startDate.year, startDate.month + durationMonths - 1, 1);
}

String _formatMonthYear(DateTime? date) {
  if (date == null) return 'Not set';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.year}';
}
