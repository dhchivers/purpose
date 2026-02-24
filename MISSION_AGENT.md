# Mission Agent Documentation

## Overview

The Mission Agent is an AI-powered system that transforms a user's purpose, values, and vision into a concrete strategic mission map. It generates 3-5 sequential missions that represent the structural and capability evolution required to journey from the current state to the envisioned future.

**Purpose:** Break down the user's long-term vision into a time-sequenced roadmap of structural transformations and capability developments.

**Key Features:**
- Three-step guided input collection (Current State, Vision State, Constraints)
- Context integration from Purpose, Values, and Vision modules
- AI generation of 3-5 sequential missions spanning the vision timeframe
- Mission editing, reordering, and manual creation capabilities
- Visual timeline showing proportional mission durations
- Strategy start date tracking with automatic timeline calculations
- Complete session history for regeneration

**AI Model:** OpenAI GPT-4o (via GeminiService)

---

## Mission Agent Philosophy

### What is a Mission Map?

A mission map is a **sequential series of structural transformation phases** that describe the evolution from current capabilities and authority to vision-level influence and responsibility. Missions are **not task lists or goals** - they are phases of fundamental change.

**Core Principles:**
1. **Structural Evolution** - Each mission represents a leap in structure, scale, or authority
2. **Sequential Building** - Missions build on each other; earlier missions enable later ones
3. **Capability Development** - Focus on what capabilities must be developed, not tasks to complete
4. **Risk-Aware** - Each mission assesses risk level and defines value guardrails
5. **Time-Bounded** - Missions have realistic durations that sum to the vision timeframe
6. **Purpose-Aligned** - Every mission advances the user's core purpose
7. **Values-Constrained** - No mission violates the user's core values or non-negotiable commitments

### Mission vs Goal vs Task

| Aspect | Mission | Goal | Task |
|--------|---------|------|------|
| **Timeframe** | 1-5 years | 3-12 months | Days to weeks |
| **Focus** | Structural transformation | Measurable outcome | Specific action |
| **Measure** | New capabilities developed | Achievement of target | Completion status |
| **Example** | "Scale from local to regional influence" | "Serve 50 organizations" | "Call 10 prospects" |

---

## Data Structures

### 1. Mission

```dart
class Mission {
  final String mission;              // "Mission 1 — Building Local Capacity"
  final String missionSequence;      // "1", "2", "3", etc.
  final String focus;                // What this mission focuses on achieving
  final String structuralShift;      // What structural change occurs
  final String capabilityRequired;   // What capabilities must be developed
  final String riskOrValueGuardrail; // Risk assessment and value constraints
  final String timeHorizon;          // "0-2 years", "2-4 years", etc.
  final RiskLevel? riskLevel;        // Parsed: low, medium, high
  final int durationMonths;          // Duration in months (default 12)
}

enum RiskLevel {
  low,
  medium,
  high,
}
```

**Purpose:** Represents a single mission phase in the strategic journey.

**Key Fields:**
- `mission` - Descriptive title capturing the essence (e.g., "Mission 1 — Foundation Building")
- `focus` - What the user is working to achieve in this phase
- `structuralShift` - How scale, authority, or organizational structure changes
- `capabilityRequired` - What new skills, systems, or capacities must be developed
- `riskOrValueGuardrail` - Includes risk level (Low/Medium/High) and value constraints
- `timeHorizon` - Relative timeframe (AI-generated, informational)
- `durationMonths` - Actual duration for timeline calculations (user-editable)

**Example Mission:**
```dart
Mission(
  mission: "Mission 1 — Local Network Building",
  missionSequence: "1",
  focus: "Establish credibility and foundational partnerships within city",
  structuralShift: "Transition from solo consultant to recognized network hub",
  capabilityRequired: "Relationship building, facilitation, resource mobilization",
  riskOrValueGuardrail: "Low risk - Focus on organic growth, maintain integrity",
  timeHorizon: "0-2 years",
  riskLevel: RiskLevel.low,
  durationMonths: 24,
)
```

---

### 2. MissionCreationSession

```dart
class MissionCreationSession {
  final String id;                        // Unique session ID
  final String userId;                    // User who owns this session
  final DateTime startedAt;               // When session began
  final DateTime? completedAt;            // When finalized (null if in progress)
  
  // CONTEXT (loaded from user profile)
  final String? purposeStatement;         // User's purpose
  final List<String>? coreValues;         // User's core values (statements)
  final String? visionStatement;          // User's vision statement
  final int? visionTimeframeYears;        // Vision timeframe (5, 10, or 15)
  
  // STEP 1: Current State
  final String? currentBuilding;          // What user is currently building/leading
  final String? currentScale;             // Current operational scale
  final String? currentAuthority;         // Current level of authority/influence
  
  // STEP 2: Vision State
  final String? visionInfluenceScale;     // Scale of influence in vision
  final String? visionEnvironment;        // Type of environment in vision
  final String? visionResponsibility;     // Level of responsibility in vision
  final String? visionMeasurableChange;   // Measurable change that exists
  
  // STEP 3: Constraints
  final List<String>? constraintValues;   // Values that cannot be violated
  final String? nonNegotiableCommitments; // Non-negotiable personal commitments
  final String? riskTolerance;            // Risk tolerance level
  
  // AI RESULTS
  final List<Mission>? missionMap;        // 3-5 missions generated by AI
  final int? selectedMissionIndex;        // Current mission focus (unused for now)
}
```

**Purpose:** Tracks the complete mission creation journey from inputs through AI generation.

**Lifecycle:**
1. Created when user starts mission creation flow
2. Populated with context (purpose, values, vision) from user profile
3. Updated progressively as user completes Steps 1-3
4. AI results added after Step 3
5. Marked complete when user finalizes mission map
6. Persisted for regeneration history

**Firestore Collection:** `mission_creation_sessions`

**Firestore Operations:**
- `saveMissionCreationSession()` - Create/update session
- `getLatestMissionCreationSession()` - Retrieve most recent session for regeneration

---

### 3. UserMissionMap

```dart
class UserMissionMap {
  final String id;                    // Unique mission map ID
  final String userId;                // User who owns this map
  final List<Mission> missions;       // 3-5 sequential missions
  final String? sessionId;            // Reference to MissionCreationSession
  final int? currentMissionIndex;     // Which mission user is on (0-based)
  final DateTime? strategyStartDate;  // When strategy execution begins
  final DateTime createdAt;           // When map was first created
  final DateTime updatedAt;           // Last modification date
}
```

**Purpose:** Stores the user's active mission map with execution tracking.

**Key Features:**
- `missions` - Ordered list of Mission objects (editable)
- `currentMissionIndex` - Tracks which mission the user is actively working on (0 = first mission)
- `strategyStartDate` - Base date for calculating mission start/end dates
- Helper methods: `currentMission`, `completionPercentage`, `isComplete`

**Computed Properties:**
- `currentMission` - Returns the Mission at `currentMissionIndex`
- `completionPercentage` - Returns 0.0 to 1.0 based on progress
- `isComplete` - Returns true when on the last mission

**Firestore Collection:** `user_mission_maps`

**Firestore Operations:**
- `saveUserMissionMap()` - Create new mission map (increments user.missionMapCount, updates user.missionMap)
- `getUserMissionMap()` - Get active mission map for user
- `userMissionMapStream()` - Real-time mission map updates
- `updateUserMissionMap()` - Update existing map (missions, dates, current index)
- `deleteUserMissionMap()` - Delete map (decrements missionMapCount, clears user.missionMap)

**User Model Integration:**
```dart
class UserModel {
  // ...
  final int missionMapCount;         // Number of times user has created mission map
  final String? missionMap;          // Current mission (from currentMission.mission)
  // ...
}
```

---

## Mission Creation Flow

The mission creation process consists of 4 steps across two phases: **User Input (Steps 1-3)** and **AI Generation & Finalization (Step 4)**.

### Phase 1: User Input Collection

#### Step 0: Context Loading

**Automatic Process:**
1. Load user profile
2. Extract `purpose` statement
3. Query `user_values` collection for core values
4. Query `user_visions` collection for vision statement and timeframe
5. Initialize `MissionCreationSession` with context

**Missing Context Handling:**
- If purpose missing → Show message: "Please complete your Purpose first"
- If values missing → Show message: "Please complete your Core Values first"
- If vision missing → Show message: "Please complete your Vision first"

**Context Displayed:**
- Purpose statement (top of page)
- Core values (comma-separated)
- Vision statement
- Vision timeframe (5, 10, or 15 years)

---

#### Step 1: Current State

**Purpose:** Establish the user's current operational baseline.

**Questions:**

1. **What are you currently building or leading?**
   - UI: Multi-line text field (4 lines)
   - Hint: "Describe your current work, role, or leadership"
   - Examples provided:
     - "A small consulting practice helping nonprofits"
     - "A community organization focused on education"
     - "An early-stage startup in the health tech space"
   - Data: `currentBuilding` (string, required)

2. **What scale are you operating at?**
   - UI: Multi-line text field (3 lines)
   - Hint: "Number of people, organizations, or reach"
   - Examples:
     - "Working with 3-5 organizations in one city"
     - "Serving 100 individuals across two communities"
     - "Operating in national markets with regional presence"
   - Data: `currentScale` (string, required)

3. **What authority do you currently hold?**
   - UI: Multi-line text field (3 lines)
   - Hint: "Your decision-making power, influence, or credibility"
   - Examples:
     - "Individual consultant with grassroots credibility"
     - "Executive director with board oversight"
     - "Team lead with budget authority"
   - Data: `currentAuthority` (string, required)

**Validation:** All three fields required

**Session Update:**
```dart
session.copyWith(
  currentBuilding: text,
  currentScale: text,
  currentAuthority: text,
)
```

---

#### Step 2: Vision State

**Purpose:** Describe the operational state that exists when the vision is realized.

**Questions:**

1. **What scale of influence will you have?**
   - UI: Multi-line text field (3 lines)
   - Hint: "National? Regional? Global? Industry-wide?"
   - Examples:
     - "National recognition as a thought leader"
     - "Regional network of partner organizations"
     - "Global community of practitioners"
   - Data: `visionInfluenceScale` (string, required)

2. **What kind of environment will you be operating in?**
   - UI: Multi-line text field (4 lines)
   - Hint: "Describe the organizations, systems, or networks"
   - Examples:
     - "Network of community organizations and social enterprises"
     - "Established institutional partnerships with universities"
     - "Cross-sector coalition including government and private sector"
   - Data: `visionEnvironment` (string, required)

3. **What level of responsibility will you hold?**
   - UI: Multi-line text field (3 lines)
   - Hint: "What will you be responsible for?"
   - Examples:
     - "Leading a movement and platform"
     - "Stewarding resources for multiple organizations"
     - "Setting strategic direction for an industry"
   - Data: `visionResponsibility` (string, required)

4. **What measurable change will exist?**
   - UI: Multi-line text field (4 lines)
   - Hint: "What observable outcomes will be true?"
   - Examples:
     - "Hundreds of communities using the frameworks"
     - "Policy changes adopted in 10+ states"
     - "Market transformation with new standards"
   - Data: `visionMeasurableChange` (string, required)

**Validation:** All four fields required

**Session Update:**
```dart
session.copyWith(
  visionInfluenceScale: text,
  visionEnvironment: text,
  visionResponsibility: text,
  visionMeasurableChange: text,
)
```

---

#### Step 3: Constraints

**Purpose:** Define the boundaries and risk parameters for the mission journey.

**Inputs:**

1. **Which values absolutely cannot be violated?**
   - UI: Multi-select chip list from user's core values
   - Display: User's value statements as selectable chips
   - Minimum: 1 value required
   - Data: `constraintValues` (List<String>)

2. **What are your non-negotiable commitments?**
   - UI: Multi-line text field (4 lines)
   - Hint: "Family time? Health? Geographic location?"
   - Examples:
     - "Must maintain work-life balance and family time"
     - "Cannot relocate due to family commitments"
     - "Must preserve financial stability during transition"
   - Data: `nonNegotiableCommitments` (string, required)

3. **What is your risk tolerance?**
   - UI: Dropdown selection
   - Options:
     - "Low - Prefer stable, incremental progress"
     - "Moderate - Willing to take calculated risks"
     - "High - Ready for bold moves and uncertainty"
   - Data: `riskTolerance` (string, required)

**Validation:** Value selection (min 1) + two text fields required

**Session Update:**
```dart
session.copyWith(
  constraintValues: selectedValues,
  nonNegotiableCommitments: text,
  riskTolerance: selectedOption,
)
```

---

### Phase 2: AI Generation & Finalization

#### Step 4: Mission Map Generation & Review

**Trigger:** User completes Step 3 and clicks "Generate Mission Map"

**Process:**

1. **AI Generation:**
   - Display loading indicator: "Generating your mission map..."
   - Call `geminiService.generateMissionMap()` with all collected data
   - Parse 3-5 missions from AI response
   - Extract risk level from `risk_or_value_guardrail` field
   - Calculate `durationMonths` from `timeHorizon` (simplified by years × 12)

2. **Session Persistence:**
   - Mark session as `completedAt: DateTime.now()`
   - Save complete session with `missionMap: missions`
   - Store in Firestore `mission_creation_sessions` collection

3. **Mission Display:**
   - Show generated missions in expandable cards
   - Display all mission attributes (focus, shift, capability, risk, timeline)
   - Visual risk badges (color-coded)
   - Expand/collapse details

4. **Finalization:**
   - User clicks "Finalize Mission Map"
   - Create `UserMissionMap` with:
     - `missions: generatedMissions`
     - `sessionId: session.id`
     - `currentMissionIndex: 0` (start on first mission)
     - `strategyStartDate: DateTime.now()` (default to today)
     - `createdAt: DateTime.now()`
     - `updatedAt: DateTime.now()`
   - Save to Firestore `user_mission_maps` collection
   - Update user profile: `user.missionMap = missions[0].mission`
   - Increment `user.missionMapCount`
   - Navigate to Mission Map page

**Error Handling:**
- If AI call fails → Use fallback missions (3 generic missions based on timeframe)
- If save fails → Show error with retry option

---

## AI Agent: Mission Synthesis Agent

### Input Parameters

The AI receives comprehensive context to generate missions:

**Context:**
- `purposeStatement` - User's core purpose
- `coreValues` - List of value statements
- `visionStatement` - User's vision statement
- `visionTimeframeYears` - 5, 10, or 15 years

**Current State:**
- `currentBuilding` - What user is building/leading now
- `currentScale` - Current operational scale
- `currentAuthority` - Current authority/influence level

**Vision State:**
- `visionInfluenceScale` - Scale of influence in vision
- `visionEnvironment` - Operating environment in vision
- `visionResponsibility` - Responsibility level in vision
- `visionMeasurableChange` - Observable outcomes

**Constraints:**
- `constraintValues` - Values that cannot be violated
- `nonNegotiableCommitments` - Personal commitments to maintain
- `riskTolerance` - Risk tolerance level

### AI Prompt Structure

The prompt guides the AI to:

1. **Analyze the Gap**
   - Compare current state to vision state
   - Identify structural transformations needed
   - Determine capability evolution required

2. **Define Sequential Phases**
   - Create 3-5 distinct missions
   - Each mission represents a structural milestone
   - Missions build on each other logically

3. **Mission Characteristics**
   - **Focus:** What the mission achieves
   - **Structural Shift:** How scale/authority/structure changes
   - **Capability Required:** What must be developed
   - **Risk & Value Guardrails:** Risk level + value constraints
   - **Time Horizon:** Realistic timeframe segment

4. **Constraints**
   - Respect non-negotiable commitments
   - Align with risk tolerance
   - Never violate constraint values
   - Stay true to purpose

5. **Time Sequencing**
   - Time horizons must be sequential
   - Total duration ≈ vision timeframe years
   - Use ranges like "0-2 years", "2-4 years", "4-7 years"

### Output Format

```json
{
  "mission_map": [
    {
      "mission": "Mission 1 — [Descriptive Title]",
      "mission_sequence": "1",
      "focus": "[What this mission focuses on achieving]",
      "structural_shift": "[What structural change occurs]",
      "capability_required": "[What capabilities must be developed]",
      "risk_or_value_guardrail": "[Risk level: Low/Medium/High] - [Value constraints]",
      "time_horizon": "[Time period, e.g., 0-2 years]"
    },
    // ... 2-4 more missions
  ]
}
```

### Fallback Missions

If AI call fails, generic fallback missions are generated:

**Mission 1 — Foundation Building**
- Focus: Establish foundational capabilities
- Structural Shift: Transition to scalable operational model
- Low risk, foundational timeframe

**Mission 2 — Scale Expansion**
- Focus: Scale operations and influence
- Structural Shift: Expand to broader impact
- Medium risk, growth timeframe

**Mission 3 — Vision Realization**
- Focus: Achieve vision-level influence
- Structural Shift: Operating at vision scale
- Medium risk, final timeframe

---

## Mission Map Management

Once a mission map is created, users can view and manage it through the Mission Map page.

### Mission Map Page Features

**Display Components:**
1. **Header**
   - Title: "Your Strategic Mission Map"
   - Action buttons (icon buttons):
     - Regenerate Map (refresh icon)
     - Delete Map (delete icon)

2. **Strategy Start Date Section**
   - Shows current strategy start date
   - "Change Date" button opens date picker
   - Used as base for timeline calculations

3. **Current Mission Card**
   - Highlighted with blue gradient
   - Shows mission title and focus
   - Flag icon indicator
   - Only visible if not on last mission

4. **Completion Card**
   - Green success gradient
   - "Mission Map Complete!" message
   - Only visible when on last mission

5. **Visual Timeline Bar**
   - Proportional rectangles for each mission (sized by duration)
   - Circled numbers above each rectangle
   - Color coding:
     - Blue: Current mission
     - Green: Completed missions
     - Gray: Future missions
   - Red vertical line: Current date indicator
   - "Today" label under current date line
   - Start date and end date labels

6. **Mission Timeline Section**
   - "Mission Timeline" heading with Add Mission icon button
   - Vertical timeline with mission cards
   - Each mission shows:
     - Mission title with timeline dates
     - Expand/collapse toggle
     - Edit and delete buttons
     - Risk badge (color-coded)
     - When expanded: Focus, Structural Shift, Capability, Risk/Value details

### Mission Editing

**Edit Flow:**
1. User clicks "Edit" button on mission card
2. Card switches to edit mode with text fields:
   - Mission title (2 lines)
   - Structural Shift (multi-line)
   - Capability Required (multi-line)
   - Risk & Value Guardrails (multi-line, with hint about including risk level)
   - Duration (months, number input)
3. "Cancel" and "Save" buttons appear
4. On save:
   - Parse risk level from guardrail text (low/medium/high keywords)
   - Calculate new time horizon from duration
   - Update mission in array
   - Save updated `UserMissionMap` to Firestore
   - Show success message
   - Exit edit mode

**Validation:**
- All fields required
- Duration must be positive integer
- Risk level parsed automatically

---

### Manual Mission Creation

**Add Mission Flow:**
1. User clicks "+" icon next to "Mission Timeline" heading
2. Dialog opens with form:
   - **Position Dropdown:** "Mission 1" to "Mission N+1" (where N = current mission count)
   - **Mission Title** (required, 2 lines)
   - **Focus** (required, 2 lines)
   - **Structural Shift** (required, 3 lines)
   - **Capability Required** (required, 3 lines)
   - **Risk & Value Guardrails** (required, 3 lines, hint includes risk level)
   - **Duration (months)** (required, number input, default: 12)
3. Validation:
   - All fields required
   - Duration must be positive number
4. On "Add Mission":
   - Calculate time horizon from duration
   - Parse risk level from guardrail text
   - Insert mission at selected position
   - Renumber all mission sequences
   - Adjust `currentMissionIndex` if necessary (if inserting before current)
   - Save updated map to Firestore
   - Show success message
   - Close dialog

**Context Handling:**
- Dialog uses `scaffoldContext` not `dialogContext` for SnackBar messages
- Prevents Flutter engine assertion errors

---

### Mission Deletion

**Delete Flow:**
1. User clicks "Delete" button on mission card
2. Confirmation dialog shows:
   - "Are you sure you want to delete this mission?"
   - Mission title (highlighted)
   - "This will adjust the timeline for all remaining missions"
3. On confirmation:
   - Remove mission from array
   - Renumber remaining mission sequences
   - Adjust `currentMissionIndex` if necessary:
     - If deleting current mission: stay at same index (now next mission)
     - If deleting before current: decrement index
     - If only one mission left: cannot delete (show error)
   - Save updated map to Firestore
   - Show success message

**Protection:**
- Cannot delete if only 1 mission remains
- Confirmation required

---

### Mission Map Regeneration

**Flow:**
1. User clicks "Regenerate Map" icon button in header
2. Redirected to `/mission/create` route
3. `MissionCreationFlowPage` loads
4. If session exists:
   - Load latest `MissionCreationSession` from Firestore
   - Pre-fill all form fields from session data
   - User can modify inputs
   - Generate new missions with updated inputs
5. New mission map replaces old one (old map deleted, new map created)

---

### Timeline Calculations

**Date Calculations:**

```dart
// Calculate mission start date
DateTime? _calculateMissionStartDate(UserMissionMap missionMap, int missionIndex) {
  if (missionMap.strategyStartDate == null) return null;
  
  int cumulativeMonths = 0;
  for (int i = 0; i < missionIndex; i++) {
    cumulativeMonths += missionMap.missions[i].durationMonths;
  }
  
  final startDate = missionMap.strategyStartDate!;
  return DateTime(startDate.year, startDate.month + cumulativeMonths, 1);
}

// Calculate mission end date
DateTime? _calculateMissionEndDate(UserMissionMap missionMap, int missionIndex) {
  final startDate = _calculateMissionStartDate(missionMap, missionIndex);
  if (startDate == null) return null;
  
  final durationMonths = missionMap.missions[missionIndex].durationMonths;
  return DateTime(startDate.year, startDate.month + durationMonths - 1, 1);
}
```

**Display Format:** "Jan 2026 - Dec 2027 (24 months)"

---

## Firestore Operations

### Mission Creation Session Operations

**Save Session:**
```dart
Future<void> saveMissionCreationSession(MissionCreationSession session) async {
  final data = session.toJson();
  // Convert DateTime to Timestamp
  data['startedAt'] = Timestamp.fromDate(session.startedAt);
  if (session.completedAt != null) {
    data['completedAt'] = Timestamp.fromDate(session.completedAt);
  }
  
  await _db
    .collection('mission_creation_sessions')
    .doc(session.id)
    .set(data);
}
```

**Get Latest Session:**
```dart
Future<MissionCreationSession?> getLatestMissionCreationSession(String userId) async {
  final querySnapshot = await _db
    .collection('mission_creation_sessions')
    .where('userId', isEqualTo: userId)
    .orderBy('startedAt', descending: true)
    .limit(1)
    .get();
  
  if (querySnapshot.docs.isEmpty) return null;
  
  final data = querySnapshot.docs.first.data();
  // Convert Timestamps to DateTime strings
  // ...
  return MissionCreationSession.fromJson(data);
}
```

---

### User Mission Map Operations

**Save Mission Map:**
```dart
Future<void> saveUserMissionMap(UserMissionMap missionMap) async {
  final data = missionMap.toJson();
  
  // Convert DateTime to Timestamp
  data['createdAt'] = Timestamp.fromDate(missionMap.createdAt);
  data['updatedAt'] = Timestamp.fromDate(missionMap.updatedAt);
  if (missionMap.strategyStartDate != null) {
    data['strategyStartDate'] = Timestamp.fromDate(missionMap.strategyStartDate!);
  }
  
  // Save mission map
  await _db
    .collection('user_mission_maps')
    .doc(missionMap.id)
    .set(data);
  
  // Update user profile
  await _db.collection('users').doc(missionMap.userId).update({
    'missionMapCount': FieldValue.increment(1),
    'missionMap': missionMap.missions.isNotEmpty 
        ? missionMap.missions[missionMap.currentMissionIndex ?? 0].mission 
        : null,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

**Get Mission Map:**
```dart
Future<UserMissionMap?> getUserMissionMap(String userId) async {
  final querySnapshot = await _db
    .collection('user_mission_maps')
    .where('userId', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
    .limit(1)
    .get();
  
  if (querySnapshot.docs.isEmpty) return null;
  
  final data = querySnapshot.docs.first.data();
  // Convert Timestamps to DateTime
  // ...
  return UserMissionMap.fromJson(data);
}
```

**Update Mission Map:**
```dart
Future<void> updateUserMissionMap(UserMissionMap missionMap) async {
  final data = missionMap.toJson();
  data['updatedAt'] = Timestamp.fromDate(DateTime.now());
  if (missionMap.strategyStartDate != null) {
    data['strategyStartDate'] = Timestamp.fromDate(missionMap.strategyStartDate!);
  }
  
  await _db
    .collection('user_mission_maps')
    .doc(missionMap.id)
    .update(data);
  
  // Update user profile with current mission
  await _db.collection('users').doc(missionMap.userId).update({
    'missionMap': missionMap.missions.isNotEmpty 
        ? missionMap.missions[missionMap.currentMissionIndex ?? 0].mission 
        : null,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

**Delete Mission Map:**
```dart
Future<void> deleteUserMissionMap(String missionMapId, String userId) async {
  await _db
    .collection('user_mission_maps')
    .doc(missionMapId)
    .delete();
  
  // Update user profile
  await _db.collection('users').doc(userId).update({
    'missionMapCount': FieldValue.increment(-1),
    'missionMap': null,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

**Stream Mission Map:**
```dart
Stream<UserMissionMap?> userMissionMapStream(String userId) {
  return _db
    .collection('user_mission_maps')
    .where('userId', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
    .limit(1)
    .snapshots()
    .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final data = snapshot.docs.first.data();
      // Convert Timestamps...
      return UserMissionMap.fromJson(data);
    });
}
```

---

## UI Components

### MissionCreationFlowPage

**File:** `lib/features/mission/mission_creation_flow_page.dart`

**Type:** ConsumerStatefulWidget (Riverpod)

**State Management:**
- Current step tracker (0-3)
- Form controllers for all text inputs
- Selected values (constraint values, risk tolerance)
- Loading states
- Session reference
- Generated missions

**Key Methods:**
- `_initializeSession()` - Load purpose, values, vision from user profile
- `_handleNext()` - Validate current step and advance
- `_handleBack()` - Go to previous step
- `_generateMissionMap()` - Call AI and parse results
- `_saveMissionMap()` - Create UserMissionMap and save
- `_buildStepContent()` - Render current step UI

**Navigation:**
- **Entry:** Dashboard "Create Mission Map" or `/mission/create` route
- **Exit:** Mission Map page with success message

**Lifecycle:**
1. Initialize session with context
2. Step 1: Collect current state
3. Step 2: Collect vision state
4. Step 3: Collect constraints
5. Generate missions via AI
6. Review and finalize
7. Save UserMissionMap
8. Navigate to Mission Map page

---

### MissionMapPage

**File:** `lib/features/mission/mission_map_page.dart`

**Type:** ConsumerStatefulWidget (Riverpod)

**State Management:**
- Editing state (which mission being edited, if any)
- Deletion loading state
- Expanded missions set (which missions are expanded)
- Edit form controllers

**Key Methods:**
- `_buildMissionMapView()` - Main view with all sections
- `_buildVisualTimeline()` - Proportional timeline bar
- `_buildMissionCard()` - Individual mission card (view/edit modes)
- `_showAddMissionDialog()` - Dialog for manual mission creation
- `_deleteMission()` - Delete with confirmation
- `_deleteMissionMap()` - Delete entire map with confirmation
- `_updateStrategyStartDate()` - Date picker for strategy start
- `_calculateMissionStartDate()` - Math for timeline
- `_calculateMissionEndDate()` - Math for timeline
- `_formatMonthYear()` - Date formatting

**Visual Components:**
1. Header with title and action icon buttons
2. Strategy start date section
3. Current mission highlight card
4. Visual timeline bar (NEW)
5. Mission timeline with expandable cards
6. Edit/delete per mission

**Navigation:**
- **Entry:** Dashboard mission card or `/mission` route
- **Empty State:** Button to create first mission map

---

## Example Mission Map

**Context:**
- **Purpose:** "To create systems that empower communities to solve local problems"
- **Core Values:** Integrity, Innovation, Community, Sustainability
- **Vision:** "Communities worldwide are equipped with tools and networks to solve their own challenges"
- **Timeframe:** 10 years

**Generated Missions:**

### Mission 1 — Local Network Building (0-2 years)

**Focus:** Establish credibility and foundational partnerships within city

**Structural Shift:** Transition from solo consultant to recognized network hub connecting multiple organizations

**Capability Required:** Relationship building, facilitation, pattern recognition across organizations, resource mobilization

**Risk & Value Guardrails:** Low risk - Focus on organic growth through trust-building, maintain integrity in all partnerships, avoid overextension

**Duration:** 24 months

---

### Mission 2 — Regional Model Development (2-4 years)

**Focus:** Develop and test replicable frameworks with 10-15 partner organizations

**Structural Shift:** Shift from service provider to framework developer, establish small team to support expanded work

**Capability Required:** Systems design, documentation, training delivery, early-stage team leadership

**Risk & Value Guardrails:** Medium risk - Testing new approaches requires experimentation, ensure sustainability considerations in all framework designs

**Duration:** 24 months

---

### Mission 3 — National Platform Launch (4-7 years)

**Focus:** Launch national platform making frameworks accessible to hundreds of communities

**Structural Shift:** Build organization with staff, technology infrastructure, and funding model to support national reach

**Capability Required:** Strategic leadership, fundraising, technology development, movement building

**Risk & Value Guardrails:** Medium risk - Scaling requires capital and complexity, maintain community-centered approach despite growth pressures

**Duration:** 36 months

---

### Mission 4 — Ecosystem Cultivation (7-10 years)

**Focus:** Cultivate thriving ecosystem where communities support each other and innovate independently

**Structural Shift:** Transition from central provider to ecosystem steward, networks self-organize and evolve

**Capability Required:** Strategic partnership with institutions, influence management, legacy systems thinking

**Risk & Value Guardrails:** Medium risk - Letting go of control while maintaining vision alignment, ensure innovation serves community needs

**Duration:** 36 months

---

## Integration with Other Modules

### Purpose Module
- **Input:** Purpose statement required for mission generation
- **Flow:** Users complete Purpose before Mission
- **Data:** `user.purpose` loaded into `MissionCreationSession.purposeStatement`

### Values Module
- **Input:** Core values required for mission generation
- **Flow:** Users complete Values before Mission
- **Data:** `user_values` statements loaded into `MissionCreationSession.coreValues`
- **Constraint Selection:** Values displayed as chips in Step 3 for selection as constraints

### Vision Module
- **Input:** Vision statement and timeframe required for mission generation
- **Flow:** Users complete Vision before Mission
- **Data:** 
  - `user_visions` statement loaded into `MissionCreationSession.visionStatement`
  - `timeframeYears` loaded into `MissionCreationSession.visionTimeframeYears`

### Dashboard
- **Display:** Mission card shows current mission title
- **Navigation:**
  - If mission map exists → Mission Map Page
  - If no mission map → Mission Creation Flow
- **Updates:** Real-time via `userMissionMapProvider` and `currentUserProvider` invalidation

### Goals Module (Future)
- **Input:** Missions will define the structural context for goals
- **Relationship:** Goals are quarterly/annual milestones within missions

### Objectives Module (Future)
- **Input:** Missions inform strategic objectives
- **Relationship:** Objectives translate mission focus into measurable targets

---

## Technical Implementation Notes

### JSON Serialization
- Uses `json_serializable` package
- Generated code in `*.g.dart` files
- Run `dart run build_runner build --delete-conflicting-outputs` after model changes

### Riverpod Providers
```dart
// Mission Map provider with auto-dispose
final userMissionMapProvider = FutureProvider.autoDispose<UserMissionMap?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserMissionMap(user.uid);
});
```

### Error Handling
- **AI Failures:** Fallback to generic missions
- **Save Failures:** Show error with retry option
- **Validation:** Inline error messages
- **Network Issues:** Loading states with retry

### Performance Considerations
- Mission map loading is lazy (FutureProvider.autoDispose)
- Only loads when Mission Map page is accessed
- Stream provider available for real-time updates
- Firestore queries use indexes on `userId` + `createdAt`

### Context Management
- Dialog operations use captured `scaffoldContext` not `dialogContext`
- Prevents Flutter engine assertion errors (window.dart:99:12)
- ScaffoldMessenger accessed from proper widget tree

---

## File Structure

```
lib/
├── core/
│   ├── models/
│   │   ├── mission_creation_session.dart     # Session data model
│   │   ├── mission_creation_session.g.dart   # Generated JSON serialization
│   │   ├── user_mission_map.dart             # Active mission map model
│   │   └── user_mission_map.g.dart           # Generated JSON serialization
│   └── services/
│       ├── gemini_service.dart               # AI mission generation
│       ├── firestore_service.dart            # Mission CRUD operations
│       └── router.dart                       # Mission routes
└── features/
    ├── mission/
    │   ├── mission_creation_flow_page.dart   # 4-step creation wizard
    │   └── mission_map_page.dart             # Mission map view & management
    └── home/
        └── dashboard_page.dart               # Mission card display

firestore/
├── mission_creation_sessions/               # Session documents
│   └── {sessionId}
├── user_mission_maps/                       # Active mission map documents
│   └── {missionMapId}
└── users/                                   # User profiles with mission reference
    └── {userId}
```

---

## Key Differences from Vision Agent

| Aspect | Mission Agent | Vision Agent |
|--------|---------------|--------------|
| **Input Steps** | 3 steps (Current, Vision, Constraints) | 4 steps (Timeframe, Change, Scale, Role) |
| **AI Output** | 3-5 sequential missions | 3 vision options (user selects 1) |
| **Editing** | Full mission editing and manual creation | Selection + optional statement editing |
| **Timeline** | Detailed timeline with dates and durations | Single timeframe selection |
| **Active Use** | Ongoing tracking with progress | One-time statement creation |
| **Management** | Add/edit/delete individual missions | Replace entire vision |
| **Visual Timeline** | Proportional timeline bar with current date | None |
| **Dependencies** | Requires Purpose, Values, Vision | Requires Purpose, Values |

---

## Future Enhancements

### Near-Term
- [ ] Mission progress tracking (milestones within missions)
- [ ] Mission templates for common journey types
- [ ] Import missions from external sources
- [ ] Mission sharing and collaboration
- [ ] AI-suggested mission edits based on progress

### Medium-Term
- [ ] Integration with Goals module (map goals to missions)
- [ ] Integration with Objectives module (mission-level OKRs)
- [ ] Mission completion ceremonies
- [ ] Progress journals per mission
- [ ] Visual journey mapping (diagrams)

### Long-Term
- [ ] Multi-user mission maps (team/organization level)
- [ ] Mission analytics and insights
- [ ] AI coach for mission navigation
- [ ] Community mission templates library
- [ ] Mission success pattern recognition

---

## Summary

The Mission Agent transforms abstract vision into concrete strategic phases. By gathering context about current state, vision state, and constraints, it generates a time-sequenced roadmap of structural transformations.

**Key Innovations:**
- **Sequential Structural Thinking** - Missions represent phases of fundamental change, not tasks
- **Full Editability** - Users can manually add, edit, delete, and reorder missions
- **Visual Timeline** - Proportional timeline shows mission durations and current progress
- **Context Integration** - Synthesizes purpose, values, and vision into actionable phases
- **Risk-Aware Planning** - Each mission assesses risk and defines value guardrails

The Mission Agent bridges the gap between aspirational vision and practical execution planning, providing the strategic architecture for long-term transformation.
