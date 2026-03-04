import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purpose/core/models/question_module.dart';
import 'package:purpose/core/models/question.dart';
import 'package:purpose/core/models/user_answer.dart';
import 'package:purpose/core/models/user_model.dart';
import 'package:purpose/core/models/module_type.dart';
import 'package:purpose/core/models/module_progress.dart';
import 'package:purpose/core/models/identity_synthesis_result.dart';
import 'package:purpose/core/models/value_creation_session.dart';
import 'package:purpose/core/models/user_value.dart';
import 'package:purpose/core/models/vision_creation_session.dart';
import 'package:purpose/core/models/user_vision.dart';
import 'package:purpose/core/models/mission_creation_session.dart';
import 'package:purpose/core/models/user_mission_map.dart';
import 'package:purpose/core/models/mission_map.dart';
import 'package:purpose/core/models/mission_document.dart';
import 'package:purpose/core/models/user_strategy.dart';
import 'package:purpose/core/models/strategy_type.dart';
import 'package:purpose/core/models/goal.dart';
import 'package:purpose/core/models/objective.dart';
import 'package:purpose/core/constants/app_constants.dart';

/// Service for managing Firestore database operations
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _usersCollection =>
      _db.collection(AppConstants.usersCollection);
  CollectionReference get _questionModulesCollection =>
      _db.collection(AppConstants.questionModulesCollection);
  CollectionReference get _questionsCollection =>
      _db.collection(AppConstants.questionsCollection);
  CollectionReference get _userAnswersCollection =>
      _db.collection(AppConstants.userAnswersCollection);
  CollectionReference get _identitySynthesisResultsCollection =>
      _db.collection(AppConstants.identitySynthesisResultsCollection);
  CollectionReference get _configCollection => _db.collection('config');
  CollectionReference get _userStrategiesCollection =>
      _db.collection('user_strategies');
  CollectionReference get _strategyTypesCollection =>
      _db.collection('strategy_types');
  CollectionReference get _valueCreationSessionsCollection =>
      _db.collection('value_creation_sessions');
  CollectionReference get _userValuesCollection =>
      _db.collection('user_values');
  CollectionReference get _visionCreationSessionsCollection =>
      _db.collection('vision_creation_sessions');
  CollectionReference get _userVisionsCollection =>
      _db.collection('user_visions');
  CollectionReference get _missionCreationSessionsCollection =>
      _db.collection('mission_creation_sessions');
  CollectionReference get _userMissionMapsCollection =>
      _db.collection('user_mission_maps');
  CollectionReference get _missionMapsCollection =>
      _db.collection('mission_maps');
  CollectionReference get _missionsCollection =>
      _db.collection('missions');
  CollectionReference get _goalsCollection =>
      _db.collection('goals');
  CollectionReference get _objectivesCollection =>
      _db.collection('objectives');

  /// Helper to convert all Timestamp objects to ISO strings to avoid Int64 issues on web
  /// Also converts integer milliseconds (from migration scripts) to ISO strings
  /// Recursively processes Maps and Lists
  static dynamic _convertTimestampsToStrings(dynamic data) {
    if (data is Timestamp) {
      return data.toDate().toIso8601String();
    } else if (data is int) {
      // Check if this int is likely a timestamp (milliseconds since epoch)
      // Range: Jan 1, 2000 (946684800000) to Jan 1, 2100 (4102444800000)
      if (data > 946684800000 && data < 4102444800000) {
        return DateTime.fromMillisecondsSinceEpoch(data, isUtc: true).toIso8601String();
      }
      return data;
    } else if (data is Map) {
      // Convert to standard Map<String, dynamic> to avoid LinkedMap issues on web
      return Map<String, dynamic>.from(
        data.map((key, value) => 
          MapEntry(key, _convertTimestampsToStrings(value)))
      );
    } else if (data is List) {
      return data.map((item) => _convertTimestampsToStrings(item)).toList();
    }
    return data;
  }

  /// Helper methods to safely extract fields from Firestore data (handles JavaScript objects on web)
  static String _getStringField(dynamic data, String field) {
    try {
      final value = data[field];
      return value?.toString() ?? '';
    } catch (e) {
      print('⚠️ Error getting field $field: $e');
      return '';
    }
  }

  static double _getDoubleField(dynamic data, String field, double defaultValue) {
    try {
      final value = data[field];
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    } catch (e) {
      print('⚠️ Error getting field $field: $e');
      return defaultValue;
    }
  }

  static bool _getBoolField(dynamic data, String field, bool defaultValue) {
    try {
      final value = data[field];
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return defaultValue;
    } catch (e) {
      print('⚠️ Error getting field $field: $e');
      return defaultValue;
    }
  }

  static DateTime? _getDateTimeField(dynamic data, String field) {
    try {
      final value = data[field];
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      if (value is int) {
        // Timestamp as milliseconds
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting date field $field: $e');
      return null;
    }
  }

  // ========== USER OPERATIONS ==========

  /// Create or update a user profile with retry logic
  Future<void> saveUser(UserModel user) async {
    int retries = 3;
    Duration delay = const Duration(seconds: 1);
    
    for (int i = 0; i < retries; i++) {
      try {
        await _usersCollection.doc(user.uid).set(user.toJson());
        return; // Success
      } catch (e) {
        print('⚠️ Attempt ${i + 1}/$retries failed to save user: $e');
        if (i < retries - 1) {
          await Future.delayed(delay);
          delay = delay * 2; // Exponential backoff
        } else {
          print('❌ All retries exhausted for saveUser');
          rethrow;
        }
      }
    }
  }

  /// Get a user by ID with retry logic
  Future<UserModel?> getUser(String uid) async {
    int retries = 3;
    Duration delay = const Duration(seconds: 2);
    
    for (int i = 0; i < retries; i++) {
      try {
        print('📖 getUser attempt ${i + 1}/$retries for uid: $uid');
        final doc = await _usersCollection.doc(uid).get();
        print('Document exists: ${doc.exists}');
        
        if (!doc.exists) {
          print('⚠️ User document does not exist');
          return null;
        }
        
        final data = doc.data() as Map<String, dynamic>;
        print('📄 User document data: $data');
        
        final userModel = UserModel.fromJson(data);
        print('✅ UserModel deserialized: ${userModel.email}');
        return userModel;
      } catch (e, stackTrace) {
        print('⚠️ Attempt ${i + 1}/$retries failed to get user: $e');
        print('Stack trace: $stackTrace');
        if (i < retries - 1) {
          await Future.delayed(delay);
          delay = delay * 2; // Exponential backoff
        } else {
          print('❌ All retries exhausted for getUser');
          rethrow;
        }
      }
    }
    return null;
  }

  /// Stream of user data with error handling
  Stream<UserModel?> userStream(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      print('📡 userStream snapshot received for $uid');
      print('Document exists: ${doc.exists}');
      
      if (!doc.exists) {
        print('⚠️ Document does not exist in userStream');
        return null;
      }
      
      try {
        final data = doc.data() as Map<String, dynamic>;
        print('📄 Document data: $data');
        final userModel = UserModel.fromJson(data);
        print('✅ UserModel deserialized successfully: ${userModel.email}');
        return userModel;
      } catch (e, stackTrace) {
        print('❌ Error deserializing UserModel: $e');
        print('Stack trace: $stackTrace');
        return null;
      }
    }).handleError((error) {
      print('❌ Error in userStream snapshots: $error');
      // Don't propagate the error, just log it
      return null;
    });
  }

  /// Update user's module progress
  Future<void> updateUserProgress({
    required String userId,
    required String questionModuleId,
    required ModuleProgress progress,
  }) async {
    await _usersCollection.doc(userId).update({
      'moduleProgress.$questionModuleId': progress.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // If completed, add to completed list
    if (progress.isCompleted) {
      await _usersCollection.doc(userId).update({
        'completedModuleIds': FieldValue.arrayUnion([questionModuleId]),
      });
    }
  }

  /// Update user's purpose, vision, or mission
  Future<void> updateUserStatement({
    required String userId,
    String? purpose,
    String? vision,
    String? mission,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (purpose != null) updates['purpose'] = purpose;
    if (vision != null) updates['vision'] = vision;
    if (mission != null) updates['mission'] = mission;

    await _usersCollection.doc(userId).update(updates);
  }

  // ========== STRATEGY OPERATIONS ==========

  /// Create a new strategy for a user
  Future<UserStrategy> createStrategy({
    required String userId,
    required String name,
    required String strategyTypeId,
    String? description,
    bool isDefault = false,
  }) async {
    try {
      final strategyId = _userStrategiesCollection.doc().id;
      
      // Get the max displayOrder for this user
      final existingStrategies = await getUserStrategies(userId);
      final maxOrder = existingStrategies.isEmpty 
          ? 0 
          : existingStrategies.map((s) => s.displayOrder).reduce((a, b) => a > b ? a : b);
      
      final strategy = UserStrategy(
        id: strategyId,
        userId: userId,
        name: name,
        strategyTypeId: strategyTypeId,
        description: description,
        status: StrategyStatus.draft,
        isDefault: isDefault,
        valueCount: 0,
        displayOrder: maxOrder + 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final data = strategy.toJson();
      data['createdAt'] = Timestamp.fromDate(strategy.createdAt);
      data['updatedAt'] = Timestamp.fromDate(strategy.updatedAt);

      await _userStrategiesCollection.doc(strategyId).set(data);
      print('✅ Created strategy: $strategyId for user: $userId');

      // Update user document
      final updates = <String, dynamic>{
        'strategyCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (isDefault) {
        updates['defaultStrategyId'] = strategyId;
      }

      await _usersCollection.doc(userId).update(updates);
      print('✅ Updated user strategyCount and defaultStrategyId');

      return strategy;
    } catch (e) {
      print('❌ Error creating strategy: $e');
      rethrow;
    }
  }

  /// Get a strategy by ID
  Future<UserStrategy?> getStrategy(String strategyId) async {
    try {
      final doc = await _userStrategiesCollection.doc(strategyId).get();
      
      if (!doc.exists) return null;

      final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
      return UserStrategy.fromJson(data);
    } catch (e, stackTrace) {
      print('❌ Error getting strategy $strategyId: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all strategies for a user
  Future<List<UserStrategy>> getUserStrategies(String userId) async {
    try {
      final querySnapshot = await _userStrategiesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('displayOrder')
          .get();

      return querySnapshot.docs
          .map((doc) {
            final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
            return UserStrategy.fromJson(data);
          })
          .toList();
    } catch (e, stackTrace) {
      print('❌ Error getting user strategies for userId=$userId: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get user's default strategy
  Future<UserStrategy?> getDefaultStrategy(String userId) async {
    try {
      final querySnapshot = await _userStrategiesCollection
          .where('userId', isEqualTo: userId)
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final data = _convertTimestampsToStrings(querySnapshot.docs.first.data()) 
          as Map<String, dynamic>;
      return UserStrategy.fromJson(data);
    } catch (e, stackTrace) {
      print('❌ Error getting default strategy for userId=$userId: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Stream of a specific strategy
  Stream<UserStrategy?> strategyStream(String strategyId) {
    return _userStrategiesCollection.doc(strategyId).snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
          return UserStrategy.fromJson(data);
        })
        .handleError((error, stackTrace) {
          print('❌ Error in strategyStream for strategyId=$strategyId: $error');
          print('Stack trace: $stackTrace');
        });
  }

  /// Stream of all user strategies
  Stream<List<UserStrategy>> userStrategiesStream(String userId) {
    return _userStrategiesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('displayOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
              return UserStrategy.fromJson(data);
            })
            .toList())
        .handleError((error, stackTrace) {
          print('❌ Error in userStrategiesStream for userId=$userId: $error');
          print('Stack trace: $stackTrace');
        });
  }

  /// Stream of user's default strategy
  Stream<UserStrategy?> defaultStrategyStream(String userId) {
    return _userStrategiesCollection
        .where('userId', isEqualTo: userId)
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final data = _convertTimestampsToStrings(snapshot.docs.first.data()) 
              as Map<String, dynamic>;
          return UserStrategy.fromJson(data);
        })
        .handleError((error, stackTrace) {
          print('❌ Error in defaultStrategyStream for userId=$userId: $error');
          print('Stack trace: $stackTrace');
        });
  }

  /// Update a strategy
  Future<void> updateStrategy(UserStrategy strategy) async {
    try {
      final data = strategy.toJson();
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());
      data['createdAt'] = Timestamp.fromDate(strategy.createdAt);
      if (strategy.archivedAt != null) {
        data['archivedAt'] = Timestamp.fromDate(strategy.archivedAt!);
      }

      await _userStrategiesCollection.doc(strategy.id).update(data);
      print('✅ Updated strategy: ${strategy.id}');
    } catch (e) {
      print('❌ Error updating strategy: $e');
      rethrow;
    }
  }

  /// Update display order for multiple strategies
  Future<void> updateStrategyDisplayOrders(Map<String, int> strategyOrders) async {
    try {
      final batch = _db.batch();
      
      for (final entry in strategyOrders.entries) {
        batch.update(
          _userStrategiesCollection.doc(entry.key),
          {
            'displayOrder': entry.value,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      
      await batch.commit();
      print('✅ Updated display order for ${strategyOrders.length} strategies');
    } catch (e) {
      print('❌ Error updating strategy display orders: $e');
      rethrow;
    }
  }

  /// Set a strategy as the default for a user
  Future<void> setDefaultStrategy(String userId, String strategyId) async {
    try {
      // Remove default from all other strategies
      final userStrategies = await getUserStrategies(userId);
      final batch = _db.batch();

      for (final strategy in userStrategies) {
        if (strategy.id == strategyId) {
          batch.update(
            _userStrategiesCollection.doc(strategy.id),
            {
              'isDefault': true,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        } else if (strategy.isDefault) {
          batch.update(
            _userStrategiesCollection.doc(strategy.id),
            {
              'isDefault': false,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      // Update user's defaultStrategyId
      batch.update(
        _usersCollection.doc(userId),
        {
          'defaultStrategyId': strategyId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      print('✅ Set default strategy: $strategyId for user: $userId');
    } catch (e) {
      print('❌ Error setting default strategy: $e');
      rethrow;
    }
  }

  /// Archive a strategy
  Future<void> archiveStrategy(String strategyId) async {
    try {
      await _userStrategiesCollection.doc(strategyId).update({
        'status': 'archived',
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Archived strategy: $strategyId');
    } catch (e) {
      print('❌ Error archiving strategy: $e');
      rethrow;
    }
  }

  /// Delete a strategy and all related data
  Future<void> deleteStrategy(String strategyId, String userId) async {
    try {
      final batch = _db.batch();

      // Delete all user_values for this strategy
      final valuesQuery = await _userValuesCollection
          .where('strategyId', isEqualTo: strategyId)
          .get();
      for (final doc in valuesQuery.docs) {
        batch.delete(doc.reference);
      }
      print('🗑️ Deleting ${valuesQuery.docs.length} values for strategy: $strategyId');

      // Delete all user_visions for this strategy
      final visionsQuery = await _userVisionsCollection
          .where('strategyId', isEqualTo: strategyId)
          .get();
      for (final doc in visionsQuery.docs) {
        batch.delete(doc.reference);
      }
      print('🗑️ Deleting ${visionsQuery.docs.length} visions for strategy: $strategyId');

      // Delete all user_mission_maps for this strategy
      final mapsQuery = await _userMissionMapsCollection
          .where('strategyId', isEqualTo: strategyId)
          .get();
      for (final doc in mapsQuery.docs) {
        batch.delete(doc.reference);
      }
      print('🗑️ Deleting ${mapsQuery.docs.length} mission maps for strategy: $strategyId');

      // Delete all value_creation_sessions for this strategy
      final valueSessionsQuery = await _valueCreationSessionsCollection
          .where('strategyId', isEqualTo: strategyId)
          .get();
      for (final doc in valueSessionsQuery.docs) {
        batch.delete(doc.reference);
      }
      print('🗑️ Deleting ${valueSessionsQuery.docs.length} value sessions for strategy: $strategyId');

      // Delete all vision_creation_sessions for this strategy
      final visionSessionsQuery = await _visionCreationSessionsCollection
          .where('strategyId', isEqualTo: strategyId)
          .get();
      for (final doc in visionSessionsQuery.docs) {
        batch.delete(doc.reference);
      }
      print('🗑️ Deleting ${visionSessionsQuery.docs.length} vision sessions for strategy: $strategyId');

      // Delete all mission_creation_sessions for this strategy
      final missionSessionsQuery = await _missionCreationSessionsCollection
          .where('strategyId', isEqualTo: strategyId)
          .get();
      for (final doc in missionSessionsQuery.docs) {
        batch.delete(doc.reference);
      }
      print('🗑️ Deleting ${missionSessionsQuery.docs.length} mission sessions for strategy: $strategyId');

      // Delete the strategy itself
      batch.delete(_userStrategiesCollection.doc(strategyId));

      // Update user document
      batch.update(
        _usersCollection.doc(userId),
        {
          'strategyCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      print('✅ Deleted strategy and all related data: $strategyId');
    } catch (e) {
      print('❌ Error deleting strategy: $e');
      rethrow;
    }
  }

  // ========== STRATEGY TYPE OPERATIONS ==========

  /// Get a strategy type by ID
  Future<StrategyType?> getStrategyType(String id) async {
    try {
      final doc = await _strategyTypesCollection.doc(id).get();
      if (!doc.exists) return null;
      
      final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
      data['id'] = doc.id;
      return StrategyType.fromJson(data);
    } catch (e, stackTrace) {
      print('❌ Error getting strategy type $id: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all strategy types ordered by order field
  Future<List<StrategyType>> getAllStrategyTypes() async {
    try {
      final snapshot = await _strategyTypesCollection
          .orderBy('order')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
        data['id'] = doc.id;
        return StrategyType.fromJson(data);
      }).toList();
    } catch (e, stackTrace) {
      print('❌ Error getting all strategy types: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get only enabled strategy types
  Future<List<StrategyType>> getEnabledStrategyTypes() async {
    try {
      final snapshot = await _strategyTypesCollection
          .where('enabled', isEqualTo: true)
          .orderBy('order')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
        data['id'] = doc.id;
        return StrategyType.fromJson(data);
      }).toList();
    } catch (e, stackTrace) {
      print('❌ Error getting enabled strategy types: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Stream of all strategy types
  Stream<List<StrategyType>> strategyTypesStream() {
    return _strategyTypesCollection
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
              data['id'] = doc.id;
              return StrategyType.fromJson(data);
            }).toList())
        .handleError((error, stackTrace) {
          print('❌ Error in strategyTypesStream: $error');
          print('Stack trace: $stackTrace');
        });
  }

  /// Create a new strategy type
  Future<String> createStrategyType(StrategyType type) async {
    try {
      final data = type.toJson();
      data['createdAt'] = Timestamp.fromDate(type.createdAt);
      data['updatedAt'] = Timestamp.fromDate(type.updatedAt);
      
      final docRef = await _strategyTypesCollection.add(data);
      print('✅ Created strategy type: ${docRef.id} (${type.name})');
      return docRef.id;
    } catch (e, stackTrace) {
      print('❌ Error creating strategy type: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update an existing strategy type
  Future<void> updateStrategyType(StrategyType type) async {
    try {
      // Prevent disabling default type (Personal)
      if (type.isDefault && !type.enabled) {
        throw Exception('Cannot disable the default strategy type (Personal)');
      }

      // If disabling, check for active strategies
      if (!type.enabled) {
        final canDisable = await canDisableStrategyType(type.id);
        if (!canDisable) {
          throw Exception('Cannot disable strategy type with active strategies');
        }
      }

      final data = type.toJson();
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());
      data['createdAt'] = Timestamp.fromDate(type.createdAt);
      
      await _strategyTypesCollection.doc(type.id).update(data);
      print('✅ Updated strategy type: ${type.id} (${type.name})');
    } catch (e, stackTrace) {
      print('❌ Error updating strategy type: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete a strategy type
  Future<void> deleteStrategyType(String id) async {
    try {
      // Check if it's the default type
      final type = await getStrategyType(id);
      if (type == null) {
        throw Exception('Strategy type not found');
      }
      
      if (type.isDefault) {
        throw Exception('Cannot delete the default strategy type (Personal)');
      }

      // Check for active strategies
      final canDelete = await canDisableStrategyType(id);
      if (!canDelete) {
        throw Exception('Cannot delete strategy type with active strategies');
      }

      await _strategyTypesCollection.doc(id).delete();
      print('✅ Deleted strategy type: $id');
    } catch (e, stackTrace) {
      print('❌ Error deleting strategy type: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if a strategy type can be disabled (no active strategies reference it)
  Future<bool> canDisableStrategyType(String typeId) async {
    try {
      final count = await countStrategiesByType(typeId);
      return count == 0;
    } catch (e, stackTrace) {
      print('❌ Error checking if strategy type can be disabled: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Count active strategies using a specific type
  Future<int> countStrategiesByType(String typeId) async {
    try {
      final snapshot = await _userStrategiesCollection
          .where('strategyTypeId', isEqualTo: typeId)
          .where('status', whereIn: ['draft', 'active'])
          .get();
      
      print('📊 Found ${snapshot.docs.length} active strategies for type: $typeId');
      return snapshot.docs.length;
    } catch (e, stackTrace) {
      print('❌ Error counting strategies by type: $e');
      print('Stack trace: $stackTrace');
      return 0;
    }
  }

  // ========== QUESTION MODULE OPERATIONS ==========

  /// Get all question modules for a specific parent module
  Future<List<QuestionModule>> getQuestionModulesByParent(
      ModuleType parentModule) async {
    final snapshot = await _questionModulesCollection
        .where('parentModule', isEqualTo: parentModule.value)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return QuestionModule.fromJson(data);
        })
        .toList();
  }

  /// Get a single question module by ID
  Future<QuestionModule?> getQuestionModule(String moduleId) async {
    final doc = await _questionModulesCollection.doc(moduleId).get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data() as Map);
    data['id'] = doc.id;
    return QuestionModule.fromJson(data);
  }

  /// Stream of question modules for a parent module
  Stream<List<QuestionModule>> questionModulesStream(ModuleType parentModule) {
    return _questionModulesCollection
        .where('parentModule', isEqualTo: parentModule.value)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              data['id'] = doc.id;
              return QuestionModule.fromJson(data);
            })
            .toList());
  }

  /// Create a new question module (admin operation)
  Future<String> createQuestionModule(QuestionModule module) async {
    final docRef = await _questionModulesCollection.add(module.toJson());
    return docRef.id;
  }

  /// Update an existing question module (admin operation)
  Future<void> updateQuestionModule(QuestionModule module) async {
    await _questionModulesCollection.doc(module.id).update(module.toJson());
  }

  /// Delete a question module (admin operation)
  Future<void> deleteQuestionModule(String moduleId) async {
    await _questionModulesCollection.doc(moduleId).delete();
  }

  /// Get all question modules (admin operation)
  Future<List<QuestionModule>> getAllQuestionModules() async {
    final snapshot = await _questionModulesCollection.orderBy('order').get();
    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return QuestionModule.fromJson(data);
        })
        .toList();
  }

  /// Stream of all question modules (admin operation)
  Stream<List<QuestionModule>> allQuestionModulesStream() {
    return _questionModulesCollection
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              data['id'] = doc.id;
              return QuestionModule.fromJson(data);
            })
            .toList());
  }

  // ========== QUESTION OPERATIONS ==========

  /// Get all questions for a question module
  Future<List<Question>> getQuestionsByModule(String questionModuleId) async {
    final snapshot = await _questionsCollection
        .where('questionModuleId', isEqualTo: questionModuleId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return Question.fromJson(data);
        })
        .toList();
  }

  /// Get a single question by ID
  Future<Question?> getQuestion(String questionId) async {
    final doc = await _questionsCollection.doc(questionId).get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data() as Map);
    data['id'] = doc.id;
    return Question.fromJson(data);
  }

  /// Stream of questions for a module
  Stream<List<Question>> questionsStream(String questionModuleId) {
    return _questionsCollection
        .where('questionModuleId', isEqualTo: questionModuleId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              data['id'] = doc.id;
              return Question.fromJson(data);
            })
            .toList());
  }

  /// Stream of all questions for a module (admin operation, includes inactive)
  Stream<List<Question>> allQuestionsStream(String questionModuleId) {
    return _questionsCollection
        .where('questionModuleId', isEqualTo: questionModuleId)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              data['id'] = doc.id;
              return Question.fromJson(data);
            })
            .toList());
  }

  /// Create a new question (admin operation)
  Future<String> createQuestion(Question question) async {
    final docRef = await _questionsCollection.add(question.toJson());
    return docRef.id;
  }

  /// Update an existing question (admin operation)
  Future<void> updateQuestion(Question question) async {
    await _questionsCollection.doc(question.id).update(question.toJson());
  }

  /// Delete a question (admin operation)
  Future<void> deleteQuestion(String questionId) async {
    await _questionsCollection.doc(questionId).delete();
  }

  // ========== USER ANSWER OPERATIONS ==========

  /// Save or update a user's answer
  Future<void> saveUserAnswer(UserAnswer answer) async {
    if (answer.id.isEmpty) {
      // Create new answer with auto-generated ID
      final docRef = await _userAnswersCollection.add(answer.toJson());
      // Optionally update the answer with the generated ID
      await docRef.update({'id': docRef.id});
    } else {
      // Update existing answer
      await _userAnswersCollection.doc(answer.id).set(answer.toJson());
    }
  }

  /// Get a specific user's answer to a question
  Future<UserAnswer?> getUserAnswer({
    required String userId,
    required String strategyId,
    required String questionId,
  }) async {
    final snapshot = await _userAnswersCollection
        .where('userId', isEqualTo: userId)
        .where('strategyId', isEqualTo: strategyId)
        .where('questionId', isEqualTo: questionId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    final docData = Map<String, dynamic>.from(doc.data() as Map);
    docData['id'] = doc.id;
    return UserAnswer.fromJson(docData);
  }

  /// Get all user answers for a question module
  /// If strategyId is provided, filters by it; otherwise loads all answers for the module
  Future<List<UserAnswer>> getUserAnswersByModule({
    required String userId,
    String? strategyId,
    required String questionModuleId,
  }) async {
    Query query = _userAnswersCollection
        .where('userId', isEqualTo: userId)
        .where('questionModuleId', isEqualTo: questionModuleId);
    
    // Only filter by strategyId if provided
    if (strategyId != null) {
      query = query.where('strategyId', isEqualTo: strategyId);
    }
    
    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      final docData = Map<String, dynamic>.from(doc.data() as Map);
      docData['id'] = doc.id;
      final data = _convertTimestampsToStrings(docData) as Map<String, dynamic>;
      return UserAnswer.fromJson(data);
    }).toList();
  }

  /// Stream of user's answers for a question module
  /// If strategyId is provided, filters by it; otherwise loads all answers for the module
  Stream<List<UserAnswer>> userAnswersStream({
    required String userId,
    String? strategyId,
    required String questionModuleId,
  }) {
    Query query = _userAnswersCollection
        .where('userId', isEqualTo: userId)
        .where('questionModuleId', isEqualTo: questionModuleId);
    
    // Only filter by strategyId if provided
    if (strategyId != null) {
      query = query.where('strategyId', isEqualTo: strategyId);
    }
    
    return query
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final docData = Map<String, dynamic>.from(doc.data() as Map);
              docData['id'] = doc.id;
              final data = _convertTimestampsToStrings(docData) as Map<String, dynamic>;
              return UserAnswer.fromJson(data);
            }).toList());
  }

  /// Check if a user has answered all questions in a module
  Future<bool> isModuleCompleted({
    required String userId,
    required String strategyId,
    required String questionModuleId,
  }) async {
    // Get total questions in module
    final module = await getQuestionModule(questionModuleId);
    if (module == null) return false;

    // Get user's answers - STRICT: Only answers for this specific strategy
    final allAnswers = await getUserAnswersByModule(
      userId: userId,
      strategyId: null, // Load all to check
      questionModuleId: questionModuleId,
    );
    
    // Filter to ONLY answers matching current strategy (no null fallback)
    final answers = allAnswers.where((answer) => 
      answer.strategyId == strategyId
    ).toList();

    // Check if all questions are answered
    return answers.length >= module.totalQuestions;
  }

  /// Get all answers for AI processing (unanswered by AI)
  /// If strategyId is provided, filters by it; otherwise loads all answers for the module
  Future<List<UserAnswer>> getUnprocessedAnswers({
    required String userId,
    String? strategyId,
    required String questionModuleId,
  }) async {
    Query query = _userAnswersCollection
        .where('userId', isEqualTo: userId)
        .where('questionModuleId', isEqualTo: questionModuleId)
        .where('processedByAI', isEqualTo: false);
    
    // Only filter by strategyId if provided
    if (strategyId != null) {
      query = query.where('strategyId', isEqualTo: strategyId);
    }
    
    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return UserAnswer.fromJson(data);
        })
        .toList();
  }

  /// Mark an answer as processed by AI with response
  Future<void> markAnswerProcessed({
    required String answerId,
    required String aiResponse,
  }) async {
    await _userAnswersCollection.doc(answerId).update({
      'processedByAI': true,
      'aiResponse': aiResponse,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ========== IDENTITY SYNTHESIS OPERATIONS ==========

  /// Calculate hash of user's purpose module answers for staleness detection
  Future<String> calculateAnswersHash(String userId, String strategyId) async {
    // Get all purpose modules
    final modules = await getQuestionModulesByParent(ModuleType.purpose);
    
    // Collect all answers for purpose modules
    final allAnswers = <UserAnswer>[];
    for (final module in modules) {
      final answers = await getUserAnswersByModule(
        userId: userId,
        strategyId: strategyId,
        questionModuleId: module.id,
      );
      allAnswers.addAll(answers);
    }
    
    // Sort by ID for consistent ordering
    allAnswers.sort((a, b) => a.id.compareTo(b.id));
    
    // Build hash from answer content
    final hashContent = allAnswers.map((a) {
      return '${a.id}:${a.answer}:${a.updatedAt.millisecondsSinceEpoch}';
    }).join('|');
    
    print('=== HASH CALCULATION ===');
    print('Answers count: ${allAnswers.length}');
    print('Hash content length: ${hashContent.length}');
    if (allAnswers.length <= 3) {
      print('Hash content: $hashContent');
    }
    
    // Generate MD5 hash
    final bytes = utf8.encode(hashContent);
    final digest = md5.convert(bytes);
    
    print('Generated hash: ${digest.toString()}');
    return digest.toString();
  }

  /// Save identity synthesis result
  Future<String> saveIdentitySynthesisResult(
    IdentitySynthesisResult result,
  ) async {
    final docRef = await _identitySynthesisResultsCollection.add(result.toJson());
    return docRef.id;
  }

  /// Update identity synthesis result (for selection/edits)
  Future<void> updateIdentitySynthesisResult(
    IdentitySynthesisResult result,
  ) async {
    await _identitySynthesisResultsCollection
        .doc(result.id)
        .update(result.toJson());
  }

  /// Get the most recent identity synthesis result for a user and strategy
  Future<IdentitySynthesisResult?> getIdentitySynthesisResult(
    String userId,
    String strategyId,
  ) async {
    final snapshot = await _identitySynthesisResultsCollection
        .where('userId', isEqualTo: userId)
        .where('strategyId', isEqualTo: strategyId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    // Convert LinkedMap to standard Map and add ID
    final docData = Map<String, dynamic>.from(snapshot.docs.first.data() as Map);
    docData['id'] = snapshot.docs.first.id;
    
    // Convert all Timestamps to ISO strings to avoid Int64 issues on web
    final data = _convertTimestampsToStrings(docData) as Map<String, dynamic>;
    
    return IdentitySynthesisResult.fromJson(data);
  }

  /// Check if identity synthesis result is stale (answers changed)
  Future<bool> isIdentitySynthesisStale(
    String userId,
    String strategyId,
    IdentitySynthesisResult result,
  ) async {
    final currentHash = await calculateAnswersHash(userId, strategyId);
    print('=== STALENESS CHECK ===');
    print('Current hash: $currentHash');
    print('Stored hash: ${result.answersHash}');
    print('Is stale: ${currentHash != result.answersHash}');
    return currentHash != result.answersHash;
  }

  /// Promote selected purpose statement to strategy's purpose field
  Future<void> promoteToUserPurpose({
    required String userId,
    required String strategyId,
    required String purposeStatement,
    required String resultId,
  }) async {
    print('=== PROMOTING PURPOSE TO STRATEGY ===');
    print('User ID: $userId');
    print('Strategy ID: $strategyId');
    print('Purpose Statement: $purposeStatement');
    print('Result ID: $resultId');
    
    final batch = _db.batch();

    // Update strategy's purpose
    batch.update(_userStrategiesCollection.doc(strategyId), {
      'purpose': purposeStatement,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Mark result as promoted
    batch.update(_identitySynthesisResultsCollection.doc(resultId), {
      'isPromoted': true,
    });

    await batch.commit();
    print('✅ Purpose promoted to strategy successfully');
  }

  // ========== BATCH OPERATIONS ==========

  /// Delete all user data (for account deletion)
  Future<void> deleteUserData(String userId) async {
    final batch = _db.batch();

    // Delete user document
    batch.delete(_usersCollection.doc(userId));

    // Delete all user answers
    final answersSnapshot =
        await _userAnswersCollection.where('userId', isEqualTo: userId).get();
    for (final doc in answersSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ========== CONFIG/SEEDS OPERATIONS ==========

  /// Stream of value seeds from config/seeds document
  Stream<List<String>> valueSeedsStream() {
    return _configCollection.doc('seeds').snapshots().map((doc) {
      if (!doc.exists) {
        print('⚠️ Seeds document does not exist, returning empty list');
        return <String>[];
      }
      
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('values')) {
        print('⚠️ Seeds document has no values field, returning empty list');
        return <String>[];
      }

      final values = data['values'];
      if (values is! List) {
        print('⚠️ Values field is not a list, returning empty list');
        return <String>[];
      }

      return values.cast<String>();
    });
  }

  /// Get value seeds as a future
  Future<List<String>> getValueSeeds() async {
    final doc = await _configCollection.doc('seeds').get();
    if (!doc.exists) return [];
    
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null || !data.containsKey('values')) return [];

    final values = data['values'];
    if (values is! List) return [];

    return values.cast<String>();
  }

  /// Add a new value seed
  Future<void> addValueSeed(String value) async {
    await _configCollection.doc('seeds').set({
      'values': FieldValue.arrayUnion([value]),
    }, SetOptions(merge: true));
  }

  /// Delete a value seed
  Future<void> deleteValueSeed(String value) async {
    await _configCollection.doc('seeds').update({
      'values': FieldValue.arrayRemove([value]),
    });
  }

  /// Update a value seed (replace old with new)
  Future<void> updateValueSeed(String oldValue, String newValue) async {
    final batch = _db.batch();
    final docRef = _configCollection.doc('seeds');

    // Remove old value and add new value atomically
    batch.update(docRef, {
      'values': FieldValue.arrayRemove([oldValue]),
    });
    batch.update(docRef, {
      'values': FieldValue.arrayUnion([newValue]),
    });

    await batch.commit();
  }

  // ========== VALUE CREATION SESSION OPERATIONS ==========

  /// Save or update a value creation session
  Future<void> saveValueCreationSession(ValueCreationSession session) async {
    try {
      final data = session.toJson();
      // Convert DateTime objects to Timestamps for Firestore
      data['startedAt'] = Timestamp.fromDate(session.startedAt);
      if (session.completedAt != null) {
        data['completedAt'] = Timestamp.fromDate(session.completedAt!);
      }

      await _valueCreationSessionsCollection.doc(session.id).set(data);
      print('✅ Saved value creation session: ${session.id}');
    } catch (e) {
      print('❌ Error saving value creation session: $e');
      rethrow;
    }
  }

  /// Get a value creation session by ID
  Future<ValueCreationSession?> getValueCreationSession(String sessionId) async {
    try {
      final doc = await _valueCreationSessionsCollection.doc(sessionId).get();
      
      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Convert Timestamps back to DateTime
      if (data['startedAt'] is Timestamp) {
        data['startedAt'] = (data['startedAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['completedAt'] is Timestamp) {
        data['completedAt'] = (data['completedAt'] as Timestamp).toDate().toIso8601String();
      }

      return ValueCreationSession.fromJson(data);
    } catch (e) {
      print('❌ Error getting value creation session: $e');
      rethrow;
    }
  }

  /// Get all value creation sessions for a user
  Future<List<ValueCreationSession>> getUserValueCreationSessions(String userId) async {
    try {
      final querySnapshot = await _valueCreationSessionsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('startedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Convert Timestamps back to DateTime
        if (data['startedAt'] is Timestamp) {
          data['startedAt'] = (data['startedAt'] as Timestamp).toDate().toIso8601String();
        }
        if (data['completedAt'] is Timestamp) {
          data['completedAt'] = (data['completedAt'] as Timestamp).toDate().toIso8601String();
        }

        return ValueCreationSession.fromJson(data);
      }).toList();
    } catch (e) {
      print('❌ Error getting user value creation sessions: $e');
      rethrow;
    }
  }

  /// Delete a value creation session
  Future<void> deleteValueCreationSession(String sessionId) async {
    try {
      await _valueCreationSessionsCollection.doc(sessionId).delete();
      print('✅ Deleted value creation session: $sessionId');
    } catch (e) {
      print('❌ Error deleting value creation session: $e');
      rethrow;
    }
  }

  // ========== USER VALUE OPERATIONS ==========

  /// Save a user value (final completed value)
  Future<void> saveUserValue(UserValue value) async {
    try {
      final data = value.toJson();
      // Convert DateTime objects to Timestamps for Firestore
      data['createdAt'] = Timestamp.fromDate(value.createdAt);
      if (value.updatedAt != null) {
        data['updatedAt'] = Timestamp.fromDate(value.updatedAt!);
      }

      await _userValuesCollection.doc(value.id).set(data);
      print('✅ Saved user value: ${value.id}');

      // Update strategy's valueCount
      await _userStrategiesCollection.doc(value.strategyId).update({
        'valueCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated strategy valueCount for: ${value.strategyId}');

      // Backward compatibility: Update user's valueCount if userId exists
      if (value.userId != null) {
        final userDoc = _usersCollection.doc(value.userId);
        await userDoc.update({
          'valueCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('❌ Error saving user value: $e');
      rethrow;
    }
  }

  /// Get all values for a strategy
  Future<List<UserValue>> getUserValues(String strategyId) async {
    try {
      final querySnapshot = await _userValuesCollection
          .where('strategyId', isEqualTo: strategyId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Convert Timestamps back to DateTime
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updatedAt'] is Timestamp) {
          data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
        }

        return UserValue.fromJson(data);
      }).toList();
    } catch (e) {
      print('❌ Error getting user values: $e');
      rethrow;
    }
  }

  /// Get all values for a user (backward compatibility - uses userId)
  @Deprecated('Use getUserValues(strategyId) instead')
  Future<List<UserValue>> getUserValuesByUserId(String userId) async {
    try {
      final querySnapshot = await _userValuesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updatedAt'] is Timestamp) {
          data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
        }

        return UserValue.fromJson(data);
      }).toList();
    } catch (e) {
      print('❌ Error getting user values by userId: $e');
      rethrow;
    }
  }

  /// Get a single user value by ID
  Future<UserValue?> getUserValue(String valueId) async {
    try {
      final doc = await _userValuesCollection.doc(valueId).get();
      
      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Convert Timestamps back to DateTime
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['updatedAt'] is Timestamp) {
        data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
      }

      return UserValue.fromJson(data);
    } catch (e) {
      print('❌ Error getting user value: $e');
      rethrow;
    }
  }

  /// Update a user value
  Future<void> updateUserValue(UserValue value) async {
    try {
      final data = value.toJson();
      // Convert DateTime objects to Timestamps for Firestore
      data['createdAt'] = Timestamp.fromDate(value.createdAt);
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());

      await _userValuesCollection.doc(value.id).set(data);
      print('✅ Updated user value: ${value.id}');
    } catch (e) {
      print('❌ Error updating user value: $e');
      rethrow;
    }
  }

  /// Delete a user value
  Future<void> deleteUserValue(String valueId, String strategyId) async {
    try {
      await _userValuesCollection.doc(valueId).delete();
      print('✅ Deleted user value: $valueId');

      // Decrement strategy's valueCount
      await _userStrategiesCollection.doc(strategyId).update({
        'valueCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error deleting user value: $e');
      rethrow;
    }
  }

  // ==================== VISION METHODS ====================

  /// Save a vision creation session
  Future<void> saveVisionCreationSession(VisionCreationSession session) async {
    try {
      final data = session.toJson();
      
      // Convert DateTime to Timestamp for Firestore
      data['startedAt'] = Timestamp.fromDate(session.startedAt);
      if (session.completedAt != null) {
        data['completedAt'] = Timestamp.fromDate(session.completedAt!);
      }

      await _visionCreationSessionsCollection.doc(session.id).set(data);
      print('✅ Saved vision creation session: ${session.id}');
    } catch (e) {
      print('❌ Error saving vision creation session: $e');
      rethrow;
    }
  }

  /// Get a vision creation session by ID
  Future<VisionCreationSession?> getVisionCreationSession(String sessionId) async {
    try {
      final doc = await _visionCreationSessionsCollection.doc(sessionId).get();
      
      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Convert Timestamps back to DateTime
      if (data['startedAt'] is Timestamp) {
        data['startedAt'] = (data['startedAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['completedAt'] is Timestamp) {
        data['completedAt'] = (data['completedAt'] as Timestamp).toDate().toIso8601String();
      }

      return VisionCreationSession.fromJson(data);
    } catch (e) {
      print('❌ Error getting vision creation session: $e');
      rethrow;
    }
  }

  /// Save a user's finalized vision
  Future<void> saveUserVision(UserVision vision) async {
    try {
      final data = vision.toJson();
      
      // Convert DateTime to Timestamp
      data['createdAt'] = Timestamp.fromDate(vision.createdAt);
      data['updatedAt'] = Timestamp.fromDate(vision.updatedAt);

      await _userVisionsCollection.doc(vision.id).set(data);
      print('✅ Saved user vision: ${vision.id}');

      // Update strategy's currentVision field and increment visionCount
      await _userStrategiesCollection.doc(vision.strategyId).update({
        'currentVision': vision.visionStatement,
        'visionCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated strategy currentVision for: ${vision.strategyId}');

      // Backward compatibility: Update user's vision field if userId exists
      if (vision.userId != null) {
        final userDoc = _usersCollection.doc(vision.userId);
        await userDoc.update({
          'vision': vision.visionStatement,
          'visionCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error saving user vision: $e');
      rethrow;
    }
  }

  /// Get a user's vision by strategyId
  Future<UserVision?> getUserVision(String strategyId) async {
    try {
      final querySnapshot = await _userVisionsCollection
          .where('strategyId', isEqualTo: strategyId)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      
      // Convert Timestamps to DateTime strings
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['updatedAt'] is Timestamp) {
        data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
      }

      return UserVision.fromJson(data);
    } catch (e) {
      print('❌ Error getting user vision: $e');
      rethrow;
    }
  }

  /// Get a user's vision by userId (backward compatibility)
  @Deprecated('Use getUserVision(strategyId) instead')
  Future<UserVision?> getUserVisionByUserId(String userId) async {
    try {
      final querySnapshot = await _userVisionsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      
      // Convert Timestamps to DateTime strings
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['updatedAt'] is Timestamp) {
        data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
      }

      return UserVision.fromJson(data);
    } catch (e) {
      print('❌ Error getting user vision by userId: $e');
      rethrow;
    }
  }

  /// Stream user's vision for real-time updates (by strategyId)
  Stream<UserVision?> userVisionStream(String strategyId) {
    return _userVisionsCollection
        .where('strategyId', isEqualTo: strategyId)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
      return UserVision.fromJson(data);
    });
  }

  /// Stream user's vision for real-time updates (by userId - backward compatibility)
  @Deprecated('Use userVisionStream(strategyId) instead')
  Stream<UserVision?> userVisionStreamByUserId(String userId) {
    return _userVisionsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
      return UserVision.fromJson(data);
    });
  }

  /// Update a user's vision
  Future<void> updateUserVision(UserVision vision) async {
    try {
      final data = vision.toJson();
      
      // Convert DateTime to Timestamp
      data['createdAt'] = Timestamp.fromDate(vision.createdAt);
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());

      await _userVisionsCollection.doc(vision.id).set(data);
      print('✅ Updated user vision: ${vision.id}');

      // Update strategy's currentVision field to reflect the change
      await _userStrategiesCollection.doc(vision.strategyId).update({
        'currentVision': vision.visionStatement,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Backward compatibility: Update user's vision field if userId exists
      if (vision.userId != null) {
        final userDoc = _usersCollection.doc(vision.userId);
        await userDoc.update({
          'vision': vision.visionStatement,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error updating user vision: $e');
      rethrow;
    }
  }

  /// Delete a user's vision
  Future<void> deleteUserVision(String visionId, String strategyId) async {
    try {
      await _userVisionsCollection.doc(visionId).delete();
      print('✅ Deleted user vision: $visionId');

      // Get the next most recent vision to update strategy.currentVision field
      final remainingVisions = await _userVisionsCollection
          .where('strategyId', isEqualTo: strategyId)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      final strategyDoc = _userStrategiesCollection.doc(strategyId);
      
      if (remainingVisions.docs.isEmpty) {
        // No more visions, clear the field and decrement count
        await strategyDoc.update({
          'currentVision': null,
          'visionCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update to the next most recent vision and decrement count
        final nextVisionData = remainingVisions.docs.first.data() as Map<String, dynamic>;
        await strategyDoc.update({
          'currentVision': nextVisionData['visionStatement'],
          'visionCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error deleting user vision: $e');
      rethrow;
    }
  }

  // ========== MISSION OPERATIONS ==========

  /// Save a mission creation session
  Future<void> saveMissionCreationSession(MissionCreationSession session) async {
    try {
      final data = session.toJson();
      
      // Convert DateTime to Timestamp
      data['startedAt'] = Timestamp.fromDate(session.startedAt);
      if (session.completedAt != null) {
        data['completedAt'] = Timestamp.fromDate(session.completedAt!);
      }

      await _missionCreationSessionsCollection.doc(session.id).set(data);
      print('✅ Saved mission creation session: ${session.id}');
    } catch (e) {
      print('❌ Error saving mission creation session: $e');
      rethrow;
    }
  }

  /// Get a mission creation session by ID
  Future<MissionCreationSession?> getMissionCreationSession(String sessionId) async {
    try {
      final doc = await _missionCreationSessionsCollection.doc(sessionId).get();
      
      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Convert Timestamps to DateTime strings
      if (data['startedAt'] is Timestamp) {
        data['startedAt'] = (data['startedAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['completedAt'] is Timestamp) {
        data['completedAt'] = (data['completedAt'] as Timestamp).toDate().toIso8601String();
      }

      return MissionCreationSession.fromJson(data);
    } catch (e) {
      print('❌ Error getting mission creation session: $e');
      rethrow;
    }
  }

  /// Get the most recent mission creation session for a user
  Future<MissionCreationSession?> getLatestMissionCreationSession(String userId) async {
    try {
      final querySnapshot = await _missionCreationSessionsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('startedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      
      // Convert Timestamps to DateTime strings
      if (data['startedAt'] is Timestamp) {
        data['startedAt'] = (data['startedAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['completedAt'] is Timestamp) {
        data['completedAt'] = (data['completedAt'] as Timestamp).toDate().toIso8601String();
      }

      return MissionCreationSession.fromJson(data);
    } catch (e) {
      print('❌ Error getting latest mission creation session: $e');
      rethrow;
    }
  }

  /// Save a user's mission map
  Future<void> saveUserMissionMap(UserMissionMap missionMap) async {
    try {
      final data = missionMap.toJson();
      
      // Convert DateTime to Timestamp
      data['createdAt'] = Timestamp.fromDate(missionMap.createdAt);
      data['updatedAt'] = Timestamp.fromDate(missionMap.updatedAt);

      await _userMissionMapsCollection.doc(missionMap.id).set(data);
      print('✅ Saved user mission map: ${missionMap.id}');

      // Update strategy's currentMission field
      final currentMission = missionMap.currentMissionIndex != null && 
                             missionMap.currentMissionIndex! < missionMap.missions.length
          ? missionMap.missions[missionMap.currentMissionIndex!].mission
          : null;
      
      await _userStrategiesCollection.doc(missionMap.strategyId).update({
        'currentMission': currentMission,
        'hasMissionMap': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated strategy currentMission for: ${missionMap.strategyId}');

      // Backward compatibility: Update user's mission fields if userId exists
      if (missionMap.userId != null) {
        final userDoc = _usersCollection.doc(missionMap.userId);
        await userDoc.update({
          'hasMissionMap': true,
          'currentMissionIndex': missionMap.currentMissionIndex,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error saving user mission map: $e');
      rethrow;
    }
  }

  /// Get a user's mission map by strategyId
  Future<UserMissionMap?> getUserMissionMap(String strategyId) async {
    try {
      final querySnapshot = await _userMissionMapsCollection
          .where('strategyId', isEqualTo: strategyId)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      
      // Convert Timestamps to DateTime strings
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['updatedAt'] is Timestamp) {
        data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
      }

      return UserMissionMap.fromJson(data);
    } catch (e) {
      print('❌ Error getting user mission map: $e');
      rethrow;
    }
  }

  /// Get a user's mission map by userId (backward compatibility)
  @Deprecated('Use getUserMissionMap(strategyId) instead')
  Future<UserMissionMap?> getUserMissionMapByUserId(String userId) async {
    try {
      final querySnapshot = await _userMissionMapsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      
      // Convert Timestamps to DateTime strings
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['updatedAt'] is Timestamp) {
        data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
      }

      return UserMissionMap.fromJson(data);
    } catch (e) {
      print('❌ Error getting user mission map by userId: $e');
      rethrow;
    }
  }

  /// Stream user's mission map for real-time updates (by strategyId)
  Stream<UserMissionMap?> userMissionMapStream(String strategyId) {
    return _userMissionMapsCollection
        .where('strategyId', isEqualTo: strategyId)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
      return UserMissionMap.fromJson(data);
    })
        .handleError((error, stackTrace) {
          print('❌ Error in userMissionMapStream for strategyId=$strategyId: $error');
          print('Stack trace: $stackTrace');
        });
  }

  /// Stream user's mission map for real-time updates (by userId - backward compatibility)
  @Deprecated('Use userMissionMapStream(strategyId) instead')
  Stream<UserMissionMap?> userMissionMapStreamByUserId(String userId) {
    return _userMissionMapsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = _convertTimestampsToStrings(doc.data()) as Map<String, dynamic>;
      return UserMissionMap.fromJson(data);
    })
        .handleError((error, stackTrace) {
          print('❌ Error in userMissionMapStreamByUserId for userId=$userId: $error');
          print('Stack trace: $stackTrace');
        });
  }

  /// Update a user's mission map (e.g., advance to next mission)
  Future<void> updateUserMissionMap(UserMissionMap missionMap) async {
    try {
      final data = missionMap.toJson();
      
      // Convert DateTime to Timestamp
      data['createdAt'] = Timestamp.fromDate(missionMap.createdAt);
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());

      await _userMissionMapsCollection.doc(missionMap.id).set(data);
      print('✅ Updated user mission map: ${missionMap.id}');

      // Update strategy's currentMission
      final currentMission = missionMap.currentMissionIndex != null && 
                             missionMap.currentMissionIndex! < missionMap.missions.length
          ? missionMap.missions[missionMap.currentMissionIndex!].mission
          : null;
      
      await _userStrategiesCollection.doc(missionMap.strategyId).update({
        'currentMission': currentMission,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Backward compatibility: Update user's current mission index if userId exists
      if (missionMap.userId != null) {
        final userDoc = _usersCollection.doc(missionMap.userId);
        await userDoc.update({
          'currentMissionIndex': missionMap.currentMissionIndex,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error updating user mission map: $e');
      rethrow;
    }
  }

  /// Delete a user's mission map
  Future<void> deleteUserMissionMap(String missionMapId, String strategyId) async {
    try {
      await _userMissionMapsCollection.doc(missionMapId).delete();
      print('✅ Deleted user mission map: $missionMapId');

      // Update strategy document to reflect no mission map
      await _userStrategiesCollection.doc(strategyId).update({
        'hasMissionMap': false,
        'currentMission': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error deleting user mission map: $e');
      rethrow;
    }
  }

  /// Advance user to next mission
  Future<void> advanceToNextMission(String strategyId) async {
    try {
      final missionMap = await getUserMissionMap(strategyId);
      if (missionMap == null) {
        throw Exception('No mission map found for strategy');
      }

      final currentIndex = missionMap.currentMissionIndex ?? 0;
      final nextIndex = currentIndex + 1;

      if (nextIndex >= missionMap.missions.length) {
        print('⚠️ Strategy is already on the last mission');
        return;
      }

      final updatedMap = missionMap.copyWith(
        currentMissionIndex: nextIndex,
        updatedAt: DateTime.now(),
      );

      await updateUserMissionMap(updatedMap);
      print('✅ Advanced strategy to mission ${nextIndex + 1}');
    } catch (e) {
      print('❌ Error advancing to next mission: $e');
      rethrow;
    }
  }

  // ============================================================================
  // NEW MISSION MAP STRUCTURE (Refactored)
  // Mission Maps and Missions are now separate collections
  // ============================================================================

  /// Save a mission map (metadata only)
  Future<void> saveMissionMap(MissionMap missionMap) async {
    try {
      final data = _convertTimestampsToStrings(missionMap.toJson()) as Map<String, dynamic>;
      await _missionMapsCollection.doc(missionMap.id).set(data);
      print('✅ Saved mission map: ${missionMap.id}');

      // Update strategy to indicate it has a mission map
      await _userStrategiesCollection.doc(missionMap.strategyId).update({
        'hasMissionMap': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error saving mission map: $e');
      rethrow;
    }
  }

  /// Get a mission map by strategy ID
  Future<MissionMap?> getMissionMap(String strategyId) async {
    try {
      final querySnapshot = await _missionMapsCollection
          .where('strategyId', isEqualTo: strategyId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('ℹ️ No mission map found for strategy: $strategyId');
        return null;
      }

      final docData = querySnapshot.docs.first.data() as Map<String, dynamic>;
      docData['id'] = querySnapshot.docs.first.id;

      // Convert Timestamps to ISO strings
      final data = _convertTimestampsToStrings(docData) as Map<String, dynamic>;

      return MissionMap.fromJson(data);
    } catch (e) {
      print('❌ Error getting mission map for strategy $strategyId: $e');
      rethrow;
    }
  }

  /// Stream mission map updates
  Stream<MissionMap?> missionMapStream(String strategyId) {
    return _missionMapsCollection
        .where('strategyId', isEqualTo: strategyId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      final docData = snapshot.docs.first.data() as Map<String, dynamic>;
      docData['id'] = snapshot.docs.first.id;
      final data = _convertTimestampsToStrings(docData) as Map<String, dynamic>;
      return MissionMap.fromJson(data);
    }).handleError((error) {
      print('❌ Error in missionMapStream for strategyId=$strategyId: $error');
      return null;
    });
  }

  /// Update a mission map
  Future<void> updateMissionMap(MissionMap missionMap) async {
    try {
      final data = _convertTimestampsToStrings(missionMap.toJson()) as Map<String, dynamic>;
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _missionMapsCollection.doc(missionMap.id).set(data);
      print('✅ Updated mission map: ${missionMap.id}');
    } catch (e) {
      print('❌ Error updating mission map: $e');
      rethrow;
    }
  }

  /// Delete a mission map and all its missions
  Future<void> deleteMissionMap(String missionMapId, String strategyId) async {
    try {
      // Delete the mission map
      await _missionMapsCollection.doc(missionMapId).delete();
      
      // Delete all associated missions
      final missionsSnapshot = await _missionsCollection
          .where('missionMapId', isEqualTo: missionMapId)
          .get();
      
      final batch = _db.batch();
      for (var doc in missionsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('✅ Deleted mission map and ${missionsSnapshot.docs.length} missions: $missionMapId');

      // Update strategy document
      await _userStrategiesCollection.doc(strategyId).update({
        'hasMissionMap': false,
        'currentMission': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error deleting mission map: $e');
      rethrow;
    }
  }

  /// Save a mission document
  Future<void> saveMissionDocument(MissionDocument mission) async {
    try {
      final data = _convertTimestampsToStrings(mission.toJson()) as Map<String, dynamic>;
      await _missionsCollection.doc(mission.id).set(data);
      print('✅ Saved mission document: ${mission.id}');
    } catch (e) {
      print('❌ Error saving mission document: $e');
      rethrow;
    }
  }

  /// Get all missions for a mission map (ordered by sequence)
  Future<List<MissionDocument>> getMissionsForMap(String missionMapId) async {
    try {
      final querySnapshot = await _missionsCollection
          .where('missionMapId', isEqualTo: missionMapId)
          .orderBy('sequenceNumber')
          .get();

      final missions = <MissionDocument>[];
      for (var doc in querySnapshot.docs) {
        final docData = doc.data() as Map<String, dynamic>;
        docData['id'] = doc.id;
        final data = _convertTimestampsToStrings(docData) as Map<String, dynamic>;
        missions.add(MissionDocument.fromJson(data));
      }

      return missions;
    } catch (e) {
      print('❌ Error getting missions for map $missionMapId: $e');
      rethrow;
    }
  }

  /// Stream missions for a mission map
  Stream<List<MissionDocument>> missionsForMapStream(String missionMapId) {
    return _missionsCollection
        .where('missionMapId', isEqualTo: missionMapId)
        .orderBy('sequenceNumber')
        .snapshots()
        .map((snapshot) {
      final missions = <MissionDocument>[];
      for (var doc in snapshot.docs) {
        final docData = doc.data() as Map<String, dynamic>;
        docData['id'] = doc.id;
        final data = _convertTimestampsToStrings(docData) as Map<String, dynamic>;
        missions.add(MissionDocument.fromJson(data));
      }
      return missions;
    }).handleError((error) {
      print('❌ Error in missionsForMapStream for missionMapId=$missionMapId: $error');
      return <MissionDocument>[];
    });
  }

  /// Get a specific mission document
  Future<MissionDocument?> getMissionDocument(String missionId) async {
    try {
      final doc = await _missionsCollection.doc(missionId).get();
      
      if (!doc.exists) {
        print('ℹ️ Mission document not found: $missionId');
        return null;
      }

      final docData = doc.data() as Map<String, dynamic>;
      docData['id'] = doc.id;
      final data = _convertTimestampsToStrings(docData) as Map<String, dynamic>;
      return MissionDocument.fromJson(data);
    } catch (e) {
      print('❌ Error getting mission document $missionId: $e');
      rethrow;
    }
  }

  /// Update a mission document
  Future<void> updateMissionDocument(MissionDocument mission) async {
    try {
      final data = _convertTimestampsToStrings(mission.toJson()) as Map<String, dynamic>;
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _missionsCollection.doc(mission.id).set(data);
      print('✅ Updated mission document: ${mission.id}');
    } catch (e) {
      print('❌ Error updating mission document: $e');
      rethrow;
    }
  }

  /// Delete a mission document
  Future<void> deleteMissionDocument(String missionId) async {
    try {
      await _missionsCollection.doc(missionId).delete();
      print('✅ Deleted mission document: $missionId');
    } catch (e) {
      print('❌ Error deleting mission document: $e');
      rethrow;
    }
  }

  // ========== GOAL OPERATIONS ==========

  /// Save a goal
  Future<void> saveGoal(Goal goal) async {
    try {
      final data = _convertTimestampsToStrings(goal.toJson()) as Map<String, dynamic>;
      await _goalsCollection.doc(goal.id).set(data);
      print('✅ Saved goal: ${goal.id}');
    } catch (e) {
      print('❌ Error saving goal: $e');
      rethrow;
    }
  }

  /// Get a specific goal
  Future<Goal?> getGoal(String goalId) async {
    try {
      final doc = await _goalsCollection.doc(goalId).get();
      
      if (!doc.exists) {
        print('ℹ️ Goal not found: $goalId');
        return null;
      }

      final data = doc.data();
      if (data == null) {
        print('⚠️ Null data for goal: $goalId');
        return null;
      }

      // Manually construct Goal to avoid json_serializable issues with JavaScript objects
      return Goal(
        id: doc.id,
        missionId: _getStringField(data, 'missionId'),
        strategyId: _getStringField(data, 'strategyId'),
        title: _getStringField(data, 'title'),
        description: _getStringField(data, 'description'),
        budgetMonetary: _getDoubleField(data, 'budgetMonetary', 0.0),
        budgetTime: _getDoubleField(data, 'budgetTime', 0.0),
        actualMonetary: _getDoubleField(data, 'actualMonetary', 0.0),
        actualTime: _getDoubleField(data, 'actualTime', 0.0),
        achieved: _getBoolField(data, 'achieved', false),
        dateAchieved: _getDateTimeField(data, 'dateAchieved'),
        dateCreated: _getDateTimeField(data, 'dateCreated') ?? DateTime.now(),
        updatedAt: _getDateTimeField(data, 'updatedAt') ?? DateTime.now(),
      );
    } catch (e) {
      print('❌ Error getting goal $goalId: $e');
      rethrow;
    }
  }

  /// Get all goals for a mission
  Future<List<Goal>> getGoalsForMission(String missionId) async {
    try {
      final querySnapshot = await _goalsCollection
          .where('missionId', isEqualTo: missionId)
          .orderBy('dateCreated')
          .get();

      final goals = <Goal>[];
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          if (data == null) {
            print('⚠️ Null data for goal document: ${doc.id}');
            continue;
          }
          // Manually construct Goal to avoid json_serializable issues with JavaScript objects
          final goal = Goal(
            id: doc.id,
            missionId: _getStringField(data, 'missionId'),
            strategyId: _getStringField(data, 'strategyId'),
            title: _getStringField(data, 'title'),
            description: _getStringField(data, 'description'),
            budgetMonetary: _getDoubleField(data, 'budgetMonetary', 0.0),
            budgetTime: _getDoubleField(data, 'budgetTime', 0.0),
            actualMonetary: _getDoubleField(data, 'actualMonetary', 0.0),
            actualTime: _getDoubleField(data, 'actualTime', 0.0),
            achieved: _getBoolField(data, 'achieved', false),
            dateAchieved: _getDateTimeField(data, 'dateAchieved'),
            dateCreated: _getDateTimeField(data, 'dateCreated') ?? DateTime.now(),
            updatedAt: _getDateTimeField(data, 'updatedAt') ?? DateTime.now(),
          );
          goals.add(goal);
        } catch (e) {
          print('❌ Error parsing goal ${doc.id}: $e');
          continue;
        }
      }

      return goals;
    } catch (e) {
      print('❌ Error getting goals for mission $missionId: $e');
      rethrow;
    }
  }

  /// Stream goals for a mission
  Stream<List<Goal>> goalsForMissionStream(String missionId) {
    return _goalsCollection
        .where('missionId', isEqualTo: missionId)
        .orderBy('dateCreated')
        .snapshots()
        .map((snapshot) {
      final goals = <Goal>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data == null) {
            print('⚠️ Null data for goal document: ${doc.id}');
            continue;
          }
          
          // Manually construct Goal to avoid json_serializable issues with JavaScript objects
          final goal = Goal(
            id: doc.id,
            missionId: _getStringField(data, 'missionId'),
            strategyId: _getStringField(data, 'strategyId'),
            title: _getStringField(data, 'title'),
            description: _getStringField(data, 'description'),
            budgetMonetary: _getDoubleField(data, 'budgetMonetary', 0.0),
            budgetTime: _getDoubleField(data, 'budgetTime', 0.0),
            actualMonetary: _getDoubleField(data, 'actualMonetary', 0.0),
            actualTime: _getDoubleField(data, 'actualTime', 0.0),
            achieved: _getBoolField(data, 'achieved', false),
            dateAchieved: _getDateTimeField(data, 'dateAchieved'),
            dateCreated: _getDateTimeField(data, 'dateCreated') ?? DateTime.now(),
            updatedAt: _getDateTimeField(data, 'updatedAt') ?? DateTime.now(),
          );
          goals.add(goal);
        } catch (e) {
          print('❌ Error parsing goal ${doc.id}: $e');
          // Skip this goal and continue with others
          continue;
        }
      }
      return goals;
    }).handleError((error) {
      print('❌ Error in goalsForMissionStream for missionId=$missionId: $error');
      return <Goal>[];
    });
  }

  /// Update a goal
  Future<void> updateGoal(Goal goal) async {
    try {
      final data = _convertTimestampsToStrings(goal.toJson()) as Map<String, dynamic>;
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _goalsCollection.doc(goal.id).set(data);
      print('✅ Updated goal: ${goal.id}');
    } catch (e) {
      print('❌ Error updating goal: $e');
      rethrow;
    }
  }

  /// Delete a goal (and all its objectives)
  Future<void> deleteGoal(String goalId) async {
    try {
      // Delete all objectives for this goal
      final objectivesSnapshot = await _objectivesCollection
          .where('goalId', isEqualTo: goalId)
          .get();
      
      final batch = _db.batch();
      for (var doc in objectivesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete the goal
      batch.delete(_goalsCollection.doc(goalId));
      
      await batch.commit();
      print('✅ Deleted goal and ${objectivesSnapshot.docs.length} objectives: $goalId');
    } catch (e) {
      print('❌ Error deleting goal: $e');
      rethrow;
    }
  }

  // ========== OBJECTIVE OPERATIONS ==========

  /// Save an objective
  Future<void> saveObjective(Objective objective) async {
    try {
      final data = _convertTimestampsToStrings(objective.toJson()) as Map<String, dynamic>;
      await _objectivesCollection.doc(objective.id).set(data);
      print('✅ Saved objective: ${objective.id}');
    } catch (e) {
      print('❌ Error saving objective: $e');
      rethrow;
    }
  }

  /// Get a specific objective
  Future<Objective?> getObjective(String objectiveId) async {
    try {
      final doc = await _objectivesCollection.doc(objectiveId).get();
      
      if (!doc.exists) {
        print('ℹ️ Objective not found: $objectiveId');
        return null;
      }

      final data = doc.data();
      if (data == null) {
        print('⚠️ Null data for objective: $objectiveId');
        return null;
      }

      // Manually construct Objective to avoid json_serializable issues with JavaScript objects
      return Objective(
        id: doc.id,
        goalId: _getStringField(data, 'goalId'),
        missionId: _getStringField(data, 'missionId'),
        strategyId: _getStringField(data, 'strategyId'),
        title: _getStringField(data, 'title'),
        description: _getStringField(data, 'description'),
        measurableRequirement: _getStringField(data, 'measurableRequirement'),
        dueDate: _getDateTimeField(data, 'dueDate'),
        costMonetary: _getDoubleField(data, 'costMonetary', 0.0),
        costTime: _getDoubleField(data, 'costTime', 0.0),
        achieved: _getBoolField(data, 'achieved', false),
        dateAchieved: _getDateTimeField(data, 'dateAchieved'),
        dateCreated: _getDateTimeField(data, 'dateCreated') ?? DateTime.now(),
        updatedAt: _getDateTimeField(data, 'updatedAt') ?? DateTime.now(),
      );
    } catch (e) {
      print('❌ Error getting objective $objectiveId: $e');
      rethrow;
    }
  }

  /// Get all objectives for a goal
  Future<List<Objective>> getObjectivesForGoal(String goalId) async {
    try {
      final querySnapshot = await _objectivesCollection
          .where('goalId', isEqualTo: goalId)
          .orderBy('dateCreated')
          .get();

      final objectives = <Objective>[];
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          if (data == null) {
            print('⚠️ Null data for objective document: ${doc.id}');
            continue;
          }
          // Manually construct Objective to avoid json_serializable issues with JavaScript objects
          final objective = Objective(
            id: doc.id,
            goalId: _getStringField(data, 'goalId'),
            missionId: _getStringField(data, 'missionId'),
            strategyId: _getStringField(data, 'strategyId'),
            title: _getStringField(data, 'title'),
            description: _getStringField(data, 'description'),
            measurableRequirement: _getStringField(data, 'measurableRequirement'),
            dueDate: _getDateTimeField(data, 'dueDate'),
            costMonetary: _getDoubleField(data, 'costMonetary', 0.0),
            costTime: _getDoubleField(data, 'costTime', 0.0),
            achieved: _getBoolField(data, 'achieved', false),
            dateAchieved: _getDateTimeField(data, 'dateAchieved'),
            dateCreated: _getDateTimeField(data, 'dateCreated') ?? DateTime.now(),
            updatedAt: _getDateTimeField(data, 'updatedAt') ?? DateTime.now(),
          );
          objectives.add(objective);
        } catch (e) {
          print('❌ Error parsing objective ${doc.id}: $e');
          continue;
        }
      }

      return objectives;
    } catch (e) {
      print('❌ Error getting objectives for goal $goalId: $e');
      rethrow;
    }
  }

  /// Stream objectives for a goal
  Stream<List<Objective>> objectivesForGoalStream(String goalId) {
    return _objectivesCollection
        .where('goalId', isEqualTo: goalId)
        .orderBy('dateCreated')
        .snapshots()
        .map((snapshot) {
      final objectives = <Objective>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data == null) {
            print('⚠️ Null data for objective document: ${doc.id}');
            continue;
          }
          
          // Manually construct Objective to avoid json_serializable issues with JavaScript objects
          final objective = Objective(
            id: doc.id,
            goalId: _getStringField(data, 'goalId'),
            missionId: _getStringField(data, 'missionId'),
            strategyId: _getStringField(data, 'strategyId'),
            title: _getStringField(data, 'title'),
            description: _getStringField(data, 'description'),
            measurableRequirement: _getStringField(data, 'measurableRequirement'),
            dueDate: _getDateTimeField(data, 'dueDate'),
            costMonetary: _getDoubleField(data, 'costMonetary', 0.0),
            costTime: _getDoubleField(data, 'costTime', 0.0),
            achieved: _getBoolField(data, 'achieved', false),
            dateAchieved: _getDateTimeField(data, 'dateAchieved'),
            dateCreated: _getDateTimeField(data, 'dateCreated') ?? DateTime.now(),
            updatedAt: _getDateTimeField(data, 'updatedAt') ?? DateTime.now(),
          );
          objectives.add(objective);
        } catch (e) {
          print('❌ Error parsing objective ${doc.id}: $e');
          // Skip this objective and continue with others
          continue;
        }
      }
      return objectives;
    }).handleError((error) {
      print('❌ Error in objectivesForGoalStream for goalId=$goalId: $error');
      return <Objective>[];
    });
  }

  /// Update an objective
  Future<void> updateObjective(Objective objective) async {
    try {
      final data = _convertTimestampsToStrings(objective.toJson()) as Map<String, dynamic>;
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _objectivesCollection.doc(objective.id).set(data);
      print('✅ Updated objective: ${objective.id}');
    } catch (e) {
      print('❌ Error updating objective: $e');
      rethrow;
    }
  }

  /// Delete an objective
  Future<void> deleteObjective(String objectiveId) async {
    try {
      await _objectivesCollection.doc(objectiveId).delete();
      print('✅ Deleted objective: $objectiveId');
    } catch (e) {
      print('❌ Error deleting objective: $e');
      rethrow;
    }
  }

  /// Advance to next mission (new structure)
  Future<void> advanceToNextMissionNew(String strategyId) async {
    try {
      final missionMap = await getMissionMap(strategyId);
      if (missionMap == null) {
        throw Exception('No mission map found for strategy');
      }

      final currentIndex = missionMap.currentMissionIndex ?? 0;
      final nextIndex = currentIndex + 1;

      if (nextIndex >= missionMap.totalMissions) {
        print('⚠️ Strategy is already on the last mission');
        return;
      }

      final updatedMap = missionMap.copyWith(
        currentMissionIndex: nextIndex,
        updatedAt: DateTime.now(),
      );

      await updateMissionMap(updatedMap);
      print('✅ Advanced strategy to mission ${nextIndex + 1}');
    } catch (e) {
      print('❌ Error advancing to next mission: $e');
      rethrow;
    }
  }

  // ============================================================================
  // END NEW MISSION MAP STRUCTURE
  // ============================================================================

  // ========== DENORMALIZATION HELPERS ==========

  /// Update strategy's purpose field
  Future<void> updateStrategyPurpose(String strategyId, String? purpose) async {
    try {
      await _userStrategiesCollection.doc(strategyId).update({
        'purpose': purpose,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated strategy purpose for: $strategyId');
    } catch (e) {
      print('❌ Error updating strategy purpose: $e');
      rethrow;
    }
  }

  /// Update strategy's currentVision field
  Future<void> updateStrategyCurrentVision(String strategyId, String? vision) async {
    try {
      await _userStrategiesCollection.doc(strategyId).update({
        'currentVision': vision,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated strategy currentVision for: $strategyId');
    } catch (e) {
      print('❌ Error updating strategy currentVision: $e');
      rethrow;
    }
  }

  /// Update strategy's currentMission field
  Future<void> updateStrategyCurrentMission(String strategyId, String? mission) async {
    try {
      await _userStrategiesCollection.doc(strategyId).update({
        'currentMission': mission,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated strategy currentMission for: $strategyId');
    } catch (e) {
      print('❌ Error updating strategy currentMission: $e');
      rethrow;
    }
  }

  /// Increment or decrement strategy's valueCount
  Future<void> updateStrategyValueCount(String strategyId, int delta) async {
    try {
      await _userStrategiesCollection.doc(strategyId).update({
        'valueCount': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated strategy valueCount by $delta for: $strategyId');
    } catch (e) {
      print('❌ Error updating strategy valueCount: $e');
      rethrow;
    }
  }

  /// Increment or decrement strategy's visionCount
  Future<void> updateStrategyVisionCount(String strategyId, int delta) async {
    try {
      await _userStrategiesCollection.doc(strategyId).update({
        'visionCount': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated strategy visionCount by $delta for: $strategyId');
    } catch (e) {
      print('❌ Error updating strategy visionCount: $e');
      rethrow;
    }
  }

  /// Sync all denormalized fields for a strategy from actual data
  /// Useful for data migration or fixing inconsistencies
  Future<void> syncStrategyDenormalizedFields(String strategyId) async {
    try {
      print('🔄 Syncing denormalized fields for strategy: $strategyId');

      // Get the strategy
      final strategy = await getStrategy(strategyId);
      if (strategy == null) {
        throw Exception('Strategy not found: $strategyId');
      }

      // Count values
      final valuesSnapshot = await _userValuesCollection
          .where('strategyId', isEqualTo: strategyId)
          .get();
      final valueCount = valuesSnapshot.docs.length;

      // Get current vision
      final currentVision = await getUserVision(strategyId);
      
      // Count visions
      final visionsSnapshot = await _userVisionsCollection
          .where('strategyId', isEqualTo: strategyId)
          .get();
      final visionCount = visionsSnapshot.docs.length;

      // Get mission map and current mission
      final missionMap = await getUserMissionMap(strategyId);
      String? currentMission;
      bool hasMissionMap = false;
      
      if (missionMap != null) {
        hasMissionMap = true;
        if (missionMap.currentMissionIndex != null && 
            missionMap.currentMissionIndex! < missionMap.missions.length) {
          currentMission = missionMap.missions[missionMap.currentMissionIndex!].mission;
        }
      }

      // Update strategy with synced data
      await _userStrategiesCollection.doc(strategyId).update({
        'valueCount': valueCount,
        'currentVision': currentVision?.visionStatement,
        'visionCount': visionCount,
        'currentMission': currentMission,
        'hasMissionMap': hasMissionMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Synced denormalized fields for strategy: $strategyId');
      print('   - Value count: $valueCount');
      print('   - Vision count: $visionCount');
      print('   - Has mission map: $hasMissionMap');
    } catch (e) {
      print('❌ Error syncing strategy denormalized fields: $e');
      rethrow;
    }
  }

  /// Sync denormalized fields for all strategies of a user
  /// Useful for data migration or bulk fixes
  Future<void> syncAllUserStrategyDenormalizedFields(String userId) async {
    try {
      print('🔄 Syncing denormalized fields for all strategies of user: $userId');

      final strategies = await getUserStrategies(userId);
      
      for (final strategy in strategies) {
        await syncStrategyDenormalizedFields(strategy.id);
      }

      print('✅ Synced ${strategies.length} strategies for user: $userId');
    } catch (e) {
      print('❌ Error syncing user strategy denormalized fields: $e');
      rethrow;
    }
  }
}
