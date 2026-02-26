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
///   dart bin/migrate.dart [--dry-run] [--user-id=<uid>]
/// 
/// Options:
///   --dry-run     Simulate migration without making changes
///   --user-id     Migrate only specific user (for testing)
///   --help        Show this help message

import 'dart:io';
import 'package:firedart/firedart.dart';
import 'package:args/args.dart';

// Firebase configuration - altruency-purpose project
const projectId = 'altruency-purpose';
const apiKey = 'AIzaSyD3dLLJuYznC0qzDiqp2t_KQ_dqyqKKYU4';

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
  final Firestore db;
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
      
    } catch (e, stackTrace) {
      print('\n❌ Migration failed: $e');
      print('Stack trace: $stackTrace');
      stats.errors++;
      stats.printSummary();
      exit(1);
    }
    
    print('\n✅ Migration completed successfully!');
  }

  /// Get users to migrate
  Future<List<Map<String, dynamic>>> _getUsers() async {
    if (targetUserId != null) {
      try {
        final doc = await db.collection('users').document(targetUserId!).get();
        return [{'uid': doc.id, ...doc.map}];
      } catch (e) {
        throw Exception('User $targetUserId not found: $e');
      }
    }

    final docs = await db.collection('users').get();
    return docs.map((doc) => {'uid': doc.id, ...doc.map}).toList();
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
        print('   ⏭️  User already has ${existingStrategies.length} strateg(ies), skipping');
        stats.usersSkipped++;
        return;
      }

      // Create default strategy
      final defaultStrategy = await _createDefaultStrategy(user);

      // Migrate all user data to the strategy
      await _migrateUserData(user, defaultStrategy);

      // Update user record
      await _updateUserRecord(user, defaultStrategy);

      stats.usersProcessed++;
      print('   ✅ User migrated successfully\n');
      
    } catch (e, stackTrace) {
      print('   ❌ Error migrating user: $e');
      print('   Stack trace: $stackTrace');
      stats.errors++;
    }
  }

  /// Get existing strategies for a user
  Future<List<Map<String, dynamic>>> _getUserStrategies(String userId) async {
    final docs = await db
        .collection('user_strategies')
        .where('userId', isEqualTo: userId)
        .get();
    
    return docs.map((doc) => doc.map).toList();
  }

  /// Create default strategy for a user
  Future<Map<String, dynamic>> _createDefaultStrategy(Map<String, dynamic> user) async {
    print('   📝 Creating default strategy...');

    final now = DateTime.now();
    final uid = user['uid'] as String;
    final purpose = user['purpose'] as String?;
    
    final strategy = {
      'userId': uid,
      'name': 'My Strategy',
      'description': 'Default strategy (auto-created during migration)',
      'status': 'active',
      'isDefault': true,
      'purpose': purpose,
      'valueCount': 0,
      'currentVision': null,
      'currentMission': null,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    if (!dryRun) {
      final doc = await db.collection('user_strategies').add(strategy);
      strategy['id'] = doc.id;
      
      // Update the document to include the id field
      await db.collection('user_strategies').document(doc.id).update({
        'id': doc.id,
      });
    } else {
      strategy['id'] = 'dry-run-id';
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
    
    final docs = await db
        .collection('user_values')
        .where('userId', isEqualTo: userId)
        .get();
    
    if (docs.isEmpty) {
      print('        ✓ No values to migrate');
      return 0;
    }

    for (final doc in docs) {
      if (!dryRun) {
        await db.collection('user_values').document(doc.id).update({
          'strategyId': strategyId,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
      stats.valuesUpdated++;
    }
    
    print('        ✓ Migrated ${docs.length} value(s)');
    return docs.length;
  }

  /// Migrate user visions
  Future<String?> _migrateVisions(String userId, String strategyId) async {
    print('      ↳ Migrating visions...');
    
    final docs = await db
        .collection('user_visions')
        .where('userId', isEqualTo: userId)
        .get();
    
    if (docs.isEmpty) {
      print('        ✓ No visions to migrate');
      return null;
    }

    String? currentVisionId;
    
    for (final doc in docs) {
      final isCurrent = doc.map['isCurrent'] as bool? ?? false;
      
      if (!dryRun) {
        await db.collection('user_visions').document(doc.id).update({
          'strategyId': strategyId,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
      
      if (isCurrent) {
        currentVisionId = doc.id;
      }
      
      stats.visionsUpdated++;
    }
    
    print('        ✓ Migrated ${docs.length} vision(s)');
    return currentVisionId;
  }

  /// Migrate user mission maps
  Future<String?> _migrateMissionMaps(String userId, String strategyId) async {
    print('      ↳ Migrating mission maps...');
    
    final docs = await db
        .collection('user_mission_maps')
        .where('userId', isEqualTo: userId)
        .get();
    
    if (docs.isEmpty) {
      print('        ✓ No mission maps to migrate');
      return null;
    }

    String? currentMissionId;
    
    for (final doc in docs) {
      final isCurrent = doc.map['isCurrent'] as bool? ?? false;
      
      if (!dryRun) {
        await db.collection('user_mission_maps').document(doc.id).update({
          'strategyId': strategyId,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
      
      if (isCurrent) {
        currentMissionId = doc.id;
      }
      
      stats.missionMapsUpdated++;
    }
    
    print('        ✓ Migrated ${docs.length} mission map(s)');
    return currentMissionId;
  }

  /// Migrate creation sessions
  Future<void> _migrateSessions(String userId, String strategyId) async {
    print('      ↳ Migrating sessions...');
    
    int totalSessions = 0;

    // Value creation sessions
    final valueSessions = await db
        .collection('value_creation_sessions')
        .where('userId', isEqualTo: userId)
        .get();
    
    for (final doc in valueSessions) {
      if (!dryRun) {
        await db.collection('value_creation_sessions').document(doc.id).update({
          'strategyId': strategyId,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
      totalSessions++;
    }

    // Vision creation sessions
    final visionSessions = await db
        .collection('vision_creation_sessions')
        .where('userId', isEqualTo: userId)
        .get();
    
    for (final doc in visionSessions) {
      if (!dryRun) {
        await db.collection('vision_creation_sessions').document(doc.id).update({
          'strategyId': strategyId,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
      totalSessions++;
    }

    // Mission creation sessions
    final missionSessions = await db
        .collection('mission_creation_sessions')
        .where('userId', isEqualTo: userId)
        .get();
    
    for (final doc in missionSessions) {
      if (!dryRun) {
        await db.collection('mission_creation_sessions').document(doc.id).update({
          'strategyId': strategyId,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
      totalSessions++;
    }

    stats.sessionsUpdated += totalSessions;
    print('        ✓ Migrated $totalSessions session(s)');
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
      await db.collection('user_strategies').document(strategyId).update({
        'valueCount': valueCount,
        'currentVision': currentVision,
        'currentMission': currentMission,
        'updatedAt': DateTime.now().toIso8601String(),
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
      await db.collection('users').document(uid).update({
        'defaultStrategyId': strategyId,
        'strategyCount': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
    
    print('   ✓ User record updated');
  }
}

void main(List<String> arguments) async {
  // Parse command line arguments
  final parser = ArgParser()
    ..addFlag('dry-run',
        negatable: false, 
        defaultsTo: false,
        help: 'Simulate migration without making changes')
    ..addOption('user-id', help: 'Migrate only specific user (for testing)')
    ..addFlag('help', negatable: false, abbr: 'h', help: 'Show this help message');

  try {
    final args = parser.parse(arguments);

    if (args['help'] as bool) {
      print('Data Migration Script: Multi-Strategy Architecture\n');
      print('Usage: dart bin/migrate.dart [options]\n');
      print(parser.usage);
      exit(0);
    }

    final dryRun = args['dry-run'] as bool? ?? false;
    final userId = args['user-id'] as String?;

    // Initialize Firedart (pure Dart Firebase client)
    print('🔌 Connecting to Firebase...');
    Firestore.initialize(projectId);
    final db = Firestore.instance;
    
    print('✓ Connected to project: $projectId\n');

    // Run migration
    final migration = StrategyMigration(
      db: db,
      dryRun: dryRun,
      targetUserId: userId,
    );

    await migration.migrate();

  } on FormatException catch (e) {
    print('Error: ${e.message}\n');
    print(parser.usage);
    exit(1);
  } catch (e, stackTrace) {
    print('Fatal error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
