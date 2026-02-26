# Phase 4 UI Layer Updates - Test Plan

## Overview
Phase 4 has implemented multi-strategy architecture throughout the UI layer. All pages now use strategy-scoped data instead of user-scoped data. This document outlines comprehensive testing for all changed components.

---

## Changed Files Summary

### Core Infrastructure (New Files)
1. **`lib/core/services/strategy_context_provider.dart`** (NEW)
   - Manages currently selected strategy
   - Auto-selects default strategy if none selected
   
2. **`lib/shared/widgets/strategy_selector.dart`** (NEW)
   - UI widget for strategy selection and creation
   - Full and compact display modes

### Updated Files
3. **`lib/features/home/dashboard_page.dart`** (MODIFIED)
   - Added strategy selector widget

4. **`lib/features/values/values_page.dart`** (MODIFIED)
   - Now uses `strategyValuesProvider` instead of `userValuesProvider`
   - Shows "No active strategy" state

5. **`lib/features/vision/vision_page.dart`** (MODIFIED)
   - Now uses `strategyVisionStreamProvider` instead of `userVisionProvider`
   - Shows "No active strategy" state

6. **`lib/features/mission/mission_map_page.dart`** (MODIFIED)
   - Now uses `strategyMissionMapStreamProvider` instead of `userMissionMapProvider`
   - Shows "No active strategy" state
   - Updated all invalidation calls to use strategyId

7. **`lib/features/vision/vision_creation_flow_page.dart`** (MODIFIED)
   - Creates visions with `strategyId`
   - Loads values from active strategy
   - Validates active strategy exists before proceeding

8. **`lib/features/mission/mission_creation_flow_page.dart`** (MODIFIED)
   - Creates mission maps with `strategyId`
   - Loads values and vision from active strategy
   - Validates active strategy exists before proceeding

---

## Test Plan by Feature

### 1. Dashboard - Strategy Selector

**Location**: Dashboard home page

**Test Cases**:

#### TC1.1: First-time User (No Strategies)
- [ ] **Action**: Login as new user with no strategies
- [ ] **Expected**: Strategy selector shows "No strategies yet" state
- [ ] **Expected**: "Create Strategy" button is visible and functional
- [ ] **Expected**: Quick action buttons for Purpose/Values/Vision/Mission are visible

#### TC1.2: Create First Strategy
- [ ] **Action**: Click "Create Strategy" button
- [ ] **Expected**: Dialog opens with name, description, and "Set as default" checkbox
- [ ] **Action**: Enter name "My First Strategy", add description "Test strategy"
- [ ] **Action**: Check "Set as default strategy"
- [ ] **Action**: Click "Create"
- [ ] **Expected**: Strategy is created successfully
- [ ] **Expected**: Toast notification shows success message
- [ ] **Expected**: Strategy selector now shows the new strategy as active
- [ ] **Expected**: Strategy has draft status icon (orange edit icon)

#### TC1.3: Create Additional Strategy
- [ ] **Action**: Click "New" button in strategy selector
- [ ] **Expected**: Dialog opens
- [ ] **Action**: Create "Professional Strategy" without setting as default
- [ ] **Expected**: Strategy is created but original remains default
- [ ] **Expected**: Both strategies visible in selector

#### TC1.4: Switch Between Strategies
- [ ] **Action**: Click on non-active strategy in selector
- [ ] **Expected**: Strategy selection changes immediately
- [ ] **Expected**: Active strategy shows blue background and checkmark
- [ ] **Expected**: Dashboard updates to reflect selected strategy data

#### TC1.5: Strategy Status Icons
- [ ] **Verify**: Draft strategies show orange edit icon
- [ ] **Verify**: Active strategies show green play icon
- [ ] **Verify**: Archived strategies show gray archive icon

---

### 2. Values Page - Strategy Context

**Location**: `/values` route

**Test Cases**:

#### TC2.1: No Active Strategy
- [ ] **Setup**: Programmatically clear active strategy (or test with no strategies)
- [ ] **Action**: Navigate to Values page
- [ ] **Expected**: Shows "No active strategy" message
- [ ] **Expected**: Shows "Go to Dashboard" button
- [ ] **Expected**: No values are displayed
- [ ] **Action**: Click "Go to Dashboard"
- [ ] **Expected**: Returns to dashboard

#### TC2.2: View Values for Active Strategy
- [ ] **Setup**: Select a strategy with existing values
- [ ] **Action**: Navigate to Values page
- [ ] **Expected**: Page title says "My Values"
- [ ] **Expected**: Values from selected strategy are displayed
- [ ] **Expected**: Values show creation date and statement text
- [ ] **Expected**: Values from other strategies are NOT shown

#### TC2.3: Create Value for Active Strategy
- [ ] **Setup**: Select a strategy with < 5 values
- [ ] **Action**: Click "Create Value" FAB
- [ ] **Action**: Complete value creation flow
- [ ] **Expected**: Value is saved with correct strategyId
- [ ] **Expected**: Value appears in Values page immediately
- [ ] **Action**: Switch to different strategy
- [ ] **Expected**: Newly created value does NOT appear (belongs to other strategy)

#### TC2.4: Values Count Limit (5 max)
- [ ] **Setup**: Create strategy with 5 values
- [ ] **Action**: Navigate to Values page
- [ ] **Expected**: "Create Value" FAB is NOT visible (hidden when count >= 5)

#### TC2.5: Switch Strategy While on Values Page
- [ ] **Setup**: Two strategies with different values
- [ ] **Action**: Navigate to Values page (strategy A selected)
- [ ] **Expected**: Shows strategy A's values
- [ ] **Action**: Return to dashboard and switch to strategy B
- [ ] **Action**: Return to Values page
- [ ] **Expected**: Shows strategy B's values (completely different list)

---

### 3. Vision Page - Strategy Context

**Location**: `/vision` route

**Test Cases**:

#### TC3.1: No Active Strategy
- [ ] **Action**: Clear active strategy and navigate to Vision page
- [ ] **Expected**: Shows "No active strategy" message
- [ ] **Expected**: Shows "Go to Dashboard" button

#### TC3.2: View Vision for Active Strategy
- [ ] **Setup**: Select strategy with existing vision
- [ ] **Action**: Navigate to Vision page
- [ ] **Expected**: Vision statement displays correctly
- [ ] **Expected**: Timeframe years displayed
- [ ] **Expected**: Session details (meaningful change, role, influence scale) visible

#### TC3.3: No Vision Yet
- [ ] **Setup**: Select strategy without vision
- [ ] **Action**: Navigate to Vision page
- [ ] **Expected**: Shows "No vision created yet" state
- [ ] **Expected**: Shows "Create Vision" button
- [ ] **Action**: Click "Create Vision"
- [ ] **Expected**: Redirects to vision creation flow

#### TC3.4: Edit Vision
- [ ] **Setup**: Strategy with existing vision
- [ ] **Action**: Click edit button on vision statement
- [ ] **Action**: Modify vision text
- [ ] **Action**: Save changes
- [ ] **Expected**: Vision updates successfully
- [ ] **Expected**: Strategy's currentVision field updates (denormalization)
- [ ] **Expected**: Toast shows success message

#### TC3.5: Delete Vision
- [ ] **Setup**: Strategy with existing vision
- [ ] **Action**: Click delete button
- [ ] **Action**: Confirm deletion
- [ ] **Expected**: Vision is deleted
- [ ] **Expected**: Strategy's currentVision field cleared
- [ ] **Expected**: Returns to "No vision" state

#### TC3.6: Strategy Switch with Vision
- [ ] **Setup**: Strategy A with vision "Scale to 1M users", Strategy B with vision "Launch in 3 markets"
- [ ] **Action**: View vision page for Strategy A
- [ ] **Expected**: Shows "Scale to 1M users"
- [ ] **Action**: Switch to Strategy B
- [ ] **Action**: Return to vision page
- [ ] **Expected**: Shows "Launch in 3 markets" (different vision)

---

### 4. Vision Creation Flow - Strategy Integration

**Location**: `/vision/create` route

**Test Cases**:

#### TC4.1: No Active Strategy
- [ ] **Action**: Navigate to vision creation without active strategy
- [ ] **Expected**: Shows error toast "No active strategy found"
- [ ] **Expected**: Redirects to dashboard

#### TC4.2: Create Vision with Active Strategy
- [ ] **Setup**: Select strategy with values
- [ ] **Action**: Start vision creation flow
- [ ] **Expected**: Step 1 shows timeframe selection
- [ ] **Expected**: Purpose statement loaded from strategy (not user)
- [ ] **Expected**: Core values loaded from strategy's values
- [ ] **Action**: Complete all steps
- [ ] **Expected**: Vision saved with correct strategyId
- [ ] **Expected**: Strategy's currentVision field updated
- [ ] **Expected**: Redirects to vision detail page

#### TC4.3: Values from Correct Strategy
- [ ] **Setup**: Strategy A with values ["Innovation", "Quality"], Strategy B with values ["Speed", "Cost"]
- [ ] **Action**: Select Strategy A
- [ ] **Action**: Start vision creation
- [ ] **Expected**: AI uses "Innovation" and "Quality" in vision generation
- [ ] **Expected**: AI does NOT use "Speed" or "Cost"

#### TC4.4: Session Persistence
- [ ] **Action**: Start vision creation (completes Step 1-2)
- [ ] **Action**: Close browser tab
- [ ] **Action**: Reopen and navigate to vision creation
- [ ] **Expected**: Session data persists (uses VisionCreationSession model)
- [ ] **Expected**: Can continue from where left off

---

### 5. Mission Map Page - Strategy Context

**Location**: `/mission` route

**Test Cases**:

#### TC5.1: No Active Strategy
- [ ] **Action**: Navigate to mission map without active strategy
- [ ] **Expected**: Shows "No active strategy" message
- [ ] **Expected**: Shows "Go to Dashboard" button

#### TC5.2: View Mission Map for Active Strategy
- [ ] **Setup**: Strategy with existing mission map
- [ ] **Action**: Navigate to mission map page
- [ ] **Expected**: Mission map displays with all missions
- [ ] **Expected**: Current mission highlighted
- [ ] **Expected**: Timeline shows mission sequence

#### TC5.3: No Mission Map Yet
- [ ] **Setup**: Strategy without mission map
- [ ] **Action**: Navigate to mission map page
- [ ] **Expected**: Shows "No Mission Map Yet" empty state
- [ ] **Expected**: Shows "Create Mission Map" button
- [ ] **Action**: Click "Create Mission Map"
- [ ] **Expected**: Redirects to mission creation flow

#### TC5.4: Edit Mission
- [ ] **Action**: Click edit on a mission
- [ ] **Action**: Modify mission title and structural shift
- [ ] **Action**: Save changes
- [ ] **Expected**: Mission updates successfully
- [ ] **Expected**: If current mission edited, strategy's currentMission updates
- [ ] **Expected**: Toast shows success

#### TC5.5: Delete Mission
- [ ] **Setup**: Mission map with 4 missions
- [ ] **Action**: Delete mission 2
- [ ] **Expected**: Mission removed from list
- [ ] **Expected**: Remaining missions reordered (3 becomes 2, 4 becomes 3)
- [ ] **Expected**: Current mission index adjusted if needed
- [ ] **Expected**: Toast shows "Mission deleted successfully. Timeline updated."

#### TC5.6: Add Mission
- [ ] **Action**: Click "Add Mission" button
- [ ] **Action**: Fill in mission details
- [ ] **Action**: Select position in timeline
- [ ] **Expected**: Mission inserted at correct position
- [ ] **Expected**: Subsequent missions shift down
- [ ] **Expected**: Toast shows position confirmation

#### TC5.7: Delete Entire Mission Map
- [ ] **Action**: Click delete mission map button
- [ ] **Action**: Confirm deletion
- [ ] **Expected**: Mission map deleted
- [ ] **Expected**: Strategy's currentMission and hasMissionMap fields cleared
- [ ] **Expected**: Redirects to home

#### TC5.8: Strategy Switch with Mission Maps
- [ ] **Setup**: Strategy A with 3 missions, Strategy B with 5 missions
- [ ] **Action**: View mission map for Strategy A
- [ ] **Expected**: Shows 3 missions
- [ ] **Action**: Switch to Strategy B
- [ ] **Action**: Return to mission map page
- [ ] **Expected**: Shows 5 missions (different mission map)

#### TC5.9: Advance to Next Mission
- [ ] **Setup**: Mission map with current mission at index 1
- [ ] **Action**: Complete current mission and advance
- [ ] **Expected**: Current mission index increments to 2
- [ ] **Expected**: Strategy's currentMission field updates to mission 2 text
- [ ] **Expected**: Timeline visualization updates

---

### 6. Mission Creation Flow - Strategy Integration

**Location**: `/mission/create` route

**Test Cases**:

#### TC6.1: No Active Strategy
- [ ] **Action**: Navigate to mission creation without active strategy
- [ ] **Expected**: Shows error toast "No active strategy found"
- [ ] **Expected**: Redirects to dashboard

#### TC6.2: Create Mission Map with Active Strategy
- [ ] **Setup**: Strategy with values and vision
- [ ] **Action**: Start mission creation flow
- [ ] **Expected**: Step 1 shows current state questions
- [ ] **Expected**: Purpose statement loaded from strategy
- [ ] **Expected**: Core values loaded from strategy
- [ ] **Expected**: Vision statement loaded from strategy
- [ ] **Action**: Complete all steps
- [ ] **Expected**: Mission map saved with correct strategyId
- [ ] **Expected**: Strategy's currentMission and hasMissionMap updated
- [ ] **Expected**: Redirects to mission map page

#### TC6.3: Correct Strategy Data Used
- [ ] **Setup**: Strategy A (vision: "Global expansion"), Strategy B (vision: "Local dominance")
- [ ] **Action**: Select Strategy A
- [ ] **Action**: Start mission creation
- [ ] **Expected**: AI uses "Global expansion" vision in mission generation
- [ ] **Expected**: Missions focus on global themes
- [ ] **Action**: Switch to Strategy B and create mission map
- [ ] **Expected**: AI uses "Local dominance" vision
- [ ] **Expected**: Missions focus on local themes (different from Strategy A)

#### TC6.4: Constraint Values
- [ ] **Setup**: Strategy with 5 values
- [ ] **Action**: Navigate to Step 3 (Constraints)
- [ ] **Expected**: All 5 strategy values pre-selected
- [ ] **Expected**: Can deselect values
- [ ] **Expected**: Can add non-negotiable commitments

---

### 7. Strategy Denormalization

**Backend Test Cases** (verify in Firestore console or logs):

#### TC7.1: Strategy Purpose Update
- [ ] **Action**: User updates purpose for a strategy
- [ ] **Verify**: `strategy.purpose` field updates in Firestore

#### TC7.2: Value Count Tracking
- [ ] **Setup**: Strategy with 2 values
- [ ] **Action**: Create new value
- [ ] **Verify**: `strategy.valueCount` increments to 3
- [ ] **Action**: Delete a value
- [ ] **Verify**: `strategy.valueCount` decrements to 2

#### TC7.3: Current Vision Tracking
- [ ] **Action**: Create vision for strategy
- [ ] **Verify**: `strategy.currentVision` populated with vision statement
- [ ] **Action**: Update vision
- [ ] **Verify**: `strategy.currentVision` updates immediately
- [ ] **Action**: Delete vision
- [ ] **Verify**: `strategy.currentVision` set to null

#### TC7.4: Current Mission Tracking
- [ ] **Action**: Create mission map for strategy
- [ ] **Verify**: `strategy.currentMission` set to mission 1 text
- [ ] **Verify**: `strategy.hasMissionMap` set to true
- [ ] **Action**: Advance to mission 2
- [ ] **Verify**: `strategy.currentMission` updates to mission 2 text
- [ ] **Action**: Delete mission map
- [ ] **Verify**: `strategy.currentMission` set to null
- [ ] **Verify**: `strategy.hasMissionMap` set to false

#### TC7.5: Vision Count Tracking
- [ ] **Action**: Create multiple visions (modify, create new)
- [ ] **Verify**: `strategy.visionCount` increments with each new vision
- [ ] **Expected**: Only most recent vision used as `currentVision`

---

### 8. Multi-Strategy Isolation

**Critical Test Cases** to ensure data doesn't leak between strategies:

#### TC8.1: Complete Strategy Isolation
- [ ] **Setup**: Create 2 strategies
  - Strategy A: "Startup Launch 2026"
    - Values: ["Move Fast", "Break Things"]
    - Vision: "Launch MVP in 6 months"
    - Missions: 3 missions for rapid launch
  - Strategy B: "Enterprise Sales"
    - Values: ["Reliability", "Trust"]
    - Vision: "Become category leader in 3 years"
    - Missions: 5 missions for enterprise adoption

- [ ] **Test**: Switch to Strategy A
  - [ ] Values page shows only "Move Fast", "Break Things"
  - [ ] Vision page shows "Launch MVP in 6 months"
  - [ ] Mission map shows 3 missions

- [ ] **Test**: Switch to Strategy B
  - [ ] Values page shows only "Reliability", "Trust"
  - [ ] Vision page shows "Become category leader in 3 years"
  - [ ] Mission map shows 5 missions

- [ ] **Test**: Edit value in Strategy A
  - [ ] Change "Move Fast" to "Move Faster"
  - [ ] Switch to Strategy B
  - [ ] Verify "Reliability" unchanged (no cross-contamination)

#### TC8.2: Creation Flow Isolation
- [ ] **Setup**: Select Strategy A with specific values/vision
- [ ] **Action**: Start vision creation flow
- [ ] **Expected**: AI uses Strategy A's data
- [ ] **Action**: Abandon flow, switch to Strategy B
- [ ] **Action**: Start vision creation flow
- [ ] **Expected**: AI uses Strategy B's data (different context)
- [ ] **Expected**: Does NOT use Strategy A's data

#### TC8.3: Delete Isolation
- [ ] **Setup**: Strategy A with values, Strategy B with values
- [ ] **Action**: Delete a value from Strategy A
- [ ] **Expected**: Only Strategy A's valueCount decrements
- [ ] **Expected**: Strategy B's valueCount unchanged
- [ ] **Action**: Switch to Strategy B
- [ ] **Expected**: All Strategy B values still present

---

### 9. Edge Cases & Error Handling

#### TC9.1: No Default Strategy
- [ ] **Setup**: User with 2 strategies, both not default
- [ ] **Action**: Login/refresh
- [ ] **Expected**: App handles gracefully (may show strategy selector prominently)
- [ ] **Expected**: No crashes

#### TC9.2: Deleted Strategy
- [ ] **Setup**: Select strategy, then delete it
- [ ] **Action**: Navigate to values/vision/mission pages
- [ ] **Expected**: Shows "No active strategy" state
- [ ] **Expected**: Can switch to different strategy from dashboard

#### TC9.3: Empty Strategy
- [ ] **Setup**: Newly created strategy with no data
- [ ] **Action**: Navigate to all pages
- [ ] **Expected**: Values page shows empty state
- [ ] **Expected**: Vision page shows "No vision yet"
- [ ] **Expected**: Mission page shows "No mission map yet"
- [ ] **Expected**: Can create data in any order

#### TC9.4: Concurrent Edits
- [ ] **Setup**: Same user, 2 browser tabs
- [ ] **Tab 1**: Select Strategy A
- [ ] **Tab 2**: Select Strategy B
- [ ] **Action**: Create value in Tab 1
- [ ] **Action**: Create value in Tab 2
- [ ] **Verify**: Values saved to correct strategies
- [ ] **Verify**: No cross-contamination

#### TC9.5: Strategy with Special Characters
- [ ] **Action**: Create strategy named "Strategy #1 (2026) - Q1/Q2"
- [ ] **Expected**: Name saves correctly
- [ ] **Expected**: Strategy selector displays properly
- [ ] **Expected**: All operations work normally

---

### 10. Performance & Real-time Updates

#### TC10.1: Strategy Switching Performance
- [ ] **Setup**: User with 5 strategies, each with full data
- [ ] **Action**: Rapidly switch between strategies
- [ ] **Expected**: UI updates quickly (< 500ms)
- [ ] **Expected**: No loading spinners flash unnecessarily
- [ ] **Expected**: Correct data loads each time

#### TC10.2: Stream Updates
- [ ] **Setup**: Two browser tabs, same strategy selected
- [ ] **Tab 1**: Update vision statement
- [ ] **Tab 2**: Watch vision page
- [ ] **Expected**: Tab 2 updates in real-time (stream provider working)
- [ ] **Expected**: No need to refresh

#### TC10.3: Large Mission Maps
- [ ] **Setup**: Strategy with 10+ missions
- [ ] **Action**: Navigate to mission map page
- [ ] **Expected**: All missions load and render
- [ ] **Expected**: Timeline displays correctly
- [ ] **Expected**: Can scroll and interact smoothly

---

### 11. Backward Compatibility

**Note**: These tests apply during migration period (Phase 5)

#### TC11.1: Existing User Data
- [ ] **Setup**: User with existing values/vision/mission (pre-migration)
- [ ] **Action**: Login after Phase 4 deployment
- [ ] **Expected**: Data still accessible (deprecated providers work)
- [ ] **Expected**: Migration script needed before full functionality

#### TC11.2: Mixed Data State
- [ ] **Setup**: Some data with strategyId, some without
- [ ] **Expected**: App handles gracefully
- [ ] **Expected**: Deprecated providers return old data
- [ ] **Expected**: New providers return only strategyId-linked data

---

## Critical Path Test Sequence

**Full User Journey Test** (recommended order):

1. [ ] **Fresh Start**: Login as new user
2. [ ] **Create Strategy**: Create "My 2026 Strategy"
3. [ ] **Create Values**: Add 3 core values
4. [ ] **Create Vision**: Complete vision creation flow
5. [ ] **Create Mission Map**: Complete mission creation flow
6. [ ] **Second Strategy**: Create "Side Project Strategy"
7. [ ] **Second Strategy Data**: Add different values/vision/mission
8. [ ] **Switch Test**: Toggle between strategies, verify isolation
9. [ ] **Edit Test**: Edit vision in first strategy, check second unchanged
10. [ ] **Delete Test**: Delete value from second strategy, check first unchanged
11. [ ] **Full Cycle**: Create new strategy, add all data, archive it

---

## Testing Tools & Tips

### Browser DevTools
- **Network Tab**: Watch Firestore requests when switching strategies
- **Console**: Check for errors or warnings
- **Application > Local Storage**: Verify no strategy leakage in client-side cache

### Firestore Console
- Navigate to Firebase console → Firestore Database
- Watch `user_strategies` collection as you create/edit
- Verify denormalized fields update correctly
- Check `user_values`, `user_visions`, `user_mission_maps` include `strategyId`

### Riverpod DevTools (if configured)
- Watch provider rebuilds when switching strategies
- Verify providers invalidate correctly
- Check for unnecessary rebuilds

### Test Data Setup
```dart
// Helper function to create test strategies
final testStrategy1 = UserStrategy(
  id: 'test-strat-1',
  userId: currentUser.uid,
  name: 'Test Strategy 1',
  status: StrategyStatus.active,
  isDefault: true,
  // ... other fields
);
```

---

## Known Limitations (Pre-Migration)

⚠️ **Important**: These limitations exist until Phase 5 (Data Migration) is complete:

1. **Existing users**: Old data without `strategyId` won't appear in strategy-scoped views
2. **Backward providers**: Deprecated `*ByUserId` providers in code but not fully tested
3. **Migration needed**: Run migration script before removing deprecated fields
4. **Mixed state**: Some data may have strategyId, some may not

---

## Success Criteria

Phase 4 is considered **successfully tested** when:

- [ ] All 11 feature test sections completed
- [ ] Critical path test sequence passes
- [ ] No data leakage between strategies confirmed
- [ ] All edge cases handled gracefully
- [ ] Performance acceptable (< 1s for strategy switches)
- [ ] Real-time updates working via stream providers
- [ ] Denormalization working (verified in Firestore)
- [ ] No console errors or warnings
- [ ] Strategy selector UX is intuitive

---

## Reporting Issues

If you find issues during testing, please note:
- **File**: Which file contains the bug
- **Test Case**: Which TC number failed
- **Expected**: What should happen
- **Actual**: What actually happened
- **Strategy Context**: Which strategy was selected
- **Console Errors**: Any error messages
- **Firestore State**: Screenshot of affected documents

---

## Next Steps

After Phase 4 testing is complete:
1. **Phase 5**: Data Migration (migrate existing user data to use strategies)
2. **Phase 6**: Cleanup & Documentation (remove deprecated code, update docs)

---

**Testing Start Date**: _________________
**Testing Completed Date**: _________________
**Tester**: _________________
**Issues Found**: _________________
**Status**: ⬜ Not Started | ⬜ In Progress | ⬜ Completed | ⬜ Blocked
