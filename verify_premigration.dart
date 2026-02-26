/// Pre-Migration Database Verification Script
/// 
/// This script checks your database state before migration to help you understand:
/// - How many users exist
/// - How many users already have strategies
/// - How many values/visions/missions need migration
/// - Data integrity checks
/// 
/// Usage:
///   dart verify_premigration.dart

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

class DatabaseStats {
  int totalUsers = 0;
  int usersWithStrategies = 0;
  int usersWithoutStrategies = 0;
  int totalStrategies = 0;
  int totalValues = 0;
  int valuesWithStrategyId = 0;
  int valuesWithoutStrategyId = 0;
  int totalVisions = 0;
  int visionsWithStrategyId = 0;
  int visionsWithoutStrategyId = 0;
  int totalMissionMaps = 0;
  int missionMapsWithStrategyId = 0;
  int missionMapsWithoutStrategyId = 0;
  
  void printReport() {
    print('\n' + '═' * 70);
    print('PRE-MIGRATION DATABASE REPORT');
    print('═' * 70);
    
    print('\n📊 USER STATISTICS');
    print('─' * 70);
    print('Total users:                  $totalUsers');
    print('Users with strategies:        $usersWithStrategies');
    print('Users needing migration:      $usersWithoutStrategies');
    
    if (totalUsers > 0) {
      final pct = (usersWithoutStrategies / totalUsers * 100).toStringAsFixed(1);
      print('  → ${pct}% of users need migration');
    }
    
    print('\n📈 STRATEGY STATISTICS');
    print('─' * 70);
    print('Total strategies:             $totalStrategies');
    if (totalStrategies > 0 && totalUsers > 0) {
      final avg = (totalStrategies / totalUsers).toStringAsFixed(2);
      print('  → Average strategies/user:  $avg');
    }
    
    print('\n📝 VALUES MIGRATION STATUS');
    print('─' * 70);
    print('Total values:                 $totalValues');
    print('  ✓ Already migrated:         $valuesWithStrategyId');
    print('  ⏳ Need migration:          $valuesWithoutStrategyId');
    if (totalValues > 0) {
      final pct = (valuesWithoutStrategyId / totalValues * 100).toStringAsFixed(1);
      print('  → ${pct}% need migration');
    }
    
    print('\n🎯 VISIONS MIGRATION STATUS');
    print('─' * 70);
    print('Total visions:                $totalVisions');
    print('  ✓ Already migrated:         $visionsWithStrategyId');
    print('  ⏳ Need migration:          $visionsWithoutStrategyId');
    if (totalVisions > 0) {
      final pct = (visionsWithoutStrategyId / totalVisions * 100).toStringAsFixed(1);
      print('  → ${pct}% need migration');
    }
    
    print('\n🚀 MISSION MAPS MIGRATION STATUS');
    print('─' * 70);
    print('Total mission maps:           $totalMissionMaps');
    print('  ✓ Already migrated:         $missionMapsWithStrategyId');
    print('  ⏳ Need migration:          $missionMapsWithoutStrategyId');
    if (totalMissionMaps > 0) {
      final pct = (missionMapsWithoutStrategyId / totalMissionMaps * 100).toStringAsFixed(1);
      print('  → ${pct}% need migration');
    }
    
    print('\n' + '═' * 70);
    print('MIGRATION IMPACT ESTIMATE');
    print('═' * 70);
    
    if (usersWithoutStrategies > 0) {
      print('\n✅ Migration will:');
      print('   • Create $usersWithoutStrategies default strategies');
      print('   • Update $usersWithoutStrategies user documents');
      print('   • Add strategyId to $valuesWithoutStrategyId values');
      print('   • Add strategyId to $visionsWithoutStrategyId visions');
      print('   • Add strategyId to $missionMapsWithoutStrategyId mission maps');
      
      final totalUpdates = usersWithoutStrategies * 2 + // strategy + user
                          valuesWithoutStrategyId +
                          visionsWithoutStrategyId +
                          missionMapsWithoutStrategyId;
      print('\n   Total document writes: ~$totalUpdates');
      
      // Time estimate (assuming ~100 writes/second)
      final seconds = (totalUpdates / 100).ceil();
      if (seconds < 60) {
        print('   Estimated time: ~${seconds}s');
      } else {
        final minutes = (seconds / 60).ceil();
        print('   Estimated time: ~${minutes}min');
      }
    } else {
      print('\n✅ No migration needed - all users already have strategies!');
    }
    
    print('\n' + '═' * 70);
    print('\n');
  }
}

class PreMigrationVerifier {
  final FirebaseFirestore db;
  final DatabaseStats stats = DatabaseStats();
  
  PreMigrationVerifier(this.db);
  
  Future<void> verify() async {
    print('🔍 Scanning database...\n');
    
    await _checkUsers();
    await _checkStrategies();
    await _checkValues();
    await _checkVisions();
    await _checkMissionMaps();
    
    stats.printReport();
    
    _printRecommendations();
  }
  
  Future<void> _checkUsers() async {
    print('   Checking users...');
    final snapshot = await db.collection('users').get();
    stats.totalUsers = snapshot.docs.length;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['defaultStrategyId'] != null) {
        stats.usersWithStrategies++;
      } else {
        stats.usersWithoutStrategies++;
      }
    }
    
    print('   ✓ Found ${stats.totalUsers} users');
  }
  
  Future<void> _checkStrategies() async {
    print('   Checking strategies...');
    final snapshot = await db.collection('user_strategies').get();
    stats.totalStrategies = snapshot.docs.length;
    print('   ✓ Found ${stats.totalStrategies} strategies');
  }
  
  Future<void> _checkValues() async {
    print('   Checking values...');
    final snapshot = await db.collection('user_values').get();
    stats.totalValues = snapshot.docs.length;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['strategyId'] != null) {
        stats.valuesWithStrategyId++;
      } else {
        stats.valuesWithoutStrategyId++;
      }
    }
    
    print('   ✓ Found ${stats.totalValues} values');
  }
  
  Future<void> _checkVisions() async {
    print('   Checking visions...');
    final snapshot = await db.collection('user_visions').get();
    stats.totalVisions = snapshot.docs.length;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['strategyId'] != null) {
        stats.visionsWithStrategyId++;
      } else {
        stats.visionsWithoutStrategyId++;
      }
    }
    
    print('   ✓ Found ${stats.totalVisions} visions');
  }
  
  Future<void> _checkMissionMaps() async {
    print('   Checking mission maps...');
    final snapshot = await db.collection('user_mission_maps').get();
    stats.totalMissionMaps = snapshot.docs.length;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['strategyId'] != null) {
        stats.missionMapsWithStrategyId++;
      } else {
        stats.missionMapsWithoutStrategyId++;
      }
    }
    
    print('   ✓ Found ${stats.totalMissionMaps} mission maps');
  }
  
  void _printRecommendations() {
    print('💡 RECOMMENDATIONS');
    print('─' * 70);
    
    if (stats.usersWithoutStrategies == 0) {
      print('✅ All users already have strategies - no migration needed!');
      print('   You can skip Phase 5 and proceed to Phase 6 (Cleanup).');
      return;
    }
    
    print('📋 Before running migration:');
    print('   1. Backup your database:');
    print('      firebase firestore:export backup-\$(date +%Y%m%d)');
    print('');
    print('   2. Run dry-run to preview:');
    print('      dart migrate_to_strategies.dart --dry-run');
    print('');
    print('   3. Test on single user:');
    print('      dart migrate_to_strategies.dart --user-id=<USER_ID>');
    print('');
    print('   4. Verify test user in Firebase Console and app');
    print('');
    print('   5. Run full migration:');
    print('      dart migrate_to_strategies.dart');
    print('');
    
    if (stats.totalUsers > 100) {
      print('⚠️  LARGE DATABASE WARNING');
      print('   You have ${stats.totalUsers} users. Consider:');
      print('   • Running migration during off-peak hours');
      print('   • Monitoring Firestore usage/costs during migration');
      print('   • Testing thoroughly with multiple users first');
      print('');
    }
    
    if (stats.valuesWithStrategyId > 0 || 
        stats.visionsWithStrategyId > 0 || 
        stats.missionMapsWithStrategyId > 0) {
      print('ℹ️  PARTIAL MIGRATION DETECTED');
      print('   Some data already has strategyId. This suggests:');
      print('   • Migration was previously run on some users');
      print('   • OR data was created after Phase 4 deployment');
      print('   The migration script will skip already-migrated data.');
      print('');
    }
    
    print('─' * 70);
  }
}

Future<void> main() async {
  print('🔥 Pre-Migration Database Verification\n');
  print('Connecting to Firebase...');
  
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    final db = FirebaseFirestore.instance;
    print('✅ Connected to: ${firebaseOptions.projectId}\n');
    
    final verifier = PreMigrationVerifier(db);
    await verifier.verify();
    
  } catch (e, stack) {
    print('\n❌ ERROR: $e');
    print(stack);
  }
}
