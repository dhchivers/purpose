import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purpose/core/services/revenue_cat_service.dart';
import 'package:purpose/core/models/subscription_status.dart';

/// Provider for RevenueCat service
final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService();
});

/// Provider for customer info stream
final customerInfoStreamProvider = StreamProvider<CustomerInfo>((ref) {
  final revenueCatService = ref.watch(revenueCatServiceProvider);
  return revenueCatService.customerInfoStream;
});

/// Provider for subscription status
final subscriptionStatusProvider = FutureProvider<SubscriptionStatus>((ref) async {
  final revenueCatService = ref.watch(revenueCatServiceProvider);
  return await revenueCatService.getSubscriptionStatus();
});

/// Provider for checking if user has Pro entitlement
final hasProEntitlementProvider = FutureProvider<bool>((ref) async {
  final revenueCatService = ref.watch(revenueCatServiceProvider);
  return await revenueCatService.hasProEntitlement();
});

/// Provider for available offerings
final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  final revenueCatService = ref.watch(revenueCatServiceProvider);
  return await revenueCatService.getOfferings();
});

/// Provider for cached subscription status (synchronous)
final cachedSubscriptionStatusProvider = Provider<SubscriptionStatus?>((ref) {
  final revenueCatService = ref.watch(revenueCatServiceProvider);
  final cachedInfo = revenueCatService.cachedCustomerInfo;
  
  if (cachedInfo == null) return null;
  return SubscriptionStatus.fromCustomerInfo(cachedInfo);
});

/// Provider for checking Pro entitlement from cache (synchronous)
final cachedHasProEntitlementProvider = Provider<bool>((ref) {
  final revenueCatService = ref.watch(revenueCatServiceProvider);
  return revenueCatService.hasCachedProEntitlement;
});

/// State notifier for managing subscription state
class SubscriptionState {
  final SubscriptionStatus? status;
  final bool isLoading;
  final String? error;

  const SubscriptionState({
    this.status,
    this.isLoading = false,
    this.error,
  });

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final RevenueCatService _revenueCatService;

  SubscriptionNotifier(this._revenueCatService) : super(const SubscriptionState());

  /// Refresh subscription status
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final status = await _revenueCatService.getSubscriptionStatus();
      state = state.copyWith(status: status, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load subscription: $e',
      );
    }
  }

  /// Purchase a package
  Future<bool> purchasePackage(Package package) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final customerInfo = await _revenueCatService.purchasePackage(package);
      
      if (customerInfo != null) {
        final status = SubscriptionStatus.fromCustomerInfo(customerInfo);
        state = state.copyWith(status: status, isLoading: false);
        return true;
      } else {
        // User cancelled
        state = state.copyWith(isLoading: false);
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Purchase failed: $e',
      );
      return false;
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final customerInfo = await _revenueCatService.restorePurchases();
      final status = SubscriptionStatus.fromCustomerInfo(customerInfo);
      state = state.copyWith(status: status, isLoading: false);
      return status.isPro;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to restore purchases: $e',
      );
      return false;
    }
  }
}

/// State notifier provider for subscription management
final subscriptionNotifierProvider = 
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final revenueCatService = ref.watch(revenueCatServiceProvider);
  return SubscriptionNotifier(revenueCatService);
});
