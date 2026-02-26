# Phase 5: Data Migration - Quick Reference

## Quick Start Commands

### 1. Preview Changes (Safe - No Modifications)
```bash
# Preview all users
dart migrate_to_strategies.dart --dry-run

# Preview single user
dart migrate_to_strategies.dart --dry-run --user-id=<USER_ID>
```

### 2. Test Migration (Single User)
```bash
# Migrate one user to test
dart migrate_to_strategies.dart --user-id=<USER_ID>
```

### 3. Full Migration (All Users)
```bash
# Migrate all users
dart migrate_to_strategies.dart
```

### 4. Interactive Helper
```bash
# Use the interactive menu
./run_migration.sh
```

---

## Pre-Migration Checklist

- [ ] Backup Firestore database
  ```bash
  firebase firestore:export backup-$(date +%Y%m%d)
  ```
- [ ] Verify Firebase credentials in script
- [ ] Run dry run on all users
- [ ] Test migration on single user
- [ ] Verify test user in Firebase Console
- [ ] Test app with migrated user

---

## What Gets Migrated

For each user **without strategies**:

| Action | Collection | Field Added |
|--------|-----------|-------------|
| Create default strategy | `user_strategies` | New document |
| Update user record | `users` | `defaultStrategyId`, `strategyCount` |
| Link values | `user_values` | `strategyId` |
| Link visions | `user_visions` | `strategyId` |
| Link mission maps | `user_mission_maps` | `strategyId` |
| Link sessions | `*_creation_sessions` | `strategyId` |
| Update strategy stats | `user_strategies` | `valueCount`, `currentVision`, `currentMission` |

---

## Verification Queries

### Check for unmigrated data

```javascript
// In Firestore Console > Query tab

// Values without strategyId
Collection: user_values
WHERE: strategyId == null

// Visions without strategyId  
Collection: user_visions
WHERE: strategyId == null

// Mission maps without strategyId
Collection: user_mission_maps
WHERE: strategyId == null

// All should return 0 results after migration
```

### Check user has strategy

```javascript
// Users collection
Collection: users
Document: <USER_ID>

// Should have:
defaultStrategyId: "strat-xyz..."
strategyCount: 1
```

---

## Common Issues

### Issue: "Firebase project not found"
**Fix:** Update credentials in `migrate_to_strategies.dart`

### Issue: "Permission denied"
**Fix:** Check Firestore security rules, run `firebase login`

### Issue: User already has strategies
**Expected:** Script skips users with strategies (idempotent)

### Issue: Some users failed
**Fix:** Check error message, fix data, re-run (safe to run multiple times)

---

## Rollback Steps

If migration causes issues:

1. **Restore from backup:**
   ```bash
   firebase firestore:import backup-YYYYMMDD
   ```

2. **Manual rollback** (per user):
   - Delete strategy doc from `user_strategies`
   - Remove `defaultStrategyId` from user doc
   - Remove `strategyId` from values/visions/missions

---

## Post-Migration Verification

### In Firebase Console:
- [ ] Random user has strategy document
- [ ] User has `defaultStrategyId` field  
- [ ] Values have `strategyId` field
- [ ] No documents missing `strategyId` (query above)

### In App:
- [ ] Dashboard shows strategy selector
- [ ] Values page displays correctly
- [ ] Vision page displays correctly
- [ ] Mission map page displays correctly
- [ ] Can create new data with strategyId

---

## Timeline Estimate

| Step | Duration |
|------|----------|
| Dry run testing | 30 min |
| Single user testing | 30 min |
| Full migration | 5-30 min |
| Verification | 1 hour |
| **Total** | **2-3 hours** |

---

## Migration Stats Example

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

**Check:**
- Users processed = total user count
- Errors = 0
- Numbers make sense for your data

---

## Files Created in Phase 5

1. **`migrate_to_strategies.dart`** - Main migration script
2. **`MIGRATION_GUIDE.md`** - Detailed migration guide
3. **`MIGRATION_QUICK_REF.md`** - This quick reference
4. **`run_migration.sh`** - Interactive helper script

---

## Next Steps

After successful migration:

1. **Monitor app** for 24 hours
2. **Phase 6: Cleanup**
   - Remove deprecated code
   - Update security rules
   - Update indexes
   - Update documentation

---

**Need Help?** See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed instructions.
