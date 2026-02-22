import 'package:dart_openai/dart_openai.dart';

void main() async {
  const apiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '', // Add your key here for local testing only
  );
  
  print('Testing OpenAI API...\n');
  
  OpenAI.apiKey = apiKey;
  
  try {
    print('Sending test request to GPT-4o-mini...');
    
    final response = await OpenAI.instance.chat.create(
      model: 'gpt-4o-mini',
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
              'Say "Hello! The OpenAI integration is working perfectly!"'
            ),
          ],
        ),
      ],
      temperature: 0.7,
      maxTokens: 100,
    );
    
    final message = response.choices.first.message.content?.first.text;
    print('\n✅ SUCCESS!');
    print('Response: $message\n');
    
  } catch (e) {
    print('\n❌ FAILED');
    print('Error: $e\n');
  }
}
