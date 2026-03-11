import 'dart:async';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purpose/core/models/subscription_status.dart';

/// Service for managing RevenueCat subscriptions and entitlements
class RevenueCatService {
  static const String _apiKey = 'test_aySEHGVpdBLBzchVKqBMaYlVasR';
  static const String _entitlementId = 'Altruency Purpose Pro';
  
  // Product identifiers
  static const String monthlyProductId = 'monthly';
  static const String yearlyProductId = 'yearly';
  static const String lifetimeProductId = 'lifetime';

  bool _isConfigured = false;
  CustomerInfo? _cachedCustomerInfo;
  
  // Stream controller for customer info updates
  final _customerInfoController = StreamController<CustomerInfo>.broadcast();
  Stream<CustomerInfo> get customerInfoStream => _customerInfoController.stream;

  /// Initialize and configure RevenueCat SDK
  Future<void> configure({String? userId}) async {
    if (_isConfigured) {
      print('RevenueCat already configured');
      return;
    }

    try {
      // Enable debug logs for development
      await Purchases.setLogLevel(LogLevel.debug);

      // Configure the SDK
      final configuration = PurchasesConfiguration(_apiKey);
      
      if (userId != null) {
        configuration.appUserID = userId;
      }

      await Purchases.configure(configuration);

      // Set up customer info listener
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _cachedCustomerInfo = customerInfo;
        _customerInfoController.add(customerInfo);
        print('Customer info updated: ${customerInfo.entitlements.active.keys}');
      });

      _isConfigured = true;
      print('RevenueCat configured successfully');

      // Fetch initial customer info
      await getCustomerInfo();
    } catch (e) {
      print('Error configuring RevenueCat: $e');
      rethrow;
    }
  }

  /// Get current customer info
  Future<CustomerInfo> getCustomerInfo() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _cachedCustomerInfo = customerInfo;
      return customerInfo;
    } catch (e) {
      print('Error getting customer info: $e');
      rethrow;
    }
  }

  /// Get current subscription status
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    try {
      final customerInfo = await getCustomerInfo();
      return SubscriptionStatus.fromCustomerInfo(customerInfo);
    } catch (e) {
      print('Error getting subscription status: $e');
      rethrow;
    }
  }

  /// Check if user has Pro entitlement
  Future<bool> hasProEntitlement() async {
    try {
      final customerInfo = await getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(_entitlementId);
    } catch (e) {
      print('Error checking pro entitlement: $e');
      return false;
    }
  }

  /// Get available offerings
  Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current == null) {
        print('No current offering available');
        return null;
      }

      print('Current offering: ${offerings.current?.identifier}');
      print('Available packages: ${offerings.current?.availablePackages.length}');
      
      return offerings;
    } catch (e) {
      print('Error getting offerings: $e');
      return null;
    }
  }

  /// Purchase a package
  Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      print('Attempting to purchase: ${package.identifier}');
      
      final purchaserInfo = await Purchases.purchasePackage(package);
      _cachedCustomerInfo = purchaserInfo.customerInfo;
      
      print('Purchase successful!');
      print('Active entitlements: ${purchaserInfo.customerInfo.entitlements.active.keys}');
      
      return purchaserInfo.customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        print('User cancelled purchase');
        return null;
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        print('User not allowed to purchase');
        throw Exception('Purchases are not allowed on this device');
      } else if (errorCode == PurchasesErrorCode.paymentPendingError) {
        print('Payment is pending');
        throw Exception('Payment is pending. Please check back later.');
      } else {
        print('Purchase error: ${e.message}');
        throw Exception('Purchase failed: ${e.message}');
      }
    } catch (e) {
      print('Unexpected purchase error: $e');
      rethrow;
    }
  }

  /// Purchase a product by identifier
  Future<CustomerInfo?> purchaseProduct(String productId) async {
    try {
      final offerings = await getOfferings();
      
      if (offerings?.current == null) {
        throw Exception('No offerings available');
      }

      // Find the package with the matching product identifier
      final package = offerings!.current!.availablePackages.firstWhere(
        (pkg) => pkg.storeProduct.identifier == productId,
        orElse: () => throw Exception('Product $productId not found'),
      );

      return await purchasePackage(package);
    } catch (e) {
      print('Error purchasing product: $e');
      rethrow;
    }
  }

  /// Restore purchases
  Future<CustomerInfo> restorePurchases() async {
    try {
      print('Restoring purchases...');
      final customerInfo = await Purchases.restorePurchases();
      _cachedCustomerInfo = customerInfo;
      
      print('Purchases restored');
      print('Active entitlements: ${customerInfo.entitlements.active.keys}');
      
      return customerInfo;
    } catch (e) {
      print('Error restoring purchases: $e');
      rethrow;
    }
  }

  /// Log in with user ID
  Future<CustomerInfo> logIn(String userId) async {
    try {
      print('Logging in user: $userId');
      final result = await Purchases.logIn(userId);
      _cachedCustomerInfo = result.customerInfo;
      
      print('User logged in successfully');
      print('Active entitlements: ${result.customerInfo.entitlements.active.keys}');
      
      return result.customerInfo;
    } catch (e) {
      print('Error logging in: $e');
      rethrow;
    }
  }

  /// Log out current user
  Future<CustomerInfo> logOut() async {
    try {
      print('Logging out user');
      final customerInfo = await Purchases.logOut();
      _cachedCustomerInfo = customerInfo;
      
      print('User logged out successfully');
      return customerInfo;
    } catch (e) {
      print('Error logging out: $e');
      rethrow;
    }
  }

  /// Set user attributes
  Future<void> setAttributes(Map<String, String> attributes) async {
    try {
      await Purchases.setAttributes(attributes);
      print('User attributes set: $attributes');
    } catch (e) {
      print('Error setting attributes: $e');
    }
  }

  /// Set email attribute
  Future<void> setEmail(String email) async {
    try {
      await Purchases.setEmail(email);
      print('Email set: $email');
    } catch (e) {
      print('Error setting email: $e');
    }
  }

  /// Set display name attribute
  Future<void> setDisplayName(String displayName) async {
    try {
      await Purchases.setDisplayName(displayName);
      print('Display name set: $displayName');
    } catch (e) {
      print('Error setting display name: $e');
    }
  }

  /// Get cached customer info (no network call)
  CustomerInfo? get cachedCustomerInfo => _cachedCustomerInfo;

  /// Check if user has Pro entitlement from cached data
  bool get hasCachedProEntitlement {
    return _cachedCustomerInfo?.entitlements.active.containsKey(_entitlementId) ?? false;
  }

  /// Dispose resources
  void dispose() {
    _customerInfoController.close();
  }
}
