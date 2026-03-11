import 'package:purchases_flutter/purchases_flutter.dart';

/// Represents the subscription status of a user
class SubscriptionStatus {
  final bool isPro;
  final bool isActive;
  final String? productIdentifier;
  final DateTime? expirationDate;
  final bool willRenew;
  final String? periodType; // monthly, yearly, lifetime
  final CustomerInfo customerInfo;

  const SubscriptionStatus({
    required this.isPro,
    required this.isActive,
    this.productIdentifier,
    this.expirationDate,
    required this.willRenew,
    this.periodType,
    required this.customerInfo,
  });

  /// Create SubscriptionStatus from CustomerInfo
  factory SubscriptionStatus.fromCustomerInfo(CustomerInfo customerInfo) {
    // Check if user has the "Altruency Purpose Pro" entitlement
    final entitlements = customerInfo.entitlements.active;
    final proEntitlement = entitlements['Altruency Purpose Pro'];
    final isPro = proEntitlement != null;

    String? productIdentifier;
    DateTime? expirationDate;
    bool willRenew = false;
    String? periodType;

    if (proEntitlement != null) {
      productIdentifier = proEntitlement.productIdentifier;
      
      // Parse expiration date
      final expirationDateString = proEntitlement.expirationDate;
      if (expirationDateString != null) {
        expirationDate = DateTime.tryParse(expirationDateString);
      }
      
      willRenew = proEntitlement.willRenew;
      
      // Determine period type from product identifier
      if (productIdentifier.toLowerCase().contains('monthly')) {
        periodType = 'monthly';
      } else if (productIdentifier.toLowerCase().contains('yearly') || 
                 productIdentifier.toLowerCase().contains('annual')) {
        periodType = 'yearly';
      } else if (productIdentifier.toLowerCase().contains('lifetime')) {
        periodType = 'lifetime';
      }
    }

    return SubscriptionStatus(
      isPro: isPro,
      isActive: isPro,
      productIdentifier: productIdentifier,
      expirationDate: expirationDate,
      willRenew: willRenew,
      periodType: periodType,
      customerInfo: customerInfo,
    );
  }

  /// Create a non-subscriber status
  factory SubscriptionStatus.free(CustomerInfo customerInfo) {
    return SubscriptionStatus(
      isPro: false,
      isActive: false,
      willRenew: false,
      customerInfo: customerInfo,
    );
  }

  /// Check if the subscription is expired
  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }

  /// Get a user-friendly description of the subscription
  String get description {
    if (!isPro) return 'Free';
    if (periodType == 'lifetime') return 'Lifetime Pro';
    if (isExpired) return 'Expired';
    if (periodType == 'monthly') return 'Monthly Pro';
    if (periodType == 'yearly') return 'Yearly Pro';
    return 'Pro';
  }

  @override
  String toString() {
    return 'SubscriptionStatus(isPro: $isPro, isActive: $isActive, '
        'productIdentifier: $productIdentifier, expirationDate: $expirationDate, '
        'willRenew: $willRenew, periodType: $periodType)';
  }
}
