# Gemini AI Integration Guide

This application integrates Google's Gemini AI to provide personalized insights and purpose discovery guidance based on user answers.

## Features

### 1. Individual Answer Analysis
- AI analyzes each user answer independently
- Provides insights into values, motivations, and purpose indicators
- Stored in the `aiResponse` field of each `user_answer` document

### 2. Module-Level Analysis
- Comprehensive analysis of all answers within a module
- Identifies key themes, patterns, and values
- Generates actionable next steps
- Available via the "View AI Insights" button after module completion

### 3. Complete Purpose Statement Generation
- Synthesizes answers across all completed modules
- Creates personalized purpose statement
- Identifies core values, strengths, and impact areas
- Provides practical action steps

## Setup Instructions

### 1. Get Your Gemini API Key

1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy your API key

### 2. Configure API Key

Open `/lib/core/config/ai_config.dart` and replace the placeholder:

```dart
static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

With your actual key:

```dart
static const String geminiApiKey = 'AIzaSy...your-key-here';
```

**Important:** Never commit your API key to version control. For production:
- Use environment variables
- Use Firebase Remote Config
- Use a secrets management service

### 3. Install Dependencies

Run:

```bash
flutter pub get
```

## Usage

### For Users

1. **Complete a Module:**
   - Navigate to Purpose modules
   - Select a module and answer all questions
   - Click "Complete" when finished

2. **View AI Insights:**
   - After completing a module, click "View AI Insights"
   - AI will analyze your answers and provide personalized guidance
   - Review the insights and continue with other modules

3. **Generate Purpose Statement:**
   - Complete multiple modules to build comprehensive context
   - Access the purpose statement generator (coming soon)
   - Receive a personalized purpose statement with action steps

### For Developers

#### Process Individual Answer

```dart
// Get services
final aiProcessor = ref.read(aiProcessorServiceProvider);

// Process single answer
final insights = await aiProcessor.processAnswer(
  answer: userAnswer,
  question: question,
  module: module,
);
```

#### Generate Module Analysis

```dart
// Generate comprehensive module analysis
final analysis = await aiProcessor.generateModuleAnalysis(
  userId: userId,
  module: module,
);
```

#### Generate Purpose Statement

```dart
// Generate complete purpose statement
final purposeStatement = await aiProcessor.generatePurposeStatement(
  userId: userId,
);
```

## Architecture

### Services

1. **GeminiService** (`/lib/core/services/gemini_service.dart`)
   - Direct interface with Google Generative AI API
   - Handles prompt construction and API calls
   - Three main methods: analyzeAnswer, analyzeModuleAnswers, generatePurposeStatement

2. **AIProcessorService** (`/lib/core/services/ai_processor_service.dart`)
   - Coordinates AI processing with Firestore
   - Manages answer processing workflow
   - Tracks processed/unprocessed status

3. **AIConfig** (`/lib/core/config/ai_config.dart`)
   - Centralized configuration
   - API key management
   - Model selection and generation parameters

### UI Components

1. **ModuleInsightsPage** (`/lib/features/purpose/module_insights_page.dart`)
   - Displays AI-generated module insights
   - Shows loading states and error handling
   - Allows regeneration of insights

2. **Module Completion Screen**
   - Updated to show "View AI Insights" button
   - Encourages users to review AI analysis

3. **Purpose Modules Page**
   - Shows brain icon on completed modules for quick access to insights

## Data Flow

```
User completes question → Answer saved to Firestore (processedByAI: false)
                              ↓
User views insights → AIProcessorService fetches unprocessed answers
                              ↓
                    GeminiService analyzes answers
                              ↓
                    Insights stored in Firestore (processedByAI: true)
                              ↓
                    UI displays insights to user
```

## Prompt Engineering

The prompts are carefully crafted to:

1. **For single answers:**
   - Provide encouraging, actionable feedback
   - Connect responses to purpose discovery
   - Ask reflective questions

2. **For module analysis:**
   - Identify themes and patterns
   - Extract core values and strengths
   - Provide structured insights with clear sections

3. **For purpose statements:**
   - Synthesize all user data
   - Create authentic, personal purpose statements
   - Include actionable next steps

## Cost Considerations

- Gemini 1.5 Flash: Used for individual answer analysis (faster, cheaper)
- Gemini 1.5 Pro: Used for comprehensive module and purpose analysis (more capable)

Typical costs (as of 2024):
- Single answer analysis: ~1,000 tokens ($0.001-0.00025)
- Module analysis: ~5,000 tokens ($0.005-0.00125)
- Purpose statement: ~10,000 tokens ($0.010-0.0025)

## Security Best Practices

1. **Never commit API keys to source control**
   - Add `ai_config.dart` to `.gitignore` if hardcoding keys
   - Use environment variables in production

2. **Implement rate limiting**
   - Track API usage per user
   - Set daily/monthly limits

3. **Validate user input**
   - Sanitize answers before sending to AI
   - Check for malicious prompt injection

4. **Monitor costs**
   - Set up Google Cloud billing alerts
   - Track token usage in analytics

## Error Handling

The system handles several error scenarios:

1. **API Key Not Configured:**
   - Throws exception on service initialization
   - Shows clear error message to user

2. **API Errors:**
   - Catches and logs errors
   - Shows user-friendly error messages
   - Allows retry functionality

3. **No Answers Found:**
   - Validates answers exist before processing
   - Shows appropriate message to user

## Testing

To test the integration:

1. Complete a Purpose module with test data
2. Click "View AI Insights"
3. Verify insights are generated and displayed
4. Check Firestore to confirm `processedByAI: true` and `aiResponse` stored

## Future Enhancements

- [ ] Streaming responses for real-time feedback
- [ ] Multi-modal analysis (images, voice)
- [ ] Progress tracking for AI processing
- [ ] Caching of AI responses
- [ ] A/B testing of different prompts
- [ ] User feedback on AI insights quality
- [ ] Purpose statement export (PDF, etc.)

## Troubleshooting

### "API key not configured" error
- Check that you've set your API key in `ai_config.dart`
- Verify the key is valid and not expired

### "Quota exceeded" error
- Check your Google Cloud billing
- Verify API quotas in Google Cloud Console
- Implement rate limiting

### Slow response times
- Consider using Gemini Flash for faster responses
- Implement caching for repeated requests
- Pre-process answers in batches

### Poor quality insights
- Review and refine prompts in `gemini_service.dart`
- Ensure questions provide enough context
- Collect user feedback to improve prompts

## Support

For issues or questions:
1. Check the error logs in terminal
2. Review Firestore data structure
3. Verify API key configuration
4. Check Google Cloud Console for API errors
