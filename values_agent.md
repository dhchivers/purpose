# Values Agent Design

## Overview
The Values Agent is a system to help users discover and articulate their core values through AI-assisted analysis and reflection.

## Goals
- Help users identify their authentic core values
- Differentiate between aspirational values and lived values
- Provide evidence-based values assessment
- Integrate values discovery with existing purpose/identity work

## User Journey

### 1. Introduction
- Explain what values are and why they matter
- Differentiate between "values I aspire to" vs "values I actually live by"
- Set expectations for the process

### 2. Values Exploration Methods

#### Option A: Answer-Based Analysis
- Analyze existing answers from Purpose modules
- Extract value indicators from user's responses
- AI identifies patterns in what user prioritizes
- Present findings with supporting evidence

#### Option B: Values Scenarios/Exercises
- Present decision-making scenarios
- Ask reflective questions about past choices
- Identify what user chose and why
- Extract values from revealed preferences

#### Option C: Direct Values Selection & Ranking
- Present comprehensive list of values
- User selects top 10-15 that resonate
- Rank in order of importance
- Provide definitions/examples for clarity

### 3. Values Synthesis
- AI analyzes all inputs to identify core values
- Cluster similar values
- Rank by evidence/importance
- Generate values statement

### 4. Values Articulation
- Top 3-5 core values identified
- Definition of what each means to the user
- Examples of how each shows up in their life
- How values connect to purpose/identity

## Data Models

### Value Model
```dart
class Value {
  String id;
  String name;
  String definition;
  String category; // e.g., "Personal Growth", "Relationships", "Achievement"
  List<String> relatedValues;
}
```

### UserValue Model
```dart
class UserValue {
  String userId;
  String valueId;
  String valueName;
  String personalDefinition; // How user defines this value
  double importance; // 0-10 scale
  List<String> evidenceFromAnswers; // Quote snippets
  List<String> realLifeExamples; // User provided
  bool isCore; // Top 3-5 values
  DateTime createdAt;
  DateTime updatedAt;
}
```

### ValuesAssessment Model
```dart
class ValuesAssessment {
  String id;
  String userId;
  List<UserValue> identifiedValues;
  String synthesisNarrative; // AI-generated explanation
  DateTime completedAt;
  Map<String, dynamic> metadata; // Source data, confidence scores
}
```

## AI Integration

### Prompts Needed

1. **Analyze Answers for Values**
   - Input: User's answers from purpose modules
   - Output: List of potential values with evidence quotes

2. **Values Synthesis**
   - Input: All value indicators, user selections, scenario responses
   - Output: Core values ranked with explanations

3. **Values Statement Generation**
   - Input: Core values + user's identity synthesis
   - Output: Cohesive values statement

## UI/UX Considerations

### Navigation
- Add "Discover Values" to main menu after Purpose modules
- Or integrate as optional step after Identity Analysis

### Progress Tracking
- Show completion status
- Allow return to refine/update values over time

### Presentation
- Visual value cards
- Evidence/examples for each value
- Connection to purpose statement

## Technical Implementation

### Phase 1: MVP
- [ ] Create data models (Value, UserValue, ValuesAssessment)
- [ ] Build values database/reference list
- [ ] Implement answer analysis (reuse existing answers)
- [ ] AI prompt for extracting values from text
- [ ] Simple UI to display identified values
- [ ] Allow user to confirm/reject/refine

### Phase 2: Enhanced
- [ ] Add scenario-based exercises
- [ ] Values ranking interface
- [ ] Personal definitions for each value
- [ ] Real-life examples collection
- [ ] Integration with purpose statement

### Phase 3: Advanced
- [ ] Values evolution tracking over time
- [ ] Values alignment checker (decisions vs values)
- [ ] Community values (shared/contrasting)
- [ ] Values-based goal setting

## Questions to Answer

1. **Scope**: Should values discovery be separate or integrated into existing modules?
2. **Timing**: When should users do values work - before, during, or after purpose discovery?
3. **Depth**: How many values should we help users identify? (3-5 core? 10-12 expanded?)
4. **Evidence**: How much evidence should we require before identifying a value?
5. **Update Frequency**: How often should users revisit/refine their values?
6. **AI Role**: Should AI suggest values or only analyze what user expresses?
7. **Storage**: Firestore structure for values data?

## Reference Materials

### Common Value Categories
- **Achievement**: Excellence, accomplishment, success, mastery
- **Autonomy**: Independence, freedom, self-direction, choice
- **Benevolence**: Kindness, helpfulness, compassion, caring
- **Conformity**: Obedience, politeness, honoring traditions
- **Hedonism**: Pleasure, enjoyment, gratification
- **Power**: Status, prestige, control, dominance
- **Security**: Safety, stability, harmony, order
- **Self-Direction**: Creativity, curiosity, choosing own goals
- **Stimulation**: Excitement, novelty, challenge, adventure
- **Tradition**: Respect, commitment, acceptance of customs
- **Universalism**: Justice, equality, peace, environmental care

### Values List Examples
- Authenticity
- Balance
- Belonging
- Compassion
- Connection
- Contribution
- Courage
- Creativity
- Curiosity
- Excellence
- Family
- Freedom
- Growth
- Health
- Honesty
- Impact
- Independence
- Innovation
- Integrity
- Justice
- Knowledge
- Leadership
- Learning
- Love
- Loyalty
- Meaning
- Nature
- Security
- Service
- Simplicity
- Spirituality
- Wisdom

## Next Steps

1. Review this design document
2. Decide on MVP scope and approach
3. Create data models
4. Build values reference database
5. Implement AI analysis of existing answers
6. Create basic UI for values display
7. Test with sample users
8. Iterate based on feedback

## Notes
- Consider reusing module questionnaire UI pattern
- Leverage existing AI integration (Gemini/OpenAI)
- Build on identity synthesis work
- Keep it simple for MVP - can expand later
