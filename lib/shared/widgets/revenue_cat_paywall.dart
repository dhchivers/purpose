import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purpose/core/services/revenue_cat_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Widget to display RevenueCat paywall
class RevenueCatPaywall extends ConsumerStatefulWidget {
  final VoidCallback? onPurchaseCompleted;
  final VoidCallback? onRestoreCompleted;
  final VoidCallback? onDismiss;
  final String? displayCloseButton;

  const RevenueCatPaywall({
    super.key,
    this.onPurchaseCompleted,
    this.onRestoreCompleted,
    this.onDismiss,
    this.displayCloseButton,
  });

  @override
  ConsumerState<RevenueCatPaywall> createState() => _RevenueCatPaywallState();
}

class _RevenueCatPaywallState extends ConsumerState<RevenueCatPaywall> {
  bool _isLoading = false;

  /// Show the RevenueCat native paywall
  Future<void> _showNativePaywall() async {
    setState(() => _isLoading = true);

    try {
      final paywallResult = await RevenueCatUI.presentPaywall();

      if (!mounted) return;

      setState(() => _isLoading = false);

      // Handle the result
      if (paywallResult == PaywallResult.purchased ||
          paywallResult == PaywallResult.restored) {
        // Refresh subscription status
        ref.read(subscriptionNotifierProvider.notifier).refresh();
        
        if (paywallResult == PaywallResult.purchased) {
          widget.onPurchaseCompleted?.call();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Welcome to Altruency Purpose Pro!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (paywallResult == PaywallResult.restored) {
          widget.onRestoreCompleted?.call();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Purchases restored successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        
        // Close the dialog/page
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else {
        // User cancelled
        widget.onDismiss?.call();
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading paywall: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-show paywall when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNativePaywall();
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

    // Fallback UI in case native paywall doesn't show
    return const Scaffold(
      body: Center(
        child: Text('Loading paywall...'),
      ),
    );
  }
}

/// Custom paywall widget with manual package selection
/// Use this if you want more control over the UI
class CustomPaywall extends ConsumerStatefulWidget {
  final VoidCallback? onPurchaseCompleted;
  final VoidCallback? onRestoreCompleted;

  const CustomPaywall({
    super.key,
    this.onPurchaseCompleted,
    this.onRestoreCompleted,
  });

  @override
  ConsumerState<CustomPaywall> createState() => _CustomPaywallState();
}

class _CustomPaywallState extends ConsumerState<CustomPaywall> {
  Package? _selectedPackage;
  bool _isProcessing = false;

  /// Handle purchase
  Future<void> _handlePurchase() async {
    if (_selectedPackage == null) return;

    setState(() => _isProcessing = true);

    try {
      final success = await ref
          .read(subscriptionNotifierProvider.notifier)
          .purchasePackage(_selectedPackage!);

      if (!mounted) return;

      if (success) {
        widget.onPurchaseCompleted?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Welcome to Altruency Purpose Pro!'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Handle restore
  Future<void> _handleRestore() async {
    setState(() => _isProcessing = true);

    try {
      final success = await ref
          .read(subscriptionNotifierProvider.notifier)
          .restorePurchases();

      if (!mounted) return;

      if (success) {
        widget.onRestoreCompleted?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Purchases restored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No purchases found to restore'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offeringsAsync = ref.watch(offeringsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Upgrade to Pro'),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _handleRestore,
            child: const Text(
              'Restore',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: offeringsAsync.when(
        data: (offerings) {
          if (offerings?.current == null) {
            return const Center(
              child: Text('No subscription plans available'),
            );
          }

          final packages = offerings!.current!.availablePackages;
          
          // Sort packages by price (lowest to highest)
          packages.sort((a, b) => 
            a.storeProduct.price.compareTo(b.storeProduct.price));

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                color: AppTheme.primary.withValues(alpha: 0.1),
                child: Column(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 64,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Altruency Purpose Pro',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unlock all features and achieve your full potential',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),

              // Features list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Pro Features:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem('✨ AI-Powered Coaching'),
                    _buildFeatureItem('📊 Advanced Analytics'),
                    _buildFeatureItem('🎯 Unlimited Goals'),
                    _buildFeatureItem('🔄 Priority Support'),
                    _buildFeatureItem('🚀 Early Access to New Features'),
                    const SizedBox(height: 24),
                    
                    // Packages
                    ...packages.map((package) => _buildPackageCard(package)),
                  ],
                ),
              ),

              // Purchase button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: _selectedPackage == null || _isProcessing
                        ? null
                        : _handlePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _selectedPackage == null
                                ? 'Select a plan'
                                : 'Subscribe Now',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
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
              Text('Error loading plans: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(offeringsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Package package) {
    final isSelected = _selectedPackage?.identifier == package.identifier;
    final product = package.storeProduct;
    
    // Determine if this is the best value
    final isBestValue = package.packageType == PackageType.annual;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPackage = package;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.white,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Radio button
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? AppTheme.primary : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  
                  // Package info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.storeProduct.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.primary : Colors.black,
                          ),
                        ),
                        if (product.description.isNotEmpty)
                          Text(
                            product.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        product.priceString,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.primary : Colors.black,
                        ),
                      ),
                      if (package.packageType != PackageType.lifetime)
                        Text(
                          _getPricePeriod(package.packageType),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Best value badge
            if (isBestValue)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getPricePeriod(PackageType type) {
    switch (type) {
      case PackageType.monthly:
        return 'per month';
      case PackageType.annual:
        return 'per year';
      case PackageType.weekly:
        return 'per week';
      case PackageType.twoMonth:
        return 'per 2 months';
      case PackageType.threeMonth:
        return 'per 3 months';
      case PackageType.sixMonth:
        return 'per 6 months';
      default:
        return '';
    }
  }
}
