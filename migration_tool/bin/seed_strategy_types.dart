/// Seed initial strategy types
/// Creates the default strategy types: Personal, Career, Financial, Business, Corporate

import 'dart:io';
import 'package:firedart/firedart.dart';

const projectId = 'altruency-purpose';

void main() async {
  print('🌱 Seeding initial strategy types...\n');
  
  Firestore.initialize(projectId);
  final db = Firestore.instance;
  
  print('✓ Connected to project: $projectId\n');
  
  try {
    // Check if strategy types already exist
    final existingTypes = await db.collection('strategy_types').get();
    
    if (existingTypes.isNotEmpty) {
      print('⚠️  Strategy types already exist (${existingTypes.length} types found)');
      print('   Do you want to skip existing types and add only missing ones? (y/n)');
      final response = stdin.readLineSync()?.toLowerCase();
      
      if (response != 'y' && response != 'yes') {
        print('❌ Operation cancelled');
        return;
      }
    }
    
    final now = DateTime.now().toUtc();
    final timestamp = now.millisecondsSinceEpoch;
    
    // Define the default strategy types
    final strategyTypes = [
      {
        'name': 'Personal',
        'enabled': true,
        'isDefault': true,
        'order': 1,
        'description': 'Personal development and life strategies',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      },
      {
        'name': 'Career',
        'enabled': true,
        'isDefault': false,
        'order': 2,
        'description': 'Professional growth and career advancement strategies',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      },
      {
        'name': 'Financial',
        'enabled': true,
        'isDefault': false,
        'order': 3,
        'description': 'Financial planning and wealth management strategies',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      },
      {
        'name': 'Business',
        'enabled': true,
        'isDefault': false,
        'order': 4,
        'description': 'Business development and entrepreneurship strategies',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      },
      {
        'name': 'Corporate',
        'enabled': true,
        'isDefault': false,
        'order': 5,
        'description': 'Corporate and organizational strategies',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      },
    ];
    
    print('📦 Creating ${strategyTypes.length} strategy types...\n');
    
    int created = 0;
    int skipped = 0;
    
    for (final typeData in strategyTypes) {
      final name = typeData['name'] as String;
      
      // Check if this type already exists
      final existing = await db
          .collection('strategy_types')
          .where('name', isEqualTo: name)
          .get();
      
      if (existing.isNotEmpty) {
        print('⏭️  Skipped: $name (already exists)');
        skipped++;
        continue;
      }
      
      // Create the strategy type
      final docRef = await db.collection('strategy_types').add(typeData);
      print('✅ Created: $name (${docRef.id})');
      created++;
    }
    
    print('\n📊 Summary:');
    print('   Created: $created');
    print('   Skipped: $skipped');
    print('   Total: ${strategyTypes.length}');
    print('\n✅ Strategy types seeding completed successfully!');
    
  } catch (e, stackTrace) {
    print('\n❌ Error seeding strategy types: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
