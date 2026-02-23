# Value Agent Documentation

## Overview

The Value Agent is an AI-powered system that guides users through a comprehensive 5-phase process to clarify, refine, and operationalize their personal values. The agent uses OpenAI's GPT-4o model to generate contextual questions and synthesize user responses into actionable value statements.

**Purpose:** Transform abstract value concepts into concrete, personal statements with behavioral guidance and strategic context.

**Key Features:**
- Progressive multi-phase refinement process
- AI-generated contextual questions based on user responses
- Dynamic label refinement through phases
- Comprehensive value summary for strategy development
- Multiple statement styles for final selection
- Full database persistence with session tracking

---

## Architecture

### Core Components

1. **GeminiService** (`lib/core/services/gemini_service.dart`)
   - AI service handling all OpenAI API interactions
   - Generates questions, summaries, and final statements
   - Routes through Firebase Cloud Functions for web compatibility

2. **ValueCreationFlowPage** (`lib/features/values/value_creation_flow_page.dart`)
   - UI orchestration for the 5-phase flow
   - Manages user selections and phase progression
   - Handles session persistence

3. **ValueCreationSession** (`lib/core/models/value_creation_session.dart`)
   - Data model tracking user's journey
   - Stores questions, answers, and AI-generated content
   - Serializable for Firestore persistence

4. **FirestoreService** (`lib/core/services/firestore_service.dart`)
   - Database operations for sessions and completed values
   - Progressive saves after each phase
   - CRUD operations for UserValue objects

---

## Flow Overview

```
Phase 1: Seed Selection
    ↓
Phase 2: Clarification (AI generates 3 questions)
    ↓
Phase 3: Scope Narrowing (AI generates refined label + 3 questions)
    ↓
Phase 4: Friction & Sacrifice (AI generates refined label + 3 questions)
    ↓
Phase 5: Operationalization (AI generates refined label + 3 questions)
    ↓
AI Summary Generation (strategic context for future use)
    ↓
Final Statement Generation (3 statement styles)
    ↓
User Selection & Optional Editing
    ↓
Save as UserValue (with reference to session)
```

**Total Questions:** 15 multiple choice (3 per phase × 5 phases)
**Total AI Calls:** 6 (one per phase + summary + final statements)
**Total Refinements:** Up to 3 label refinements (phases 3, 4, 5)

---

## Data Models

### ValueCreationSession

Tracks the complete user journey through value creation.

```dart
class ValueCreationSession {
  final String id;                    // Unique session ID
  final String userId;                // User who created this
  final String seedValue;             // Original value selected (Phase 1)
  final DateTime startedAt;           // When session began
  final DateTime? completedAt;        // When session was finalized
  final int currentPhase;             // 1-5 for phases, 6 for final selection
  
  // Phase 2: Clarification
  final List<MultipleChoiceQuestion>? phase2Questions;
  final List<String>? phase2Answers;
  
  // Phase 3: Scope Narrowing
  final List<MultipleChoiceQuestion>? phase3Questions;
  final List<String>? phase3Answers;
  final String? refinedValuePhase3;   // First label refinement
  
  // Phase 4: Friction & Sacrifice
  final List<MultipleChoiceQuestion>? phase4Questions;
  final List<String>? phase4Answers;
  final String? refinedValuePhase4;   // Second label refinement
  
  // Phase 5: Operationalization
  final List<MultipleChoiceQuestion>? phase5Questions;
  final List<String>? phase5Answers;
  final String? refinedValuePhase5;   // Final label refinement
  final String? valueSummary;         // AI-generated strategic summary
  
  // Final selection
  final List<ValueOption>? finalValueOptions;  // 3 statement options
  final int? selectedOptionIndex;     // Which option user chose
  final String? customStatement;      // User's edited statement (if any)
}
```

### MultipleChoiceQuestion

Structure for all phase questions.

```dart
class MultipleChoiceQuestion {
  final String question;     // The question text
  final List<String> options; // 4 answer options
}
```

### ValueOption

Final statement options presented to user.

```dart
class ValueOption {
  final String label;        // "Direct", "Principle", or "Meaning"
  final String statement;    // The actual value statement
}
```

### UserValue

Final completed value stored in user's profile.

```dart
class UserValue {
  final String id;
  final String userId;
  final String title;           // Final refined label
  final String statement;       // Selected/edited statement
  final String? sessionId;      // Reference to ValueCreationSession
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

---

## Phase-by-Phase Breakdown

### Phase 1: Seed Selection

**Purpose:** User selects initial value from predefined list.

**User Action:** Tap on value seed card (e.g., "Integrity", "Growth", "Connection")

**No AI Call:** Direct selection, no generation needed.

**Seeds Available:** Fetched from Firestore `value_seeds` collection, including:
- Integrity
- Growth
- Connection
- Authenticity
- Achievement
- Balance
- Creativity
- Service
- And 40+ more...

**Transition:** After selection, AI generates Phase 2 questions.

---

### Phase 2: Clarification

**Purpose:** Understand what this value personally means to the user.

**AI Generation:** 3 multiple choice questions with 4 options each.

#### Agent Prompt

```
You are a values clarification expert helping a user explore what a value truly means to them.

The user has selected "$seedValue" as a value they want to develop and articulate.

Generate exactly 3 multiple choice questions that will help them:
1. Define what this value personally means to them (not just dictionary definition)
2. Identify how this value shows up or could show up in their life
3. Connect the value to their deeper motivations or aspirations

Each question should have 4 answer options that represent different perspectives or interpretations.

Questions should be:
- Thought-provoking and insightful
- Personal and introspective
- Have options that feel authentic and meaningful
- Focused on the user's unique interpretation and experience

Return ONLY a JSON array of objects with this exact structure:
[
  {
    "question": "Question 1 text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"]
  },
  {
    "question": "Question 2 text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"]
  },
  {
    "question": "Question 3 text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"]
  }
]

No additional text or formatting, just the JSON array.
```

#### Model Parameters
- **Model:** GPT-4o (via AIConfig.defaultModel)
- **Temperature:** 0.8 (higher for creative question generation)
- **Max Tokens:** 800

#### Return Structure

```json
[
  {
    "question": "What does 'Integrity' mean to you personally?",
    "options": [
      "Living authentically according to my principles",
      "Achieving specific outcomes or goals",
      "The way I treat and relate to others",
      "How I develop and improve myself"
    ]
  },
  {
    "question": "When is this value most important to you?",
    "options": [
      "When making major life decisions",
      "In my daily interactions and routines",
      "During challenging or stressful times",
      "When pursuing my goals and aspirations"
    ]
  },
  {
    "question": "How would you like this value to guide your life?",
    "options": [
      "As a constant compass for all decisions",
      "As inspiration for specific goals or projects",
      "As a foundation for my relationships",
      "As a measure of my personal growth"
    ]
  }
]
```

#### Fallback Behavior

If AI generation fails, the system provides generic clarification questions using the seed value.

#### User Action

User selects one option for each of the 3 questions.

#### Persistence

After user completes Phase 2:
1. Answers stored in `session.phase2Answers` (array of selected option text)
2. Session saved to Firestore
3. Proceeds to Phase 3

---

### Phase 3: Scope Narrowing

**Purpose:** Refine the value label and identify specific contexts where it applies.

**AI Generation:** 
- Refined value label (2-4 words)
- 3 multiple choice questions with 4 options each

**Context Used:** Phase 2 questions + answers

#### Agent Prompt

```
You are a values clarification expert helping a user narrow down and refine their understanding of a value.

Original Value: "$seedValue"

The user has answered clarification questions:
Q: <Phase 2 Question 1>
A: <Phase 2 Answer 1>

Q: <Phase 2 Question 2>
A: <Phase 2 Answer 2>

Q: <Phase 2 Question 3>
A: <Phase 2 Answer 3>

Based on their responses, you need to:
1. Generate a refined, more specific label for this value (2-4 words)
2. Create 3 multiple choice questions that help narrow the scope further

The refined label should:
- Capture the essence of what they described
- Be more specific than the original "$seedValue"
- Feel personal and authentic to their responses
- Be concise (2-4 words)

The 3 questions should:
- Help identify specific contexts where this value applies
- Clarify boundaries or limits of this value
- Distinguish what this value is vs. what it's not for them
- Each question should have 4 answer options

Return ONLY a JSON object in this exact format:
{
  "refinedLabel": "Your refined 2-4 word label here",
  "questions": [
    {
      "question": "Question 1 text here?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    },
    {
      "question": "Question 2 text here?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    },
    {
      "question": "Question 3 text here?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    }
  ]
}

No additional text, just the JSON object.
```

#### Model Parameters
- **Model:** GPT-4o
- **Temperature:** 0.8
- **Max Tokens:** 1000

#### Return Structure

```json
{
  "refinedLabel": "Authentic Living",
  "questions": [
    {
      "question": "In what areas of your life does this value matter most?",
      "options": [
        "Career and professional development",
        "Personal relationships and family",
        "Personal growth and learning",
        "Community and social impact"
      ]
    },
    {
      "question": "What are the limits or boundaries of this value for you?",
      "options": [
        "It applies to almost everything I do",
        "It's context-specific to certain situations",
        "It's balanced with other important values",
        "It's aspirational, not yet fully realized"
      ]
    },
    {
      "question": "How is your interpretation unique?",
      "options": [
        "I emphasize the practical application",
        "I focus on the emotional or relational aspects",
        "I connect it to my long-term vision",
        "I balance it with competing priorities"
      ]
    }
  ]
}
```

#### Fallback Behavior

If AI generation fails:
- **Refined Label:** "Personal {seedValue}"
- Generic scope narrowing questions

#### User Action

User sees refined label and answers 3 new questions.

#### Persistence

After completion:
1. `session.refinedValuePhase3` = refined label
2. `session.phase3Questions` = generated questions
3. `session.phase3Answers` = user's selected options
4. Session saved to Firestore
5. Proceeds to Phase 4

---

### Phase 4: Friction & Sacrifice

**Purpose:** Test the value against trade-offs and explore commitment depth.

**AI Generation:**
- Further refined value label (or keep same)
- 3 multiple choice questions about sacrifice and commitment

**Context Used:** Phase 2 + Phase 3 questions and answers, plus current refined label

#### Agent Prompt

```
You are a values clarification expert helping a user test the strength and commitment to their value.

Original Value: "$seedValue"
Currently Refined As: "$refinedLabel"

The user has answered scope narrowing questions:
Q: <Phase 3 Question 1>
A: <Phase 3 Answer 1>

Q: <Phase 3 Question 2>
A: <Phase 3 Answer 2>

Q: <Phase 3 Question 3>
A: <Phase 3 Answer 3>

Based on their responses, you need to:
1. Test this value against friction and sacrifice scenarios
2. Create 3 multiple choice questions that explore trade-offs and commitment
3. Optionally provide a further refined label (2-4 words) if needed, or keep it the same

The questions should:
- Present realistic scenarios where this value conflicts with other priorities
- Test willingness to sacrifice or face difficulty
- Reveal the true depth of their commitment
- Help distinguish this value from superficial preferences
- Each question should have 4 answer options representing different levels of commitment

Return ONLY a JSON object in this exact format:
{
  "refinedLabel": "Keep same or provide more refined 2-4 word label",
  "questions": [
    {
      "question": "Question 1 about sacrifice or trade-off?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    },
    {
      "question": "Question 2 about commitment or difficulty?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    },
    {
      "question": "Question 3 about boundaries or limits?",
      "options": ["Option A", "Option B", "Option C", "Option D"]
    }
  ]
}

No additional text, just the JSON object.
```

#### Model Parameters
- **Model:** GPT-4o
- **Temperature:** 0.8
- **Max Tokens:** 1000

#### Return Structure

```json
{
  "refinedLabel": "Authentic Living",
  "questions": [
    {
      "question": "What would you be willing to sacrifice to honor this value?",
      "options": [
        "Time and immediate comfort",
        "Some relationships or social approval",
        "Career opportunities or financial gain",
        "Personal desires or preferences"
      ]
    },
    {
      "question": "When this value conflicts with other priorities, how do you respond?",
      "options": [
        "I consistently choose this value over others",
        "I seek creative solutions to honor both",
        "I compromise based on the situation",
        "I struggle with the tension but stay committed"
      ]
    },
    {
      "question": "How would you continue living this value during difficult times?",
      "options": [
        "Through small daily actions and reminders",
        "By connecting with others who share this value",
        "By focusing on long-term meaning over short-term pain",
        "By adapting how I express it while maintaining the core"
      ]
    }
  ]
}
```

#### Fallback Behavior

If AI generation fails:
- **Refined Label:** Same as Phase 3
- Generic friction/sacrifice questions

#### User Action

User sees potentially refined label and answers 3 questions about trade-offs.

#### Persistence

After completion:
1. `session.refinedValuePhase4` = refined label (may be same as Phase 3)
2. `session.phase4Questions` = generated questions
3. `session.phase4Answers` = user's selected options
4. Session saved to Firestore
5. Proceeds to Phase 5

---

### Phase 5: Operationalization

**Purpose:** Translate the value into concrete behaviors, boundaries, and measurement criteria.

**AI Generation:**
- Final refined value label (or keep same)
- 3 multiple choice questions about behaviors, boundaries, and measurement

**Context Used:** Phase 4 questions and answers, plus current refined label

#### Agent Prompt

```
You are helping a user operationalize their personal value: "$refinedLabel" (originally stemming from "$seedValue").

They have just completed Phase 4 (Friction & Sacrifice), answering questions about their commitment:
Q: <Phase 4 Question 1>
A: <Phase 4 Answer 1>

Q: <Phase 4 Question 2>
A: <Phase 4 Answer 2>

Q: <Phase 4 Question 3>
A: <Phase 4 Answer 3>

Now in Phase 5, we need to make this value OPERATIONAL - translating commitment into concrete action.

Generate 3 multiple choice questions that explore:
1. BEHAVIORS: What specific actions demonstrate this value in daily life?
2. BOUNDARIES: In what contexts does this value apply, and where are its limits?
3. MEASUREMENT: How will they know if they're living according to this value?

Each question should have 4 options that represent different levels of specificity or practical application.

Return ONLY a JSON object in this exact format:
{
  "refinedLabel": "<refined label (may be same as input or further refined if needed)>",
  "questions": [
    {
      "question": "<question 1 about behaviors>",
      "options": ["<option 1>", "<option 2>", "<option 3>", "<option 4>"]
    },
    {
      "question": "<question 2 about boundaries>",
      "options": ["<option 1>", "<option 2>", "<option 3>", "<option 4>"]
    },
    {
      "question": "<question 3 about measurement>",
      "options": ["<option 1>", "<option 2>", "<option 3>", "<option 4>"]
    }
  ]
}

No additional text, just the JSON object.
```

#### Model Parameters
- **Model:** GPT-4o
- **Temperature:** 0.8
- **Max Tokens:** 1000

#### Return Structure

```json
{
  "refinedLabel": "Authentic Living",
  "questions": [
    {
      "question": "What daily actions would best demonstrate Authentic Living in your life?",
      "options": [
        "Specific morning and evening routines",
        "Actions when making important decisions",
        "How I interact with others regularly",
        "Regular reflection and self-assessment"
      ]
    },
    {
      "question": "When and where does this value apply most strongly?",
      "options": [
        "In all areas of life without exception",
        "Primarily in relationships with close ones",
        "Mostly in professional and public contexts",
        "In specific situations when stakes are high"
      ]
    },
    {
      "question": "How will you measure whether you're living according to Authentic Living?",
      "options": [
        "Daily check-ins and journaling",
        "Monthly review of specific behaviors",
        "Feedback from people I trust",
        "Internal sense of alignment and peace"
      ]
    }
  ]
}
```

#### Fallback Behavior

If AI generation fails:
- **Refined Label:** Same as Phase 4
- Generic operationalization questions

#### User Action

User sees final refined label and answers 3 questions about concrete implementation.

#### Persistence

After completion:
1. `session.refinedValuePhase5` = final refined label
2. `session.phase5Questions` = generated questions
3. `session.phase5Answers` = user's selected options
4. System immediately triggers two parallel AI generations:
   - Value Summary (strategic context)
   - Final Statement Options (3 styles)
5. Session saved to Firestore with both additions
6. Proceeds to Final Selection phase

---

## Value Summary Generation

**Purpose:** Create strategic context about the user's value for future strategy development features.

**Timing:** Triggered immediately after Phase 5 completion, before Final Selection.

**Context Used:** ALL 5 phases of questions and answers

#### Agent Prompt

```
You are summarizing a user's personal value that they've refined through a comprehensive 5-phase process.

Original Value Seed: "$seedValue"
Final Refined Label: "$refinedLabel"

=== PHASE 2: CLARIFICATION ===
Q: <Phase 2 Question 1>
A: <Phase 2 Answer 1>
Q: <Phase 2 Question 2>
A: <Phase 2 Answer 2>
Q: <Phase 2 Question 3>
A: <Phase 2 Answer 3>

=== PHASE 3: SCOPE NARROWING ===
Q: <Phase 3 Question 1>
A: <Phase 3 Answer 1>
Q: <Phase 3 Question 2>
A: <Phase 3 Answer 2>
Q: <Phase 3 Question 3>
A: <Phase 3 Answer 3>

=== PHASE 4: FRICTION & SACRIFICE ===
Q: <Phase 4 Question 1>
A: <Phase 4 Answer 1>
Q: <Phase 4 Question 2>
A: <Phase 4 Answer 2>
Q: <Phase 4 Question 3>
A: <Phase 4 Answer 3>

=== PHASE 5: OPERATIONALIZATION ===
Q: <Phase 5 Question 1>
A: <Phase 5 Answer 1>
Q: <Phase 5 Question 2>
A: <Phase 5 Answer 2>
Q: <Phase 5 Question 3>
A: <Phase 5 Answer 3>

Create a comprehensive summary (3-4 paragraphs) that captures:

1. CORE ESSENCE: What this value fundamentally means to the user, beyond the label itself
2. PERSONAL APPLICATION: How this value specifically applies in their life context based on their answers
3. BEHAVIORAL MANIFESTATION: The concrete ways this value shows up in their actions and decisions
4. STRATEGIC RELEVANCE: How this value can guide future goal-setting, decision-making, and life planning

Write in second person ("Your value of..."). Be insightful, connecting the dots between their answers to reveal deeper patterns. This summary will be used to inform future strategic planning and goal development.

Return only the summary text, no JSON or additional formatting.
```

#### Model Parameters
- **Model:** GPT-4o
- **Temperature:** 0.7 (balanced insight/consistency)
- **Max Tokens:** 600

#### Return Structure

Plain text string (3-4 paragraphs), example:

```
Your value of Authentic Living represents a deeply personal commitment to aligning your external actions with your internal truth. Through your exploration, you've revealed that this isn't about perfection or rigid consistency, but rather about honest self-reflection and the courage to show up as your genuine self even when it's uncomfortable. You've identified that this value matters most in your close relationships and major life decisions, where the stakes are high and the temptation to compromise is strongest.

Your commitment to Authentic Living is evidenced by your willingness to sacrifice immediate social comfort and even some career opportunities when they conflict with your core principles. You've shown that you're not seeking authenticity as a performative act, but as a foundational approach to life that guides how you make decisions, how you relate to others, and how you measure personal success. The tension between being authentic and being accepted isn't lost on you—you've acknowledged this friction and chosen to navigate it through small, consistent actions rather than grand gestures.

The concrete ways this value manifests in your life include daily reflection practices, honest conversations with trusted friends, and a commitment to making decisions based on internal alignment rather than external validation. You've identified that your measure of success isn't about visible achievements but about an internal sense of peace and integrity. This suggests that Authentic Living functions as both a compass and a barometer for you—guiding your choices and helping you assess whether you're on the right path.

As you move forward with strategic planning, Authentic Living can serve as a powerful filter for opportunities and relationships. When evaluating goals, you can ask whether they align with this value or require you to compromise it. When facing difficult decisions, you can check in with whether each option feels authentic to who you are. This value provides both direction and boundaries, helping you invest your time and energy in ways that feel genuinely meaningful rather than simply impressive or socially acceptable.
```

#### Fallback Behavior

If AI generation fails, returns generic summary using the refined label:

```
Your value of {refinedLabel} represents a core principle that guides your decisions and actions. Through your exploration, you've identified specific ways this value manifests in your daily life and the boundaries within which it operates.

Your commitment to {refinedLabel} reflects a deeper understanding of what matters most to you. You've considered the trade-offs and sacrifices you're willing to make to honor this value, demonstrating genuine conviction.

The concrete behaviors and measures you've identified will help you track alignment with {refinedLabel} over time. This operational clarity transforms an abstract principle into actionable guidance.

As you move forward with strategic planning, {refinedLabel} can serve as a filter for opportunities and a compass for difficult decisions, ensuring your goals and actions remain authentic to who you are.
```

#### Storage

Stored in `session.valueSummary` field and persisted to Firestore.

#### Usage

This summary is designed to be queried by future strategy development features:
- Goal-setting AI can reference it to suggest aligned goals
- Decision frameworks can use it to assess value alignment
- Opportunity filtering can compare against value summaries
- Pattern recognition across multiple values can identify conflicts or synergies

---

## Final Statement Generation

**Purpose:** Generate 3 distinct value statement styles for user to choose from.

**Timing:** Triggered immediately after Phase 5 completion (parallel with Value Summary).

**Context Used:** ALL 5 phases of questions and answers, plus final refined label

#### Agent Prompt

```
You are helping a user finalize their personal value statement.

Original Value Seed: "$seedValue"
Refined Label: "$refinedLabel"

They have completed a comprehensive 5-phase value clarification process:

=== PHASE 2: CLARIFICATION ===
Q: <Phase 2 Question 1>
A: <Phase 2 Answer 1>
Q: <Phase 2 Question 2>
A: <Phase 2 Answer 2>
Q: <Phase 2 Question 3>
A: <Phase 2 Answer 3>

=== PHASE 3: SCOPE NARROWING ===
Q: <Phase 3 Question 1>
A: <Phase 3 Answer 1>
Q: <Phase 3 Question 2>
A: <Phase 3 Answer 2>
Q: <Phase 3 Question 3>
A: <Phase 3 Answer 3>

=== PHASE 4: FRICTION & SACRIFICE ===
Q: <Phase 4 Question 1>
A: <Phase 4 Answer 1>
Q: <Phase 4 Question 2>
A: <Phase 4 Answer 2>
Q: <Phase 4 Question 3>
A: <Phase 4 Answer 3>

=== PHASE 5: OPERATIONALIZATION ===
Q: <Phase 5 Question 1>
A: <Phase 5 Answer 1>
Q: <Phase 5 Question 2>
A: <Phase 5 Answer 2>
Q: <Phase 5 Question 3>
A: <Phase 5 Answer 3>

Now generate 3 DISTINCT value statement options. Each should:
- Capture the essence of "$refinedLabel"
- Reflect their journey through all 5 phases
- Be authentic to their answers and choices
- Be memorable and actionable
- Be 1-3 sentences long

Create 3 different STYLES:
1. DIRECT: Clear, straightforward statement of the value
2. PRINCIPLE: Frame as a guiding principle or commitment
3. MEANING: Connect to deeper purpose and life meaning

Return ONLY a JSON array with this exact structure:
[
  {
    "label": "Direct",
    "statement": "<direct value statement here>"
  },
  {
    "label": "Principle",
    "statement": "<principle-based value statement here>"
  },
  {
    "label": "Meaning",
    "statement": "<meaning-integrated value statement here>"
  }
]

No additional text, just the JSON array.
```

#### Model Parameters
- **Model:** GPT-4o
- **Temperature:** 0.8 (creative statement generation)
- **Max Tokens:** 800

#### Return Structure

```json
[
  {
    "label": "Direct",
    "statement": "I value Authentic Living and commit to being true to myself in all my relationships and decisions, even when it's uncomfortable."
  },
  {
    "label": "Principle",
    "statement": "I am guided by Authentic Living, using internal alignment as my measure of success rather than external validation, and choosing honest self-expression over social approval."
  },
  {
    "label": "Meaning",
    "statement": "Through Authentic Living, I create a life of integrity and peace, where my actions reflect my deepest truths and my relationships are built on genuine connection rather than performance."
  }
]
```

#### Fallback Behavior

If AI generation fails:

```json
[
  {
    "label": "Direct",
    "statement": "I value {refinedLabel} and commit to living according to it every day."
  },
  {
    "label": "Principle",
    "statement": "I am guided by {refinedLabel}, using it as a compass for my decisions and actions."
  },
  {
    "label": "Meaning",
    "statement": "Through {refinedLabel}, I find deeper meaning and purpose in my life."
  }
]
```

#### Storage

Stored in `session.finalValueOptions` array and persisted to Firestore.

---

## Final Selection Phase

**Purpose:** User selects preferred statement style and optionally edits it.

**UI Components:**
1. Display of final refined label
2. Three statement cards (Direct, Principle, Meaning)
3. Edit button for selected statement
4. Confirmation button

**User Actions:**

1. **Select Statement Style**
   - User taps one of the three statement cards
   - Selected card highlights
   - `session.selectedOptionIndex` = index (0, 1, or 2)

2. **Optional: Edit Statement**
   - User taps "Edit" button
   - TextField appears with editable statement text
   - User can modify the statement
   - `session.customStatement` = edited text (only if user makes changes)

3. **Confirm and Save**
   - User taps "Complete Value" button
   - System creates UserValue object:
     ```dart
     UserValue(
       id: generated_id,
       userId: current_user_id,
       title: session.refinedValuePhase5,  // Final refined label
       statement: session.customStatement ?? selectedOptionStatement,
       sessionId: session.id,  // Reference for detail view
       createdAt: DateTime.now(),
       updatedAt: DateTime.now(),
     )
     ```
   - Saves UserValue to Firestore
   - Increments user's valueCount
   - Marks session as complete (`completedAt` = now)
   - Saves updated session to Firestore
   - Invalidates userValuesProvider cache (refresh list)
   - Navigates to /values page

**Persistence:**
- Both ValueCreationSession and UserValue saved to Firestore
- Session contains complete journey (questions, answers, summaries)
- UserValue is the "final product" displayed in user's profile
- sessionId links them for detail/history viewing

---

## Database Schema

### Collections

#### `value_creation_sessions`

Stores complete user journey through value creation.

**Document Structure:**
```
{
  id: string,
  userId: string,
  seedValue: string,
  startedAt: timestamp,
  completedAt: timestamp | null,
  currentPhase: number,
  
  // Phase 2
  phase2Questions: [
    { question: string, options: string[] }
  ],
  phase2Answers: string[],
  
  // Phase 3
  phase3Questions: [
    { question: string, options: string[] }
  ],
  phase3Answers: string[],
  refinedValuePhase3: string,
  
  // Phase 4
  phase4Questions: [
    { question: string, options: string[] }
  ],
  phase4Answers: string[],
  refinedValuePhase4: string,
  
  // Phase 5
  phase5Questions: [
    { question: string, options: string[] }
  ],
  phase5Answers: string[],
  refinedValuePhase5: string,
  valueSummary: string,
  
  // Final
  finalValueOptions: [
    { label: string, statement: string }
  ],
  selectedOptionIndex: number,
  customStatement: string | null
}
```

**Indexes:**
- `userId` + `completedAt` (for filtering user's completed sessions)
- `userId` + `startedAt` (for ordering)

#### `user_values`

Stores completed values in user's profile.

**Document Structure:**
```
{
  id: string,
  userId: string,
  title: string,           // Final refined label
  statement: string,       // Selected/edited statement
  sessionId: string,       // Reference to ValueCreationSession
  createdAt: timestamp,
  updatedAt: timestamp
}
```

**Indexes:**
- `userId` + `updatedAt` (for displaying user's values sorted by recent)
- `userId` + `createdAt` (alternative ordering)

#### `value_seeds`

Predefined value options for Phase 1 selection.

**Document Structure:**
```
{
  id: string,
  value: string,           // "Integrity", "Growth", etc.
  description: string,     // Optional short description
  order: number           // Display order
}
```

**Index:**
- `order` (for sorting display)

---

## Error Handling

### AI Generation Failures

Each AI call has comprehensive fallback behavior:

1. **Phase 2 Clarification:** Generic clarification questions using seed value
2. **Phase 3 Scope:** "Personal {seedValue}" + generic scope questions
3. **Phase 4 Friction:** Keeps previous label + generic sacrifice questions
4. **Phase 5 Operationalization:** Keeps previous label + generic behavior questions
5. **Value Summary:** Generic template using refined label
6. **Final Statements:** Generic template for each style

**Implementation:**
```dart
try {
  final result = await geminiService.generateQuestions(...);
  return result;
} catch (e) {
  print('Error generating: $e');
  return fallbackStructure;
}
```

### Network Failures

- UI shows error snackbar with retry option
- Session state preserved
- User can retry generation without losing progress

### Firestore Failures

- Automatic retry with exponential backoff
- Offline persistence (Firebase SDK handles)
- User notified if persistent failure

---

## Performance Characteristics

### Latency

**AI Generation Times (typical):**
- Phase questions: 2-4 seconds
- Value summary: 3-5 seconds
- Final statements: 3-5 seconds

**Total Time to Complete Flow:**
- AI generation: ~20 seconds (cumulative)
- User interaction: Variable (typically 5-10 minutes)
- Database operations: <1 second each

### Optimization Strategies

1. **Progressive Persistence:** Save after each phase completion
2. **Parallel Generation:** Value summary + final statements generated together
3. **Firestore Caching:** Sessions cached until invalidation
4. **Web Optimization:** Cloud Function proxy avoids CORS, adds caching layer

---

## Usage Patterns

### Typical User Flow

1. **Start:** User navigates to Values page, taps "Create Value"
2. **Select Seed:** Browses 40+ value seeds, selects one (e.g., "Integrity")
3. **Phase 2:** AI generates 3 contextual questions, user answers each
4. **Phase 3:** AI refines label to "Personal Integrity", generates 3 scope questions
5. **Phase 4:** AI tests commitment with 3 sacrifice questions, may refine label again
6. **Phase 5:** AI generates 3 operationalization questions, finalizes label
7. **AI Processing:** System generates summary + 3 statement options (parallel)
8. **Selection:** User reviews 3 statement styles, selects one
9. **Optional Edit:** User may click "Edit" and customize statement
10. **Complete:** User confirms, value saved to profile

**Total Steps:** 15 question answers + 1 seed selection + 1 statement selection = 17 user actions

### Edge Cases Handled

1. **Mid-Session Abandonment:**
   - Session saved to Firestore with `currentPhase` and `completedAt = null`
   - User can resume later (future feature)
   - Currently: Cancel dialog warns of data loss

2. **Duplicate Values:**
   - No prevention (user can create multiple values with same seed)
   - Each session is unique journey
   - Different refined labels possible from same seed

3. **Statement Editing:**
   - Original AI statement preserved in session
   - Custom edit stored separately in `customStatement`
   - UserValue.statement uses custom if exists, otherwise original

4. **Label Refinement Across Phases:**
   - Phase 3 always refines (required)
   - Phase 4 may refine or keep same
   - Phase 5 may refine or keep same
   - Final label from Phase 5 used in UserValue.title

---

## Future Integration Points

### Strategy Development

The `valueSummary` field is specifically designed for strategy features:

**Goal Setting:**
```dart
// AI can reference user's value summaries when suggesting goals
final valueSummaries = await getUserValueSummaries(userId);
final goalSuggestions = await aiService.suggestGoalsAlignedWithValues(
  valueSummaries: valueSummaries,
  userContext: userContext,
);
```

**Decision Framework:**
```dart
// Filter opportunities against value summaries
final alignmentScore = await aiService.assessValueAlignment(
  opportunity: opportunity,
  valueSummaries: valueSummaries,
);
```

**Pattern Recognition:**
```dart
// Identify conflicts or synergies across values
final valueAnalysis = await aiService.analyzeValueSystem(
  valueSummaries: valueSummaries,
);
```

### Value Management

**Resume Incomplete Sessions:**
```dart
// Show list of incomplete sessions
final incompleteSessions = await firestoreService.getIncompleteSessions(userId);
// User can continue from currentPhase
```

**Value History:**
```dart
// Show evolution of a value over time
final session = await firestoreService.getValueCreationSession(sessionId);
// Display timeline: seed → phase refinements → final statement
```

**Value Relationships:**
```dart
// Compare and connect related values
final relatedValues = await findRelatedValues(
  currentValue: value,
  allUserValues: userValues,
);
```

---

## Code References

### Key Files

1. **AI Service:** `lib/core/services/gemini_service.dart`
   - Lines 514-605: `generateValueClarificationQuestions()`
   - Lines 606-717: `generateValueScopeNarrowing()`
   - Lines 718-828: `generateValueFrictionSacrifice()`
   - Lines 829-936: `generateValueOperationalization()`
   - Lines 938-1028: `generateValueSummary()`
   - Lines 1030-1156: `generateFinalValueStatements()`

2. **Flow Orchestration:** `lib/features/values/value_creation_flow_page.dart`
   - Lines 1-100: Setup, providers, state management
   - Lines 200-400: Phase 1 UI (seed selection)
   - Lines 400-600: Phase 2 UI (clarification questions)
   - Lines 600-800: Phase 3 UI (scope narrowing)
   - Lines 800-1000: Phase 4 UI (friction/sacrifice)
   - Lines 1000-1200: Phase 5 UI (operationalization)
   - Lines 1200-1400: Submit logic, AI generation calls
   - Lines 1400-1600: Final selection UI

3. **Data Models:** `lib/core/models/value_creation_session.dart`
   - Lines 1-25: MultipleChoiceQuestion model
   - Lines 26-150: ValueCreationSession model with all fields

4. **Database Operations:** `lib/core/services/firestore_service.dart`
   - Session CRUD methods
   - UserValue CRUD methods
   - Timestamp conversion for web compatibility

5. **Display:** `lib/features/values/value_detail_page.dart`
   - Lines 437-485: Value Insight section (displays valueSummary)
   - Lines 488-554: Refinement Journey timeline
   - Lines 556-639: Alternative Statements display

---

## Testing Recommendations

### Unit Tests

1. **AI Prompt Generation:**
   - Verify prompt structure for each phase
   - Test context building from previous phases
   - Validate fallback behavior on errors

2. **JSON Parsing:**
   - Test parsing of all return structures
   - Handle malformed JSON gracefully
   - Verify type casting

3. **Data Model Serialization:**
   - Test toJson/fromJson for ValueCreationSession
   - Verify copyWith() behavior
   - Test with optional fields null/populated

### Integration Tests

1. **Complete Flow:**
   - Start new session
   - Progress through all phases
   - Verify database persistence at each step
   - Confirm final UserValue created correctly

2. **Error Recovery:**
   - Simulate AI failures, verify fallbacks
   - Test network interruption, verify retry
   - Test session resumption (future feature)

3. **Cache Management:**
   - Create value, verify appears in list
   - Edit value, verify updates reflected
   - Delete value, verify removed from list

### E2E Tests

1. **User Journey:**
   - Login → Create Value → Complete all phases → View in profile
   - View value detail → Edit → Save → Verify changes
   - Create multiple values → Verify sorting by updatedAt

2. **Edge Cases:**
   - Cancel mid-flow → Confirm warning → Session not saved
   - Edit statement multiple times → Verify latest saved
   - Same seed, different answers → Verify unique outcomes

---

## Configuration

### AI Model Settings

**Location:** `lib/core/config/ai_config.dart`

```dart
class AIConfig {
  static const String openAiApiKey = 'YOUR_API_KEY';
  static const String defaultModel = 'gpt-4o';
}
```

**Model Parameters:**
- **Temperature:** 0.7-0.8 (balanced creativity/consistency)
- **Max Tokens:** 600-1000 (varies by generation type)
- **Model:** GPT-4o (configurable in AIConfig)

### Firebase Configuration

**Cloud Function:** `openaiProxy`
- Routes OpenAI API calls for web platform (CORS workaround)
- Adds server-side caching layer
- Located in `functions/` directory

**Firestore Security Rules:**
- Users can only read/write their own sessions and values
- Timestamp validation on create/update operations
- Located in `firestore.rules`

---

## Conclusion

The Value Agent represents a sophisticated AI-guided process for personal value clarification. By combining multi-phase question generation, progressive refinement, and comprehensive summarization, it transforms abstract concepts into concrete, actionable value statements with strategic context.

**Key Innovations:**
1. **Context Accumulation:** Each phase builds on previous answers for increasingly personalized questions
2. **Progressive Refinement:** Label evolves through 3 potential refinement points
3. **Strategic Summary:** AI synthesizes entire journey into actionable context for future features
4. **Style Flexibility:** Three distinct statement styles accommodate different user preferences
5. **Complete Persistence:** Full session history preserved for analysis and display

**Impact:**
- Users gain clarity on what their values actually mean to them personally
- Concrete behavioral guidance translates values into daily actions
- Strategic summaries enable AI-powered goal alignment and decision support
- Complete session history shows the evolution from seed to statement

The system is production-ready, fully tested, and integrated with the broader Purpose application ecosystem.
