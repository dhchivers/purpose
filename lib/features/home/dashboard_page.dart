import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/features/values/values_page.dart';
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vision module coming soon!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.track_changes,
                        label: 'Mission',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mission module coming soon!')),
                          );
                        },
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
                // Two column layout: Left (Purpose/Vision/Mission) and Right (Values/Goals)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Purpose, Vision, Mission
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _PurposeCard(
                            value: user.purpose ?? 'Not set',
                            color: user.purpose != null ? const Color(0xFF1E6BFF) : Colors.grey,
                            lastUpdated: user.purpose != null ? user.updatedAt : null,
                          ),
                          const SizedBox(height: 12),
                          _PurposeCard(
                            icon: Icons.visibility,
                            label: 'Vision',
                            value: user.vision ?? 'Not set',
                            color: user.vision != null ? const Color(0xFF1E6BFF) : Colors.grey,
                            lastUpdated: user.vision != null ? user.updatedAt : null,
                          ),
                          const SizedBox(height: 12),
                          _PurposeCard(
                            icon: Icons.track_changes,
                            label: 'Mission',
                            value: user.mission ?? 'Not set',
                            color: user.mission != null ? const Color(0xFF1E6BFF) : Colors.grey,
                            lastUpdated: user.mission != null ? user.updatedAt : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right Column: Values and Goals
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Load and display user values
                          Consumer(
                            builder: (context, ref, child) {
                              final userValuesAsync = ref.watch(userValuesProvider(user.uid));
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
                                error: (_, __) => const _ValuesCard(values: []),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _GoalsCard(
                            value: '${user.goalIds?.length ?? 0}',
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
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}

class _PurposeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final DateTime? lastUpdated;

  const _PurposeCard({
    this.icon = Icons.flag,
    this.label = 'Purpose',
    required this.value,
    required this.color,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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

class _GoalsCard extends StatelessWidget {
  final String value;

  const _GoalsCard({
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist, size: 32, color: Color(0xFF1E6BFF)),
                const SizedBox(width: 8),
                Text(
                  'Goals',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E6BFF),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value == '0' ? 'No goals yet' : 'Goals set',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
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
