# Value Profile Agent Implementation Plan

## Overview
Build an AI-powered agent that refines preference weights and monetary factors through adaptive multiple-choice questioning, updating visualizations in real-time.

---

## 1. Architecture & Data Flow

### 1.1 Core Components
```
ValueProfilePage (Main Container)
├── Left Column: Enhanced Bar Chart
│   ├── Dual-bar visualization (weight + monetary)
│   ├── Dual Y-axis scaling
│   └── Real-time updates from agent
│
└── Right Column: Agent Interface
    ├── Stability Meter (top)
    ├── Agent Feedback Panel
    ├── Multiple Choice Questions (up to 3)
    └── Answer submission handling
```

### 1.2 State Management
```dart
// Existing providers (keep)
- preferenceWeightsProvider: List<PreferenceWeight>
- selectedPreferenceProvider: TypePreference?

// New providers needed
- agentSessionProvider: AgentSession
- agentStabilityProvider: StabilityMetrics
- agentQuestionsProvider: List<AgentQuestion>
- questionHistoryProvider: List<QuestionAnswer>
```

### 1.3 Data Models

#### AgentSession
```dart
class AgentSession {
  final String id;
  final String strategyId;
  final DateTime startedAt;
  final int iterationCount;
  final bool isActive;
  final Map<String, double> initialWeights;
  final Map<String, double> initialMonetary;
  final Map<String, double> currentWeights;
  final Map<String, double> currentMonetary;
  final List<QuestionAnswer> history;
}
```

#### AgentQuestion
```dart
class AgentQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final String reasoning; // Why this question is being asked
  final QuestionType type; // WEIGHT_COMPARISON, MONETARY_VALUE, TRADEOFF
}
```

#### QuestionAnswer
```dart
class QuestionAnswer {
  final String questionId;
  final String questionText;
  final String selectedOption;
  final int optionIndex;
  final DateTime answeredAt;
  final Map<String, double> weightsBefore;
  final Map<String, double> weightsAfter;
}
```

#### StabilityMetrics
```dart
class StabilityMetrics {
  final double overallStability; // 0.0 to 1.0
  final Map<String, double> preferenceStability; // Per preference
  final int consistentAnswers;
  final int totalAnswers;
  final bool isConverged; // True when stable enough
}
```

---

## 2. AI Service Integration

### 2.1 Agent Prompt Structure
```
SYSTEM CONTEXT:
- Strategy type and preferences (names, descriptions)
- Current relativeWeights (0.0-1.0 for each preference)
- Current monetaryFactorPerYear (dollar values for each)
- Question/answer history from this session
- Stability metrics

USER GOAL:
Refine the preference weights and monetary values to accurately 
reflect the user's true priorities and economic reality.

AGENT TASK:
1. Analyze current values and past answers for inconsistencies
2. Generate 1-3 multiple choice questions that:
   - Reveal true preferences through comparisons/tradeoffs
   - Clarify monetary valuations
   - Resolve contradictions in previous answers
3. Provide brief reasoning (3-5 sentences) for why these questions matter
4. Calculate updated weights/monetary values based on answers
```

### 2.2 AI Service Method
```dart
class ValueProfileAgentService {
  Future<AgentResponse> generateQuestions({
    required List<TypePreference> preferences,
    required Map<String, double> currentWeights,
    required Map<String, double> currentMonetary,
    required List<QuestionAnswer> history,
    required StabilityMetrics stability,
  });

  Future<AgentRefinement> processAnswers({
    required List<AgentQuestion> questions,
    required List<int> selectedOptionIndices,
    required Map<String, double> currentWeights,
    required Map<String, double> currentMonetary,
  });
}
```

### 2.3 AI Provider Integration
- Use existing Gemini service (gemini_service.dart)
- Extend with structured JSON output for questions/refinements
- Add function calling for numerical updates

---

## 3. UI Components

### 3.1 Enhanced Bar Chart (Left Column)

#### Dual Bar Design
```
Each preference shows TWO bars side-by-side:
┌────────────────────┐
│ [Blue Bar]         │ ← Relative Weight (0-100%)
│ [Green Bar]        │ ← Monetary Factor (scaled to fit)
│ Label              │
└────────────────────┘

Dual Y-Axis:
Left Axis:  0% - 100% (for weights)
Right Axis: $0 - $MAX (for monetary, dynamic scale)
```

#### Implementation Details
```dart
Widget _buildDualBarChart() {
  // Calculate monetary scale
  double maxMonetary = weights.map((w) => w.monetary).reduce(max);
  
  return Row(
    children: weights.map((w) => 
      _buildDualPreferenceBar(
        preference: w.preference,
        weight: w.weight,
        monetary: w.monetary,
        monetaryScale: maxMonetary,
      )
    ).toList(),
  );
}
```

### 3.2 Stability Meter (Top of Right Column)

#### Visual Design
```
┌─────────────────────────────────┐
│ Stability: ████████░░ 80%       │
│ Status: Converging... 🔄        │
│ 12/15 answers consistent        │
└─────────────────────────────────┘
```

#### Calculation Logic
```dart
double calculateStability(List<QuestionAnswer> history) {
  // Compare recent answers to earlier answers on similar questions
  // Higher score = more consistent preferences
  // Return 0.0 to 1.0
}
```

### 3.3 Agent Feedback Panel

```
┌─────────────────────────────────┐
│ 💭 Agent Feedback               │
├─────────────────────────────────┤
│ Your answers suggest that Cost  │
│ is more important than Time, but│
│ the monetary values don't align.│
│ Let's clarify your economic     │
│ priorities with these questions.│
└─────────────────────────────────┘
```

### 3.4 Multiple Choice Questions

```
┌─────────────────────────────────┐
│ Question 1/3                    │
│ If you could reduce costs by    │
│ $10,000/year but increase time  │
│ by 20%, would you do it?        │
│                                 │
│ ○ Yes, cost savings are worth  │
│ ○ No, time is more valuable    │
│ ○ Depends on the context       │
│ ○ They're equally important    │
└─────────────────────────────────┘
```

---

## 4. Implementation Phases

### Phase 1: Data Models & State (Week 1)
- [ ] Create AgentSession model
- [ ] Create AgentQuestion model  
- [ ] Create QuestionAnswer model
- [ ] Create StabilityMetrics model
- [ ] Add JSON serialization for all models
- [ ] Create Riverpod providers
- [ ] Add Firestore collections:
  - `agent_sessions`
  - `agent_questions` (sub-collection)
  - `question_answers` (sub-collection)

### Phase 2: Dual Bar Chart (Week 1-2)
- [ ] Modify PreferenceWeight to include monetary value
- [ ] Implement dual-bar widget with side-by-side bars
- [ ] Add dual Y-axis labels
- [ ] Add scaling logic for monetary values
- [ ] Add color differentiation (blue=weight, green=monetary)
- [ ] Add legends
- [ ] Test with various data ranges

### Phase 3: AI Service Integration (Week 2)
- [ ] Extend GeminiService with agent methods
- [ ] Create structured prompts for question generation
- [ ] Implement JSON parsing for questions
- [ ] Create refinement calculation logic
- [ ] Add error handling for AI responses
- [ ] Add fallback questions if AI fails
- [ ] Test with various preference configurations

### Phase 4: Stability Calculation (Week 2-3)
- [ ] Implement consistency scoring algorithm
- [ ] Create per-preference stability tracking
- [ ] Define convergence threshold (e.g., >85% stability)
- [ ] Add trending indicators (improving/degrading)
- [ ] Test with synthetic answer patterns

### Phase 5: Agent UI Components (Week 3)
- [ ] Build StabilityMeter widget
- [ ] Build AgentFeedback widget
- [ ] Build MultipleChoiceQuestion widget
- [ ] Build question list container
- [ ] Add answer submission handling
- [ ] Add loading states during AI processing
- [ ] Add animations for updates

### Phase 6: Integration & Polish (Week 4)
- [ ] Connect agent UI to right column
- [ ] Wire up answer submission → AI processing → chart updates
- [ ] Add session management (start/pause/resume)
- [ ] Add session history view
- [ ] Implement auto-save of progress
- [ ] Add "Done" flow when stable
- [ ] Add explanations of changes
- [ ] User testing & refinement

---

## 5. Technical Considerations

### 5.1 AI Prompt Engineering

#### Question Generation Prompt Template
```
You are a value preference refinement agent. Your goal is to help users 
accurately define their strategic preferences through thoughtful questions.

CURRENT STATE:
Strategy Type: {strategyType}
Preferences:
{for each preference:
  - Name: {name}
  - Description: {description}
  - Weight: {relativeWeight}
  - Monetary: {monetaryFactorPerYear}
}

ANSWER HISTORY:
{for each answer:
  Q: {question}
  A: {answer}
  Impact: {how weights/monetary changed}
}

STABILITY: {stabilityScore}/100

TASK:
Generate 1-3 multiple choice questions (JSON format) that will:
1. Identify inconsistencies between weights and monetary values
2. Clarify trade-offs between competing preferences
3. Ground monetary values in realistic scenarios

Each question should have 3-4 options. Provide a brief reasoning 
(3-5 sentences) explaining why these questions are necessary.

OUTPUT FORMAT:
{
  "reasoning": "string",
  "questions": [
    {
      "id": "uuid",
      "text": "string",
      "options": ["string", "string", "string"],
      "type": "WEIGHT_COMPARISON" | "MONETARY_VALUE" | "TRADEOFF"
    }
  ]
}
```

#### Refinement Calculation Prompt Template
```
Given the user's answer to this question, calculate updated weights and 
monetary values that better reflect their true preferences.

QUESTION: {questionText}
ANSWER SELECTED: {selectedOption}
QUESTION TYPE: {type}

CURRENT VALUES:
{preferences with weights and monetary}

PREVIOUS ADJUSTMENTS:
{history of changes}

Calculate new values ensuring:
1. All weights sum to 1.0
2. Monetary values are realistic and consistent with weights
3. Changes are gradual (max 10% shift per iteration)
4. Tradeoffs are mathematically coherent

OUTPUT FORMAT:
{
  "updatedWeights": {"preferenceA": 0.25, "preferenceB": 0.35, ...},
  "updatedMonetary": {"preferenceA": 15000, "preferenceB": 8000, ...},
  "explanation": "Brief explanation of changes (2-3 sentences)"
}
```

### 5.2 Stability Algorithm

```dart
double calculateStabilityScore(List<QuestionAnswer> history) {
  if (history.length < 3) return 0.0;
  
  // Score based on:
  // 1. Weight volatility (lower = better)
  double weightStability = _calculateWeightVariance(history);
  
  // 2. Answer consistency (similar questions, similar answers)
  double answerConsistency = _calculateAnswerConsistency(history);
  
  // 3. Convergence trend (getting more stable over time)
  double convergenceTrend = _calculateConvergenceTrend(history);
  
  // 4. Weight-monetary alignment (do they make sense together?)
  double alignment = _calculateWeightMonetaryAlignment(history);
  
  // Weighted average
  return (weightStability * 0.3 +
          answerConsistency * 0.3 +
          convergenceTrend * 0.2 +
          alignment * 0.2);
}
```

### 5.3 Question Types

#### Type 1: Weight Comparison
- "Which is more important: A or B?"
- Forces ranking decisions
- Updates relative weights

#### Type 2: Monetary Value
- "How much would you pay to improve X by 20%?"
- Grounds monetary factors in reality
- Updates monetary values

#### Type 3: Tradeoff
- "If A decreases by X, how much must B improve?"
- Tests consistency
- Refines both weights and monetary

### 5.4 Performance Considerations

- **Debounce AI calls**: Don't call AI on every answer, batch questions
- **Cache sessions**: Store in Firestore for persistence
- **Optimistic UI**: Update chart immediately, refine with AI async
- **Timeout handling**: Max 10 seconds for AI response, fallback to manual
- **Rate limiting**: Max 1 AI call per 5 seconds

---

## 6. User Experience Flow

### 6.1 Initial State
```
User clicks "Next" after manual weight setting
→ Preferences saved
→ Agent session created
→ Right panel shows: "Agent Development in Progress"
→ AI generates first set of questions
→ Questions appear with reasoning
```

### 6.2 During Refinement
```
User answers Question 1
→ Chart updates in real-time (optimistic)
→ AI processes answer
→ New questions generated (if needed)
→ Stability meter updates
→ Feedback explains changes
→ Repeat until stable
```

### 6.3 Convergence
```
Stability reaches 85%+
→ "Your preferences are now well-defined! ✓"
→ "Finish" button appears
→ Click → Save final values → Return to dashboard
```

### 6.4 Manual Override
```
User can still use +/- buttons or edit percentages
→ Incorporates manual changes into AI context
→ May generate new questions based on changes
→ Maintains question history
```

---

## 7. Testing Strategy

### 7.1 Unit Tests
- Stability calculation with synthetic data
- Weight normalization after updates
- Monetary value bounds checking
- Question parsing from AI responses

### 7.2 Integration Tests
- Full question → answer → update cycle
- Session persistence across page reloads
- Multiple users working simultaneously
- AI service fallbacks

### 7.3 User Testing Scenarios
1. **New User**: Starting with equal weights
2. **Confident User**: Strong initial preferences
3. **Uncertain User**: Contradictory answers
4. **Edge Cases**: All weight on one preference
5. **Monetary Extremes**: Very high/low values

---

## 8. Future Enhancements (Post-MVP)

### 8.1 Advanced Features
- **Confidence Intervals**: Show uncertainty ranges on weights
- **Historical Comparison**: Compare current vs. past sessions
- **Peer Benchmarking**: "Users like you typically value X at..."
- **Scenario Testing**: "What if Cost increased by 50%?"
- **Visual Explanations**: Show why values changed (animated diff)

### 8.2 AI Improvements
- **Learning from Population**: Use aggregate data to improve questions
- **Personalization**: Adapt question style to user's comprehension
- **Multi-turn Dialogues**: Follow-up questions for clarity
- **Explanation Generation**: Natural language rationale for all changes

### 8.3 Analytics
- **Session Metrics**: Average time to convergence, # questions needed
- **Preference Patterns**: Common configurations by strategy type
- **Question Effectiveness**: Which questions lead to fastest convergence

---

## 9. Risk Mitigation

### 9.1 AI Risks
- **Hallucination**: Validate all numerical outputs
- **Inappropriate Questions**: Filter for business relevance
- **Slow Response**: Implement timeout with fallback
- **Cost**: Cache common patterns, limit calls

### 9.2 UX Risks
- **User Fatigue**: Cap at 15 questions per session
- **Confusion**: Clear explanations for all changes
- **Lost Progress**: Auto-save every answer
- **Stuck in Loop**: Force convergence after 20 questions

### 9.3 Technical Risks
- **State Sync**: Use optimistic updates + reconciliation
- **Race Conditions**: Queue AI requests
- **Memory Leaks**: Clean up listeners properly
- **Browser Compatibility**: Test dual-axis charts across browsers

---

## 10. Success Metrics

### 10.1 Quantitative
- **Time to Convergence**: < 10 minutes average
- **Question Count**: 8-15 questions typical
- **Stability Score**: > 85% before finishing
- **User Retention**: Users complete vs. abandon

### 10.2 Qualitative
- **User Confidence**: "I feel my preferences are accurately captured"
- **Understanding**: "I understand why these questions were asked"
- **Trust**: "The AI made sensible updates to my values"
- **Utility**: "This was more effective than manual adjustment"

---

## 11. File Structure

### New Files to Create
```
lib/
  features/
    value_profile/
      value_profile_page.dart (MODIFY)
      widgets/
        dual_bar_chart.dart (NEW)
        preference_dual_bar.dart (NEW)
        stability_meter.dart (NEW)
        agent_feedback_panel.dart (NEW)
        agent_question_card.dart (NEW)
        agent_question_list.dart (NEW)
      services/
        value_profile_agent_service.dart (NEW)
        stability_calculator.dart (NEW)
      models/
        agent_session.dart (NEW)
        agent_session.g.dart (generated)
        agent_question.dart (NEW)
        agent_question.g.dart (generated)
        question_answer.dart (NEW)
        question_answer.g.dart (generated)
        stability_metrics.dart (NEW)
        agent_response.dart (NEW)
      providers/
        agent_session_provider.dart (NEW)
        agent_questions_provider.dart (NEW)
        agent_stability_provider.dart (NEW)
        question_history_provider.dart (NEW)
```

### Modified Files
```
lib/
  core/
    models/
      strategy_preference.dart (ALREADY EXISTS - no changes needed)
    services/
      gemini_service.dart (EXTEND with agent methods)
      firestore_service.dart (ADD agent session CRUD)
```

---

## 12. Implementation Checklist

### Pre-Development
- [x] Review plan with stakeholders
- [ ] Validate AI prompt effectiveness with manual testing
- [ ] Design UI mockups for approval
- [ ] Set up monitoring/analytics

### Phase 1 - Foundation (Week 1)
- [ ] Create all data models
- [ ] Add JSON serialization
- [ ] Run build_runner
- [ ] Create Firestore collections
- [ ] Create providers
- [ ] Write model unit tests

### Phase 2 - Visualization (Week 1-2)
- [ ] Build dual bar widget
- [ ] Add dual Y-axis
- [ ] Test with various scales
- [ ] Add animations
- [ ] Polish styling

### Phase 3 - AI Integration (Week 2)
- [ ] Extend Gemini service
- [ ] Test prompt with real data
- [ ] Implement refinement logic
- [ ] Add error handling
- [ ] Test edge cases

### Phase 4 - Stability System (Week 2-3)
- [ ] Implement stability calculator
- [ ] Test with synthetic data
- [ ] Build stability meter widget
- [ ] Add convergence detection

### Phase 5 - User Interface (Week 3)
- [ ] Build question cards
- [ ] Build feedback panel
- [ ] Wire up answer handling
- [ ] Add loading states
- [ ] Implement animations

### Phase 6 - Integration (Week 3-4)
- [ ] Connect all components
- [ ] End-to-end testing
- [ ] Performance optimization
- [ ] User acceptance testing
- [ ] Bug fixes & polish

### Phase 7 - Launch (Week 4)
- [ ] Deploy to production
- [ ] Monitor metrics
- [ ] Gather user feedback
- [ ] Iterate based on data

---

## 13. Next Steps

1. **Review this plan** - Validate approach and timeline
2. **Create UI mockups** - Visual design for dual bars, stability meter, questions
3. **Test AI prompts** - Manually verify question quality
4. **Prioritize features** - Decide what's MVP vs. nice-to-have
5. **Begin Phase 1** - Start with data models and state management

---

## Questions for Stakeholder Review

1. **Convergence Threshold**: Is 85% stability sufficient, or should we aim higher?
2. **Question Limit**: Should we cap at 15 questions, or allow unlimited refinement?
3. **Manual Override**: Should manual edits during agent session reset stability?
4. **Monetary Scale**: What's a reasonable range for monetaryFactorPerYear ($1K-$1M)?
5. **AI Provider**: Continue with Gemini, or also support OpenAI/Claude?
6. **Session Persistence**: Should users be able to resume sessions days later?
7. **Multi-Device**: Should sessions sync across devices in real-time?

---

**Document Version**: 1.0  
**Created**: February 27, 2026  
**Status**: Ready for Review  
**Estimated Effort**: 3-4 weeks (1 developer)
