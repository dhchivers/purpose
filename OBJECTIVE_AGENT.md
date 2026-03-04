# Objective Agent Documentation

## Overview

The Objective Agent is an AI-powered system that generates tactical, measurable objective suggestions for goals within a user's strategic roadmap. It creates action-focused objectives with clear success criteria that directly contribute to achieving their parent goal.

**Purpose:** Transform goal-level outcomes into specific, measurable, actionable objectives that can be tracked to completion with quantifiable success metrics.

**Key Features:**
- Context-aware objective generation using mission, goal, and existing objectives
- Emphasis on measurable, quantifiable success criteria
- Single-click AI suggestion workflow with comprehensive context
- Tactical action focus (specific steps toward goal achievement)
- Duplicate avoidance through existing objective analysis
- Inline suggestion display with measurable requirement preview
- One-click form population or manual editing
- Manual objective creation always available

**AI Model:** OpenAI GPT-4o (via GeminiService)

---

## Objective Agent Philosophy

### What is an Objective?

An objective is a **specific, measurable, actionable task** that directly contributes to achieving a goal. Objectives are tactical, time-bounded, and include clear success criteria that define what "done" looks like.

**Core Principles:**
1. **Tactical Focus** - Objectives describe specific actions, not high-level outcomes
2. **Goal-Aligned** - Every objective directly advances its parent goal
3. **Measurable** - Success criteria must be quantifiable and verifiable
4. **Action-Oriented** - Clear about what needs to be done
5. **Time-Bounded** - Has a due date (user-defined)
6. **Cost-Tracked** - Actual time and money spent are recorded
7. **Completion-Verifiable** - Anyone can objectively determine if it's achieved

### Mission vs Goal vs Objective

| Aspect | Mission | Goal | Objective |
|--------|---------|------|-----------|
| **Timeframe** | 1-5 years | 3-12 months | 1-8 weeks |
| **Focus** | Structural transformation | Measurable outcome | Specific action |
| **Measure** | New capabilities developed | Achievement of target | Completion + metrics |
| **Specificity** | Broad direction | Clear outcome | Precise task |
| **Example** | "Scale to regional influence" | "Establish 5 key partnerships" | "Sign partnership MOU with Org X - Complete legal review and obtain 3 board signatures by March 31" |
| **Success Criteria** | Capability assessment | Goal achieved (binary) | Measurable requirement met |
| **AI Agent** | Mission Agent | Goal Agent | Objective Agent |

---

## Data Structures

### 1. Objective

```dart
class Objective {
  final String id;                        // Unique identifier
  final String goalId;                    // Parent goal reference
  final String missionId;                 // Denormalized mission reference
  final String strategyId;                // Denormalized strategy reference
  final String title;                     // Action-oriented name (5-10 words)
  final String description;               // What needs to be done and why
  final String measurableRequirement;     // Specific success metric/criteria
  final DateTime? dueDate;                // Target completion date (optional)
  final double costMonetary;              // Actual cost in monetary units
  final double costTime;                  // Actual time spent (hours/days)
  final bool achieved;                    // Completion status
  final DateTime? dateAchieved;           // When objective was completed
  final DateTime dateCreated;             // Creation timestamp
  final DateTime updatedAt;               // Last modification timestamp
}
```

**Purpose:** Represents a specific, measurable action that advances a goal toward completion. The objective defines not just what to do, but how to measure success.

**Key Fields:**
- `title` - Clear action statement (e.g., "Draft Partnership Agreement Template")
- `description` - Detailed explanation of the work and what success looks like
- `measurableRequirement` - **Critical field** - The quantifiable metric that defines completion
  - Examples: "3 board signatures obtained", "Page load time < 2 seconds", "50 users onboarded"
- `dueDate` - Target date (optional but recommended)
- `costMonetary` / `costTime` - Actual resources spent (tracked, not estimated)
- `achieved` - Boolean completion flag

**Key Methods:**
- `isOverdue` - Calculated: `dueDate != null && !achieved && DateTime.now() > dueDate`
- `daysUntilDue` - Calculated: Days remaining (negative if overdue)

**Example Objective:**
```dart
Objective(
  id: 'obj_abc123',
  goalId: 'goal_xyz',
  missionId: 'mission_001',
  strategyId: 'strat_001',
  title: 'Conduct Initial Stakeholder Interviews',
  description: 'Schedule and complete discovery interviews with key stakeholders to understand needs, pain points, and success criteria. Document findings in structured format.',
  measurableRequirement: 'Complete interviews with minimum 8 stakeholders and produce summary document',
  dueDate: DateTime(2026, 3, 31),
  costMonetary: 0.0,
  costTime: 0.0,
  achieved: false,
  dateAchieved: null,
  dateCreated: DateTime.now(),
  updatedAt: DateTime.now(),
)
```

---

## AI Generation

### Input Context

The Objective Agent receives deeper hierarchical context than the Goal Agent to ensure tactical relevance:

```dart
Future<Map<String, dynamic>> generateObjectiveSuggestion({
  required String missionTitle,        // E.g., "Mission 1 — Building Local Capacity"
  required String missionFocus,        // Mission's strategic focus
  required String goalTitle,           // E.g., "Establish Regional Advisory Board"
  required String goalDescription,     // What the goal aims to achieve
  required List<Map<String, dynamic>> existingObjectives, // Objectives already created
})
```

**Context Usage:**
- `missionTitle` + `missionFocus` - Provides strategic frame for tactical work
- `goalTitle` + `goalDescription` - Defines what outcome this objective serves
- `existingObjectives` - Prevents duplication and suggests logical next steps
  - Includes: title, description, measurableRequirement, achieved status
  - AI can see what work is done vs. pending

**Context Depth Comparison:**
```
Goal Agent receives:     Mission details + existing goals
Objective Agent receives:   Mission details + Goal details + existing objectives (with measurable requirements)
```

This deeper context allows the Objective Agent to:
1. Understand the full strategic hierarchy
2. Generate objectives that directly advance the specific goal
3. Suggest logical sequences (e.g., "research" before "implementation")
4. Avoid duplicating work already captured in existing objectives

---

### Prompt Strategy

The Objective Agent uses a detailed prompt that heavily emphasizes measurability:

**Key Instructions to AI:**

1. Suggest ONE new objective that is:
   - Specific and actionable
   - Directly contributes to achieving the goal
   - Measurable with clear success criteria
   - Different from existing objectives (avoid duplication)
   - A concrete step toward completing this goal

2. The objective should be tactical and action-focused

3. **MUST include:**
   - A clear, measurable requirement (the metric/criteria for success)
   - A specific description of what needs to be done
   - How achievement will be measured or verified

4. **DO NOT include:**
   - Due dates or time constraints (user will add these)
   - Cost estimates (user will add these)
   - Time/hour estimates (user will add these)
   - Vague or subjective measures

5. **The measurable requirement should be:**
   - Quantifiable where possible (numbers, percentages, specific outcomes)
   - Verifiable (can be checked objectively)
   - Closely aligned with the description
   - Clear enough that anyone could determine if it's achieved

6. Respond with valid JSON in this format:
```json
{
  "title": "Clear, action-oriented objective title (5-10 words)",
  "description": "Detailed description of what needs to be done and what achievement looks like (2-3 sentences)",
  "measurableRequirement": "Specific, quantifiable metric or criteria that defines success (e.g., 'Increase conversion rate from 2% to 5%', 'Complete onboarding for 50 users', 'Reduce load time to under 2 seconds')",
  "reasoning": "Brief explanation of why this objective is important for achieving the goal (1-2 sentences)"
}
```

**Measurable Requirement Examples:**

Good (Quantifiable):
- ✅ "Increase conversion rate from 2% to 5%"
- ✅ "Complete onboarding for 50 users"
- ✅ "Reduce page load time to under 2 seconds"
- ✅ "Obtain signatures from all 5 board members"
- ✅ "Publish 12 blog posts (minimum 800 words each)"

Poor (Vague):
- ❌ "Improve performance"
- ❌ "Increase engagement"
- ❌ "Make progress on partnerships"
- ❌ "Complete research"
- ❌ "Enhance user experience"

---

### AI Parameters

```dart
model: AIConfig.proModel          // GPT-4o
temperature: 0.7                  // Balanced creativity
maxTokens: 800                    // Sufficient for detailed response
responseFormat: {type: 'json_object'}  // Structured output
```

**Temperature Rationale:** 0.7 provides creative objective suggestions while maintaining tactical precision and measurability.

**Token Budget:** 800 tokens allows for comprehensive description and measurable requirement without excessive length.

---

## User Interface Flow

### 1. Objective Creation Dialog

Located in: `lib/features/mission/mission_detail_page.dart` (within goal expansion)

**Components:**
- "Ask Objective Agent for Suggestions" button (top of dialog)
- AI suggestion display card (when suggestion received)
- Title field (required)
- Description field (required, multi-line)
- **Measurable Requirement field** (required, multi-line) ← **Key field**
- Due Date picker (optional)
- Cost fields: Monetary $ and Time Hours (optional, side-by-side)
- Save/Cancel actions

**Dialog Width:** 500px (consistent with goal dialog)

---

### 2. Objective Agent Workflow

```
User expands goal card to see objectives
    ↓
User clicks "Add Objective" button
    ↓
Objective Creation Dialog opens
    ↓
User clicks "Ask Objective Agent for Suggestions"
    ↓
Loading state: "Thinking..." with spinner
    ↓
Backend fetches:
  - Mission document (title, focus)
  - Goal details (title, description)
  - Existing objectives for this goal (with measurable requirements)
    ↓
AI generates suggestion with:
  - Title
  - Description
  - Measurable Requirement ← Critical component
  - Reasoning
    ↓
Suggestion card displays with:
  - 💡 Title
  - 📝 Description
  - 📊 Measurable Requirement (highlighted box)
  - 💭 Reasoning
  - "Use This Suggestion" button
  - Dismiss button
    ↓
User clicks "Use This Suggestion"
    ↓
Form fields auto-populate:
  - Title ← suggestion.title
  - Description ← suggestion.description
  - Measurable Requirement ← suggestion.measurableRequirement
    ↓
User can edit or accept as-is
    ↓
User adds due date, cost estimates (optional) and saves
    ↓
Objective saved to Firestore
    ↓
Real-time update in objective list within goal card
```

---

### 3. Suggestion Display Card

**Visual Design:**
- Light blue background (primaryLight.withOpacity(0.05))
- Border: primaryLight.withOpacity(0.3)
- Lightbulb icon header
- Title in bold graphite (15px, weight 600)
- Description in gray medium (13px, height 1.4)
- **Measurable Requirement in highlighted box:**
  - Background: primary.withOpacity(0.1)
  - Track changes icon (🎯)
  - Primary color text (12px, weight 500)
  - Rounded corners (6px radius)
- Reasoning in italic gray with 💡 emoji (12px)
- Full-width "Use This Suggestion" button (primary color)
- Dismiss icon (X) in top-right corner

**State Management:**
```dart
class _ObjectiveDialogState {
  Map<String, dynamic>? _aiSuggestion;  // null = no suggestion
  bool _isLoadingSuggestion = false;     // true = AI request in progress
  
  final TextEditingController _titleController;
  final TextEditingController _descriptionController;
  final TextEditingController _measurableRequirementController;  // Key field
  final TextEditingController _costMonetaryController;
  final TextEditingController _costTimeController;
  DateTime? _dueDate;
}
```

---

### 4. Objective Display Card

Objectives are displayed in an expandable list within each goal card:

**Visual Design:**
- Border color: Green if achieved, Red if overdue, Blue if pending
- Status badge: "✓ Done" (green) or "⚠️ Overdue" (red)
- Title and description
- **Measurable requirement badge:**
  - Icon: 📊
  - Light blue background
  - Truncated if long (with ellipsis)
- Detail chips: Due date, Cost $, Time hours
- Action buttons: Edit, Delete (with confirmation)

**Overdue Warning:**
```dart
if (objective.isOverdue) {
  Container(
    padding: EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      '⚠️ Overdue',
      style: TextStyle(color: Colors.red),
    ),
  )
}
```

---

## Implementation Details

### 1. Objective Agent Method

**Location:** `lib/core/services/gemini_service.dart`

```dart
Future<Map<String, dynamic>> generateObjectiveSuggestion({
  required String missionTitle,
  required String missionFocus,
  required String goalTitle,
  required String goalDescription,
  required List<Map<String, dynamic>> existingObjectives,
}) async {
  final prompt = _buildObjectiveSuggestionPrompt(
    missionTitle: missionTitle,
    missionFocus: missionFocus,
    goalTitle: goalTitle,
    goalDescription: goalDescription,
    existingObjectives: existingObjectives,
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

**Prompt Builder:**
```dart
String _buildObjectiveSuggestionPrompt({
  required String missionTitle,
  required String missionFocus,
  required String goalTitle,
  required String goalDescription,
  required List<Map<String, dynamic>> existingObjectives,
}) {
  // Format existing objectives to show what's done vs. pending
  final existingObjectivesText = existingObjectives.isEmpty
      ? 'No existing objectives yet.'
      : existingObjectives.map((o) {
          final achieved = o['achieved'] == true ? '✓ Achieved' : '○ Not yet achieved';
          return '- ${o['title']}: ${o['description']}\n  Measurable: ${o['measurableRequirement']} [$achieved]';
        }).join('\n');

  return '''
You are a tactical planning assistant...
[Full prompt with mission context, goal context, existing objectives]
''';
}
```

---

### 2. UI Integration

**Location:** `lib/features/mission/mission_detail_page.dart`

**Key Methods:**

```dart
// Fetch comprehensive context and call AI
Future<void> _askObjectiveAgent() async {
  setState(() => _isLoadingSuggestion = true);
  
  try {
    final firestoreService = ref.read(firestoreServiceProvider);
    final geminiService = await ref.read(geminiServiceProvider.future);
    
    // Fetch mission context
    final mission = await firestoreService.getMissionDocument(widget.missionId);
    
    // Fetch goal context
    final goal = await firestoreService.getGoal(widget.goalId);
    
    // Fetch existing objectives with full details
    final existingObjectives = await firestoreService.getObjectivesForGoal(widget.goalId);
    
    // Map to format expected by AI
    final objectivesList = existingObjectives.map((obj) => {
      'title': obj.title,
      'description': obj.description,
      'measurableRequirement': obj.measurableRequirement,  // Critical field
      'achieved': obj.achieved,
    }).toList();
    
    // Call AI with full context
    final suggestion = await geminiService.generateObjectiveSuggestion(
      missionTitle: mission.mission,
      missionFocus: mission.focus,
      goalTitle: goal.title,
      goalDescription: goal.description,
      existingObjectives: objectivesList,
    );
    
    if (mounted) {
      setState(() {
        _aiSuggestion = suggestion;
        _isLoadingSuggestion = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoadingSuggestion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting suggestion: ${e.toString()}')),
      );
    }
  }
}

// Populate form from suggestion
void _applySuggestion() {
  if (_aiSuggestion == null) return;
  
  setState(() {
    _titleController.text = _aiSuggestion!['title'] ?? '';
    _descriptionController.text = _aiSuggestion!['description'] ?? '';
    _measurableRequirementController.text = _aiSuggestion!['measurableRequirement'] ?? '';
    _aiSuggestion = null;  // Clear suggestion
  });
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('✨ Suggestion applied! Edit as needed and add due date/costs.')),
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
      objectives/{objectiveId}/
        - id: string
        - goalId: string (denormalized)
        - missionId: string (denormalized)
        - strategyId: string (denormalized)
        - title: string
        - description: string
        - measurableRequirement: string ← Key field
        - dueDate: timestamp (nullable)
        - costMonetary: number
        - costTime: number
        - achieved: boolean
        - dateAchieved: timestamp (nullable)
        - dateCreated: timestamp
        - updatedAt: timestamp
```

### Key Operations

**Create Objective:**
```dart
await firestoreService.createObjective(
  goalId: goalId,
  missionId: missionId,
  strategyId: strategyId,
  title: title,
  description: description,
  measurableRequirement: measurableRequirement,  // Required
  dueDate: dueDate,  // Optional
  costMonetary: costMonetary,
  costTime: costTime,
);
```

**Update Objective:**
```dart
await firestoreService.updateObjective(
  objectiveId: objectiveId,
  updates: {
    'title': newTitle,
    'description': newDescription,
    'measurableRequirement': newMeasurable,
    'dueDate': newDueDate,
    // ... other fields
  },
);
```

**Mark Objective Complete:**
```dart
await firestoreService.updateObjective(
  objectiveId: objectiveId,
  updates: {
    'achieved': true,
    'dateAchieved': FieldValue.serverTimestamp(),
  },
);
```

**Stream Objectives for Goal:**
```dart
final objectivesStream = ref.watch(objectivesForGoalStreamProvider(goalId));

objectivesStream.when(
  data: (objectives) => /* Display objectives */,
  loading: () => /* Show loading */,
  error: (err, stack) => /* Show error */,
);
```

---

## Best Practices

### 1. When to Use Objective Agent

✅ **Good Use Cases:**
- Goal is clear but tactical steps aren't obvious
- Need measurable criteria for vague work
- Want AI perspective on logical task sequence
- Starting a new goal and need first objectives
- Stuck on how to make work measurable

❌ **Avoid When:**
- Objective is already crystal clear
- Task is routine or template-based
- Goal context is incomplete
- Measurable requirement is industry-standard

### 2. Editing AI Suggestions

**Critical: Review Measurable Requirements**

The AI often generates good measurable requirements, but always verify:
- ✅ Can you objectively determine when it's achieved?
- ✅ Is the metric specific enough? (numbers, deadlines, deliverables)
- ✅ Is it verifiable by someone else?
- ❌ Avoid subjective measures ("better", "improved", "enhanced")

**Customization Checklist:**
1. Adjust title to match your team's terminology
2. Expand description with specific context
3. **Refine measurable requirement** for precision
4. Add realistic due date
5. Estimate actual costs if known
6. Consider dependencies on other objectives

### 3. Manual Objective Creation

The Objective Agent is **optional** - users can create objectives manually:
- Expand goal card
- Click "Add Objective"
- Fill in all fields
- Skip AI agent button
- Save directly

This is often faster when you know exactly what to do.

---

## Measurable Requirements: Deep Dive

### Why Measurable Requirements Matter

The `measurableRequirement` field is what distinguishes objectives from vague "to-do" items. It answers: **"How will we know this is done?"**

**Without Measurable Requirement:**
```dart
Objective(
  title: "Improve website speed",
  description: "Make the website faster for better user experience",
  measurableRequirement: "",  // ❌ Unclear when this is done
)
```

**With Measurable Requirement:**
```dart
Objective(
  title: "Optimize Website Load Time",
  description: "Implement caching, compress assets, and optimize database queries to improve page load performance",
  measurableRequirement: "Homepage loads in under 2 seconds on 4G connection for 95th percentile users",  // ✅ Clear success criteria
)
```

### Types of Measurable Requirements

**1. Quantitative (Preferred):**
- Count: "Complete 10 user interviews"
- Percentage: "Increase conversion rate from 2% to 5%"
- Time: "Reduce load time to under 2 seconds"
- Money: "Generate $50,000 in revenue"
- Rate: "Achieve 95% uptime"

**2. Binary Deliverable:**
- "Contract signed by both parties"
- "Feature deployed to production"
- "Documentation published on website"
- "Approval received from legal team"

**3. Threshold:**
- "Minimum 8 stakeholders interviewed"
- "At least 50 users onboarded"
- "No more than 5% error rate"

**4. Composite:**
- "Complete 3 case studies (minimum 1000 words each) and publish on website"
- "Conduct user testing with 20 participants and achieve average SUS score above 70"

### Common Mistakes

❌ **Too Vague:**
- "Make progress on research"
- "Improve engagement"
- "Enhance user experience"

✅ **Better Alternatives:**
- "Complete literature review of 15 academic papers and produce 5-page summary"
- "Increase daily active users from 100 to 250"
- "Achieve average NPS score of 50+ based on survey of 100 users"

---

## Error Handling

### Common Issues

**1. Missing Mission/Goal Context**
- **Symptom:** Generic or irrelevant objective suggestions
- **Cause:** Mission or goal details incomplete
- **Handling:** Validate parent entities exist and have required fields
- **Prevention:** Ensure mission has focus field, goal has description

**2. API Timeout**
- **Symptom:** Loading indicator spins > 30 seconds
- **Cause:** OpenAI API slow or unavailable
- **Handling:** Show timeout error, offer retry button
- **User Action:** Retry or create objective manually

**3. Invalid JSON Response**
- **Symptom:** Error message after AI response received
- **Cause:** AI response not valid JSON (rare with json_object format)
- **Handling:** Catch JSON decode error, log full response, show friendly message
- **User Action:** Retry or create manually

**4. Vague Measurable Requirements**
- **Symptom:** AI returns subjective measures like "improved" or "better"
- **Cause:** Prompt not emphasizing quantifiability enough (rare)
- **Handling:** User edits measurable requirement before saving
- **Prevention:** Prompt heavily emphasizes quantifiable metrics

**5. Web Platform CORS**
- **Symptom:** API errors on web but not mobile
- **Cause:** OpenAI API doesn't support direct browser calls
- **Solution:** Route through Firebase Cloud Function (implemented in `_makeOpenAIRequest`)

### Error Messages

```dart
try {
  // AI call
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not generate objective suggestion: ${e.toString()}'),
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _askObjectiveAgent,
        ),
      ),
    );
  }
}
```

---

## Testing Considerations

### Manual Testing

**1. Context Variations:**
- Goal with no existing objectives
- Goal with 1-2 objectives
- Goal with 5+ objectives
- Goal with mix of achieved and pending objectives
- Goal with all objectives marked achieved

**2. Suggestion Quality:**
- Title is action-oriented (5-10 words)
- Description explains what to do and why
- **Measurable requirement is quantifiable and verifiable**
- No due dates or cost estimates in suggestion
- Different from existing objectives

**3. Measurable Requirement Quality:**
- Contains numbers, percentages, or specific deliverables
- Anyone can determine if requirement is met
- Aligned with description
- Not subjective ("better", "improved")

**4. UI Behavior:**
- Loading state displays during API call
- Button disabled during loading
- Suggestion card appears with all 4 fields
- Measurable requirement shown in highlighted box
- Form populates all 3 fields on "Use This Suggestion"
- Suggestion clears on dismiss
- Manual creation works without AI

**5. Edge Cases:**
- Very short goal description (< 10 words)
- Very long goal description (> 300 words)
- Special characters in goal/mission text
- Network errors during API call
- Objective dialog opened when mission/goal recently created

### Automated Testing

**Unit Tests:**
```dart
test('generateObjectiveSuggestion returns valid structure', () async {
  final result = await geminiService.generateObjectiveSuggestion(
    missionTitle: 'Test Mission',
    missionFocus: 'Test Focus',
    goalTitle: 'Test Goal',
    goalDescription: 'Test Description',
    existingObjectives: [],
  );
  
  expect(result, contains('title'));
  expect(result, contains('description'));
  expect(result, contains('measurableRequirement'));
  expect(result, contains('reasoning'));
});

test('Objective isOverdue works correctly', () {
  final overdueObj = Objective(
    /* ... */
    dueDate: DateTime.now().subtract(Duration(days: 1)),
    achieved: false,
  );
  
  expect(overdueObj.isOverdue, true);
});
```

---

## Performance Considerations

### Response Time

**Typical AI Call Duration:**
- Fast: 2-4 seconds (light load)
- Normal: 4-8 seconds (moderate load)
- Slow: 8-15 seconds (high load or complex prompt)
- Timeout: > 30 seconds (error handling triggers)

**Optimization Strategies:**
1. Show loading indicator immediately
2. Disable button during request
3. Cache mission/goal data (already fetched for display)
4. Batch objective fetching with goals (already implemented)

### Token Usage

**Input Tokens (Approximate):**
- Prompt template: ~500 tokens
- Mission context: ~50 tokens
- Goal context: ~50 tokens
- Existing objectives: ~100 tokens per objective
- **Total:** ~700 + (100 × num_objectives)

**Output Tokens:**
- Typical response: 150-250 tokens
- Max allowed: 800 tokens

**Cost per Request:**
- GPT-4o pricing: ~$0.02-0.04 per request
- Budget consideration for high-volume users

---

## Future Enhancements

### Potential Improvements

**1. Multiple Suggestions in Sequence**
- Generate 2-3 next logical objectives
- Show sequence/dependency between them
- User can add all or select favorites

**2. Smart Sequencing**
- AI identifies which objectives should be done first
- Flags dependencies between objectives
- Suggests critical path through goal

**3. Due Date Recommendations**
- Based on objective complexity
- Historical data from similar objectives
- Mission timeline constraints

**4. Effort Estimation**
- AI suggests likely time/cost based on description
- Learn from user's actual costs over time
- Warn if objective seems too large (should be multiple objectives)

**5. Automatic Measurable Requirement Validation**
- Parse measurable requirement for quantitative terms
- Flag subjective language for user review
- Suggest improvements to vague requirements

**6. Template Library**
- Save commonly used objectives as templates
- Suggest from templates before AI call
- Customize templates with AI

**7. Dependency Management**
- Link objectives that depend on each other
- Block starting objective B until A is complete
- Visualize dependency graph

**8. Progress Tracking**
- Partial completion percentages
- Automatic updates from integrated tools
- Real-time collaboration on shared objectives

---

## Integration Points

### With Goal Agent

```
Mission
  ├─ Goal 1 (Goal Agent generates this)
  │   ├─ Objective 1.1 (Objective Agent generates this)
  │   ├─ Objective 1.2 (Objective Agent generates this)
  │   └─ Objective 1.3 (Objective Agent generates this)
  └─ Goal 2 (Goal Agent generates this)
      ├─ Objective 2.1 (Objective Agent generates this)
      └─ Objective 2.2 (Objective Agent generates this)
```

**Context Flow:**
```
Mission Agent → Mission Document
     ↓
Goal Agent receives: Mission context
Goal Agent generates: Goal
     ↓
Objective Agent receives: Mission context + Goal context
Objective Agent generates: Objective (with measurable requirement)
```

### With Firestore

**Real-time Updates:**
- Objectives stream updates immediately when created/edited
- Expandable goal card shows live objective list
- Overdue status calculated client-side (isOverdue getter)
- Badge colors update based on achievement status

**Denormalization:**
- `missionId` and `strategyId` stored in Objective
- Enables querying objectives across missions/strategies
- Indexes support efficient queries

---

## Related Documentation

- [GOAL_AGENT.md](GOAL_AGENT.md) - Parent-level goal generation
- [MISSION_AGENT.md](MISSION_AGENT.md) - Grandparent-level mission generation
- [FIRESTORE_DATA_MODEL.md](FIRESTORE_DATA_MODEL.md) - Database schema
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Testing procedures

---

## Summary

The Objective Agent transforms goal-level outcomes into tactical, measurable actions with clear success criteria. It emphasizes quantifiable measurable requirements that define objective completion, provides deep hierarchical context awareness (mission → goal → existing objectives), and delivers an intuitive UI for reviewing and customizing suggestions. The `measurableRequirement` field is the defining feature that makes objectives trackable and verifiable, distinguishing them from vague tasks. Users retain full control with editing capabilities and manual creation options, ensuring the agent enhances rather than replaces human tactical planning.
