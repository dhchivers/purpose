/// Post-Migration Verification Script
/// 
/// Verifies that migration completed successfully by checking:
/// - All users have strategies
/// - All data has strategyId
/// - No orphaned data
/// - Data integrity
/// 
/// Usage:
///   dart verify_postmigration.dart

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

class MigrationIssue {
  final String severity; // 'error', 'warning', 'info'
  final String category;
  final String message;
  final String? docId;
  
  MigrationIssue({
    required this.severity,
    required this.category,
    required this.message,
    this.docId,
  });
}

class PostMigrationVerifier {
  final FirebaseFirestore db;
  final List<MigrationIssue> issues = [];
  
  int totalUsers = 0;
  int usersWithStrategies = 0;
  int orphanedValues = 0;
  int orphanedVisions = 0;
  int orphanedMissions = 0;
  int unmigratedValues = 0;
  int unmigratedVisions = 0;
  int unmigratedMissions = 0;
  int strategyCountMismatches = 0;
  
  PostMigrationVerifier(this.db);
  
  Future<void> verify() async {
    print('🔍 Running post-migration verification...\n');
    
    await _checkUsers();
    await _checkOrphanedData();
    await _checkUnmigratedData();
    await _checkDataIntegrity();
    
    _printResults();
  }
  
  Future<void> _checkUsers() async {
    print('   Checking users...');
    
    final snapshot = await db.collection('users').get();
    totalUsers = snapshot.docs.length;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final userId = doc.id;
      final defaultStrategyId = data['defaultStrategyId'] as String?;
      final strategyCount = data['strategyCount'] as int?;
      
      if (defaultStrategyId == null) {
        issues.add(MigrationIssue(
          severity: 'error',
          category: 'Users',
          message: 'User missing defaultStrategyId',
          docId: userId,
        ));
      } else {
        usersWithStrategies++;
        
        // Verify strategy exists
        final strategyDoc = await db.collection('user_strategies').doc(defaultStrategyId).get();
        if (!strategyDoc.exists) {
          issues.add(MigrationIssue(
            severity: 'error',
            category: 'Users',
            message: 'User points to non-existent strategy: $defaultStrategyId',
            docId: userId,
          ));
        }
      }
      
      // Check strategyCount
      if (strategyCount == null) {
        issues.add(MigrationIssue(
          severity: 'warning',
          category: 'Users',
          message: 'User missing strategyCount',
          docId: userId,
        ));
      } else {
        // Verify actual count matches
        final actualCount = await db
            .collection('user_strategies')
            .where('userId', isEqualTo: userId)
            .count()
            .get();
        
        if (actualCount.count != strategyCount) {
          strategyCountMismatches++;
          issues.add(MigrationIssue(
            severity: 'warning',
            category: 'Users',
            message: 'strategyCount mismatch: expected $strategyCount, found ${actualCount.count}',
            docId: userId,
          ));
        }
      }
    }
    
    print('   ✓ Checked $totalUsers users');
  }
  
  Future<void> _checkOrphanedData() async {
    print('   Checking for orphaned data...');
    
    // Check values
    final valuesSnapshot = await db.collection('user_values').get();
    for (final doc in valuesSnapshot.docs) {
      final data = doc.data();
      final strategyId = data['strategyId'] as String?;
      
      if (strategyId != null) {
        final strategyDoc = await db.collection('user_strategies').doc(strategyId).get();
        if (!strategyDoc.exists) {
          orphanedValues++;
          issues.add(MigrationIssue(
            severity: 'error',
            category: 'Values',
            message: 'Value points to non-existent strategy: $strategyId',
            docId: doc.id,
          ));
        }
      }
    }
    
    // Check visions
    final visionsSnapshot = await db.collection('user_visions').get();
    for (final doc in visionsSnapshot.docs) {
      final data = doc.data();
      final strategyId = data['strategyId'] as String?;
      
      if (strategyId != null) {
        final strategyDoc = await db.collection('user_strategies').doc(strategyId).get();
        if (!strategyDoc.exists) {
          orphanedVisions++;
          issues.add(MigrationIssue(
            severity: 'error',
            category: 'Visions',
            message: 'Vision points to non-existent strategy: $strategyId',
            docId: doc.id,
          ));
        }
      }
    }
    
    // Check mission maps
    final missionsSnapshot = await db.collection('user_mission_maps').get();
    for (final doc in missionsSnapshot.docs) {
      final data = doc.data();
      final strategyId = data['strategyId'] as String?;
      
      if (strategyId != null) {
        final strategyDoc = await db.collection('user_strategies').doc(strategyId).get();
        if (!strategyDoc.exists) {
          orphanedMissions++;
          issues.add(MigrationIssue(
            severity: 'error',
            category: 'Missions',
            message: 'Mission map points to non-existent strategy: $strategyId',
            docId: doc.id,
          ));
        }
      }
    }
    
    print('   ✓ Checked for orphaned data');
  }
  
  Future<void> _checkUnmigratedData() async {
    print('   Checking for unmigrated data...');
    
    // Values without strategyId
    final valuesSnapshot = await db.collection('user_values').get();
    for (final doc in valuesSnapshot.docs) {
      final data = doc.data();
      if (data['strategyId'] == null) {
        unmigratedValues++;
        issues.add(MigrationIssue(
          severity: 'error',
          category: 'Values',
          message: 'Value missing strategyId',
          docId: doc.id,
        ));
      }
    }
    
    // Visions without strategyId
    final visionsSnapshot = await db.collection('user_visions').get();
    for (final doc in visionsSnapshot.docs) {
      final data = doc.data();
      if (data['strategyId'] == null) {
        unmigratedVisions++;
        issues.add(MigrationIssue(
          severity: 'error',
          category: 'Visions',
          message: 'Vision missing strategyId',
          docId: doc.id,
        ));
      }
    }
    
    // Mission maps without strategyId
    final missionsSnapshot = await db.collection('user_mission_maps').get();
    for (final doc in missionsSnapshot.docs) {
      final data = doc.data();
      if (data['strategyId'] == null) {
        unmigratedMissions++;
        issues.add(MigrationIssue(
          severity: 'error',
          category: 'Missions',
          message: 'Mission map missing strategyId',
          docId: doc.id,
        ));
      }
    }
    
    print('   ✓ Checked for unmigrated data');
  }
  
  Future<void> _checkDataIntegrity() async {
    print('   Checking data integrity...');
    
    final strategiesSnapshot = await db.collection('user_strategies').get();
    
    for (final doc in strategiesSnapshot.docs) {
      final data = doc.data();
      final strategyId = doc.id;
      final userId = data['userId'] as String?;
      final valueCount = data['valueCount'] as int? ?? 0;
      
      if (userId == null) {
        issues.add(MigrationIssue(
          severity: 'error',
          category: 'Strategies',
          message: 'Strategy missing userId',
          docId: strategyId,
        ));
        continue;
      }
      
      // Verify user exists
      final userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        issues.add(MigrationIssue(
          severity: 'error',
          category: 'Strategies',
          message: 'Strategy points to non-existent user: $userId',
          docId: strategyId,
        ));
      }
      
      // Verify valueCount matches actual values
      final actualValues = await db
          .collection('user_values')
          .where('strategyId', isEqualTo: strategyId)
          .count()
          .get();
      
      if (actualValues.count != valueCount) {
        issues.add(MigrationIssue(
          severity: 'warning',
          category: 'Strategies',
          message: 'valueCount mismatch: expected $valueCount, found ${actualValues.count}',
          docId: strategyId,
        ));
      }
    }
    
    print('   ✓ Checked data integrity');
  }
  
  void _printResults() {
    print('\n' + '═' * 70);
    print('POST-MIGRATION VERIFICATION RESULTS');
    print('═' * 70);
    
    // Overall status
    final errors = issues.where((i) => i.severity == 'error').length;
    final warnings = issues.where((i) => i.severity == 'warning').length;
    
    if (errors == 0 && warnings == 0) {
      print('\n✅ MIGRATION SUCCESSFUL - No issues found!\n');
    } else {
      if (errors > 0) {
        print('\n❌ MIGRATION ISSUES DETECTED - $errors error(s) found\n');
      } else {
        print('\n⚠️  MIGRATION COMPLETED WITH WARNINGS - $warnings warning(s)\n');
      }
    }
    
    // Statistics
    print('📊 OVERVIEW');
    print('─' * 70);
    print('Total users:              $totalUsers');
    print('Users with strategies:    $usersWithStrategies');
    print('Users without strategies: ${totalUsers - usersWithStrategies}');
    
    if (totalUsers > 0) {
      final pct = (usersWithStrategies / totalUsers * 100).toStringAsFixed(1);
      print('  → ${pct}% migrated');
    }
    
    print('\n🔍 DATA CHECK');
    print('─' * 70);
    print('Unmigrated values:        $unmigratedValues');
    print('Unmigrated visions:       $unmigratedVisions');
    print('Unmigrated mission maps:  $unmigratedMissions');
    print('Orphaned values:          $orphanedValues');
    print('Orphaned visions:         $orphanedVisions');
    print('Orphaned mission maps:    $orphanedMissions');
    print('Strategy count mismatches: $strategyCountMismatches');
    
    // Issues by category
    if (issues.isNotEmpty) {
      print('\n⚠️  ISSUES FOUND');
      print('─' * 70);
      
      final byCategory = <String, List<MigrationIssue>>{};
      for (final issue in issues) {
        byCategory.putIfAbsent(issue.category, () => []).add(issue);
      }
      
      for (final category in byCategory.keys) {
        final categoryIssues = byCategory[category]!;
        final categoryErrors = categoryIssues.where((i) => i.severity == 'error').length;
        final categoryWarnings = categoryIssues.where((i) => i.severity == 'warning').length;
        
        print('\n$category: ${categoryIssues.length} issue(s)');
        print('  Errors: $categoryErrors | Warnings: $categoryWarnings');
        
        // Show first 5 issues
        final toShow = categoryIssues.take(5);
        for (final issue in toShow) {
          final icon = issue.severity == 'error' ? '❌' : '⚠️';
          final docInfo = issue.docId != null ? ' [${issue.docId}]' : '';
          print('  $icon ${issue.message}$docInfo');
        }
        
        if (categoryIssues.length > 5) {
          print('  ... and ${categoryIssues.length - 5} more');
        }
      }
    }
    
    print('\n' + '═' * 70);
    print('NEXT STEPS');
    print('═' * 70);
    
    if (errors > 0) {
      print('\n❌ Critical issues found:');
      print('   1. Review errors listed above');
      print('   2. Investigate affected documents in Firebase Console');
      print('   3. Fix data issues manually or re-run migration');
      print('   4. Run this verification script again');
      print('');
      print('   If issues persist, consider rollback:');
      print('   firebase firestore:import backup-YYYYMMDD');
    } else if (warnings > 0) {
      print('\n⚠️  Minor issues found:');
      print('   Review warnings above and decide if action needed');
      print('   Most warnings are non-critical but should be reviewed');
    } else {
      print('\n✅ Migration verified successfully!');
      print('');
      print('   Recommended next steps:');
      print('   1. Test application with multiple user accounts');
      print('   2. Monitor for 24 hours for issues');
      print('   3. Proceed to Phase 6: Cleanup & Documentation');
      print('      • Remove deprecated code');
      print('      • Update security rules');
      print('      • Update indexes');
      print('      • Update documentation');
    }
    
    print('\n' + '═' * 70);
    print('\n');
  }
}

Future<void> main() async {
  print('🔥 Post-Migration Verification\n');
  print('Connecting to Firebase...');
  
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    final db = FirebaseFirestore.instance;
    print('✅ Connected to: ${firebaseOptions.projectId}\n');
    
    final verifier = PostMigrationVerifier(db);
    await verifier.verify();
    
  } catch (e, stack) {
    print('\n❌ ERROR: $e');
    print(stack);
  }
}
