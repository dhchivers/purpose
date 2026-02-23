import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/models/user_value.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Provider for user values
final userValuesProvider = FutureProvider.family<List<UserValue>, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserValues(userId);
});

/// Page displaying user's values and entry point to value creation
class ValuesPage extends ConsumerWidget {
  const ValuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('My Values'),
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

          // Load user's values from Firestore
          final userValuesAsync = ref.watch(userValuesProvider(user.uid));

          return userValuesAsync.when(
            data: (values) => _buildValuesContent(context, values),
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
                    onPressed: () => ref.refresh(userValuesProvider(user.uid)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: currentUserAsync.maybeWhen(
        data: (user) {
          if (user == null) return null;
          final valuesAsync = ref.watch(userValuesProvider(user.uid));
          final valueCount = valuesAsync.maybeWhen(
            data: (values) => values.length,
            orElse: () => 0,
          );
          
          // Only show FAB if under 5 values
          if (valueCount >= 5) return null;
          
          return FloatingActionButton.extended(
            onPressed: () => context.go('/values/create'),
            icon: const Icon(Icons.add),
            label: const Text('Create Value'),
            backgroundColor: AppTheme.primary,
          );
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildValuesContent(BuildContext context, List<UserValue> values) {
    return Column(
      children: [
        // Header with info
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
                Icons.favorite,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'Discover Your Values',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Refine 3-5 core values that guide your decisions',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
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
                          // TODO: Navigate to value detail page
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
