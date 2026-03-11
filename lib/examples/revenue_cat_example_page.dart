import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/revenue_cat_provider.dart';
import 'package:purpose/core/utils/entitlement_utils.dart';
import 'package:purpose/shared/widgets/revenue_cat_paywall.dart';
import 'package:purpose/shared/widgets/revenue_cat_customer_center.dart';

/// Example page demonstrating RevenueCat integration
class RevenueCatExamplePage extends ConsumerWidget {
  const RevenueCatExamplePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProAsync = ref.watch(hasProEntitlementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RevenueCat Example'),
        actions: [
          // Show Pro badge
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ProBadge(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Subscription Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription Status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  hasProAsync.when(
                    data: (hasPro) => Text(
                      hasPro ? '✅ Pro User' : '❌ Free User',
                      style: TextStyle(
                        fontSize: 18,
                        color: hasPro ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Text('Error: $err'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Show Paywall Button
          ElevatedButton.icon(
            onPressed: () async {
              final purchased = await context.showPaywall();
              if (purchased == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Welcome to Pro!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Show Paywall'),
          ),

          const SizedBox(height: 8),

          // Show Custom Paywall Button
          OutlinedButton.icon(
            onPressed: () async {
              final purchased = await context.showCustomPaywall();
              if (purchased == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Welcome to Pro!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Show Custom Paywall'),
          ),

          const SizedBox(height: 8),

          // Show Customer Center Button
          OutlinedButton.icon(
            onPressed: () => context.showCustomerCenter(),
            icon: const Icon(Icons.settings),
            label: const Text('Manage Subscription'),
          ),

          const SizedBox(height: 8),

          // Restore Purchases Button
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final success = await ref
                    .read(subscriptionNotifierProvider.notifier)
                    .restorePurchases();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '✅ Purchases restored!'
                            : 'No purchases found',
                      ),
                      backgroundColor: success ? Colors.green : Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.restore),
            label: const Text('Restore Purchases'),
          ),

          const SizedBox(height: 24),

          // Pro-Gated Feature Example
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Pro Feature Example',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      ProBadge(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: ProGate(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 64,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'This is a Pro feature!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Detailed Subscription Info
          _SubscriptionDetailsCard(),
        ],
      ),
    );
  }
}

/// Widget showing detailed subscription information
class _SubscriptionDetailsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(subscriptionStatusProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            statusAsync.when(
              data: (status) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Status', status.description),
                    if (status.isPro) ...[
                      _buildInfoRow('Active', status.isActive ? 'Yes' : 'No'),
                      if (status.productIdentifier != null)
                        _buildInfoRow('Product', status.productIdentifier!),
                      if (status.periodType != null)
                        _buildInfoRow('Period', status.periodType!),
                      if (status.expirationDate != null)
                        _buildInfoRow(
                          'Expires',
                          '${status.expirationDate!.month}/${status.expirationDate!.day}/${status.expirationDate!.year}',
                        ),
                      _buildInfoRow(
                        'Auto-renew',
                        status.willRenew ? 'Yes' : 'No',
                      ),
                    ],
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error loading details: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Example of a Pro-only page using EntitlementCheckMixin
class ProOnlyFeaturePage extends ConsumerStatefulWidget {
  const ProOnlyFeaturePage({super.key});

  @override
  ConsumerState<ProOnlyFeaturePage> createState() => _ProOnlyFeaturePageState();
}

class _ProOnlyFeaturePageState extends ConsumerState<ProOnlyFeaturePage>
    with EntitlementCheckMixin {
  Future<void> _useProFeature() async {
    final hasAccess = await requireProEntitlement(
      message: 'This feature requires Altruency Purpose Pro',
      showPaywall: true,
    );

    if (hasAccess) {
      // User has Pro access, proceed with feature
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pro feature accessed!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // User doesn't have Pro or cancelled
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pro access required'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pro-Only Feature'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star,
              size: 100,
              color: Colors.amber,
            ),
            const SizedBox(height: 24),
            const Text(
              'This is a Pro-only feature!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _useProFeature,
              child: const Text('Access Pro Feature'),
            ),
          ],
        ),
      ),
    );
  }
}
