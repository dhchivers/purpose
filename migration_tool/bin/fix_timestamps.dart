/// Fix timestamp fields in user_strategies collection
/// Converts ISO8601 strings to Firestore Timestamps

import 'dart:io';
import 'package:firedart/firedart.dart';

const projectId = 'altruency-purpose';

void main() async {
  print('🔧 Fixing timestamp fields in user_strategies...');
  
  Firestore.initialize(projectId);
  final db = Firestore.instance;
  
  print('✓ Connected to project: $projectId\n');
  
  try {
    final strategies = await db.collection('user_strategies').get();
    
    print('📊 Found ${strategies.length} strateg(ies) to fix\n');
    
    int fixed = 0;
    
    for (final doc in strategies) {
      final data = doc.map;
      final updates = <String, dynamic>{};
      
      // Firedart stores timestamps differently, but we need to ensure
      // they are proper date objects, not strings
      if (data['createdAt'] is String) {
        final date = DateTime.parse(data['createdAt'] as String);
        // Store as milliseconds since epoch (Firestore will handle conversion)
        updates['createdAt'] = date.millisecondsSinceEpoch;
        print('  Fixing createdAt for ${doc.id}');
      }
      
      if (data['updatedAt'] is String) {
        final date = DateTime.parse(data['updatedAt'] as String);
        updates['updatedAt'] = date.millisecondsSinceEpoch;
        print('  Fixing updatedAt for ${doc.id}');
      }
      
      if (data['archivedAt'] != null && data['archivedAt'] is String) {
        final date = DateTime.parse(data['archivedAt'] as String);
        updates['archivedAt'] = date.millisecondsSinceEpoch;
        print('  Fixing archivedAt for ${doc.id}');
      }
      
      if (updates.isNotEmpty) {
        await db.collection('user_strategies').document(doc.id).update(updates);
        fixed++;
        print('✓ Fixed ${doc.id}\n');
      }
    }
    
    print('=' * 60);
    print('SUMMARY');
    print('=' * 60);
    print('Fixed: $fixed');
    print('=' * 60);
    print('\n✅ Fix completed!');
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
