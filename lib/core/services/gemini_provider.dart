import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/gemini_service.dart';

/// Provider for GeminiService
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});
