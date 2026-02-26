/// Fix denormalized fields in user_strategies
/// Updates currentVision and currentMission with actual text instead of IDs

import 'dart:io';
import 'package:firedart/firedart.dart';

const projectId = 'altruency-purpose';

void main() async {
  print('🔧 Fixing denormalized fields in user_strategies...\n');
  
  Firestore.initialize(projectId);
  final db = Firestore.instance;
  
  print('✓ Connected to project: $projectId\n');
  
  try {
    final strategies = await db.collection('user_strategies').get();
    
    print('📊 Found ${strategies.length} strateg(ies) to fix\n');
    
    int fixed = 0;
    
    for (final strategyDoc in strategies) {
      final strategyId = strategyDoc.id;
      final strategyData = strategyDoc.map;
      
      print('Strategy: ${strategyData['name']} ($strategyId)');
      
      final updates = <String, dynamic>{};
      
      // Fix currentVision - get the actual vision statement
      print('  Checking visions...');
      final visions = await db
          .collection('user_visions')
          .where('strategyId', isEqualTo: strategyId)
          .get();
      
      if (visions.isNotEmpty) {
        // Get the most recent vision or one marked as current
        var currentVision = visions.firstWhere(
          (doc) => doc.map['isCurrent'] as bool? ?? false,
          orElse: () => visions.first,
        );
        
        final visionStatement = currentVision.map['visionStatement'] as String?;
        if (visionStatement != null && visionStatement != strategyData['currentVision']) {
          updates['currentVision'] = visionStatement;
          print('    ✓ Will update currentVision: "${visionStatement.substring(0, visionStatement.length > 50 ? 50 : visionStatement.length)}..."');
        } else {
          print('    ✓ currentVision already correct');
        }
      } else {
        print('    • No visions found');
        if (strategyData['currentVision'] != null) {
          updates['currentVision'] = null;
          print('    ✓ Will clear currentVision');
        }
      }
      
      // Fix currentMission - get the current mission text
      print('  Checking mission maps...');
      final missionMaps = await db
          .collection('user_mission_maps')
          .where('strategyId', isEqualTo: strategyId)
          .get();
      
      if (missionMaps.isNotEmpty) {
        // Get the most recent mission map or one marked as current
        var currentMissionMap = missionMaps.firstWhere(
          (doc) => doc.map['isCurrent'] as bool? ?? false,
          orElse: () => missionMaps.first,
        );
        
        final missions = currentMissionMap.map['missions'] as List?;
        final currentMissionIndex = currentMissionMap.map['currentMissionIndex'] as int? ?? 0;
        
        if (missions != null && missions.isNotEmpty && currentMissionIndex < missions.length) {
          final mission = missions[currentMissionIndex] as Map<String, dynamic>;
          final missionText = mission['mission'] as String?;
          
          if (missionText != null && missionText != strategyData['currentMission']) {
            updates['currentMission'] = missionText;
            print('    ✓ Will update currentMission: "$missionText"');
          } else {
            print('    ✓ currentMission already correct');
          }
        } else {
          print('    • No current mission to set');
          if (strategyData['currentMission'] != null) {
            updates['currentMission'] = null;
            print('    ✓ Will clear currentMission');
          }
        }
      } else {
        print('    • No mission maps found');
        if (strategyData['currentMission'] != null) {
          updates['currentMission'] = null;
          print('    ✓ Will clear currentMission');
        }
      }
      
      // Apply updates if any
      if (updates.isNotEmpty) {
        updates['updatedAt'] = DateTime.now().toIso8601String();
        await db.collection('user_strategies').document(strategyId).update(updates);
        fixed++;
        print('✅ Fixed $strategyId\n');
      } else {
        print('⏭️  No changes needed\n');
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
