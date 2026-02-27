# Firestore Data Model Architecture

## Overview
This document describes the complete Firestore database structure for the Purpose app, including the question module system that feeds the AI agent.

---

## 📊 Firestore Collections

### Collection Hierarchy

```
Firestore Database
│
├── users/                          # User profiles
│   └── {userId}/                   # Document per user
│
├── user_strategies/                # User strategies
│   └── {strategyId}/               # Document per strategy
│
├── strategy_types/                 # Strategy type definitions
│   └── {typeId}/                   # Document per strategy type
│
├── strategy_preferences/           # Preferences within strategies
│   └── {preferenceId}/             # Document per preference
│
├── type_preferences/               # Baseline preferences for strategy types
│   └── {typePreferenceId}/         # Document per type preference
│
├── question_modules/               # Question module containers
│   └── {moduleId}/                 # Document per question module
│
├── questions/                      # Individual questions
│   └── {questionId}/               # Document per question
│
├── user_answers/                   # User responses
│   └── {answerId}/                 # Document per answer
│
├── user_values/                    # User values
│   └── {valueId}/                  # Document per value
│
├── user_vision/                    # User vision statements
│   └── {visionId}/                 # Document per vision
│
├── user_mission_maps/              # User mission maps
│   └── {missionMapId}/             # Document per mission map
│
└── identity_synthesis_results/     # AI identity analysis results
    └── {resultId}/                 # Document per synthesis
```

---

## 1. Users Collection

**Collection**: `users`  
**Purpose**: Store user profiles and track progress

### UserModel Structure

```dart
{
  uid: string,                              // Firebase Auth UID
  email: string,                            // User email
  displayName: string?,                     // User's name
  photoUrl: string?,                        // Profile photo URL
  createdAt: Timestamp,                     // Account creation
  updatedAt: Timestamp,                     // Last update
  emailVerified: boolean,                   // Email verification status
  
  // Core statements (generated from question answers)
  purpose: string?,                         // Life purpose statement
  vision: string?,                          // Vision statement
  mission: string?,                         // Mission statement
  
  // Progress tracking
  goalIds: [string]?,                       // List of goal IDs
  onboardingCompleted: boolean,             // Onboarding status
  
  // Question module progress (map)
  moduleProgress: {
    "{questionModuleId}": {
      questionModuleId: string,
      answeredQuestions: number,
      totalQuestions: number,
      isCompleted: boolean,
      startedAt: Timestamp,
      completedAt: Timestamp?,
      updatedAt: Timestamp
    }
  }?,
  
  completedModuleIds: [string]?             // Quick lookup for completed modules
}
```

### Example User Document

```json
{
  "uid": "abc123",
  "email": "user@example.com",
  "displayName": "John Doe",
  "emailVerified": true,
  "createdAt": "2026-02-19T10:00:00Z",
  "updatedAt": "2026-02-19T15:30:00Z",
  
  "purpose": "To inspire and empower others through technology",
  "vision": "A world where everyone has access to quality education",
  "mission": null,
  
  "moduleProgress": {
    "purpose_module_1": {
      "questionModuleId": "purpose_module_1",
      "answeredQuestions": 5,
      "totalQuestions": 5,
      "isCompleted": true,
      "startedAt": "2026-02-19T10:00:00Z",
      "completedAt": "2026-02-19T10:30:00Z",
      "updatedAt": "2026-02-19T10:30:00Z"
    },
    "vision_module_1": {
      "questionModuleId": "vision_module_1",
      "answeredQuestions": 3,
      "totalQuestions": 7,
      "isCompleted": false,
      "startedAt": "2026-02-19T11:00:00Z",
      "updatedAt": "2026-02-19T15:30:00Z"
    }
  },
  
  "completedModuleIds": ["purpose_module_1"],
  "onboardingCompleted": true
}
```

---

## 2. Question Modules Collection

**Collection**: `question_modules`  
**Purpose**: Group related questions for each major module

### QuestionModule Structure

```dart
{
  id: string,                               // Auto-generated document ID
  parentModule: string,                     // "purpose" | "vision" | "mission" | "goals" | "objectives"
  strategyTypeId: string?,                  // Reference to strategy type (Personal, Career, Financial, etc.)
  name: string,                             // Display name
  description: string,                      // What this module covers
  order: number,                            // Display order
  totalQuestions: number,                   // Number of questions
  isActive: boolean,                        // Whether visible to users
  agentPrompt: string?,                     // Instructions for AI agent to process module answers
  agentResponse: string?,                   // AI agent's generated insights/response
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Example Question Module

```json
{
  "id": "purpose_discovery_1",
  "parentModule": "purpose",
  "strategyTypeId": "personal_001",
  "name": "Passion Discovery",
  "description": "Explore what brings you joy and fulfillment",
  "order": 1,
  "totalQuestions": 8,
  "isActive": true,
  "agentPrompt": "Analyze the user's answers to identify their core passions. Create a summary highlighting their strongest areas of interest and fulfillment.",
  "agentResponse": "Based on your responses, you demonstrate strongest passion in creative expression and helping others...",
  "createdAt": "2026-02-01T00:00:00Z",
  "updatedAt": "2026-02-01T00:00:00Z"
}
```

### Parent Module Types

1. **purpose** - Life purpose discovery
2. **vision** - Future vision crafting
3. **mission** - Mission statement development
4. **goals** - Goal setting and planning
5. **objectives** - Breaking goals into objectives

---

## 3. Questions Collection

**Collection**: `questions`  
**Purpose**: Individual questions within question modules

### Question Structure

```dart
{
  id: string,                               // Auto-generated document ID
  questionModuleId: string,                 // Parent module reference
  questionText: string,                     // The question to ask
  helperText: string?,                      // Additional guidance
  questionType: string,                     // Type of input required
  options: [string]?,                       // For multiple choice
  scaleMin: number?,                        // For scale questions
  scaleMax: number?,                        // For scale questions
  scaleLabels: [string]?,                   // Labels for scale endpoints
  order: number,                            // Order within module
  isRequired: boolean,                      // Must be answered
  isActive: boolean,                        // Currently active
  aiPromptTemplate: string?,                // Template for AI processing
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Question Types

1. **short_text** - Single line text input
2. **long_text** - Multi-line text area
3. **multiple_choice** - Select from options
4. **scale** - Rating scale (e.g., 1-10)
5. **yes_no** - Boolean yes/no question

### Example Questions

```json
// Short Text Question
{
  "id": "q1",
  "questionModuleId": "purpose_discovery_1",
  "questionText": "What activities make you lose track of time?",
  "helperText": "Think about when you're most engaged and energized",
  "questionType": "short_text",
  "order": 1,
  "isRequired": true,
  "isActive": true,
  "aiPromptTemplate": "The user finds fulfillment in: {answer}. What does this suggest about their purpose?",
  "createdAt": "2026-02-01T00:00:00Z",
  "updatedAt": "2026-02-01T00:00:00Z"
}

// Multiple Choice Question
{
  "id": "q2",
  "questionModuleId": "purpose_discovery_1",
  "questionText": "Which best describes your ideal impact?",
  "questionType": "multiple_choice",
  "options": [
    "Help individuals directly",
    "Create systemic change",
    "Inspire and educate",
    "Build and innovate"
  ],
  "order": 2,
  "isRequired": true,
  "isActive": true,
  "createdAt": "2026-02-01T00:00:00Z",
  "updatedAt": "2026-02-01T00:00:00Z"
}

// Scale Question
{
  "id": "q3",
  "questionModuleId": "purpose_discovery_1",
  "questionText": "How important is financial success in your purpose?",
  "questionType": "scale",
  "scaleMin": 1,
  "scaleMax": 10,
  "scaleLabels": ["Not Important", "Extremely Important"],
  "order": 3,
  "isRequired": true,
  "isActive": true,
  "createdAt": "2026-02-01T00:00:00Z",
  "updatedAt": "2026-02-01T00:00:00Z"
}
```

---

## 4. User Answers Collection

**Collection**: `user_answers`  
**Purpose**: Store user responses to questions

### UserAnswer Structure

```dart
{
  id: string,                               // Auto-generated document ID
  userId: string,                           // User who answered
  questionId: string,                       // Question being answered
  questionModuleId: string,                 // For easier querying
  
  // Answer fields (only one will be populated based on question type)
  textAnswer: string?,                      // For text questions
  numericAnswer: number?,                   // For scale questions
  selectedOption: string?,                  // For multiple choice
  booleanAnswer: boolean?,                  // For yes/no questions
  
  notes: string?,                           // Optional user notes
  
  // AI processing
  processedByAI: boolean,                   // Has AI processed this?
  aiResponse: string?,                      // AI's insights/response
  
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Example User Answers

```json
// Text Answer
{
  "id": "ans1",
  "userId": "user123",
  "questionId": "q1",
  "questionModuleId": "purpose_discovery_1",
  "textAnswer": "Teaching, coding, and helping others learn new skills",
  "processedByAI": true,
  "aiResponse": "Your passion for teaching and technology suggests a purpose in education technology...",
  "createdAt": "2026-02-19T10:15:00Z",
  "updatedAt": "2026-02-19T10:20:00Z"
}

// Multiple Choice Answer
{
  "id": "ans2",
  "userId": "user123",
  "questionId": "q2",
  "questionModuleId": "purpose_discovery_1",
  "selectedOption": "Inspire and educate",
  "processedByAI": false,
  "createdAt": "2026-02-19T10:16:00Z",
  "updatedAt": "2026-02-19T10:16:00Z"
}

// Scale Answer
{
  "id": "ans3",
  "userId": "user123",
  "questionId": "q3",
  "questionModuleId": "purpose_discovery_1",
  "numericAnswer": 7,
  "notes": "Important but not the primary driver",
  "processedByAI": false,
  "createdAt": "2026-02-19T10:17:00Z",
  "updatedAt": "2026-02-19T10:17:00Z"
}
```

---

## 5. Identity Synthesis Results Collection

**Collection**: `identity_synthesis_results`  
**Purpose**: Store AI-generated identity analysis and purpose statements

### IdentitySynthesisResult Structure

```dart
{
  id: string,                               // Auto-generated document ID
  userId: string,                           // User this analysis belongs to
  
  // Tier-level analysis (one per question module)
  tierAnalysis: [
    {
      tierName: string,                     // Module name
      dominantFeatures: [string],           // Primary patterns identified
      secondaryFeatures: [string],          // Secondary themes
      tensionsDetected: [string],           // Contradictions found
      signalStrength: string,               // "Low", "Moderate", "High"
      confidenceScore: number,              // 0.0-1.0
      summary: string                       // Concise tier summary
    }
  ],
  
  // Cross-tier integration
  integratedIdentity: {
    keyPatterns: [string],                  // Patterns across all tiers
    tensions: [string],                     // Cross-tier tensions
    summary: string                         // Identity architecture (3-5 sentences)
  },
  
  // Generated purpose statement options
  purposeOptions: [
    {
      label: string,                        // "Direct", "Strategic", "Visionary"
      statement: string                     // The purpose statement
    }
  ],
  
  createdAt: Timestamp,                     // When analysis was run
  answersHash: string,                      // Hash of answers (detect staleness)
  selectedOptionIndex: number?,             // Which option user selected (0-2)
  editedStatement: string?,                 // User's edited version
  isPromoted: boolean                       // Promoted to user.purpose field
}
```

### Example Identity Synthesis Result

```json
{
  "id": "synthesis_abc123",
  "userId": "user123",
  "tierAnalysis": [
    {
      "tierName": "Core Values & Drivers",
      "dominantFeatures": [
        "Strong emphasis on helping others",
        "Values autonomy and independence",
        "Drawn to creative problem-solving"
      ],
      "secondaryFeatures": [
        "Collaborative orientation",
        "Systems thinking"
      ],
      "tensionsDetected": [
        "Tension between autonomy and collaboration needs"
      ],
      "signalStrength": "High",
      "confidenceScore": 0.87,
      "summary": "This tier reveals a strong service orientation paired with a need for independence in execution. The user gravitates toward helping roles but prefers operating with high autonomy."
    }
  ],
  "integratedIdentity": {
    "keyPatterns": [
      "Service-oriented with systems-level thinking",
      "Balances independence with collaborative impact",
      "Values creative problem-solving in social domains"
    ],
    "tensions": [
      "Autonomy vs. collaboration balance",
      "Individual impact vs. systemic change"
    ],
    "summary": "This identity architecture centers on autonomous service delivery with systems-level awareness. The individual seeks to help others through creative problem-solving while maintaining operational independence. The primary tension involves balancing solo execution with collaborative impact."
  },
  "purposeOptions": [
    {
      "label": "Direct",
      "statement": "To solve complex social problems through innovative systems design."
    },
    {
      "label": "Strategic",
      "statement": "To architect scalable solutions that amplify individual agency in underserved communities."
    },
    {
      "label": "Visionary",
      "statement": "To transform lives by building systems that unlock human potential and foster sustainable independence."
    }
  ],
  "createdAt": "2026-02-21T14:30:00Z",
  "answersHash": "a3f8d92b1c4e",
  "selectedOptionIndex": 1,
  "editedStatement": "To design scalable solutions that empower individuals in underserved communities.",
  "isPromoted": true
}
```

### Staleness Detection

The `answersHash` field contains a hash of all purpose module answers. When:
- User modifies any answer in purpose modules
- Hash is recalculated and compared
- If different → analysis is stale, rerun synthesis agent
- Prevents outdated analysis from being used

---

## 🔄 Data Flow: Questions → Answers → AI → Purpose

### Step 1: User Answers Questions
1. User navigates to a module (e.g., Purpose)
2. App loads question modules for that parent module
3. For each module, app loads questions
4. User answers questions → saved to `user_answers` collection
5. Progress tracked in `users.moduleProgress`

### Step 2: Module Completion
1. When all questions answered: `moduleProgress.isCompleted = true`
2. Module ID added to `completedModuleIds`
3. Triggers AI processing

### Step 3: AI Processing
1. Fetch all unprocessed answers: `processedByAI = false`
2. Send answers to AI agent with prompt templates
3. AI generates insights and suggestions
4. Save AI response to `user_answers.aiResponse`
5. Mark as processed: `processedByAI = true`

### Step 4: Generate Statements
1. When module complete, AI synthesizes all answers
2. Generates purpose/vision/mission statement
3. Saves to `users.purpose`, `users.vision`, or `users.mission`
4. User can review, edit, and refine

---

## 🔍 Firestore Queries

### Common Query Patterns

```dart
// Get user progress
firestoreService.getUser(userId)

// Get all purpose modules
firestoreService.getQuestionModulesByParent(ModuleType.purpose)

// Get questions for a module
firestoreService.getQuestionsByModule(questionModuleId)

// Get user's answer to specific question
firestoreService.getUserAnswer(userId: userId, questionId: questionId)

// Get all answers for a module
firestoreService.getUserAnswersByModule(
  userId: userId,
  questionModuleId: questionModuleId
)

// Check if module completed
firestoreService.isModuleCompleted(
  userId: userId,
  questionModuleId: questionModuleId
)

// Get answers needing AI processing
firestoreService.getUnprocessedAnswers(
  userId: userId,
  questionModuleId: questionModuleId
)

// Mark answer as processed
firestoreService.markAnswerProcessed(
  answerId: answerId,
  aiResponse: response
)
```

---

## 📝 Firestore Security Rules (TODO)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can only read/write their own user doc
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Question modules are read-only for all authenticated users
    match /question_modules/{moduleId} {
      allow read: if request.auth != null;
      allow write: if false; // Admin only (via Firebase Console)
    }
    
    // Questions are read-only for all authenticated users
    match /questions/{questionId} {
      allow read: if request.auth != null;
      allow write: if false; // Admin only
    }
    
    // Users can only read/write their own answers
    match /user_answers/{answerId} {
      allow read, write: if request.auth != null 
        && request.resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## 9. Strategy Preferences Collection

**Collection**: `strategy_preferences`  
**Purpose**: Store preference values and priorities within each strategy

### StrategyPreference Structure

```dart
{
  id: string,                               // Auto-generated document ID
  strategyId: string,                       // Reference to parent strategy
  name: string,                             // Full name of the preference
  shortLabel: string,                       // Short label for compact displays
  description: string,                      // Detailed description
  relativeWeight: number,                   // Relative importance (0.0 to 1.0)
  monetaryFactorPerYear: number,           // Annual monetary value/impact
  order: number,                            // Display order
  enabled: boolean,                         // Whether preference is active
  createdAt: Timestamp,                     // Creation timestamp
  updatedAt: Timestamp                      // Last update timestamp
}
```

### Example Strategy Preference Document

```json
{
  "id": "pref_abc123",
  "strategyId": "strategy_xyz789",
  "name": "Work-Life Balance",
  "shortLabel": "Balance",
  "description": "Maintaining healthy boundaries between professional and personal life",
  "relativeWeight": 0.85,
  "monetaryFactorPerYear": 15000,
  "order": 1,
  "enabled": true,
  "createdAt": "2026-02-26T10:00:00Z",
  "updatedAt": "2026-02-26T10:00:00Z"
}
```

### Key Features

- **Relative Weight**: Values between 0.0 and 1.0 to indicate priority
- **Monetary Factor**: Annual financial impact or value in base currency
- **Ordering**: Custom sort order for display
- **Strategy-scoped**: Each preference belongs to a specific strategy
- **Flexible**: Can represent costs, benefits, values, or priorities

### Common Use Cases

1. **Priority Weighting**: Rank different aspects of strategy by importance
2. **Cost-Benefit Analysis**: Track financial implications of preferences
3. **Decision Making**: Use weights to guide strategic choices
4. **Resource Allocation**: Allocate budget based on monetary factors
5. **Trade-off Analysis**: Compare preferences across multiple dimensions

### Firestore Indexes Required

```
Collection: strategy_preferences
- strategyId (Ascending) + order (Ascending)
- strategyId (Ascending) + enabled (Ascending) + order (Ascending)
- strategyId (Ascending) + relativeWeight (Descending)
```

---

## 10. Type Preferences Collection

**Collection**: `type_preferences`  
**Purpose**: Store baseline preference templates for each strategy type

### TypePreference Structure

```dart
{
  id: string,                               // Auto-generated document ID
  strategyTypeId: string,                   // Reference to parent strategy type
  name: string,                             // Full name of the preference
  shortLabel: string,                       // Short label for compact displays
  description: string,                      // Detailed description
  order: number,                            // Display order
  enabled: boolean,                         // Whether preference is active
  createdAt: Timestamp,                     // Creation timestamp
  updatedAt: Timestamp                      // Last update timestamp
}
```

### Example Type Preference Document

```json
{
  "id": "type_pref_abc123",
  "strategyTypeId": "personal_strategy_type",
  "name": "Work-Life Balance",
  "shortLabel": "Balance",
  "description": "Maintaining healthy boundaries between professional and personal life",
  "order": 1,
  "enabled": true,
  "createdAt": "2026-02-26T10:00:00Z",
  "updatedAt": "2026-02-26T10:00:00Z"
}
```

### Key Features

- **Template-based**: Provides baseline preferences for each strategy type
- **Reusable**: Can be selected when creating strategy-specific preferences
- **Type-scoped**: Each preference belongs to a specific strategy type
- **Admin-managed**: Typically maintained by administrators
- **Extensible**: Users can customize when applying to specific strategies

### Common Use Cases

1. **Preference Templates**: Provide standard options for each strategy type
2. **Quick Selection**: Users can select from pre-defined preferences
3. **Consistency**: Ensure similar strategies use similar preference sets
4. **Onboarding**: Help new users understand common preferences
5. **Best Practices**: Encode expert knowledge into preference templates

### Relationship to Strategy Preferences

When a user creates a new strategy, they can:
1. View type preferences available for that strategy type
2. Select relevant preferences to add to their strategy
3. Customize the selected preferences (set weights, monetary values)
4. Save as strategy-specific preferences

### Firestore Indexes Required

```
Collection: type_preferences
- strategyTypeId (Ascending) + order (Ascending)
- strategyTypeId (Ascending) + enabled (Ascending) + order (Ascending)
```

---

## 🚀 Next Steps

### To Enable Question Modules:

1. **Create Firestore Database**
   - Go to Firebase Console
   - Navigate to Firestore Database
   - Click "Create database"
   - Choose "Start in test mode" (for development)
   - Select a region close to your users

2. **Seed Initial Data** (Admin task)
   - Create question modules for Purpose
   - Add questions to each module
   - Set proper order and configuration

3. **Build Question UI**
   - Question module list screen
   - Question answering interface
   - Progress tracking UI
   - AI response display

4. **Integrate AI Agent**
   - Choose AI provider (OpenAI, Claude, Gemini)
   - Create prompt engineering system
   - Process answers → generate insights
   - Generate final purpose/vision/mission statements

---

## 📊 Data Model Benefits

✅ **Flexible**: Easy to add new modules and question types  
✅ **Scalable**: Efficient queries with proper indexing  
✅ **AI-Ready**: Structured for AI processing pipeline  
✅ **Progress Tracking**: Users can pause and resume  
✅ **Insights**: AI can analyze patterns across all answers  
✅ **Maintainable**: Admin can update questions without code changes

---

**The data model is now ready for implementation!** 🎉
