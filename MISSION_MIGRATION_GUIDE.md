# Mission Data Structure Migration Guide

## Overview

This migration refactors the mission data structure from a single collection with embedded arrays to two separate collections for better scalability and querying.

### Old Structure
```
user_mission_maps/
  {docId}/
    - id, strategyId, userId
    - missions: [Mission, Mission, Mission]  ← EMBEDDED ARRAY
    - sessionId, currentMissionIndex
    - createdAt, updatedAt
```

### New Structure
```
mission_maps/              missions/
  {docId}/                   {docId}/
    - id, strategyId           - id, missionMapId
    - totalMissions            - strategyId, sequenceNumber
    - currentMissionIndex      - mission, focus, etc.
    - sessionId                - createdAt, updatedAt
    - createdAt, updatedAt
```

## Benefits

1. **Individual mission updates** - No need to rewrite entire document
2. **Direct mission queries** - Query missions by strategyId, riskLevel, etc.
3. **Composite indexes** - Create Firestore indexes on mission fields
4. **Better scaling** - No document size limits
5. **Efficient caching** - Firestore can cache individual missions

## Migration Steps

### 1. Dry Run (Preview Changes)

First, run a dry run to preview what will be migrated:

```bash
dart run migrate_missions.dart --dry-run
```

This will:
- ✅ Create a backup file
- ✅ Show statistics about your data
- ❌ NOT modify the database

**Review the output carefully!**

### 2. Run Migration

When ready, run the actual migration:

```bash
dart run migrate_missions.dart
```

This will:
1. Create a backup file in `migration_backups/`
2. Analyze your data
3. Ask for confirmation
4. Migrate data to new structure
5. Verify the migration succeeded

**Important:** Follow the prompts and confirm when asked!

### 3. Verify Data

After migration, verify everything looks correct:

```bash
# Option 1: Check Firestore console
# - Open Firebase Console
# - Navigate to Firestore Database
# - Check mission_maps and missions collections

# Option 2: Query in your app
# - Use the new FirestoreService methods
# - Check that missions load correctly
```

### 4. Rollback (If Needed)

If something goes wrong, you can rollback:

```bash
dart run migrate_missions.dart --rollback migration_backups/user_mission_maps_backup_2024-01-15.json
```

This will:
1. Delete mission_maps and missions collections
2. Restore user_mission_maps from backup
3. Return your database to pre-migration state

## Migration Verification Checklist

After migration, verify:

- [ ] **Count**: mission_maps count matches old user_mission_maps count
- [ ] **Count**: Total missions count matches sum of all mission arrays
- [ ] **References**: Each mission has correct missionMapId
- [ ] **Ordering**: sequenceNumber matches original array index (0, 1, 2...)
- [ ] **Data**: All fields preserved (mission, focus, structuralShift, etc.)
- [ ] **Relationships**: strategyId references are correct
- [ ] **UI**: App loads and displays missions correctly
- [ ] **Navigation**: Can advance through missions successfully

## Firestore Indexes

After migration, deploy the new indexes:

```bash
firebase deploy --only firestore:indexes
```

The following indexes will be created:

```json
{
  "indexes": [
    {
      "collectionGroup": "mission_maps",
      "fields": [
        {"fieldPath": "strategyId", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "missions",
      "fields": [
        {"fieldPath": "missionMapId", "order": "ASCENDING"},
        {"fieldPath": "sequenceNumber", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "missions",
      "fields": [
        {"fieldPath": "strategyId", "order": "ASCENDING"},
        {"fieldPath": "sequenceNumber", "order": "ASCENDING"}
      ]
    }
  ]
}
```

## Code Updates Required

### Update Providers

Replace old UserMissionMap providers with new ones:

```dart
// OLD
final userMissionMapProvider = StreamProvider.family<UserMissionMap?, String>(...);

// NEW
final missionMapProvider = StreamProvider.family<MissionMap?, String>((ref, strategyId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.missionMapStream(strategyId);
});

final missionsForMapProvider = StreamProvider.family<List<MissionDocument>, String>((ref, missionMapId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.missionsForMapStream(missionMapId);
});
```

### Update UI Components

Replace method calls:

```dart
// OLD
final missionMap = await firestoreService.getUserMissionMap(strategyId);
final currentMission = missionMap?.missions[missionMap.currentMissionIndex];

// NEW
final missionMap = await firestoreService.getMissionMap(strategyId);
final missions = await firestoreService.getMissionsForMap(missionMap.id);
final currentMission = missions[missionMap.currentMissionIndex];
```

## Troubleshooting

### Migration fails with "Permission denied"

**Cause:** Firestore security rules blocking the migration script

**Solution:** Temporarily allow admin access (use with caution):
```javascript
// firestore.rules
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true; // ⚠️ TEMPORARILY for migration
    }
  }
}
```

Don't forget to restore proper rules after migration!

### Missing missions after migration

**Cause:** Mission array was empty or null in original document

**Solution:** Check backup file to confirm data. If missions were truly missing, no action needed.

### sequenceNumber out of order

**Cause:** Bug in migration script

**Solution:** Run rollback and report the issue. The sequenceNumber should always match the array index (0, 1, 2, 3, 4).

### Rollback fails

**Cause:** Backup file not found or corrupted

**Solution:** 
1. Check the `migration_backups/` directory
2. Verify the backup file exists and is valid JSON
3. If backup is corrupted, contact support immediately

## Safety Notes

⚠️ **Before migration:**
- Test on a staging/development environment first
- Schedule during low-traffic time
- Have team members available for monitoring
- Ensure you have Firebase project admin access

✅ **After migration:**
- Keep backup files for at least 7 days
- Monitor for errors in production
- Verify all mission-related features work
- Update documentation

## Support

If you encounter issues during migration:

1. **Don't panic** - The backup file contains all your data
2. **Don't delete backup files** - You need them for rollback
3. **Run rollback if needed** - It's safe and tested
4. **Document the error** - Copy error messages for debugging
5. **Contact team** - Share backup file and error logs

## Post-Migration Cleanup

After successful migration and 7 days of monitoring:

1. Archive old `user_mission_maps` collection (don't delete immediately)
2. Remove old methods from FirestoreService (marked deprecated)
3. Update all documentation references
4. Clean up old backup files (keep at least one)

## Files Modified by Migration

- `lib/core/models/mission_map.dart` - New model (metadata only)
- `lib/core/models/mission_document.dart` - New model (individual missions)
- `lib/core/services/firestore_service.dart` - New methods added
- `firestore.indexes.json` - New indexes for optimized queries

## Timeline

**Recommended migration timeline:**

- **Week 1**: Test migration on staging environment
- **Week 2**: Schedule production migration
- **Week 3-4**: Monitor production, keep backups ready
- **Week 5**: Begin code updates to use new structure
- **Week 6-8**: Complete transition, deprecate old methods
- **Week 9**: Archive old collection, cleanup backups
