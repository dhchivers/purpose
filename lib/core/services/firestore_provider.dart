import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/firestore_service.dart';
import 'package:purpose/core/models/strategy_preference.dart';
import 'package:purpose/core/models/type_preference.dart';

/// Provider for the FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Stream provider for strategy preferences by strategy ID
/// Usage: ref.watch(strategyPreferencesStreamProvider(strategyId))
final strategyPreferencesStreamProvider = 
    StreamProvider.family<List<StrategyPreference>, String>((ref, strategyId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.strategyPreferencesStream(strategyId);
});

/// Stream provider for type preferences by strategy type ID
/// Usage: ref.watch(typePreferencesStreamProvider(strategyTypeId))
final typePreferencesStreamProvider = 
    StreamProvider.family<List<TypePreference>, String>((ref, strategyTypeId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.typePreferencesStream(strategyTypeId);
});
