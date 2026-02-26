/// Delete all strategies (for re-migration with proper timestamps)

import 'dart:io';
import 'package:firedart/firedart.dart';

const projectId = 'altruency-purpose';

void main() async {
  print('🗑️  Deleting all user_strategies documents...');
  print('⚠️  This will allow re-running the migration with proper timestamp format\n');
  
  print('Press Enter to continue or Ctrl+C to cancel...');
  stdin.readLineSync();
  
  Firestore.initialize(projectId);
  final db = Firestore.instance;
  
  print('✓ Connected to project: $projectId\n');
  
  try {
    final strategies = await db.collection('user_strategies').get();
    
    print('📊 Found ${strategies.length} strateg(ies) to delete\n');
    
    for (final doc in strategies) {
      print('  Deleting ${doc.id}...');
      await db.collection('user_strategies').document(doc.id).delete();
    }
    
    // Also remove strategyId from migrated data
    print('\n🔄 Removing strategyId from migrated collections...');
    
    final values = await db.collection('user_values').get();
    print('  Found ${values.length} value(s) to reset');
    for (final doc in values) {
      await db.collection('user_values').document(doc.id).update({
        'strategyId': null,
      });
    }
    
    print('\n✅ Cleanup completed! You can now re-run the migration.');
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
