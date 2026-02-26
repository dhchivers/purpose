# Phase 5: Data Migration - Complete

## ✅ Phase 5 Implementation Complete

All migration tools and documentation have been created. The migration is **ready to run** when you're ready.

## 📦 Files Created

### Migration Scripts
1. **[migrate_to_strategies.dart](migrate_to_strategies.dart)** (550 lines)
   - Main migration script
   - Creates default strategies for users
   - Links all existing data to strategies
   - Updates denormalized fields
   - Supports dry-run and single-user testing

2. **[verify_premigration.dart](verify_premigration.dart)** (240 lines)
   - Database verification tool
   - Shows current migration state
   - Estimates migration impact
   - Provides recommendations

3. **[run_migration.sh](run_migration.sh)** (130 lines)
   - Interactive migration helper
   - Menu-driven interface
   - Safety checks and confirmations

### Documentation
4. **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** (comprehensive guide)
   - Complete step-by-step instructions
   - Prerequisites and setup
   - Testing procedures
   - Troubleshooting
   - Rollback procedures

5. **[MIGRATION_QUICK_REF.md](MIGRATION_QUICK_REF.md)** (quick reference)
   - Command cheat sheet
   - Verification queries
   - Common issues and fixes

## 🚀 Quick Start

### Step 1: Verify Current State
```bash
dart verify_premigration.dart
```

This shows:
- How many users need migration
- How much data will be updated
- Estimated time

### Step 2: Preview Changes (Dry Run)
```bash
dart migrate_to_strategies.dart --dry-run
```

Safe to run - makes no changes, just shows what would happen.

### Step 3: Test on Single User
```bash
# Get a test user ID from Firebase Console
dart migrate_to_strategies.dart --user-id=<USER_ID>
```

Verify the test user in:
- Firebase Console (check strategyId fields)
- Your app (login and test all pages)

### Step 4: Full Migration
```bash
dart migrate_to_strategies.dart
```

Migrates all users. Takes 5-30 minutes depending on data size.

### Interactive Helper
```bash
./run_migration.sh
```

Menu-driven interface with safety checks.

## 📊 What Gets Migrated

| Action | Target | Result |
|--------|--------|--------|
| Create default strategy | Each user without strategies | New doc in `user_strategies` |
| Update user record | `users` collection | Add `defaultStrategyId`, `strategyCount` |
| Link values | `user_values` | Add `strategyId` field |
| Link visions | `user_visions` | Add `strategyId` field |
| Link mission maps | `user_mission_maps` | Add `strategyId` field |
| Link sessions | `*_creation_sessions` | Add `strategyId` field |
| Update strategy stats | `user_strategies` | Set `valueCount`, `currentVision`, `currentMission` |

## ⚠️ Important Notes

### Migration is Idempotent
✅ Safe to run multiple times
- Skips users who already have strategies
- Skips data that already has `strategyId`
- Can be interrupted and restarted

### Users Already Using Phase 4 Code
If you've deployed Phase 4 to production and users have created strategies:
- Those users will be **skipped** (already migrated)
- Only users without strategies will be migrated
- New data created after Phase 4 already has `strategyId`

### Backup First!
🚨 **Always backup before live migration:**
```bash
firebase firestore:export backup-$(date +%Y%m%d)
```

## 🔍 Verification Checklist

After migration, verify:

### In Firebase Console
- [ ] Random users have `defaultStrategyId` field
- [ ] Strategy documents exist in `user_strategies`
- [ ] Values have `strategyId` field
- [ ] Visions have `strategyId` field
- [ ] Mission maps have `strategyId` field

### Query for Unmigrated Data
```javascript
// Should return 0 results:
Collection: user_values
WHERE: strategyId == null
```

### In Application
- [ ] Login as migrated user
- [ ] Dashboard shows strategy selector
- [ ] Values page displays correctly
- [ ] Vision page displays correctly
- [ ] Mission map page displays correctly
- [ ] Can create new data (has strategyId)

## 📈 Migration Stats Example

After running migration, you'll see:

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
- `Errors` is 0
- `Users processed` matches expected count
- Numbers make sense for your data

## 🛠️ Troubleshooting

### Issue: Firebase connection fails
**Fix:** Script already has correct credentials for `altruency-purpose` project

### Issue: Some users show errors
**Action:** 
1. Check error message in output
2. Investigate user's data in Firebase Console
3. Re-run migration (skips successful users)

### Issue: Data didn't migrate
**Check:**
- Does data have correct `userId` field?
- Does user exist in `users` collection?
- Check migration logs for that user

## 🔄 Rollback (If Needed)

### Option 1: Restore Backup
```bash
firebase firestore:import backup-YYYYMMDD
```

### Option 2: Delete Migration Changes
For each user:
1. Delete strategy from `user_strategies`
2. Remove `defaultStrategyId` from user doc
3. Remove `strategyId` from values/visions/missions

## ⏱️ Estimated Timeline

| Step | Duration |
|------|----------|
| Pre-migration verification | 10 min |
| Dry run testing | 20 min |
| Single user testing | 30 min |
| Full migration execution | 5-30 min |
| Post-migration verification | 1 hour |
| **Total** | **~2-3 hours** |

## ✅ Ready to Migrate?

1. Review [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed instructions
2. Use [MIGRATION_QUICK_REF.md](MIGRATION_QUICK_REF.md) for commands
3. Run `dart verify_premigration.dart` to see current state
4. Follow the 4-step process above

## 🎯 Next Steps

After successful migration:

1. **Monitor application** (24 hours)
   - Watch for errors
   - Check user feedback
   - Verify data integrity

2. **Proceed to Phase 6: Cleanup & Documentation**
   - Remove deprecated code
   - Update Firestore security rules
   - Update Firestore indexes
   - Update project documentation

---

## Phase 5 Status

- [x] Migration script created
- [x] Verification script created
- [x] Helper scripts created
- [x] Comprehensive documentation written
- [x] Firebase credentials configured
- [ ] **Migration executed** (when you're ready)
- [ ] **Post-migration verification** (after execution)

---

**Phase 5 Implementation**: ✅ **COMPLETE**  
**Migration Execution**: ⏳ **Ready to run when you are**

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for step-by-step instructions.
