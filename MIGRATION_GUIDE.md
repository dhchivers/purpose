# Phase 5: Data Migration Guide

## Overview

This guide covers the migration of existing user data to the new multi-strategy architecture implemented in Phase 4.

## What Gets Migrated

For each existing user **without strategies**, the migration will:

1. ✅ Create a default strategy named "My Strategy"
2. ✅ Link all existing user values to the default strategy
3. ✅ Link all existing user visions to the default strategy
4. ✅ Link all existing mission maps to the default strategy
5. ✅ Link all creation sessions to the default strategy
6. ✅ Set user's `defaultStrategyId` field
7. ✅ Set user's `strategyCount` to 1
8. ✅ Update strategy's denormalized fields:
   - `valueCount` - number of values
   - `currentVision` - latest vision statement
   - `currentMission` - current mission title

## Prerequisites

### 1. Update Firebase Configuration

Edit `migrate_to_strategies.dart` and update the Firebase credentials:

```dart
const firebaseOptions = FirebaseOptions(
  apiKey: 'YOUR_API_KEY',
  appId: 'YOUR_APP_ID',
  messagingSenderId: 'YOUR_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
  storageBucket: 'YOUR_STORAGE_BUCKET',
);
```

**Where to find these values:**
- Go to Firebase Console > Project Settings > General
- Scroll to "Your apps" section
- Select your web app
- Copy values from the Firebase SDK snippet

### 2. Backup Your Database

**CRITICAL**: Always backup before migration!

```bash
# Export Firestore data
gcloud firestore export gs://YOUR_BUCKET/backups/pre-migration-$(date +%Y%m%d)

# Or use Firebase CLI
firebase firestore:export backup-$(date +%Y%m%d)
```

### 3. Install Dependencies

The migration script uses your existing Flutter dependencies:

```bash
# Ensure all dependencies are installed
flutter pub get
```

## Migration Process

### Step 1: Dry Run (Preview Changes)

**Always start with a dry run** to see what would happen without making changes:

```bash
# Preview all users
dart migrate_to_strategies.dart --dry-run

# Preview single user (for testing)
dart migrate_to_strategies.dart --dry-run --user-id=abc123def456
```

**Expected output:**
```
🚀 Starting multi-strategy migration...
Mode: DRY RUN (no changes)
Target: All users

📊 Found 15 user(s) to process

👤 Processing user: john@example.com (abc123)
   📝 Creating default strategy...
   ✓ Strategy created: strat-xyz789
   📦 Migrating user data to strategy...
      ↳ Migrating values...
        ✓ Migrated 3 value(s)
      ↳ Migrating visions...
        ✓ Migrated 1 vision(s)
      ↳ Migrating mission maps...
        ✓ Migrated 1 mission map(s)
      ↳ Migrating sessions...
        ✓ Migrated 2 session(s)
      ↳ Updating strategy denormalized fields...
        ✓ Updated (valueCount=3, hasVision=true, hasMission=true)
   🔄 Updating user record...
   ✓ User record updated
   ✅ User migration complete

============================================================
MIGRATION SUMMARY
============================================================
Users processed:       15
Users skipped:         0
Strategies created:    15
Values updated:        45
Visions updated:       12
Mission maps updated:  8
Sessions updated:      27
Errors:                0
============================================================

✅ Dry run complete. No changes were made.
Run without --dry-run to apply changes.
```

### Step 2: Test on Single User

Before migrating all users, test on a single user account:

```bash
# Find a test user ID
# Check Firebase Console > Firestore > users collection

# Run migration on single user
dart migrate_to_strategies.dart --user-id=YOUR_TEST_USER_ID
```

**Verify the result:**
1. Check Firebase Console > Firestore > `user_strategies` collection
   - Should see new strategy document
2. Check `user_values` collection
   - Values should have `strategyId` field
3. Check `user_visions` collection
   - Visions should have `strategyId` field
4. Check `user_mission_maps` collection
   - Mission maps should have `strategyId` field
5. Check `users` collection > your test user
   - Should have `defaultStrategyId` field
   - Should have `strategyCount: 1`

**Test in the app:**
1. Login as the test user
2. Navigate to dashboard
   - Should see strategy selector with "My Strategy"
3. Navigate to Values page
   - Should see all existing values
4. Navigate to Vision page
   - Should see existing vision
5. Navigate to Mission Map page
   - Should see existing mission map
6. Create a new value
   - Should be linked to the strategy

### Step 3: Full Migration (Production)

Once single-user test is successful:

```bash
# Run full migration
dart migrate_to_strategies.dart
```

⚠️ **This will:**
- Modify all user records
- Create default strategies for all users
- Update all values/visions/missions with `strategyId`

**The script will:**
- Wait 5 seconds before starting (cancel with Ctrl+C)
- Process all users sequentially
- Skip users who already have strategies
- Continue processing even if one user fails
- Print detailed progress
- Show summary at the end

### Step 4: Verify Migration

After migration completes:

#### Check Statistics

The migration script outputs a summary:
```
============================================================
MIGRATION SUMMARY
============================================================
Users processed:       15
Users skipped:         0
Strategies created:    15
Values updated:        45
Visions updated:       12
Mission maps updated:  8
Sessions updated:      27
Errors:                0
============================================================
```

**Verify:**
- `Users processed` matches your total user count
- `Errors` is 0
- Numbers make sense for your data

#### Spot Check in Firebase Console

1. **Random user check:**
   - Pick 3-5 random users
   - Verify they have:
     - Entry in `user_strategies` collection
     - `defaultStrategyId` field in user doc
     - `strategyCount: 1` in user doc

2. **Data linkage check:**
   - Pick a user with data
   - Check their strategy's `valueCount` matches actual values
   - Check `currentVision` matches latest vision
   - Check `currentMission` matches current mission

3. **Old data check:**
   - Query for documents **without** `strategyId`:
     ```javascript
     // In Firestore Console > Queries
     // Collection: user_values
     // WHERE: strategyId == null
     ```
   - Should return 0 results (all migrated)

#### Test in Application

1. **Login as different users** and verify:
   - Dashboard shows strategy selector
   - Values page displays correctly
   - Vision page displays correctly
   - Mission map page displays correctly
   - Can create new values/visions (with strategyId)

2. **Create data post-migration:**
   - Create new value → verify has `strategyId`
   - Create new vision → verify has `strategyId`
   - Create mission map → verify has `strategyId`

## Troubleshooting

### Issue: Firebase credentials error

```
Error: Firebase project not found
```

**Solution:** Update `firebaseOptions` in `migrate_to_strategies.dart` with correct credentials.

### Issue: Permission denied

```
Error: Missing or insufficient permissions
```

**Solution:** 
1. Check Firestore security rules allow admin access
2. Ensure you're authenticated with Firebase
3. Run `firebase login` if needed

### Issue: Some users failed

```
❌ Error migrating user: ...
```

**Solution:**
1. Check the error message for specific user
2. Investigate user's data in Firebase Console
3. Fix data issue manually or update script
4. Re-run migration (it's idempotent - safe to run multiple times)

### Issue: User already has strategies

```
⏭️  User already has 1 strategy(ies), skipping
```

**This is normal!** The script skips users who already have strategies. This makes the migration idempotent (safe to run multiple times).

### Issue: Data didn't migrate

Check if data has `userId` field matching the user:
- Migration only migrates data linked by `userId`
- Data without `userId` won't be migrated
- Check Firestore queries in script match your data structure

## Rollback (If Needed)

If migration fails or causes issues:

### Option 1: Restore from Backup

```bash
# Import previous backup
gcloud firestore import gs://YOUR_BUCKET/backups/pre-migration-YYYYMMDD
```

### Option 2: Manual Rollback

For each affected user:

1. Delete created strategy:
   - Delete doc from `user_strategies` collection

2. Remove strategy references:
   ```javascript
   // Update user doc
   users/{userId}:
     - Remove defaultStrategyId
     - Remove strategyCount

   // Update values/visions/missions
   user_values, user_visions, user_mission_maps:
     - Remove strategyId field
   ```

3. Restart app and verify old code paths work

## Post-Migration

After successful migration:

### 1. Monitor Application
- Check error logs for issues
- Monitor user reports
- Watch for data inconsistencies

### 2. Update Security Rules

Add strategy-scoped rules (Phase 6):

```javascript
// Firestore Rules
match /user_values/{valueId} {
  allow read: if request.auth.uid == resource.data.userId;
  allow write: if request.auth.uid == request.resource.data.userId
                && request.resource.data.strategyId != null;
}
```

### 3. Update Indexes

Add composite indexes for strategy queries (Phase 6):

```json
{
  "indexes": [
    {
      "collectionGroup": "user_values",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "strategyId", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    }
  ]
}
```

### 4. Proceed to Phase 6

Once migration is verified:
- Remove deprecated code
- Update documentation
- Clean up old TODOs

## Migration Checklist

Use this checklist to track your migration progress:

- [ ] **Pre-Migration**
  - [ ] Backup database
  - [ ] Update Firebase credentials in script
  - [ ] Review migration script
  - [ ] Identify test user

- [ ] **Testing**
  - [ ] Run dry run (all users)
  - [ ] Run dry run (single user)
  - [ ] Run live migration (single user)
  - [ ] Verify single user in Firebase Console
  - [ ] Test single user in app

- [ ] **Production Migration**
  - [ ] Run full migration
  - [ ] Verify migration summary (0 errors)
  - [ ] Spot check 5 users in Firebase Console
  - [ ] Query for unmigrated data (should be 0)
  - [ ] Test app with multiple user accounts

- [ ] **Post-Migration**
  - [ ] Monitor error logs (24 hours)
  - [ ] Check user feedback
  - [ ] Update security rules (Phase 6)
  - [ ] Update indexes (Phase 6)
  - [ ] Mark Phase 5 complete

- [ ] **Cleanup** (Phase 6)
  - [ ] Remove deprecated providers
  - [ ] Remove deprecated Firestore methods
  - [ ] Update documentation
  - [ ] Archive migration script

## Estimated Timeline

- **Dry run testing**: 30 minutes
- **Single user testing**: 30 minutes
- **Full migration**: 5-30 minutes (depends on user count)
- **Verification**: 1 hour
- **Total**: ~2-3 hours

## Support

If you encounter issues:
1. Check this guide's troubleshooting section
2. Review migration script logs
3. Check Firebase Console for data state
4. Review Phase 4 test plan for validation steps

---

**Migration Status**: ⬜ Not Started | ⬜ Testing | ⬜ Complete | ⬜ Rolled Back

**Date Started**: ________________

**Date Completed**: ________________

**Notes**: 
