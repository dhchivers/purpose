# Quick Start: Gemini AI Integration

## 🚀 5-Minute Setup

### Step 1: Get API Key (2 minutes)

1. Go to https://makersuite.google.com/app/apikey
2. Sign in with Google
3. Click "Create API Key"
4. Copy the key (starts with `AIzaSy...`)

### Step 2: Configure (1 minute)

Open `lib/core/config/ai_config.dart`:

```dart
static const String geminiApiKey = 'AIzaSy_paste_your_key_here';
```

### Step 3: Run (2 minutes)

```bash
flutter pub get
flutter run -d chrome --web-port 8080
```

## ✅ Verify It Works

1. **Login** to the app
2. **Navigate** to Purpose → Select a module
3. **Answer** all questions
4. **Click** "View AI Insights" 
5. **Watch** AI analyze your responses! 🧠

## 📋 What You Get

### Single Answer Insights
Each answer gets personalized feedback connecting to your purpose.

### Module Analysis
After completing a module:
- 🎯 Key themes and patterns
- 💎 Core values identified  
- 💪 Strengths and passions
- 🎯 Purpose indicators
- 📝 Next steps for reflection

### Purpose Statement (Coming Soon)
Complete multiple modules to generate your personalized purpose statement.

## 🎨 User Experience

```
Complete Module → Click "View AI Insights" → AI analyzes → Shows insights
       ↓                                                          ↓
    Saves answers                                      Opens insights page
  (processedByAI: false)                          (Stores processedByAI: true)
```

## 🔍 Where to Find It

### In the App:
1. **Completion Screen**: "View AI Insights" button appears after finishing a module
2. **Module List**: Brain icon (🧠) on completed modules - click to view insights
3. **Insights Page**: Full AI analysis with themes, values, and action steps

### In the Code:
- **Service**: `lib/core/services/gemini_service.dart`
- **Processor**: `lib/core/services/ai_processor_service.dart`
- **UI**: `lib/features/purpose/module_insights_page.dart`
- **Config**: `lib/core/config/ai_config.dart`

## 🎯 Usage Example

```dart
// In your code:
final aiProcessor = ref.read(aiProcessorServiceProvider);

// Generate insights for a completed module
final insights = await aiProcessor.generateModuleAnalysis(
  userId: currentUser.uid,
  module: purposeModule,
);

// Display to user
showInsights(insights);
```

## ⚙️ Configuration Options

In `ai_config.dart`:

```dart
// Models
static const String defaultModel = 'gemini-1.5-flash';  // Fast & economical
static const String proModel = 'gemini-1.5-pro';        // More capable

// Generation settings
static const double temperature = 0.7;        // Creativity (0.0-1.0)
static const int maxOutputTokens = 2048;      // Response length
```

## 🛡️ Best Practices

1. **Never commit API keys** - Use environment variables in production
2. **Monitor costs** - Set up billing alerts in Google Cloud Console
3. **Cache responses** - Store AI insights in Firestore to avoid re-processing
4. **Handle errors** - Show friendly messages when API fails
5. **Rate limit** - Implement per-user limits to control costs

## 💰 Cost Estimate

With Gemini 1.5 Flash/Pro pricing:
- Single insight: ~$0.001 per answer
- Module analysis: ~$0.005 per module
- Purpose statement: ~$0.010 per generation

**Example:** 100 users completing 5 modules each = ~$2.50

## 🐛 Troubleshooting

### "API key not configured"
→ Check `ai_config.dart` has your key

### "Quota exceeded"
→ Check Google Cloud Console billing/quotas

### Slow response
→ Use Gemini Flash instead of Pro

### No insights showing
→ Check browser console and Flutter logs for errors

## 📊 Monitor Usage

Track in Firestore:
```javascript
// Processed answers
db.collection('user_answers')
  .where('processedByAI', '==', true)
  .count()

// Unprocessed answers
db.collection('user_answers')
  .where('processedByAI', '==', false)
  .count()
```

## 🚀 Next Steps

1. **Test with real data** - Complete modules and review insights
2. **Refine prompts** - Edit `gemini_service.dart` to customize AI responses
3. **Add analytics** - Track which insights users find most valuable
4. **Implement caching** - Save token costs by reusing responses
5. **Build purpose statement** - Extend to create complete purpose synthesis

## 📚 Resources

- [Gemini API Docs](https://ai.google.dev/docs)
- [Google AI Studio](https://makersuite.google.com/)
- [Full Documentation](./GEMINI_INTEGRATION.md)
- [Pricing](https://ai.google.dev/pricing)

---

**Ready to discover purpose with AI? Let's go! 🎯✨**
