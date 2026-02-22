import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/services/config_service.dart';

/// Provider for ConfigService
final configServiceProvider = Provider<ConfigService>((ref) {
  return ConfigService();
});

/// Provider for OpenAI API Key
/// Fetches the key from Firestore on first access
final openAiKeyProvider = FutureProvider<String>((ref) async {
  final configService = ref.watch(configServiceProvider);
  return configService.getOpenAiKey();
});
