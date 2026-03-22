import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/models/user_value.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Page displaying user's values and entry point to value creation
class ValuesPage extends ConsumerWidget {
  const ValuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final activeStrategyAsync = ref.watch(activeStrategyAsyncProvider);

    return currentUserAsync.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              title: const Text('Core Values'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
            ),
            body: const Center(child: Text('Please log in')),
          );
        }

        return activeStrategyAsync.when(
          data: (strategy) {
            if (strategy == null) {
              return Scaffold(
                appBar: AppBar(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  title: const Text('Core Values'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/'),
                  ),
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No active strategy',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please create or select a strategy from the dashboard.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Go to Dashboard'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Load values for the active strategy
            final valuesAsync = ref.watch(strategyValuesProvider(strategy.id));

            return Scaffold(
              appBar: AppBar(
                backgroundColor: AppTheme.graphite,
                foregroundColor: Colors.white,
                title: Text(
                  strategy.name,
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
              body: valuesAsync.when(
                data: (values) => _buildValuesContent(context, values, strategy.name),
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
                        onPressed: () => ref.refresh(strategyValuesProvider(strategy.id)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => Scaffold(
            appBar: AppBar(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              title: const Text('Core Values'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Scaffold(
            appBar: AppBar(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              title: const Text('Core Values'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading strategy: $error'),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          title: const Text('Core Values'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          title: const Text('Core Values'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildValuesContent(BuildContext context, List<UserValue> values, String strategyName) {
    return Column(
      children: [
        // Header with info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: const BoxDecoration(
            color: AppTheme.primary,
          ),
          child: Row(
            children: [
              const SizedBox(width: 22),
              const Expanded(
                child: Center(
                  child: Text(
                    'Core Values',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (values.length < 5)
                IconButton(
                  onPressed: () => context.go('/values/create'),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Create Value',
                  iconSize: 28,
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                const SizedBox(width: 22),
            ],
          ),
        ),

        // Progress info
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.primaryTintLight,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have ${values.length} of 3-5 values defined. ${values.length < 3 ? 'Define at least ${3 - values.length} more.' : values.length >= 5 ? 'Value limit reached.' : 'You can add ${5 - values.length} more.'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.graphite,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Values list or empty state
        Expanded(
          child: values.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No values yet',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start by creating your first value',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/values/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Your First Value'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: values.length,
                  itemBuilder: (context, index) {
                    final value = values[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryTintLight,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          value.refinedLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            value.statement,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          context.go('/values/${value.id}');
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
