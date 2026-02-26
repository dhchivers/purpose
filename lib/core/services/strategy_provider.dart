/// Strategy Providers
/// 
/// This file contains Riverpod providers for the multi-strategy architecture.
/// 
/// ## Provider Categories:
/// 
/// ### 1. Strategy Management Providers
/// - strategyProvider: Get a single strategy by ID (Future)
/// - strategyStreamProvider: Stream a single strategy with real-time updates
/// - userStrategiesProvider: Get all strategies for a user (Future)
/// - userStrategiesStreamProvider: Stream all strategies for a user
/// - defaultStrategyProvider: Get user's default strategy (Future)
/// - defaultStrategyStreamProvider: Stream user's default strategy
/// - currentUserDefaultStrategyProvider: Convenience stream for current user's default strategy
/// - currentUserStrategiesProvider: Convenience stream for current user's all strategies
/// 
/// ### 2. Strategy-Scoped Data Providers
/// These providers fetch data scoped to a specific strategy:
/// - strategyValuesProvider: Get values for a strategy
/// - strategyVisionProvider: Get vision for a strategy (Future)
/// - strategyVisionStreamProvider: Stream vision for a strategy
/// - strategyMissionMapProvider: Get mission map for a strategy (Future)
/// - strategyMissionMapStreamProvider: Stream mission map for a strategy
/// 
/// ### 3. Backward Compatibility Providers (Deprecated)
/// These providers use userId instead of strategyId for migration compatibility:
/// - userValuesProviderDeprecated
/// - userVisionProviderDeprecated
/// - userVisionStreamProviderDeprecated
/// - userMissionMapProviderDeprecated
/// - userMissionMapStreamProviderDeprecated
/// 
/// ## Usage Examples:
/// 
/// ```dart
/// // Get current user's default strategy
/// final defaultStrategy = ref.watch(currentUserDefaultStrategyProvider).value;
/// 
/// // Get values for a specific strategy
/// if (defaultStrategy != null) {
///   final values = ref.watch(strategyValuesProvider(defaultStrategy.id));
/// }
/// 
/// // Stream all strategies for current user
/// final strategies = ref.watch(currentUserStrategiesProvider).value ?? [];
/// ```
/// 
/// ## Migration Notes:
/// - During Phase 4 (UI updates), UI components will be updated to use strategy-scoped providers
/// - During Phase 5 (data migration), deprecated providers will help transition existing data
/// - After Phase 6, deprecated providers can be removed
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/models/user_strategy.dart';
import 'package:purpose/core/models/user_value.dart';
import 'package:purpose/core/models/user_vision.dart';
import 'package:purpose/core/models/user_mission_map.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';

// ========== STRATEGY PROVIDERS ==========

/// Provider for a single strategy by ID (Future)
final strategyProvider = FutureProvider.family<UserStrategy?, String>((ref, strategyId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getStrategy(strategyId);
});

/// Provider for a single strategy stream (real-time updates)
final strategyStreamProvider = StreamProvider.family<UserStrategy?, String>((ref, strategyId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.strategyStream(strategyId);
});

/// Provider for all strategies of a user
final userStrategiesProvider = FutureProvider.family<List<UserStrategy>, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserStrategies(userId);
});

/// Provider for all strategies of a user (stream - real-time updates)
final userStrategiesStreamProvider = StreamProvider.family<List<UserStrategy>, String>((ref, userId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.userStrategiesStream(userId);
});

/// Provider for user's default strategy
final defaultStrategyProvider = FutureProvider.family<UserStrategy?, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getDefaultStrategy(userId);
});

/// Provider for user's default strategy (stream - real-time updates)
final defaultStrategyStreamProvider = StreamProvider.family<UserStrategy?, String>((ref, userId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.defaultStrategyStream(userId);
});

/// Convenience provider for current user's default strategy
final currentUserDefaultStrategyProvider = StreamProvider<UserStrategy?>((ref) {
  final currentUserAsync = ref.watch(currentUserProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  
  return currentUserAsync.value != null 
      ? firestoreService.defaultStrategyStream(currentUserAsync.value!.uid)
      : Stream.value(null);
});

/// Convenience provider for current user's all strategies
final currentUserStrategiesProvider = StreamProvider<List<UserStrategy>>((ref) {
  final currentUserAsync = ref.watch(currentUserProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  
  return currentUserAsync.value != null 
      ? firestoreService.userStrategiesStream(currentUserAsync.value!.uid)
      : Stream.value([]);
});

// ========== STRATEGY-SCOPED DATA PROVIDERS ==========

/// Provider for values by strategyId
final strategyValuesProvider = FutureProvider.family<List<UserValue>, String>((ref, strategyId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserValues(strategyId);
});

/// Provider for vision by strategyId
final strategyVisionProvider = FutureProvider.family<UserVision?, String>((ref, strategyId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserVision(strategyId);
});

/// Provider for vision by strategyId (stream - real-time updates)
final strategyVisionStreamProvider = StreamProvider.family<UserVision?, String>((ref, strategyId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.userVisionStream(strategyId);
});

/// Provider for mission map by strategyId
final strategyMissionMapProvider = FutureProvider.family<UserMissionMap?, String>((ref, strategyId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserMissionMap(strategyId);
});

/// Provider for mission map by strategyId (stream - real-time updates)
final strategyMissionMapStreamProvider = StreamProvider.family<UserMissionMap?, String>((ref, strategyId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.userMissionMapStream(strategyId);
});

// ========== BACKWARD COMPATIBILITY PROVIDERS (DEPRECATED) ==========

/// Provider for values by userId (backward compatibility)
/// @deprecated Use strategyValuesProvider instead
@Deprecated('Use strategyValuesProvider with strategyId instead')
final userValuesProviderDeprecated = FutureProvider.family<List<UserValue>, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  // ignore: deprecated_member_use_from_same_package
  return firestoreService.getUserValuesByUserId(userId);
});

/// Provider for vision by userId (backward compatibility)
/// @deprecated Use strategyVisionProvider instead
@Deprecated('Use strategyVisionProvider with strategyId instead')
final userVisionProviderDeprecated = FutureProvider.family<UserVision?, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  // ignore: deprecated_member_use_from_same_package
  return firestoreService.getUserVisionByUserId(userId);
});

/// Provider for vision by userId (stream - backward compatibility)
/// @deprecated Use strategyVisionStreamProvider instead
@Deprecated('Use strategyVisionStreamProvider with strategyId instead')
final userVisionStreamProviderDeprecated = StreamProvider.family<UserVision?, String>((ref, userId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  // ignore: deprecated_member_use_from_same_package
  return firestoreService.userVisionStreamByUserId(userId);
});

/// Provider for mission map by userId (backward compatibility)
/// @deprecated Use strategyMissionMapProvider instead
@Deprecated('Use strategyMissionMapProvider with strategyId instead')
final userMissionMapProviderDeprecated = FutureProvider.family<UserMissionMap?, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  // ignore: deprecated_member_use_from_same_package
  return firestoreService.getUserMissionMapByUserId(userId);
});

/// Provider for mission map by userId (stream - backward compatibility)
/// @deprecated Use strategyMissionMapStreamProvider instead
@Deprecated('Use strategyMissionMapStreamProvider with strategyId instead')
final userMissionMapStreamProviderDeprecated = StreamProvider.family<UserMissionMap?, String>((ref, userId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  // ignore: deprecated_member_use_from_same_package
  return firestoreService.userMissionMapStreamByUserId(userId);
});
