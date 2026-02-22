import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/gemini_service.dart';
import 'package:purpose/core/services/config_provider.dart';
import 'package:purpose/core/config/ai_config.dart';

/// Provider for GeminiService
/// Fetches API key from Firestore config, falls back to AIConfig if not available
final geminiServiceProvider = FutureProvider<GeminiService>((ref) async {
  // Try to get API key from Firestore
  final configKey = await ref.watch(openAiKeyProvider.future);
  
  // Use Firestore key if available, otherwise fall back to AIConfig
  final apiKey = configKey.isNotEmpty ? configKey : AIConfig.openAiApiKey;
  
  return GeminiService(apiKey: apiKey);
});
