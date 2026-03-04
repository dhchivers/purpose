import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:purpose/core/models/mission_map.dart';
import 'package:purpose/core/models/mission_document.dart';
import 'package:purpose/core/models/mission_creation_session.dart';

/// Migration script to refactor mission data structure
/// 
/// OLD STRUCTURE:
/// - user_mission_maps collection
///   - Contains UserMissionMap documents with embedded missions list
/// 
/// NEW STRUCTURE:
/// - mission_maps collection (metadata only)
///   - Contains MissionMap documents (no embedded missions)
/// - missions collection
///   - Contains individual MissionDocument documents
///   - Each mission references its parent missionMapId
/// 
/// USAGE:
/// ```dart
/// final migrator = MissionMigrationScript();
/// await migrator.runMigration();
/// ```

class MissionMigrationScript {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String backupDir = 'migration_backups';
  final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

  /// Run the full migration process
  Future<void> runMigration({bool dryRun = false}) async {
    print('\n${'=' * 80}');
    print('MISSION DATA STRUCTURE MIGRATION');
    print('${'=' * 80}');
    print('Timestamp: $timestamp');
    print('Dry Run: $dryRun');
    print('${'=' * 80}\n');

    try {
      // Step 1: Backup
      print('📦 STEP 1: Creating backup...');
      final backupData = await _backupUserMissionMaps();
      final backupFile = await _saveBackupToFile(backupData);
      print('✅ Backup saved to: $backupFile\n');

      // Step 2: Analyze
      print('📊 STEP 2: Analyzing data...');
      final stats = _analyzeBackupData(backupData);
      _printStats(stats);

      if (dryRun) {
        print('\n⚠️  DRY RUN MODE - No data will be migrated');
        print('Review the stats and backup file, then run with dryRun=false\n');
        return;
      }

      // Step 3: Migration (confirmation happens in UI for web)
      if (!kIsWeb) {
        print('\n⚠️  WARNING: This will modify your Firestore database!');
        print('Press ENTER to continue or Ctrl+C to cancel...');
        // stdin.readLineSync(); // Only for command-line, not web
      }

      // Step 4: Migrate
      print('\n🔄 STEP 3: Migrating data...');
      final migrationResults = await _migrateData(backupData);
      print('✅ Migration completed!');
      _printMigrationResults(migrationResults);

      // Step 5: Verify
      print('\n🔍 STEP 4: Verifying migration...');
      final verification = await _verifyMigration(backupData);
      _printVerification(verification);

      if (verification['success'] == true) {
        print('\n✅ Migration successful! 🎉');
        print('Backup file available for rollback: $backupFile');
      } else {
        print('\n❌ Migration verification failed!');
        print('Check the logs and backup file for rollback.');
      }

    } catch (e, stackTrace) {
      print('\n❌ MIGRATION FAILED: $e');
      print('Stack trace: $stackTrace');
      print('\nPlease check backup file and contact support if needed.');
    }

    print('\n${'=' * 80}\n');
  }

  /// Step 1: Backup all user_mission_maps documents
  Future<List<Map<String, dynamic>>> _backupUserMissionMaps() async {
    final snapshot = await _db.collection('user_mission_maps').get();
    final backupData = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      // Convert Timestamps to ISO strings for JSON compatibility
      final cleanedData = _convertTimestampsToStrings(data);
      backupData.add(cleanedData);
    }

    print('   Backed up ${backupData.length} documents');
    return backupData;
  }

  /// Convert Firestore Timestamps to ISO strings recursively
  Map<String, dynamic> _convertTimestampsToStrings(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is Map) {
        result[key] = _convertTimestampsToStrings(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Timestamp) {
            return item.toDate().toIso8601String();
          } else if (item is Map) {
            return _convertTimestampsToStrings(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });
    
    return result;
  }

  /// Save backup data to JSON file (web-compatible)
  Future<String> _saveBackupToFile(List<Map<String, dynamic>> data) async {
    final jsonData = {
      'timestamp': timestamp,
      'collection': 'user_mission_maps',
      'count': data.length,
      'documents': data,
    };

    final jsonString = JsonEncoder.withIndent('  ').convert(jsonData);

    if (kIsWeb) {
      // For web: Save to localStorage AND trigger download
      final filename = 'user_mission_maps_backup_$timestamp.json';
      
      // Store in localStorage for recovery
      html.window.localStorage['migration_backup_$timestamp'] = jsonString;
      
      // Trigger browser download
      final bytes = utf8.encode(jsonString);
      final blob = html.Blob([bytes], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
      
      print('   Saved ${data.length} documents to browser downloads: $filename');
      print('   Also stored in localStorage as backup');
      return 'Downloaded: $filename (also in browser localStorage)';
    } else {
      // For non-web platforms (future-proofing)
      throw UnimplementedError('Migration only supports web platform currently');
    }
  }

  /// Analyze backup data
  Map<String, dynamic> _analyzeBackupData(List<Map<String, dynamic>> data) {
    int totalMaps = data.length;
    int totalMissions = 0;
    int mapsWithSessions = 0;
    int mapsWithCurrentIndex = 0;
    int mapsWithStrategyStartDate = 0;
    final strategyIds = <String>{};

    for (var doc in data) {
      final missions = doc['missions'] as List<dynamic>? ?? [];
      totalMissions += missions.length;

      if (doc['sessionId'] != null) mapsWithSessions++;
      if (doc['currentMissionIndex'] != null) mapsWithCurrentIndex++;
      if (doc['strategyStartDate'] != null) mapsWithStrategyStartDate++;
      
      if (doc['strategyId'] != null) {
        strategyIds.add(doc['strategyId'] as String);
      }
    }

    return {
      'totalMaps': totalMaps,
      'totalMissions': totalMissions,
      'mapsWithSessions': mapsWithSessions,
      'mapsWithCurrentIndex': mapsWithCurrentIndex,
      'mapsWithStrategyStartDate': mapsWithStrategyStartDate,
      'uniqueStrategies': strategyIds.length,
    };
  }

  /// Print statistics
  void _printStats(Map<String, dynamic> stats) {
    print('   Total Mission Maps: ${stats['totalMaps']}');
    print('   Total Missions: ${stats['totalMissions']}');
    print('   Maps with Sessions: ${stats['mapsWithSessions']}');
    print('   Maps with Current Index: ${stats['mapsWithCurrentIndex']}');
    print('   Maps with Start Date: ${stats['mapsWithStrategyStartDate']}');
    print('   Unique Strategies: ${stats['uniqueStrategies']}');
  }

  /// Step 3: Migrate data to new structure
  Future<Map<String, dynamic>> _migrateData(List<Map<String, dynamic>> backupData) async {
    int migratedMaps = 0;
    int migratedMissions = 0;
    final errors = <String>[];

    for (var oldDoc in backupData) {
      try {
        // Convert old document to new structure
        final missionMap = _convertToMissionMap(oldDoc);
        final missions = _convertToMissionDocuments(oldDoc, missionMap.id);

        // Save mission map
        await _db.collection('mission_maps').doc(missionMap.id).set(missionMap.toJson());
        migratedMaps++;

        // Save missions
        final batch = _db.batch();
        for (var mission in missions) {
          batch.set(
            _db.collection('missions').doc(mission.id),
            mission.toJson(),
          );
        }
        await batch.commit();
        migratedMissions += missions.length;

        print('   ✅ Migrated: ${missionMap.id} (${missions.length} missions)');
      } catch (e) {
        final error = 'Failed to migrate ${oldDoc['id']}: $e';
        errors.add(error);
        print('   ❌ $error');
      }
    }

    return {
      'migratedMaps': migratedMaps,
      'migratedMissions': migratedMissions,
      'errors': errors,
    };
  }

  /// Convert UserMissionMap to MissionMap
  MissionMap _convertToMissionMap(Map<String, dynamic> oldDoc) {
    final missions = oldDoc['missions'] as List<dynamic>? ?? [];
    final createdAt = _parseTimestamp(oldDoc['createdAt']);
    final updatedAt = _parseTimestamp(oldDoc['updatedAt']);
    final strategyStartDate = _parseTimestamp(oldDoc['strategyStartDate']);

    return MissionMap(
      id: oldDoc['id'] as String,
      strategyId: oldDoc['strategyId'] as String,
      sessionId: oldDoc['sessionId'] as String?,
      currentMissionIndex: oldDoc['currentMissionIndex'] as int?,
      totalMissions: missions.length,
      strategyStartDate: strategyStartDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Convert missions list to MissionDocuments
  List<MissionDocument> _convertToMissionDocuments(
    Map<String, dynamic> oldDoc,
    String missionMapId,
  ) {
    final missions = oldDoc['missions'] as List<dynamic>? ?? [];
    final strategyId = oldDoc['strategyId'] as String;
    final missionDocs = <MissionDocument>[];

    for (int i = 0; i < missions.length; i++) {
      final missionData = missions[i] as Map<String, dynamic>;
      final now = DateTime.now();

      // Parse risk level
      RiskLevel? riskLevel;
      if (missionData['riskLevel'] != null) {
        final riskLevelStr = missionData['riskLevel'] as String;
        riskLevel = RiskLevel.values.firstWhere(
          (e) => e.toString().split('.').last == riskLevelStr,
          orElse: () => RiskLevel.medium,
        );
      }

      final missionDoc = MissionDocument(
        id: '${missionMapId}_mission_$i', // Generate consistent ID
        missionMapId: missionMapId,
        strategyId: strategyId,
        sequenceNumber: i,
        mission: missionData['mission'] as String,
        missionSequence: missionData['missionSequence'] as String,
        focus: missionData['focus'] as String,
        structuralShift: missionData['structuralShift'] as String,
        capabilityRequired: missionData['capabilityRequired'] as String,
        riskOrValueGuardrail: missionData['riskOrValueGuardrail'] as String,
        timeHorizon: missionData['timeHorizon'] as String,
        riskLevel: riskLevel,
        durationMonths: missionData['durationMonths'] as int? ?? 12,
        createdAt: now,
        updatedAt: now,
      );

      missionDocs.add(missionDoc);
    }

    return missionDocs;
  }

  /// Parse Timestamp or DateTime from various formats
  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  /// Print migration results
  void _printMigrationResults(Map<String, dynamic> results) {
    print('   Migrated Mission Maps: ${results['migratedMaps']}');
    print('   Migrated Missions: ${results['migratedMissions']}');
    
    final errors = results['errors'] as List<String>;
    if (errors.isNotEmpty) {
      print('   Errors: ${errors.length}');
      for (var error in errors) {
        print('     - $error');
      }
    }
  }

  /// Step 4: Verify migration
  Future<Map<String, dynamic>> _verifyMigration(List<Map<String, dynamic>> backupData) async {
    int verifiedMaps = 0;
    int verifiedMissions = 0;
    final issues = <String>[];

    for (var oldDoc in backupData) {
      try {
        final mapId = oldDoc['id'] as String;
        
        // Check mission map exists
        final mapDoc = await _db.collection('mission_maps').doc(mapId).get();
        if (!mapDoc.exists) {
          issues.add('Mission map not found: $mapId');
          continue;
        }
        verifiedMaps++;

        // Check missions exist
        final oldMissions = oldDoc['missions'] as List<dynamic>? ?? [];
        final missionSnapshot = await _db.collection('missions')
            .where('missionMapId', isEqualTo: mapId)
            .get();

        if (missionSnapshot.docs.length != oldMissions.length) {
          issues.add('Mission count mismatch for $mapId: expected ${oldMissions.length}, got ${missionSnapshot.docs.length}');
        } else {
          verifiedMissions += missionSnapshot.docs.length;
        }
      } catch (e) {
        issues.add('Verification error for ${oldDoc['id']}: $e');
      }
    }

    return {
      'success': issues.isEmpty,
      'verifiedMaps': verifiedMaps,
      'verifiedMissions': verifiedMissions,
      'issues': issues,
    };
  }

  /// Print verification results
  void _printVerification(Map<String, dynamic> verification) {
    print('   Verified Mission Maps: ${verification['verifiedMaps']}');
    print('   Verified Missions: ${verification['verifiedMissions']}');
    
    final issues = verification['issues'] as List<String>;
    if (issues.isNotEmpty) {
      print('   Issues found: ${issues.length}');
      for (var issue in issues) {
        print('     - $issue');
      }
    }
  }

  /// Rollback migration (restore from backup) - Web compatible
  Future<void> rollback(String backupKey) async {
    print('\n${'=' * 80}');
    print('ROLLING BACK MIGRATION');
    print('${'=' * 80}');
    print('Backup key: $backupKey\n');

    try {
      String? jsonContent;
      
      if (kIsWeb) {
        // Load from localStorage
        jsonContent = html.window.localStorage[backupKey];
        if (jsonContent == null) {
          throw Exception('Backup not found in localStorage: $backupKey\nCheck browser localStorage or provide the downloaded JSON content.');
        }
      } else {
        throw UnimplementedError('Rollback only supports web platform currently');
      }

      final backupJson = jsonDecode(jsonContent) as Map<String, dynamic>;
      final documents = backupJson['documents'] as List<dynamic>;

      print('📦 Loaded ${documents.length} documents from backup\n');

      // Delete new collections
      print('\n🗑️  Deleting new collections...');
      await _deleteCollection('mission_maps');
      await _deleteCollection('missions');

      // Restore old collection
      print('📥 Restoring user_mission_maps...');
      int restored = 0;
      for (var doc in documents) {
        final docData = Map<String, dynamic>.from(doc as Map);
        final docId = docData.remove('id') as String;
        await _db.collection('user_mission_maps').doc(docId).set(docData);
        restored++;
      }

      print('✅ Restored $restored documents\n');
      print('✅ Rollback completed successfully! 🎉\n');
    } catch (e, stackTrace) {
      print('❌ ROLLBACK FAILED: $e');
      print('Stack trace: $stackTrace');
    }

    print('${'=' * 80}\n');
  }

  /// Delete all documents in a collection
  Future<void> _deleteCollection(String collectionName) async {
    final snapshot = await _db.collection(collectionName).get();
    final batch = _db.batch();
    
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
    print('   Deleted ${snapshot.docs.length} documents from $collectionName');
  }
}
