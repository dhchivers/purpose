import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/ai_processor_service.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';

/// Provider for AIProcessorService
final aiProcessorServiceProvider = FutureProvider<AIProcessorService>((ref) async {
  final geminiService = await ref.watch(geminiServiceProvider.future);
  final firestoreService = ref.watch(firestoreServiceProvider);
  
  return AIProcessorService(
    geminiService: geminiService,
    firestoreService: firestoreService,
  );
});
