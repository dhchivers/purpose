import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/firestore_service.dart';

/// Provider for the FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
