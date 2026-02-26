/// Check strategy document structure

import 'dart:io';
import 'dart:convert';
import 'package:firedart/firedart.dart';

const projectId = 'altruency-purpose';

void main() async {
  print('🔍 Checking user_strategies documents...\n');
  
  Firestore.initialize(projectId);
  final db = Firestore.instance;
  
  try {
    final strategies = await db.collection('user_strategies').get();
    
    print('📊 Found ${strategies.length} strateg(ies)\n');
    
    for (final doc in strategies) {
      print('Strategy ID: ${doc.id}');
      print('Data:');
      print(JsonEncoder.withIndent('  ').convert(doc.map));
      print('\nRequired fields check:');
      print('  - id: ${doc.map['id']}');
      print('  - userId: ${doc.map['userId']}');
      print('  - name: ${doc.map['name']}');
      print('  - status: ${doc.map['status']}');
      print('  - createdAt: ${doc.map['createdAt']} (type: ${doc.map['createdAt'].runtimeType})');
      print('  - updatedAt: ${doc.map['updatedAt']} (type: ${doc.map['updatedAt'].runtimeType})');
      print('\n' + '=' * 60 + '\n');
    }
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
