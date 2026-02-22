import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/ai_processor_service.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';

/// Provider for AIProcessorService
final aiProcessorServiceProvider = Provider<AIProcessorService>((ref) {
  final geminiService = ref.watch(geminiServiceProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  
  return AIProcessorService(
    geminiService: geminiService,
    firestoreService: firestoreService,
  );
});
