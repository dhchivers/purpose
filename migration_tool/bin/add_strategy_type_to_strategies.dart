/// Add strategyTypeId to existing strategies
/// Assigns the Personal type to all strategies that don't have a strategyTypeId

import 'dart:io';
import 'package:firedart/firedart.dart';

const projectId = 'altruency-purpose';

void main() async {
  print('🔧 Adding strategyTypeId to existing strategies...\n');
  
  Firestore.initialize(projectId);
  final db = Firestore.instance;
  
  print('✓ Connected to project: $projectId\n');
  
  try {
    // Get the Personal strategy type
    print('📖 Finding Personal strategy type...');
    final personalTypes = await db
        .collection('strategy_types')
        .where('name', isEqualTo: 'Personal')
        .get();
    
    if (personalTypes.isEmpty) {
      print('❌ Error: Personal strategy type not found!');
      print('   Please run seed_strategy_types.dart first to create the strategy types.');
      exit(1);
    }
    
    final personalType = personalTypes.first;
    final personalTypeId = personalType.id;
    
    print('✓ Found Personal type: $personalTypeId\n');
    
    // Get all strategies
    final strategies = await db.collection('user_strategies').get();
    
    print('📊 Found ${strategies.length} strateg(ies) to check\n');
    
    int updated = 0;
    int skipped = 0;
    
    for (final strategyDoc in strategies) {
      final strategyId = strategyDoc.id;
      final strategyData = strategyDoc.map;
      final name = strategyData['name'] as String? ?? 'Unknown';
      
      // Check if strategyTypeId already exists
      if (strategyData.containsKey('strategyTypeId')) {
        print('⏭️  Skipped: $name ($strategyId) - already has strategyTypeId');
        skipped++;
        continue;
      }
      
      // Add strategyTypeId
      await db.collection('user_strategies').document(strategyId).update({
        'strategyTypeId': personalTypeId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      print('✅ Updated: $name ($strategyId) -> Personal type');
      updated++;
    }
    
    print('\n📊 Summary:');
    print('   Updated: $updated');
    print('   Skipped: $skipped');
    print('   Total: ${strategies.length}');
    print('\n✅ Migration completed successfully!');
    
  } catch (e, stackTrace) {
    print('\n❌ Error migrating strategies: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
