/// Data Migration Script: Multi-Strategy Architecture
/// 
/// This script migrates existing user data to the new multi-strategy model.
/// 
/// What it does:
/// 1. Creates a default strategy for each user without strategies
/// 2. Links all existing values/visions/missions to the default strategy
/// 3. Updates user records with defaultStrategyId and strategyCount
/// 4. Updates strategy denormalized fields (valueCount, currentVision, etc.)
/// 
/// Usage:
///   dart migrate_to_strategies.dart [--dry-run] [--user-id=<uid>]
/// 
/// Options:
///   --dry-run     Simulate migration without making changes
///   --user-id     Migrate only specific user (for testing)
///   --help        Show this help message

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Firebase configuration - altruency-purpose project
const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyD3dLLJuYznC0qzDiqp2t_KQ_dqyqKKYU4',
  authDomain: 'altruency-purpose.firebaseapp.com',
  projectId: 'altruency-purpose',
  storageBucket: 'altruency-purpose.firebasestorage.app',
  messagingSenderId: '519798970874',
  appId: '1:519798970874:web:5e15b35cb136868c5e6c43',
);

class MigrationStats {
  int usersProcessed = 0;
  int usersSkipped = 0;
  int strategiesCreated = 0;
  int valuesUpdated = 0;
  int visionsUpdated = 0;
  int missionMapsUpdated = 0;
  int sessionsUpdated = 0;
  int errors = 0;

  void printSummary() {
    print('\n' + '=' * 60);
    print('MIGRATION SUMMARY');
    print('=' * 60);
    print('Users processed:       $usersProcessed');
    print('Users skipped:         $usersSkipped');
    print('Strategies created:    $strategiesCreated');
    print('Values updated:        $valuesUpdated');
    print('Visions updated:       $visionsUpdated');
    print('Mission maps updated:  $missionMapsUpdated');
    print('Sessions updated:      $sessionsUpdated');
    print('Errors:                $errors');
    print('=' * 60);
  }
}

class StrategyMigration {
  final FirebaseFirestore db;
  final bool dryRun;
  final String? targetUserId;
  final MigrationStats stats = MigrationStats();

  StrategyMigration({
    required this.db,
    this.dryRun = false,
    this.targetUserId,
  });

  /// Main migration entry point
  Future<void> migrate() async {
    print('\n🚀 Starting multi-strategy migration...');
    print('Mode: ${dryRun ? "DRY RUN (no changes)" : "LIVE (will modify data)"}');
    
    if (targetUserId != null) {
      print('Target: Single user ($targetUserId)');
    } else {
      print('Target: All users');
    }
    
    if (!dryRun) {
      print('\n⚠️  WARNING: This will modify your database!');
      print('Press Ctrl+C within 5 seconds to cancel...');
      await Future.delayed(Duration(seconds: 5));
    }
    
    print('\n');

    try {
      // Get all users (or single user)
      final users = await _getUsers();
      print('📊 Found ${users.length} user(s) to process\n');

      // Process each user
      for (final user in users) {
        await _migrateUser(user);
      }

      // Print summary
      stats.printSummary();

      if (dryRun) {
        print('\n✅ Dry run complete. No changes were made.');
        print('Run without --dry-run to apply changes.');
      } else {
        print('\n✅ Migration complete!');
      }
    } catch (e, stack) {
      print('\n❌ Migration failed: $e');
      print(stack);
      stats.errors++;
      rethrow;
    }
  }

  /// Get users to migrate
  Future<List<Map<String, dynamic>>> _getUsers() async {
    Query query = db.collection('users');
    
    if (targetUserId != null) {
      final doc = await db.collection('users').doc(targetUserId).get();
      if (!doc.exists) {
        throw Exception('User $targetUserId not found');
      }
      return [{'uid': doc.id, ...doc.data()!}];
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {'uid': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  /// Migrate a single user
  Future<void> _migrateUser(Map<String, dynamic> user) async {
    final uid = user['uid'] as String;
    final email = user['email'] as String? ?? 'unknown';
    print('👤 Processing user: $email ($uid)');

    try {
      // Check if user already has strategies
      final existingStrategies = await _getUserStrategies(uid);
      
      if (existingStrategies.isNotEmpty) {
        print('   ⏭️  User already has ${existingStrategies.length} strategy(ies), skipping');
        stats.usersSkipped++;
        return;
      }

      // Create default strategy
      final defaultStrategy = await _createDefaultStrategy(user);
      
      // Migrate all existing data to this strategy
      await _migrateUserData(user, defaultStrategy);
      
      // Update user record
      await _updateUserRecord(user, defaultStrategy);
      
      stats.usersProcessed++;
      print('   ✅ User migration complete\n');
      
    } catch (e, stack) {
      print('   ❌ Error migrating user: $e');
      print(stack);
      stats.errors++;
      // Continue with other users
    }
  }

  /// Get existing strategies for a user
  Future<List<Map<String, dynamic>>> _getUserStrategies(String userId) async {
    final snapshot = await db
        .collection('user_strategies')
        .where('userId', isEqualTo: userId)
        .get();
    
    return snapshot.docs
        .map((doc) => doc.data())
        .toList();
  }

  /// Create default strategy for a user
  Future<Map<String, dynamic>> _createDefaultStrategy(Map<String, dynamic> user) async {
    print('   📝 Creating default strategy...');

    final now = DateTime.now();
    final strategyDoc = db.collection('user_strategies').doc();
    final uid = user['uid'] as String;
    final purpose = user['purpose'] as String?;
    
    final strategy = {
      'id': strategyDoc.id,
      'userId': uid,
      'name': 'My Strategy',
      'description': 'Default strategy (auto-created during migration)',
      'status': 'active',
      'isDefault': true,
      'purpose': purpose,
      'valueCount': 0,
      'currentVision': null,
      'currentMission': null,
      'createdAt': now,
      'updatedAt': now,
    };

    if (!dryRun) {
      await strategyDoc.set(strategy);
    }
    
    stats.strategiesCreated++;
    print('   ✓ Strategy created: ${strategy['id']}');
    
    return strategy;
  }

  /// Migrate all user data to the strategy
  Future<void> _migrateUserData(Map<String, dynamic> user, Map<String, dynamic> strategy) async {
    print('   📦 Migrating user data to strategy...');

    final uid = user['uid'] as String;
    final strategyId = strategy['id'] as String;
    
    // Migrate values
    final valueCount = await _migrateValues(uid, strategyId);
    
    // Migrate visions
    final currentVision = await _migrateVisions(uid, strategyId);
    
    // Migrate mission maps
    final currentMission = await _migrateMissionMaps(uid, strategyId);
    
    // Migrate sessions (value/vision/mission creation sessions)
    await _migrateSessions(uid, strategyId);
    
    // Update strategy denormalized fields
    await _updateStrategyDenormalizedFields(
      strategy,
      valueCount: valueCount,
      currentVision: currentVision,
      currentMission: currentMission,
    );
  }

  /// Migrate user values
  Future<int> _migrateValues(String userId, String strategyId) async {
    print('      ↳ Migrating values...');
    
    // Find values without strategyId (old data)
    final snapshot = await db
        .collection('user_values')
        .where('userId', isEqualTo: userId)
        .get();
    
    int migrated = 0;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      
      // Skip if already has strategyId
      if (data['strategyId'] != null) {
        continue;
      }
      
      if (!dryRun) {
        await doc.reference.update({
          'strategyId': strategyId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      migrated++;
    }
    
    stats.valuesUpdated += migrated;
    print('        ✓ Migrated $migrated value(s)');
    
    return migrated;
  }

  /// Migrate user visions
  Future<String?> _migrateVisions(String userId, String strategyId) async {
    print('      ↳ Migrating visions...');
    
    // Find visions without strategyId (old data)
    final snapshot = await db
        .collection('user_visions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    
    int migrated = 0;
    String? latestVision;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      
      // Skip if already has strategyId
      if (data['strategyId'] != null) {
        continue;
      }
      
      if (!dryRun) {
        await doc.reference.update({
          'strategyId': strategyId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      migrated++;
      
      // Track latest vision for denormalization
      if (latestVision == null) {
        latestVision = data['visionStatement'] as String?;
      }
    }
    
    stats.visionsUpdated += migrated;
    print('        ✓ Migrated $migrated vision(s)');
    
    return latestVision;
  }

  /// Migrate mission maps
  Future<String?> _migrateMissionMaps(String userId, String strategyId) async {
    print('      ↳ Migrating mission maps...');
    
    // Find mission maps without strategyId (old data)
    final snapshot = await db
        .collection('user_mission_maps')
        .where('userId', isEqualTo: userId)
        .get();
    
    int migrated = 0;
    String? currentMission;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      
      // Skip if already has strategyId
      if (data['strategyId'] != null) {
        continue;
      }
      
      if (!dryRun) {
        await doc.reference.update({
          'strategyId': strategyId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      migrated++;
      
      // Get current mission for denormalization
      final missions = data['missions'] as List<dynamic>?;
      final currentIndex = data['currentMissionIndex'] as int?;
      if (missions != null && 
          currentIndex != null && 
          currentIndex < missions.length) {
        currentMission = missions[currentIndex]['title'] as String?;
      }
    }
    
    stats.missionMapsUpdated += migrated;
    print('        ✓ Migrated $migrated mission map(s)');
    
    return currentMission;
  }

  /// Migrate creation sessions
  Future<void> _migrateSessions(String userId, String strategyId) async {
    print('      ↳ Migrating sessions...');
    
    int migrated = 0;
    
    // Migrate value creation sessions
    migrated += await _migrateCollection(
      'value_creation_sessions',
      userId,
      strategyId,
    );
    
    // Migrate vision creation sessions
    migrated += await _migrateCollection(
      'vision_creation_sessions',
      userId,
      strategyId,
    );
    
    // Migrate mission creation sessions
    migrated += await _migrateCollection(
      'mission_creation_sessions',
      userId,
      strategyId,
    );
    
    stats.sessionsUpdated += migrated;
    print('        ✓ Migrated $migrated session(s)');
  }

  /// Generic collection migration helper
  Future<int> _migrateCollection(
    String collection,
    String userId,
    String strategyId,
  ) async {
    final snapshot = await db
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .get();
    
    int migrated = 0;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      
      // Skip if already has strategyId
      if (data['strategyId'] != null) {
        continue;
      }
      
      if (!dryRun) {
        await doc.reference.update({
          'strategyId': strategyId,
        });
      }
      
      migrated++;
    }
    
    return migrated;
  }

  /// Update strategy's denormalized fields
  Future<void> _updateStrategyDenormalizedFields(
    Map<String, dynamic> strategy, {
    required int valueCount,
    required String? currentVision,
    required String? currentMission,
  }) async {
    print('      ↳ Updating strategy denormalized fields...');
    
    final strategyId = strategy['id'] as String;
    
    if (!dryRun) {
      await db.collection('user_strategies').doc(strategyId).update({
        'valueCount': valueCount,
        'currentVision': currentVision,
        'currentMission': currentMission,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    print('        ✓ Updated (valueCount=$valueCount, hasVision=${currentVision != null}, hasMission=${currentMission != null})');
  }

  /// Update user record with strategy info
  Future<void> _updateUserRecord(Map<String, dynamic> user, Map<String, dynamic> strategy) async {
    print('   🔄 Updating user record...');
    
    final uid = user['uid'] as String;
    final strategyId = strategy['id'] as String;
    
    if (!dryRun) {
      await db.collection('users').doc(uid).update({
        'defaultStrategyId': strategyId,
        'strategyCount': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    print('   ✓ User record updated');
  }
}

/// Parse command line arguments
Map<String, dynamic> parseArgs(List<String> args) {
  bool dryRun = false;
  String? userId;
  bool showHelp = false;

  for (final arg in args) {
    if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg.startsWith('--user-id=')) {
      userId = arg.substring('--user-id='.length);
    } else if (arg == '--help' || arg == '-h') {
      showHelp = true;
    } else {
      print('⚠️  Unknown argument: $arg');
      showHelp = true;
    }
  }

  return {
    'dryRun': dryRun,
    'userId': userId,
    'showHelp': showHelp,
  };
}

/// Show help message
void showHelp() {
  print('''
Data Migration Script: Multi-Strategy Architecture

This script migrates existing user data to the new multi-strategy model.

Usage:
  dart migrate_to_strategies.dart [OPTIONS]

Options:
  --dry-run           Simulate migration without making changes
  --user-id=<uid>     Migrate only specific user (for testing)
  --help, -h          Show this help message

Examples:
  # Dry run (preview changes)
  dart migrate_to_strategies.dart --dry-run

  # Migrate single user (testing)
  dart migrate_to_strategies.dart --dry-run --user-id=abc123

  # Live migration (all users)
  dart migrate_to_strategies.dart

  # Live migration (single user)
  dart migrate_to_strategies.dart --user-id=abc123

Important Notes:
  1. Always run with --dry-run first to preview changes
  2. Test on a single user before migrating all users
  3. Back up your database before live migration
  4. Migration is idempotent (safe to run multiple times)
''');
}

Future<void> main(List<String> args) async {
  // Parse arguments
  final config = parseArgs(args);
  
  if (config['showHelp']) {
    showHelp();
    exit(0);
  }

  print('🔥 Firebase Multi-Strategy Migration Tool');
  print('=' * 60);

  try {
    // Initialize Firebase
    print('Initializing Firebase...');
    await Firebase.initializeApp(options: firebaseOptions);
    final db = FirebaseFirestore.instance;
    print('✓ Firebase initialized\n');

    // Run migration
    final migration = StrategyMigration(
      db: db,
      dryRun: config['dryRun'],
      targetUserId: config['userId'],
    );

    await migration.migrate();
    
    exit(0);
  } catch (e, stack) {
    print('\n❌ FATAL ERROR: $e');
    print(stack);
    exit(1);
  }
}
