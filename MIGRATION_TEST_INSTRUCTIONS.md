# Testing the Mission Data Migration

## Quick Start Guide

### Access the Migration Test Page

1. **Start the app** (if not already running):
   ```bash
   flutter run -d chrome --web-port 8080
   ```

2. **Log in as admin** user

3. **Navigate to Admin Settings**:
   - Click your profile menu
   - Select "Admin Settings"

4. **Open Migration Test Page**:
   - Find "Mission Data Migration" tile
   - Click to open the migration test interface

### Step 1: Run Dry Run

**Important**: Always run a dry run first!

1. Click **"1. Run Dry Run (Preview)"** button
2. Wait for the analysis to complete
3. Review the output in the console below:
   - Total Mission Maps
   - Total Missions  
   - Maps with Sessions
   - Unique Strategies

This **DOES NOT** modify your database - it only creates a backup file and shows you what would be migrated.

### Step 2: Review Backup

After the dry run, check the `migration_backups/` folder:
- You'll see a file like: `user_mission_maps_backup_2026-03-03T10-30-45.123Z.json`
- This contains all your current mission data
- Keep this file safe - it's your rollback safety net

### Step 3: Run Migration (Optional)

Only proceed if:
- ✅ Dry run completed successfully
- ✅ Backup file created
- ✅ Stats look correct
- ✅ You're ready to modify the database

1. Click **"2. Run Actual Migration"** button
2. Confirm the warning dialog
3. Wait for migration to complete
4. Review verification results

### Expected Results

**Before Migration:**
```
user_mission_maps/
  doc1/
    - missions: [Mission1, Mission2, Mission3]
```

**After Migration:**
```
mission_maps/
  doc1/
    - totalMissions: 3
    - currentMissionIndex: 0
    
missions/
  doc1_mission_0/ - Mission1
  doc1_mission_1/ - Mission2  
  doc1_mission_2/ - Mission3
```

### Verification Checklist

After migration completes, verify:

- [ ] **Console shows**: "✅ Migration completed successfully!"
- [ ] **Firebase Console**: Check new collections exist
  - Go to: https://console.firebase.google.com/
  - Open: Firestore Database
  - Verify: `mission_maps` collection has documents
  - Verify: `missions` collection has documents
- [ ] **Count matches**: Total missions = sum of all mission arrays
- [ ] **App still works**: Navigate to mission pages and verify data loads

### Troubleshooting

**❌ Permission Denied**
- Temporarily update Firestore rules to allow admin access
- See [MISSION_MIGRATION_GUIDE.md](MISSION_MIGRATION_GUIDE.md) for details

**❌ Migration Failed**
1. Don't panic - your backup file has all data
2. Check console for error message
3. Note the backup file name
4. Contact support with backup and error details

**🔄 Need to Rollback?**
Currently rollback is only available via command line:
```bash
dart run migrate_missions.dart --rollback migration_backups/user_mission_maps_backup_[timestamp].json
```

### Next Steps After Successful Migration

1. **Deploy indexes** (if not already done):
   ```bash
   firebase deploy --only firestore:indexes
   ```

2. **Monitor the app** for 24-48 hours
   - Check for any mission loading errors
   - Verify navigation still works
   - Test mission updates

3. **Keep backup files** for at least 7 days
   - Don't delete `migration_backups/` folder
   - These are your safety net

4. **Update code** to use new structure:
   - Replace `UserMissionMap` references
   - Use new `MissionMap` and `MissionDocument` models
   - Update providers (see [MISSION_MIGRATION_GUIDE.md](MISSION_MIGRATION_GUIDE.md))

## Safety Notes

⚠️ **This is a production migration tool**
- The migration modifies your live Firestore database
- Always run dry run first
- Always verify backup was created
- Test during low-traffic times
- Have team members available to help monitor

✅ **Safe to use**
- Creates backups automatically
- Verifies data integrity
- Provides detailed logging
- Non-destructive (old collection preserved)

## Support

If you encounter issues:
1. Note the exact error message
2. Note the backup file name
3. Screenshot the console output
4. Check [MISSION_MIGRATION_GUIDE.md](MISSION_MIGRATION_GUIDE.md) for detailed troubleshooting
