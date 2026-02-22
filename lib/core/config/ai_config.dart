/// AI Configuration
/// 
/// Store your OpenAI API key in environment variables or Firebase Remote Config
/// For development, you can temporarily hardcode it here (DO NOT commit to git)
class AIConfig {
  // TODO: Replace with your OpenAI API key or load from environment
  // Get your API key from: https://platform.openai.com/api-keys
  static const String openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '', // Add your key here for local development only
  );
  
  // Model configuration
  // Using GPT-4o-mini for fast, cost-effective analysis
  // For more comprehensive analysis, use gpt-4o or gpt-4-turbo
  static const String defaultModel = 'gpt-4o-mini';
  static const String proModel = 'gpt-4o';
  
  // Generation settings
  static const double temperature = 0.7;
  static const int maxTokens = 2048;
  
  // Validate configuration
  static bool get isConfigured => 
      openAiApiKey.isNotEmpty && 
      openAiApiKey != 'YOUR_OPENAI_API_KEY_HERE' &&
      openAiApiKey.startsWith('sk-');
}
