import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/core/constants/app_constants.dart';

class AdminSettingsPage extends ConsumerWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Admin Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppConstants.homeRoute),
        ),
      ),
      body: currentUserAsync.when(
        data: (user) {
          // Verify user is actually an admin
          if (user == null || !user.isAdmin) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outlined,
                    size: 80,
                    color: AppTheme.grayMedium,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.graphite,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You do not have permission to access this page.',
                    style: TextStyle(color: AppTheme.grayMedium),
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
                // Admin info card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.grayLight, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            size: 40,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Administrator',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.graphite,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.grayMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Admin sections
                const Text(
                  'Content Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.graphite,
                  ),
                ),
                const SizedBox(height: 16),

                // Question Modules Management
                _buildAdminTile(
                  context: context,
                  icon: Icons.question_answer,
                  title: 'Purpose Question Modules',
                  subtitle: 'Manage question modules and questions',
                  onTap: () => context.go('/admin/modules'),
                ),
                const SizedBox(height: 12),

                // Values Seeds Management
                _buildAdminTile(
                  context: context,
                  icon: Icons.lightbulb_outline,
                  title: 'Values Seeds',
                  subtitle: 'Manage value options for exploration',
                  onTap: () => context.go('/admin/values-seeds'),
                ),
                const SizedBox(height: 12),

                // Strategy Types Management
                _buildAdminTile(
                  context: context,
                  icon: Icons.category,
                  title: 'Strategy Types',
                  subtitle: 'Manage strategy classification types',
                  onTap: () => context.go('/admin/strategy-types'),
                ),
                const SizedBox(height: 12),

                // Mission Data Migration (Testing)
                _buildAdminTile(
                  context: context,
                  icon: Icons.cloud_sync,
                  title: 'Mission Data Migration',
                  subtitle: '⚠️ Test migration to new structure',
                  onTap: () => context.go('/admin/migration-test'),
                ),
                const SizedBox(height: 12),

                // User Management
                _buildAdminTile(
                  context: context,
                  icon: Icons.people,
                  title: 'User Management',
                  subtitle: 'View and manage users',
                  onTap: () {
                    // TODO: Navigate to user management
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User management coming soon'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                const Text(
                  'System',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.graphite,
                  ),
                ),
                const SizedBox(height: 16),

                // Analytics
                _buildAdminTile(
                  context: context,
                  icon: Icons.analytics,
                  title: 'Analytics',
                  subtitle: 'View usage statistics and reports',
                  onTap: () {
                    // TODO: Navigate to analytics
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Analytics coming soon'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Settings
                _buildAdminTile(
                  context: context,
                  icon: Icons.settings,
                  title: 'Settings',
                  subtitle: 'Configure application settings',
                  onTap: () {
                    // TODO: Navigate to settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: AppTheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: const TextStyle(color: AppTheme.grayMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.grayLight, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primary,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.graphite,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.grayMedium,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.grayMedium,
        ),
        onTap: onTap,
      ),
    );
  }
}
