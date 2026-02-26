/// Add displayOrder field to existing strategies
/// Assigns order based on current document order or creation date

import 'dart:io';
import 'package:firedart/firedart.dart';

const projectId = 'altruency-purpose';

void main() async {
  print('🔧 Adding displayOrder to existing strategies...\n');
  
  Firestore.initialize(projectId);
  final db = Firestore.instance;
  
  print('✓ Connected to project: $projectId\n');
  
  try {
    // Get all users
    final users = await db.collection('users').get();
    
    print('📊 Found ${users.length} user(s)\n');
    
    int totalUpdated = 0;
    int totalSkipped = 0;
    
    for (final userDoc in users) {
      final userId = userDoc.id;
      final userData = userDoc.map;
      final userName = userData['fullName'] ?? 'Unknown User';
      
      print('User: $userName ($userId)');
      
      // Get all strategies for this user
      final strategies = await db
          .collection('user_strategies')
          .where('userId', isEqualTo: userId)
          .get();
      
      if (strategies.isEmpty) {
        print('  No strategies found\n');
        continue;
      }
      
      print('  Found ${strategies.length} strateg(ies)');
      
      // Sort by createdAt if available, otherwise keep document order
      final sortedStrategies = strategies.toList();
      sortedStrategies.sort((a, b) {
        final aCreatedAt = a.map['createdAt'];
        final bCreatedAt = b.map['createdAt'];
        
        if (aCreatedAt is int && bCreatedAt is int) {
          return aCreatedAt.compareTo(bCreatedAt);
        }
        return 0; // Keep original order if no timestamps
      });
      
      int updated = 0;
      int skipped = 0;
      
      for (int i = 0; i < sortedStrategies.length; i++) {
        final strategyDoc = sortedStrategies[i];
        final strategyData = strategyDoc.map;
        final strategyName = strategyData['name'] as String? ?? 'Unknown';
        
        // Check if displayOrder already exists
        if (strategyData.containsKey('displayOrder')) {
          print('    ⏭️  $strategyName - already has displayOrder');
          skipped++;
          continue;
        }
        
        // Add displayOrder
        await db.collection('user_strategies').document(strategyDoc.id).update({
          'displayOrder': i,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        
        print('    ✅ $strategyName - displayOrder: $i');
        updated++;
      }
      
      totalUpdated += updated;
      totalSkipped += skipped;
      
      print('  Updated: $updated, Skipped: $skipped\n');
    }
    
    print('📊 Overall Summary:');
    print('   Total Updated: $totalUpdated');
    print('   Total Skipped: $totalSkipped');
    print('\n✅ Migration completed successfully!');
    
  } catch (e, stackTrace) {
    print('\n❌ Error migrating strategies: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
