import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:purpose/core/services/revenue_cat_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Widget to display RevenueCat Customer Center
/// Allows users to manage their subscription, view purchase history, etc.
class RevenueCatCustomerCenter extends ConsumerStatefulWidget {
  const RevenueCatCustomerCenter({super.key});

  @override
  ConsumerState<RevenueCatCustomerCenter> createState() => _RevenueCatCustomerCenterState();
}

class _RevenueCatCustomerCenterState extends ConsumerState<RevenueCatCustomerCenter> {
  bool _isLoading = false;

  /// Show the RevenueCat native customer center
  Future<void> _showNativeCustomerCenter() async {
    setState(() => _isLoading = true);

    try {
      await RevenueCatUI.presentCustomerCenter();

      if (!mounted) return;

      setState(() => _isLoading = false);

      // Refresh subscription status after customer center is dismissed
      ref.read(subscriptionNotifierProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading customer center: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-show customer center when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNativeCustomerCenter();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Fallback UI in case native customer center doesn't show
    return const Scaffold(
      body: Center(
        child: Text('Loading customer center...'),
      ),
    );
  }
}

/// Custom subscription management page
/// Use this if you want more control over the subscription management UI
class CustomSubscriptionManagement extends ConsumerWidget {
  const CustomSubscriptionManagement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionStatusAsync = ref.watch(subscriptionStatusProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Subscription Management'),
      ),
      body: subscriptionStatusAsync.when(
        data: (status) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Subscription status card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            status.isPro 
                                ? Icons.workspace_premium 
                                : Icons.person_outline,
                            color: status.isPro ? Colors.amber : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status.isPro 
                                      ? 'Altruency Purpose Pro' 
                                      : 'Free Plan',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  status.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      if (status.isPro) ...[
                        const Divider(height: 24),
                        
                        // Product identifier
                        if (status.productIdentifier != null)
                          _buildInfoRow(
                            'Plan',
                            status.periodType?.toUpperCase() ?? 'Unknown',
                          ),
                        
                        // Expiration date (if not lifetime)
                        if (status.expirationDate != null && 
                            status.periodType != 'lifetime')
                          _buildInfoRow(
                            status.willRenew ? 'Renews on' : 'Expires on',
                            _formatDate(status.expirationDate!),
                          ),
                        
                        // Auto-renewal status
                        if (status.periodType != 'lifetime')
                          _buildInfoRow(
                            'Auto-renew',
                            status.willRenew ? 'Enabled' : 'Disabled',
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              if (!status.isPro) ...[
                // Upgrade button for free users
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/subscription/paywall');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Upgrade to Pro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                // Manage subscription button for pro users
                OutlinedButton.icon(
                  onPressed: () async {
                    // Show native customer center
                    await RevenueCatUI.presentCustomerCenter();
                    // Refresh after dismissal
                    ref.invalidate(subscriptionStatusProvider);
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Manage Subscription'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Restore purchases button
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final success = await ref
                        .read(subscriptionNotifierProvider.notifier)
                        .restorePurchases();
                    
                    if (!context.mounted) return;
                    
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Purchases restored successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No purchases found to restore'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error restoring purchases: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.restore),
                label: const Text('Restore Purchases'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 32),

              // Pro features section
              const Text(
                'Pro Features',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                icon: Icons.auto_awesome,
                title: 'AI-Powered Coaching',
                description: 'Get personalized insights and guidance',
                isPro: status.isPro,
              ),
              _buildFeatureCard(
                icon: Icons.analytics,
                title: 'Advanced Analytics',
                description: 'Track your progress with detailed metrics',
                isPro: status.isPro,
              ),
              _buildFeatureCard(
                icon: Icons.emoji_events,
                title: 'Unlimited Goals',
                description: 'Create and track unlimited goals',
                isPro: status.isPro,
              ),
              _buildFeatureCard(
                icon: Icons.support_agent,
                title: 'Priority Support',
                description: '24/7 dedicated support team',
                isPro: status.isPro,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading subscription: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(subscriptionStatusProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isPro,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isPro ? AppTheme.primary : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isPro ? Icons.check_circle : Icons.lock_outline,
              color: isPro ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
