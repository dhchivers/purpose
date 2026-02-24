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

  /// Helper to convert all Timestamp objects to ISO strings to avoid Int64 issues on web
  /// Recursively processes Maps and Lists
  static dynamic _convertTimestampsToStrings(dynamic data) {
    if (data is Timestamp) {
      return data.toDate().toIso8601String();
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
    required String questionId,
  }) async {
    final snapshot = await _userAnswersCollection
        .where('userId', isEqualTo: userId)
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
  Future<List<UserAnswer>> getUserAnswersByModule({
    required String userId,
    required String questionModuleId,
  }) async {
    final snapshot = await _userAnswersCollection
        .where('userId', isEqualTo: userId)
        .where('questionModuleId', isEqualTo: questionModuleId)
        .get();

    return snapshot.docs.map((doc) {
      final docData = Map<String, dynamic>.from(doc.data() as Map);
      docData['id'] = doc.id;
      final data = _convertTimestampsToStrings(docData) as Map<String, dynamic>;
      return UserAnswer.fromJson(data);
    }).toList();
  }

  /// Stream of user's answers for a question module
  Stream<List<UserAnswer>> userAnswersStream({
    required String userId,
    required String questionModuleId,
  }) {
    return _userAnswersCollection
        .where('userId', isEqualTo: userId)
        .where('questionModuleId', isEqualTo: questionModuleId)
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
    required String questionModuleId,
  }) async {
    // Get total questions in module
    final module = await getQuestionModule(questionModuleId);
    if (module == null) return false;

    // Get user's answers
    final answers = await getUserAnswersByModule(
      userId: userId,
      questionModuleId: questionModuleId,
    );

    // Check if all questions are answered
    return answers.length >= module.totalQuestions;
  }

  /// Get all answers for AI processing (unanswered by AI)
  Future<List<UserAnswer>> getUnprocessedAnswers({
    required String userId,
    required String questionModuleId,
  }) async {
    final snapshot = await _userAnswersCollection
        .where('userId', isEqualTo: userId)
        .where('questionModuleId', isEqualTo: questionModuleId)
        .where('processedByAI', isEqualTo: false)
        .get();

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
  Future<String> calculateAnswersHash(String userId) async {
    // Get all purpose modules
    final modules = await getQuestionModulesByParent(ModuleType.purpose);
    
    // Collect all answers for purpose modules
    final allAnswers = <UserAnswer>[];
    for (final module in modules) {
      final answers = await getUserAnswersByModule(
        userId: userId,
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

  /// Get the most recent identity synthesis result for a user
  Future<IdentitySynthesisResult?> getIdentitySynthesisResult(
    String userId,
  ) async {
    final snapshot = await _identitySynthesisResultsCollection
        .where('userId', isEqualTo: userId)
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
    IdentitySynthesisResult result,
  ) async {
    final currentHash = await calculateAnswersHash(userId);
    print('=== STALENESS CHECK ===');
    print('Current hash: $currentHash');
    print('Stored hash: ${result.answersHash}');
    print('Is stale: ${currentHash != result.answersHash}');
    return currentHash != result.answersHash;
  }

  /// Promote selected purpose statement to user's purpose field
  Future<void> promoteToUserPurpose({
    required String userId,
    required String purposeStatement,
    required String resultId,
  }) async {
    print('=== PROMOTING PURPOSE TO USER PROFILE ===');
    print('User ID: $userId');
    print('Purpose Statement: $purposeStatement');
    print('Result ID: $resultId');
    
    final batch = _db.batch();

    // Update user's purpose
    batch.update(_usersCollection.doc(userId), {
      'purpose': purposeStatement,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Mark result as promoted
    batch.update(_identitySynthesisResultsCollection.doc(resultId), {
      'isPromoted': true,
    });

    await batch.commit();
    print('✅ Purpose promoted successfully');
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

      // Update user's valueCount
      final userDoc = _usersCollection.doc(value.userId);
      await userDoc.update({
        'valueCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('❌ Error saving user value: $e');
      rethrow;
    }
  }

  /// Get all user values for a user
  Future<List<UserValue>> getUserValues(String userId) async {
    try {
      final querySnapshot = await _userValuesCollection
          .where('userId', isEqualTo: userId)
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
  Future<void> deleteUserValue(String valueId, String userId) async {
    try {
      await _userValuesCollection.doc(valueId).delete();
      print('✅ Deleted user value: $valueId');

      // Decrement user's valueCount
      final userDoc = _usersCollection.doc(userId);
      await userDoc.update({
        'valueCount': FieldValue.increment(-1),
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

      // Update user's vision field and increment visionCount
      final userDoc = _usersCollection.doc(vision.userId);
      await userDoc.update({
        'vision': vision.visionStatement,
        'visionCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error saving user vision: $e');
      rethrow;
    }
  }

  /// Get a user's vision
  Future<UserVision?> getUserVision(String userId) async {
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
      print('❌ Error getting user vision: $e');
      rethrow;
    }
  }

  /// Stream user's vision for real-time updates
  Stream<UserVision?> userVisionStream(String userId) {
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

      // Update user's vision field to reflect the change
      final userDoc = _usersCollection.doc(vision.userId);
      await userDoc.update({
        'vision': vision.visionStatement,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating user vision: $e');
      rethrow;
    }
  }

  /// Delete a user's vision
  Future<void> deleteUserVision(String visionId, String userId) async {
    try {
      await _userVisionsCollection.doc(visionId).delete();
      print('✅ Deleted user vision: $visionId');

      // Get the next most recent vision to update user.vision field
      final remainingVisions = await _userVisionsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      final userDoc = _usersCollection.doc(userId);
      
      if (remainingVisions.docs.isEmpty) {
        // No more visions, clear the field and decrement count
        await userDoc.update({
          'vision': null,
          'visionCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update to the next most recent vision and decrement count
        final nextVisionData = remainingVisions.docs.first.data() as Map<String, dynamic>;
        await userDoc.update({
          'vision': nextVisionData['visionStatement'],
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

      // Update user's missionsCompleted field (optional, for dashboard)
      final userDoc = _usersCollection.doc(missionMap.userId);
      await userDoc.update({
        'hasMissionMap': true,
        'currentMissionIndex': missionMap.currentMissionIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error saving user mission map: $e');
      rethrow;
    }
  }

  /// Get a user's mission map
  Future<UserMissionMap?> getUserMissionMap(String userId) async {
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
      print('❌ Error getting user mission map: $e');
      rethrow;
    }
  }

  /// Stream user's mission map for real-time updates
  Stream<UserMissionMap?> userMissionMapStream(String userId) {
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

      // Update user's current mission index
      final userDoc = _usersCollection.doc(missionMap.userId);
      await userDoc.update({
        'currentMissionIndex': missionMap.currentMissionIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating user mission map: $e');
      rethrow;
    }
  }

  /// Delete a user's mission map
  Future<void> deleteUserMissionMap(String missionMapId, String userId) async {
    try {
      await _userMissionMapsCollection.doc(missionMapId).delete();
      print('✅ Deleted user mission map: $missionMapId');

      // Update user document to reflect no mission map
      final userDoc = _usersCollection.doc(userId);
      await userDoc.update({
        'hasMissionMap': false,
        'currentMissionIndex': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error deleting user mission map: $e');
      rethrow;
    }
  }

  /// Advance user to next mission
  Future<void> advanceToNextMission(String userId) async {
    try {
      final missionMap = await getUserMissionMap(userId);
      if (missionMap == null) {
        throw Exception('No mission map found for user');
      }

      final currentIndex = missionMap.currentMissionIndex ?? 0;
      final nextIndex = currentIndex + 1;

      if (nextIndex >= missionMap.missions.length) {
        print('⚠️ User is already on the last mission');
        return;
      }

      final updatedMap = missionMap.copyWith(
        currentMissionIndex: nextIndex,
        updatedAt: DateTime.now(),
      );

      await updateUserMissionMap(updatedMap);
      print('✅ Advanced user to mission ${nextIndex + 1}');
    } catch (e) {
      print('❌ Error advancing to next mission: $e');
      rethrow;
    }
  }
}
