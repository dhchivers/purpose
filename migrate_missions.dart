import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purpose/core/services/mission_migration_script.dart';

/// Command-line tool to migrate mission data structure
/// 
/// USAGE:
///   dart run migrate_missions.dart              # Run migration (with confirmation)
///   dart run migrate_missions.dart --dry-run    # Preview migration without changes
///   dart run migrate_missions.dart --rollback <backup-file>  # Rollback from backup
///   dart run migrate_missions.dart --staging    # Use staging environment
/// 
/// EXAMPLES:
///   dart run migrate_missions.dart --dry-run
///   dart run migrate_missions.dart
///   dart run migrate_missions.dart --rollback migration_backups/user_mission_maps_backup_2024-01-15.json

void main(List<String> args) async {
  print('\n🚀 Mission Data Structure Migration Tool\n');

  // Parse arguments
  final dryRun = args.contains('--dry-run');
  final isStaging = args.contains('--staging');
  final rollbackIndex = args.indexOf('--rollback');
  final isRollback = rollbackIndex != -1;
  final backupFile = isRollback && args.length > rollbackIndex + 1
      ? args[rollbackIndex + 1]
      : null;

  if (isRollback && backupFile == null) {
    print('❌ Error: --rollback requires a backup file path');
    print('Usage: dart run migrate_missions.dart --rollback <backup-file>');
    return;
  }

  try {
    // Initialize Firebase with production config
    // Note: For staging, you would use different Firebase project credentials
    print('🔧 Initializing Firebase...');
    print('Environment: ${isStaging ? 'STAGING' : 'PRODUCTION'}');
    
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyD3dLLJuYznC0qzDiqp2t_KQ_dqyqKKYU4',
        authDomain: 'altruency-purpose.firebaseapp.com',
        projectId: 'altruency-purpose',
        storageBucket: 'altruency-purpose.firebasestorage.app',
        messagingSenderId: '519798970874',
        appId: '1:519798970874:web:5e15b35cb136868c5e6c43',
      ),
    );
    
    // Configure Firestore
    final firestore = FirebaseFirestore.instance;
    firestore.settings = const Settings(
      persistenceEnabled: false,
      sslEnabled: true,
    );
    
    print('✅ Firebase initialized\n');

    // Create migrator
    final migrator = MissionMigrationScript();

    if (isRollback) {
      // Run rollback
      await migrator.rollback(backupFile!);
    } else {
      // Run migration
      await migrator.runMigration(dryRun: dryRun);
    }
  } catch (e, stackTrace) {
    print('\n❌ Fatal error: $e');
    print('Stack trace: $stackTrace');
    print('\nMigration terminated.\n');
  }
}
