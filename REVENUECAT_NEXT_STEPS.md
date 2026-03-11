# RevenueCat Integration - Next Steps Guide

This guide outlines the actionable steps needed to complete your RevenueCat integration for Altruency AI / Purpose app.

## ✅ Already Completed

- [x] RevenueCat SDK packages installed (`purchases_flutter`, `purchases_ui_flutter`)
- [x] Service layer created with API key configured
- [x] Riverpod providers set up for state management
- [x] Paywall UI components created (native + custom)
- [x] Customer center UI implemented
- [x] Entitlement checking utilities built
- [x] User syncing integrated with Firebase Authentication
- [x] RevenueCat initialization added to app startup
- [x] Example page created with all features demonstrated

## 🎯 Step 1: Configure RevenueCat Dashboard

### 1.1 Create Products in RevenueCat

1. Log in to [RevenueCat Dashboard](https://app.revenuecat.com/)
2. Navigate to your project
3. Go to **Products** section
4. Create three products:
   - **Monthly Subscription**
     - Identifier: `monthly`
     - Type: Subscription
   - **Yearly Subscription**
     - Identifier: `yearly`
     - Type: Subscription
   - **Lifetime Purchase**
     - Identifier: `lifetime`
     - Type: Non-subscription

### 1.2 Create Entitlement

1. Navigate to **Entitlements** section
2. Create new entitlement:
   - **Name**: `Altruency Purpose Pro`
   - **Identifier**: `Altruency Purpose Pro`
3. Attach all three products (monthly, yearly, lifetime) to this entitlement

### 1.3 Create Offering

1. Navigate to **Offerings** section
2. Create a new offering (or use the default offering)
3. Add packages:
   - Add `monthly` product
   - Add `yearly` product (mark as "Best Value")
   - Add `lifetime` product
4. Make this offering current

### 1.4 Configure Paywall (Optional)

If using the native RevenueCat paywall:
1. Navigate to **Paywalls** in dashboard
2. Create a new paywall design
3. Customize:
   - Colors to match your app theme (primary: `#C32F38`)
   - Feature list
   - Call-to-action text
   - Layout and presentation
4. Associate paywall with your offering

## 🍎 Step 2: Set Up iOS In-App Purchases

### 2.1 App Store Connect Configuration

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select your app (create it if needed)
3. Navigate to **Features** → **In-App Purchases**
4. Create three in-app purchases matching your RevenueCat products:

   **Monthly Subscription:**
   - Type: Auto-Renewable Subscription
   - Product ID: `monthly` (must match RevenueCat)
   - Subscription Group: Create new group "Altruency Pro"
   - Duration: 1 Month
   - Price: Set your price tier

   **Yearly Subscription:**
   - Type: Auto-Renewable Subscription
   - Product ID: `yearly` (must match RevenueCat)
   - Subscription Group: Same as above
   - Duration: 1 Year
   - Price: Set your price tier

   **Lifetime Purchase:**
   - Type: Non-Consumable
   - Product ID: `lifetime` (must match RevenueCat)
   - Price: Set your price tier

5. For each product, provide:
   - Display name
   - Description
   - Screenshots (if required)
   - Review information

### 2.2 Link Products to RevenueCat

1. Return to RevenueCat Dashboard
2. Navigate to your iOS app configuration
3. For each product, add the **App Store Product ID**
4. Save configuration

### 2.3 Testing on iOS

1. Create sandbox test users in App Store Connect
2. Sign out of App Store on test device
3. Run app and trigger purchase
4. Sign in with sandbox account when prompted
5. Complete test purchase (no charge)

## 🤖 Step 3: Set Up Android In-App Purchases

### 3.1 Google Play Console Configuration

1. Go to [Google Play Console](https://play.google.com/console/)
2. Select your app (create it if needed)
3. Navigate to **Monetize** → **In-app products**
4. Create three in-app products:

   **Monthly Subscription:**
   - Product ID: `monthly` (must match RevenueCat)
   - Type: Auto-renewing subscription
   - Billing period: 1 month
   - Base plans: Configure pricing

   **Yearly Subscription:**
   - Product ID: `yearly` (must match RevenueCat)
   - Type: Auto-renewing subscription
   - Billing period: 1 year
   - Base plans: Configure pricing

   **Lifetime Purchase:**
   - Product ID: `lifetime` (must match RevenueCat)
   - Type: One-time product
   - Price: Set your price

5. For each product, provide:
   - Title
   - Description
   - Activate the products

### 3.2 Link Products to RevenueCat

1. Return to RevenueCat Dashboard
2. Navigate to your Android app configuration
3. For each product, add the **Google Play Product ID**
4. Save configuration

### 3.3 Testing on Android

1. Add test users in Google Play Console (License Testing)
2. Run app and trigger purchase
3. Complete test purchase (no charge for test users)

## 🌐 Step 4: Configure for Web (Optional)

RevenueCat currently has limited web support. For web subscriptions:

**Option 1:** Use Stripe directly
- Configure Stripe integration separately
- Use RevenueCat for mobile only

**Option 2:** Redirect to mobile
- Show message directing users to download mobile app for subscription

**Option 3:** Custom web implementation
- Build custom paywall for web
- Use RevenueCat REST API for backend

## 💻 Step 5: Integrate into Your App

### 5.1 Add Paywall Triggers

Identify where users should see the paywall:
- Onboarding completion
- Feature discovery
- Settings page "Upgrade" button
- In-context when accessing Pro features

Example placements:

```dart
// In your home page or dashboard
IconButton(
  icon: Icon(Icons.workspace_premium),
  onPressed: () => context.showPaywall(),
)

// In settings page
ListTile(
  leading: Icon(Icons.star),
  title: Text('Upgrade to Pro'),
  trailing: ProBadge(),
  onTap: () => context.showPaywall(),
)

// Gate a pro feature
ProGate(
  child: AdvancedAnalyticsPage(),
)
```

### 5.2 Add Pro Feature Gates

Protect premium features with entitlement checks:

```dart
// Using ProGate widget
ProGate(
  child: MyProFeature(),
)

// Using EntitlementCheckMixin
class MyFeature extends ConsumerStatefulWidget {
  @override
  _MyFeatureState createState() => _MyFeatureState();
}

class _MyFeatureState extends ConsumerState<MyFeature> 
    with EntitlementCheckMixin {
  
  Future<void> useFeature() async {
    if (!await requireProEntitlement(
      message: 'This feature requires Pro',
      showPaywall: true,
    )) return;
    
    // Feature code here
  }
}
```

### 5.3 Add Subscription Management

Add to your settings or profile page:

```dart
ListTile(
  leading: Icon(Icons.card_membership),
  title: Text('Manage Subscription'),
  subtitle: Text('View and manage your subscription'),
  onTap: () => context.showCustomerCenter(),
)

// Or use custom page
ListTile(
  leading: Icon(Icons.card_membership),
  title: Text('Subscription'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomSubscriptionManagement(),
      ),
    );
  },
)
```

### 5.4 Update UI with Pro Status

Show Pro status throughout your app:

```dart
// In app bar
AppBar(
  title: Text('Altruency Purpose'),
  actions: [
    ProBadge(),
  ],
)

// In user profile
Row(
  children: [
    Text(userName),
    SizedBox(width: 8),
    ProBadge(showFree: true),
  ],
)

// Conditional features
final hasPro = ref.watch(cachedHasProEntitlementProvider);
if (hasPro) {
  // Show pro features in UI
}
```

## 🧪 Step 6: Test Everything

### 6.1 Test Flows

✅ **Purchase Flow:**
- [ ] Open paywall
- [ ] Select product
- [ ] Complete purchase
- [ ] Verify entitlement granted
- [ ] Check Pro features unlock

✅ **Restore Flow:**
- [ ] Make purchase on device A
- [ ] Delete and reinstall app
- [ ] Tap "Restore Purchases"
- [ ] Verify entitlement restored

✅ **Cross-Device Sync:**
- [ ] Purchase on device A
- [ ] Sign in on device B with same account
- [ ] Verify entitlement synced

✅ **Subscription Management:**
- [ ] Open customer center
- [ ] View subscription details
- [ ] Cancel subscription
- [ ] Resubscribe

✅ **Expiration:**
- [ ] Cancel subscription
- [ ] Wait for expiration (or use sandbox to fast-forward)
- [ ] Verify entitlement removed
- [ ] Check Pro features lock

### 6.2 Test Edge Cases

- [ ] No internet connection
- [ ] Payment failure
- [ ] User cancels purchase
- [ ] Invalid receipt
- [ ] Refunded purchase

## 🚀 Step 7: Prepare for Production

### 7.1 Switch to Production API Key

1. Get production API key from RevenueCat Dashboard
2. Update in `lib/core/services/revenue_cat_service.dart`:

```dart
// Replace test key
static const String _apiKey = 'prod_YOUR_PRODUCTION_KEY_HERE';
```

3. Remove debug logging:

```dart
// In configure() method, change:
await Purchases.setLogLevel(LogLevel.error); // or LogLevel.warn
```

### 7.2 Final Checklist

- [ ] Production API key configured
- [ ] All products created in stores
- [ ] Products linked in RevenueCat
- [ ] Entitlements configured correctly
- [ ] Offerings are current
- [ ] Paywall tested on real devices
- [ ] Restore purchases works
- [ ] Customer center functional
- [ ] All Pro features properly gated
- [ ] Analytics/events tracked (optional)
- [ ] Privacy policy updated to mention subscriptions
- [ ] Terms of service include subscription terms
- [ ] App Store/Play Store listings mention subscriptions

### 7.3 Store Submission

**iOS:**
- Submit in-app purchases for review
- Submit app update with subscription features
- Include screenshots of paywall and Pro features

**Android:**
- Activate in-app products
- Submit app update with subscription features
- Include screenshots of paywall and Pro features

## 📊 Step 8: Monitor and Optimize

### 8.1 RevenueCat Dashboard Monitoring

Monitor daily:
- New subscribers
- Churn rate
- Trial conversions
- Revenue metrics

### 8.2 Optimize Paywall

Track and improve:
- Paywall view rate
- Conversion rate
- Package selection distribution
- Time to purchase

### 8.3 A/B Testing

Consider testing:
- Different pricing
- Paywall designs
- Feature descriptions
- Call-to-action text
- Package positioning

## 🆘 Troubleshooting

### Common Issues

**"No products found"**
- Verify products are created in App Store Connect/Play Console
- Check product IDs match exactly in RevenueCat
- Wait 2-4 hours after creating products
- Clear app data and reinstall

**"Entitlement not granted after purchase"**
- Verify entitlement is configured in RevenueCat
- Check products are attached to entitlement
- Check RevenueCat dashboard for transaction logs
- Verify user is logged in (`logIn()` called)

**"Restore not finding purchases"**
- User must use same Apple ID/Google account
- Purchases must be on same platform (iOS/Android)
- Check RevenueCat customer lookup in dashboard

**"Paywall not displaying"**
- Check offerings are configured and current
- Verify packages exist in current offering
- Check console logs for errors
- Ensure RevenueCat is initialized before showing paywall

## 📚 Additional Resources

- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [Flutter SDK Guide](https://docs.revenuecat.com/docs/flutter)
- [Subscription Best Practices](https://docs.revenuecat.com/docs/subscription-guidance)
- [Testing Guide](https://docs.revenuecat.com/docs/test-and-launch)
- [Migration Guides](https://docs.revenuecat.com/docs/migrating-to-revenuecat)

## 🎯 Quick Reference Commands

```bash
# Run app with hot reload
flutter run -d chrome --web-port 8080

# Test on iOS simulator
flutter run -d ios

# Test on Android emulator
flutter run -d android

# Build for release
flutter build ios --release
flutter build appbundle --release

# Check for errors
flutter analyze

# Update dependencies
flutter pub upgrade
```

## 📝 Notes

- Keep test API key during development
- Test thoroughly before switching to production
- Document any custom modifications
- Keep RevenueCat SDK updated
- Review RevenueCat changelog for updates

---

**Current Status:** ✅ Code integration complete, waiting for store setup

**Next Action:** Configure products in RevenueCat Dashboard (Step 1)

**Estimated Time to Launch:** 2-4 days (depending on store review)
