# Goal Agent Documentation

## Overview

The Goal Agent is an AI-powered system that generates strategic goal suggestions for missions within a user's strategy roadmap. It creates outcome-focused goals that serve as key milestones toward completing a mission's structural transformation.

**Purpose:** Transform mission-level strategic direction into specific, achievable goals that advance the mission's focus and structural shift requirements.

**Key Features:**
- Context-aware goal generation using mission details and existing goals
- Single-click AI suggestion workflow
- Strategic outcome focus (WHAT to achieve, not HOW or WHEN)
- Duplicate avoidance through existing goal analysis
- Inline suggestion display with reasoning
- One-click form population or manual editing
- Manual goal creation always available

**AI Model:** OpenAI GPT-4o (via GeminiService)

---

## Goal Agent Philosophy

### What is a Goal?

A goal is a **key milestone or outcome** that must be achieved to complete a mission. Goals are strategic, outcome-focused statements that describe what success looks like, without specifying the tactical details of how or when.

**Core Principles:**
1. **Strategic Focus** - Goals describe desired outcomes, not implementation steps
2. **Mission-Aligned** - Every goal directly supports the mission's focus and structural shift
3. **Outcome-Based** - Focus on WHAT should be achieved, not HOW to achieve it
4. **Measurable at Goal Level** - Success can be determined, but detailed metrics belong in objectives
5. **Time-Bounded Mission** - Goals must be achievable within the mission's timeframe
6. **Duplicate-Aware** - AI avoids suggesting goals similar to existing ones
7. **Capability-Linked** - Goals should leverage or develop the mission's required capabilities

### Mission vs Goal vs Objective

| Aspect | Mission | Goal | Objective |
|--------|---------|------|-----------|
| **Timeframe** | 1-5 years | 3-12 months | 1-8 weeks |
| **Focus** | Structural transformation | Measurable outcome | Specific action |
| **Measure** | New capabilities developed | Achievement of target | Completion + metrics |
| **Example** | "Scale to regional influence" | "Establish partnerships with 5 key organizations" | "Complete partnership agreement with Org X - Signed MOU by March 31" |
| **AI Agent** | Mission Agent | Goal Agent | Objective Agent |

---

## Data Structures

### 1. Goal

```dart
class Goal {
  final String id;                  // Unique identifier
  final String missionId;           // Parent mission reference
  final String strategyId;          // Denormalized strategy reference
  final String title;               // Concise goal name (5-10 words)
  final String description;         // Detailed explanation of desired outcome
  final double budgetMonetary;      // Budget in monetary units
  final double budgetTime;          // Budget in hours/days
  final double actualMonetary;      // Actual spent (monetary)
  final double actualTime;          // Actual time spent (hours/days)
  final bool achieved;              // Completion status
  final DateTime? dateAchieved;     // When goal was achieved (if complete)
  final DateTime dateCreated;       // Creation timestamp
  final DateTime updatedAt;         // Last modification timestamp
}
```

**Purpose:** Represents a strategic milestone within a mission that must be achieved to advance toward the mission's structural shift.

**Key Fields:**
- `title` - Clear, concise goal statement (e.g., "Establish Regional Advisory Board")
- `description` - Detailed explanation of what this goal means and why it matters
- `budgetMonetary` / `budgetTime` - Resource allocation for achieving this goal
- `actualMonetary` / `actualTime` - Actual resources spent (for tracking variance)
- `achieved` - Boolean flag marking goal completion
- `dateAchieved` - Timestamp when goal was marked complete

**Key Methods:**
- `budgetVarianceMonetary` - Calculated property: budget - actual (positive = under budget)
- `budgetVarianceTime` - Calculated property: budget time - actual time

**Example Goal:**
```dart
Goal(
  id: 'goal_abc123',
  missionId: 'mission_xyz',
  strategyId: 'strat_001',
  title: 'Launch Regional Community Events',
  description: 'Establish a presence in 3 neighboring cities through monthly community engagement events that demonstrate value and build local credibility.',
  budgetMonetary: 5000.0,
  budgetTime: 120.0,
  actualMonetary: 0.0,
  actualTime: 0.0,
  achieved: false,
  dateAchieved: null,
  dateCreated: DateTime.now(),
  updatedAt: DateTime.now(),
)
```

---

## AI Generation

### Input Context

The Goal Agent receives comprehensive mission context to generate relevant suggestions:

```dart
Future<Map<String, dynamic>> generateGoalSuggestion({
  required String missionTitle,        // E.g., "Mission 1 — Building Local Capacity"
  required String missionFocus,        // What the mission aims to achieve
  required String structuralShift,     // How structure/scale will change
  required String capabilityRequired,  // What capabilities must be developed
  required List<Map<String, dynamic>> existingGoals, // Goals already created
})
```

**Context Usage:**
- `missionTitle` - Provides overall mission context
- `missionFocus` - Defines what the goal should advance
- `structuralShift` - Ensures goal aligns with structural transformation
- `capabilityRequired` - Suggests goals that build or leverage required capabilities
- `existingGoals` - Prevents duplication and builds on prior work

---

### Prompt Strategy

The Goal Agent uses a carefully crafted prompt that emphasizes strategic thinking:

**Key Instructions to AI:**
1. Suggest ONE new goal that is:
   - Specific and clearly defined
   - Achievable within the mission's scope
   - Directly relevant to mission focus and structural shift
   - Different from existing goals (avoid duplication)
   - A key milestone toward completing the mission

2. Strategic and outcome-focused (not tactical)

3. DO NOT include:
   - Measurable requirements (belong in objectives)
   - Time constraints or deadlines (belong in objectives)
   - Budget estimates
   - Implementation details

4. Focus on WHAT should be achieved, not HOW or WHEN

**Output Format:**
```json
{
  "title": "Clear, concise goal title (5-10 words)",
  "description": "Detailed description of what this goal aims to achieve and why it matters for this mission (2-3 sentences)",
  "reasoning": "Brief explanation of why this goal is important for this mission right now (1-2 sentences)"
}
```

---

### AI Parameters

```dart
model: AIConfig.proModel          // GPT-4o
temperature: 0.7                  // Balanced creativity
maxTokens: 800                    // Sufficient for detailed response
responseFormat: {type: 'json_object'}  // Structured output
```

**Temperature Rationale:** 0.7 provides creative goal suggestions while maintaining coherence and relevance to mission context.

**Token Budget:** 800 tokens allows for comprehensive title, description, and reasoning without excessive verbosity.

---

## User Interface Flow

### 1. Goal Creation Dialog

Located in: `lib/features/mission/mission_detail_page.dart`

**Components:**
- "Ask Goal Agent for Suggestions" button (top of dialog)
- AI suggestion display card (when suggestion received)
- Title field (required)
- Description field (required, multi-line)
- Budget fields (monetary and time, optional)
- Save/Cancel actions

**Dialog Width:** 500px (consistent with other dialogs)

---

### 2. Goal Agent Workflow

```
User clicks "Add Goal" button
    ↓
Goal Creation Dialog opens
    ↓
User clicks "Ask Goal Agent for Suggestions"
    ↓
Loading state: "Thinking..."
    ↓
Backend fetches:
  - Mission document (title, focus, structural shift, capability)
  - Existing goals for this mission
    ↓
AI generates suggestion with:
  - Title
  - Description
  - Reasoning
    ↓
Suggestion card displays with:
  - ✨ Title
  - 📝 Description
  - 💡 Reasoning
  - "Use This Suggestion" button
  - Dismiss button
    ↓
User clicks "Use This Suggestion"
    ↓
Form fields auto-populate:
  - Title ← suggestion.title
  - Description ← suggestion.description
    ↓
User can edit or accept as-is
    ↓
User adds budget (optional) and saves
    ↓
Goal saved to Firestore
```

---

### 3. Suggestion Display Card

**Visual Design:**
- Light blue background (primaryLight.withOpacity(0.05))
- Border: primaryLight.withOpacity(0.3)
- Lightbulb icon header
- Title in bold graphite
- Description in gray medium
- Reasoning in italic with 💡 emoji
- Full-width "Use This Suggestion" button (primary color)
- Dismiss icon in top-right corner

**State Management:**
```dart
Map<String, dynamic>? _aiSuggestion;  // null = no suggestion
bool _isLoadingSuggestion = false;     // true = AI request in progress
```

---

## Implementation Details

### 1. Goal Agent Method

**Location:** `lib/core/services/gemini_service.dart`

```dart
Future<Map<String, dynamic>> generateGoalSuggestion({
  required String missionTitle,
  required String missionFocus,
  required String structuralShift,
  required String capabilityRequired,
  required List<Map<String, dynamic>> existingGoals,
}) async {
  final prompt = _buildGoalSuggestionPrompt(
    missionTitle: missionTitle,
    missionFocus: missionFocus,
    structuralShift: structuralShift,
    capabilityRequired: capabilityRequired,
    existingGoals: existingGoals,
  );

  final response = await _makeOpenAIRequest(
    model: AIConfig.proModel,
    messages: [{'role': 'user', 'content': prompt}],
    temperature: 0.7,
    maxTokens: 800,
    responseFormat: {'type': 'json_object'},
  );

  final content = _extractContent(response);
  return jsonDecode(content) as Map<String, dynamic>;
}
```

---

### 2. UI Integration

**Location:** `lib/features/mission/mission_detail_page.dart`

**Key Methods:**

```dart
// Fetch context and call AI
Future<void> _askGoalAgent() async {
  setState(() => _isLoadingSuggestion = true);
  
  try {
    // Fetch mission context
    final mission = await firestoreService.getMissionDocument(widget.missionId);
    
    // Fetch existing goals
    final existingGoals = await firestoreService.getGoalsForMission(widget.missionId);
    
    // Map to simple format for AI
    final goalsList = existingGoals.map((g) => {
      'title': g.title,
      'description': g.description,
      'achieved': g.achieved,
    }).toList();
    
    // Call AI
    final suggestion = await geminiService.generateGoalSuggestion(
      missionTitle: mission.mission,
      missionFocus: mission.focus,
      structuralShift: mission.structuralShift,
      capabilityRequired: mission.capabilityRequired,
      existingGoals: goalsList,
    );
    
    setState(() => _aiSuggestion = suggestion);
  } catch (e) {
    // Show error to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error getting suggestion: $e')),
    );
  } finally {
    setState(() => _isLoadingSuggestion = false);
  }
}

// Populate form from suggestion
void _applySuggestion() {
  if (_aiSuggestion == null) return;
  
  setState(() {
    _titleController.text = _aiSuggestion!['title'] ?? '';
    _descriptionController.text = _aiSuggestion!['description'] ?? '';
    _aiSuggestion = null;  // Clear suggestion
  });
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('✨ Suggestion applied! Edit as needed.')),
  );
}
```

---

## Database Operations

### Firestore Structure

```
strategies/{strategyId}/
  missions/{missionId}/
    goals/{goalId}/
      - id: string
      - missionId: string (denormalized)
      - strategyId: string (denormalized)
      - title: string
      - description: string
      - budgetMonetary: number
      - budgetTime: number
      - actualMonetary: number
      - actualTime: number
      - achieved: boolean
      - dateAchieved: timestamp (nullable)
      - dateCreated: timestamp
      - updatedAt: timestamp
```

### Key Operations

**Create Goal:**
```dart
await firestoreService.createGoal(
  missionId: missionId,
  strategyId: strategyId,
  title: title,
  description: description,
  budgetMonetary: budgetMonetary,
  budgetTime: budgetTime,
);
```

**Update Goal:**
```dart
await firestoreService.updateGoal(
  goalId: goalId,
  updates: {
    'title': newTitle,
    'description': newDescription,
    'budgetMonetary': newBudget,
    // ... other fields
  },
);
```

**Mark Goal Complete:**
```dart
await firestoreService.updateGoal(
  goalId: goalId,
  updates: {
    'achieved': true,
    'dateAchieved': FieldValue.serverTimestamp(),
  },
);
```

**Stream Goals for Mission:**
```dart
final goalsStream = ref.watch(goalsForMissionStreamProvider(missionId));

goalsStream.when(
  data: (goals) => /* Display goals */,
  loading: () => /* Show loading */,
  error: (err, stack) => /* Show error */,
);
```

---

## Best Practices

### 1. When to Use Goal Agent

✅ **Good Use Cases:**
- Starting a new mission and need goal ideas
- Mission has clear focus but goals aren't obvious
- Want strategic perspective on what to prioritize
- Need inspiration for next milestone

❌ **Avoid When:**
- Goal is already clear and specific
- Mission context is incomplete or unclear
- Just filling in mandatory fields

### 2. Editing AI Suggestions

**Always review and customize:**
- Adjust title to match your terminology
- Expand or clarify description for your context
- Add budget estimates based on your resources
- Consider if goal scope is appropriate for your timeline

**The AI provides a starting point, not a final answer.**

### 3. Manual Goal Creation

The Goal Agent is **optional** - users can always create goals manually:
- Click "Add Goal" button
- Fill in title and description
- Skip the AI agent button
- Add budget and save

This ensures users maintain full control and aren't dependent on AI.

---

## Error Handling

### Common Issues

**1. API Timeout**
- **Symptom:** Loading indicator spins indefinitely
- **Cause:** OpenAI API slow or unavailable
- **Handling:** 30-second timeout, error message to user

**2. Invalid JSON Response**
- **Symptom:** Error message after AI response
- **Cause:** AI response not valid JSON
- **Handling:** Catch JSON decode error, show user-friendly message

**3. Missing Context**
- **Symptom:** Generic or irrelevant goal suggestions
- **Cause:** Mission fields incomplete (empty focus or capability)
- **Handling:** Validate mission has required fields before calling agent

**4. Web Platform CORS**
- **Symptom:** API errors on web but not mobile
- **Cause:** OpenAI API doesn't support direct browser calls
- **Handling:** Route through Firebase Cloud Function (implemented)

### Error Messages

```dart
try {
  // AI call
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Could not generate suggestion: ${e.toString()}'),
      action: SnackBarAction(
        label: 'Retry',
        onPressed: _askGoalAgent,
      ),
    ),
  );
}
```

---

## Testing Considerations

### Manual Testing

1. **Context Variations:**
   - Mission with no existing goals
   - Mission with 1-2 existing goals
   - Mission with 5+ existing goals
   - Mission with all goals marked achieved

2. **Suggestion Quality:**
   - Title is clear and concise (5-10 words)
   - Description explains WHAT, not HOW
   - No tactical details or deadlines
   - Different from existing goals

3. **UI Behavior:**
   - Loading state displays during API call
   - Suggestion card appears after response
   - Form populates correctly on "Use This Suggestion"
   - Suggestion clears on dismiss
   - Manual creation still works without AI

4. **Edge Cases:**
   - Very short mission focus (< 10 words)
   - Very long mission focus (> 200 words)
   - Special characters in mission text
   - Network errors during API call

---

## Future Enhancements

### Potential Improvements

1. **Multiple Suggestions**
   - Generate 2-3 goal options
   - Let user choose best fit
   - Regenerate without dismissing

2. **Goal Prioritization**
   - AI suggests which goal to tackle first
   - Consider dependencies between goals
   - Highlight critical path goals

3. **Budget Estimation**
   - AI suggests budget range based on goal type
   - Historical data from similar goals
   - Optional budget recommendation

4. **Progress Tracking Integration**
   - AI suggests when goal might be achievable
   - Track goal progress over time
   - Alert when goals are off-track

5. **Learning from History**
   - Analyze user's achieved goals
   - Personalize suggestions based on patterns
   - Learn user's preferred goal structure

---

## Related Documentation

- [MISSION_AGENT.md](MISSION_AGENT.md) - Parent-level mission generation
- [OBJECTIVE_AGENT.md](OBJECTIVE_AGENT.md) - Child-level objective generation
- [FIRESTORE_DATA_MODEL.md](FIRESTORE_DATA_MODEL.md) - Database schema
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Testing procedures

---

## Summary

The Goal Agent transforms mission-level strategy into concrete, achievable goals through AI-powered suggestions. It maintains strategic focus while avoiding tactical details, generates context-aware recommendations, and provides an intuitive UI for reviewing and customizing suggestions. Users retain full control with the ability to edit AI suggestions or create goals manually, ensuring the agent enhances rather than replaces human strategic thinking.
