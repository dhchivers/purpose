# RevenueCat Integration Guide

## Overview

This document describes the complete RevenueCat integration for Altruency AI / Purpose app. The integration includes subscription management, entitlement checking, paywall UI, and customer center.

## Configuration

### API Key
- **Test Key**: `test_aySEHGVpdBLBzchVKqBMaYlVasR`
- Configured in: `lib/core/services/revenue_cat_service.dart`

### Entitlement
- **Entitlement ID**: `Altruency Purpose Pro`
- This is the entitlement name that gates Pro features

### Products
Configure these products in the RevenueCat dashboard:
- **Monthly**: `monthly`
- **Yearly**: `yearly`
- **Lifetime**: `lifetime`

## Project Structure

```
lib/
├── core/
│   ├── models/
│   │   └── subscription_status.dart      # Subscription status model
│   ├── services/
│   │   ├── revenue_cat_service.dart     # Core RevenueCat service
│   │   └── revenue_cat_provider.dart    # Riverpod providers
│   └── utils/
│       └── entitlement_utils.dart       # Entitlement checking utilities
└── shared/
    └── widgets/
        ├── revenue_cat_paywall.dart            # Paywall UI
        └── revenue_cat_customer_center.dart    # Customer center UI
```

## Initialization

RevenueCat is automatically initialized in `main.dart` when the app starts:

```dart
// Initialize RevenueCat
try {
  print('=== RevenueCat Initialization Start ===');
  final revenueCatService = RevenueCatService();
  await revenueCatService.configure();
  print('✅ RevenueCat initialized successfully');
} catch (e) {
  print('❌ RevenueCat initialization error: $e');
}
```

### User Syncing

The integration automatically syncs users with RevenueCat when they:
- Sign up: `auth_provider.dart` → `signUp()`
- Sign in: `auth_provider.dart` → `signIn()`
- Sign out: `auth_provider.dart` → `signOut()`

This ensures that purchases are properly attributed to the correct user across devices.

## Usage Examples

### 1. Check if User Has Pro Entitlement

#### Using FutureProvider (Async)
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProAsync = ref.watch(hasProEntitlementProvider);
    
    return hasProAsync.when(
      data: (hasPro) => Text(hasPro ? 'Pro User' : 'Free User'),
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
```

#### Using Cached Provider (Sync)
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPro = ref.watch(cachedHasProEntitlementProvider);
    return Text(hasPro ? 'Pro User' : 'Free User');
  }
}
```

#### Using Service Directly
```dart
class MyWidget extends ConsumerStatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends ConsumerState<MyWidget> {
  Future<void> checkPro() async {
    final revenueCatService = ref.read(revenueCatServiceProvider);
    final hasPro = await revenueCatService.hasProEntitlement();
    print('Has Pro: $hasPro');
  }
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: checkPro,
      child: Text('Check Pro Status'),
    );
  }
}
```

### 2. Show Paywall

#### Using Context Extension
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        final purchased = await context.showPaywall();
        if (purchased == true) {
          print('User subscribed!');
        }
      },
      child: Text('Upgrade to Pro'),
    );
  }
}
```

#### Using Navigator
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const RevenueCatPaywall(),
    fullscreenDialog: true,
  ),
);
```

#### Using Custom Paywall (More Control)
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const CustomPaywall(),
    fullscreenDialog: true,
  ),
);
```

### 3. Gate Features with Pro Check

#### Using ProGate Widget
```dart
class MyFeaturePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProGate(
      child: MyProFeatureContent(),
      // Optional custom fallback
      fallback: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('This feature requires Pro'),
            ElevatedButton(
              onPressed: () => context.showPaywall(),
              child: Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### Using EntitlementCheckMixin
```dart
class MyFeaturePage extends ConsumerStatefulWidget {
  @override
  _MyFeaturePageState createState() => _MyFeaturePageState();
}

class _MyFeaturePageState extends ConsumerState<MyFeaturePage> 
    with EntitlementCheckMixin {
  
  Future<void> useProFeature() async {
    final hasAccess = await requireProEntitlement(
      message: 'This feature requires Altruency Purpose Pro',
      showPaywall: true,
    );
    
    if (hasAccess) {
      // User has Pro access, proceed with feature
      print('Accessing Pro feature');
    } else {
      // User cancelled or doesn't have Pro
      print('Pro access denied');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: useProFeature,
      child: Text('Use Pro Feature'),
    );
  }
}
```

### 4. Show Customer Center

#### Using Context Extension
```dart
ElevatedButton(
  onPressed: () => context.showCustomerCenter(),
  child: Text('Manage Subscription'),
);
```

#### Using Navigator
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const RevenueCatCustomerCenter(),
    fullscreenDialog: true,
  ),
);
```

#### Using Custom Subscription Management
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const CustomSubscriptionManagement(),
  ),
);
```

### 5. Display Pro Badge

```dart
class UserHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Text('John Doe'),
        SizedBox(width: 8),
        ProBadge(), // Shows "PRO" badge if user has Pro
      ],
    );
  }
}
```

### 6. Get Subscription Status

```dart
class SubscriptionInfo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(subscriptionStatusProvider);
    
    return statusAsync.when(
      data: (status) {
        return Column(
          children: [
            Text('Status: ${status.description}'),
            if (status.isPro) ...[
              Text('Plan: ${status.periodType}'),
              if (status.expirationDate != null)
                Text('Expires: ${status.expirationDate}'),
              Text('Auto-renew: ${status.willRenew}'),
            ],
          ],
        );
      },
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
```

### 7. Purchase a Specific Product

```dart
class BuyButton extends ConsumerStatefulWidget {
  final String productId; // 'monthly', 'yearly', or 'lifetime'
  
  const BuyButton({required this.productId});
  
  @override
  _BuyButtonState createState() => _BuyButtonState();
}

class _BuyButtonState extends ConsumerState<BuyButton> {
  bool _isLoading = false;
  
  Future<void> purchase() async {
    setState(() => _isLoading = true);
    
    try {
      final revenueCatService = ref.read(revenueCatServiceProvider);
      final customerInfo = await revenueCatService.purchaseProduct(widget.productId);
      
      if (customerInfo != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase successful!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : purchase,
      child: _isLoading 
          ? CircularProgressIndicator() 
          : Text('Buy ${widget.productId}'),
    );
  }
}
```

### 8. Restore Purchases

```dart
class RestoreButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () async {
        try {
          final success = await ref
              .read(subscriptionNotifierProvider.notifier)
              .restorePurchases();
          
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Purchases restored!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No purchases found'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Text('Restore Purchases'),
    );
  }
}
```

### 9. Listen to Subscription Changes

```dart
class SubscriptionListener extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<CustomerInfo>>(
      customerInfoStreamProvider,
      (previous, next) {
        next.whenData((customerInfo) {
          final hasPro = customerInfo.entitlements.active
              .containsKey('Altruency Purpose Pro');
          
          if (hasPro) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('You now have Pro access!')),
            );
          }
        });
      },
    );
    
    return MyAppContent();
  }
}
```

## Providers Reference

### Service Provider
```dart
final revenueCatServiceProvider = Provider<RevenueCatService>
```
Provides the RevenueCat service instance.

### Customer Info Stream
```dart
final customerInfoStreamProvider = StreamProvider<CustomerInfo>
```
Real-time stream of customer info updates.

### Subscription Status
```dart
final subscriptionStatusProvider = FutureProvider<SubscriptionStatus>
```
One-time fetch of subscription status.

### Pro Entitlement Check
```dart
final hasProEntitlementProvider = FutureProvider<bool>
```
One-time check if user has Pro entitlement.

### Offerings
```dart
final offeringsProvider = FutureProvider<Offerings?>
```
Available subscription offerings from RevenueCat.

### Cached Subscription Status
```dart
final cachedSubscriptionStatusProvider = Provider<SubscriptionStatus?>
```
Synchronous access to cached subscription status.

### Cached Pro Check
```dart
final cachedHasProEntitlementProvider = Provider<bool>
```
Synchronous access to cached Pro entitlement status.

### Subscription State Notifier
```dart
final subscriptionNotifierProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>
```
Manages subscription state and provides methods for purchases and restore.

## Error Handling

### Purchase Errors
```dart
try {
  await revenueCatService.purchasePackage(package);
} on PlatformException catch (e) {
  final errorCode = PurchasesErrorHelper.getErrorCode(e);
  
  if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
    // User cancelled
  } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
    // Purchases not allowed
  } else if (errorCode == PurchasesErrorCode.paymentPendingError) {
    // Payment pending
  }
}
```

### Handling Network Errors
The service includes automatic error handling and logging. Check console for detailed error messages.

## Best Practices

### 1. Cache First, Fetch Later
Use cached providers for immediate UI updates, then fetch fresh data:
```dart
// Show cached status immediately
final cachedHasPro = ref.watch(cachedHasProEntitlementProvider);

// Fetch fresh status
ref.watch(hasProEntitlementProvider);
```

### 2. Refresh After Actions
Refresh subscription status after purchases or restores:
```dart
await revenueCatService.purchasePackage(package);
ref.invalidate(subscriptionStatusProvider);
```

### 3. Handle User Sign In/Out
The integration automatically handles this in `auth_provider.dart`, but if you manually call RevenueCat methods:
```dart
// On sign in
await revenueCatService.logIn(userId);
await revenueCatService.setEmail(email);
await revenueCatService.setDisplayName(name);

// On sign out
await revenueCatService.logOut();
```

### 4. Test with Test Keys
Use the test API key during development:
- Purchases won't charge real money
- Can test all flows without real payments
- Switch to production key for release

### 5. Monitor Customer Info Stream
Use the stream provider to react to subscription changes in real-time:
```dart
ref.listen(customerInfoStreamProvider, (previous, next) {
  // Handle subscription changes
});
```

## Testing

### Local Testing
1. Run the app with test API key
2. Sign in with a test user
3. Trigger paywall with `context.showPaywall()`
4. Purchase a subscription (no charge with test key)
5. Check entitlement with `hasProEntitlement()`
6. Test customer center with `context.showCustomerCenter()`
7. Test restore with restore button

### RevenueCat Dashboard
1. Check customer info at: https://app.revenuecat.com/customers/
2. View transactions in the dashboard
3. Monitor events and webhooks
4. Test different scenarios

## Troubleshooting

### Issue: Paywall not showing
- Check that offerings are configured in RevenueCat dashboard
- Verify products are set up in App Store Connect / Google Play Console
- Check console logs for initialization errors

### Issue: Purchases not attributed to user
- Ensure `logIn()` is called after authentication
- Check that Firebase UID matches RevenueCat app user ID
- Verify user attributes are set (email, display name)

### Issue: Entitlements not updating
- Check that entitlement ID matches in dashboard: "Altruency Purpose Pro"
- Verify products are attached to entitlement
- Wait a few seconds for real-time updates
- Call `getCustomerInfo()` to force refresh

### Issue: Restore not working
- Ensure user is signed in to same Apple ID / Google account
- Previous purchases must be in same store (iOS/Android)
- Check RevenueCat dashboard for customer's purchase history

## Next Steps

1. **Configure Products**: Set up monthly, yearly, and lifetime products in RevenueCat dashboard
2. **Design Paywalls**: Customize `CustomPaywall` widget to match your app's design
3. **Set Up Offerings**: Create offerings in RevenueCat dashboard and attach products
4. **Test Flows**: Test purchase, restore, and subscription management flows
5. **Add Analytics**: Integrate RevenueCat events with your analytics platform
6. **Production Key**: Switch to production API key before releasing
7. **Store Setup**: Configure In-App Purchases in App Store Connect and Google Play Console

## Additional Resources

- [RevenueCat Documentation](https://www.revenuecat.com/docs)
- [Flutter SDK Reference](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- [Paywalls Guide](https://www.revenuecat.com/docs/tools/paywalls)
- [Customer Center Guide](https://www.revenuecat.com/docs/tools/customer-center)
- [Entitlements Guide](https://www.revenuecat.com/docs/entitlements)
