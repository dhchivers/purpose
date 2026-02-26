/// Quick fix script to add missing 'id' field to user_strategies
/// 
/// This fixes strategies created by the migration script that are missing
/// the 'id' field in Firestore.

import 'dart:io';
import 'package:firedart/firedart.dart';

const projectId = 'altruency-purpose';

void main() async {
  print('🔧 Fixing user_strategies documents...');
  
  // Initialize Firedart
  Firestore.initialize(projectId);
  final db = Firestore.instance;
  
  print('✓ Connected to project: $projectId\n');
  
  try {
    // Get all strategies
    final strategies = await db.collection('user_strategies').get();
    
    print('📊 Found ${strategies.length} strateg(ies) to check\n');
    
    int fixed = 0;
    int skipped = 0;
    
    for (final doc in strategies) {
      final id = doc.id;
      final data = doc.map;
      
      if (data['id'] == null || data['id'] == '') {
        print('🔧 Fixing strategy: $id');
        await db.collection('user_strategies').document(id).update({
          'id': id,
        });
        fixed++;
      } else {
        print('✓ Strategy $id already has id field');
        skipped++;
      }
    }
    
    print('\n' + '=' * 60);
    print('SUMMARY');
    print('=' * 60);
    print('Fixed:   $fixed');
    print('Skipped: $skipped');
    print('=' * 60);
    
    print('\n✅ Fix completed!');
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
