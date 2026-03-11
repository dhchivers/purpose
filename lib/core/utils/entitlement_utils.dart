import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/revenue_cat_provider.dart';
import 'package:purpose/shared/widgets/revenue_cat_paywall.dart';
import 'package:purpose/shared/widgets/revenue_cat_customer_center.dart';

/// Mixin to add entitlement checking functionality to widgets
mixin EntitlementCheckMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Check if user has Pro entitlement
  Future<bool> hasProEntitlement() async {
    final revenueCatService = ref.read(revenueCatServiceProvider);
    return await revenueCatService.hasProEntitlement();
  }

  /// Check if user has Pro entitlement (cached, synchronous)
  bool hasCachedProEntitlement() {
    return ref.read(cachedHasProEntitlementProvider);
  }

  /// Show paywall if user doesn't have Pro entitlement
  /// Returns true if user has or gained Pro access, false otherwise
  Future<bool> requireProEntitlement({
    String? message,
    bool showPaywall = true,
  }) async {
    final hasPro = await hasProEntitlement();
    
    if (hasPro) {
      return true;
    }

    if (!mounted) return false;

    // Show message if provided
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Upgrade',
            onPressed: () {
              _showPaywall();
            },
          ),
        ),
      );
    }

    // Show paywall if requested
    if (showPaywall) {
      final purchased = await _showPaywall();
      return purchased == true;
    }

    return false;
  }

  /// Show the paywall
  Future<bool?> _showPaywall() async {
    return await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const RevenueCatPaywall(),
        fullscreenDialog: true,
      ),
    );
  }
}

/// Widget that conditionally shows content based on Pro entitlement
class ProGate extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;
  final bool showPaywallButton;

  const ProGate({
    super.key,
    required this.child,
    this.fallback,
    this.showPaywallButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProAsync = ref.watch(hasProEntitlementProvider);

    return hasProAsync.when(
      data: (hasPro) {
        if (hasPro) {
          return child;
        }
        
        return fallback ?? _buildDefaultFallback(context);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error checking subscription: $error'),
      ),
    );
  }

  Widget _buildDefaultFallback(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Pro Feature',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature requires Altruency Purpose Pro',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (showPaywallButton) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RevenueCatPaywall(),
                      fullscreenDialog: true,
                    ),
                  );
                },
                child: const Text('Upgrade to Pro'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Badge widget to show Pro status
class ProBadge extends ConsumerWidget {
  final bool showFree;

  const ProBadge({
    super.key,
    this.showFree = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProAsync = ref.watch(hasProEntitlementProvider);

    return hasProAsync.when(
      data: (hasPro) {
        if (hasPro) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.amber, Colors.orange],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }
        
        if (showFree) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'FREE',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Extension to add entitlement checking to BuildContext
extension EntitlementCheckExtension on BuildContext {
  /// Show paywall
  Future<bool?> showPaywall() async {
    return await Navigator.of(this).push<bool>(
      MaterialPageRoute(
        builder: (context) => const RevenueCatPaywall(),
        fullscreenDialog: true,
      ),
    );
  }

  /// Show custom paywall
  Future<bool?> showCustomPaywall() async {
    return await Navigator.of(this).push<bool>(
      MaterialPageRoute(
        builder: (context) => const CustomPaywall(),
        fullscreenDialog: true,
      ),
    );
  }

  /// Show customer center
  Future<void> showCustomerCenter() async {
    await Navigator.of(this).push(
      MaterialPageRoute(
        builder: (context) => const RevenueCatCustomerCenter(),
        fullscreenDialog: true,
      ),
    );
  }
}
