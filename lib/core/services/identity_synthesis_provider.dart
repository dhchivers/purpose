import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/identity_synthesis_service.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';

/// Provider for IdentitySynthesisService
final identitySynthesisServiceProvider = FutureProvider<IdentitySynthesisService>((ref) async {
  return IdentitySynthesisService(
    geminiService: await ref.watch(geminiServiceProvider.future),
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});
