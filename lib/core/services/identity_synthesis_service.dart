import 'dart:convert';
import 'package:purpose/core/models/identity_synthesis_result.dart';
import 'package:purpose/core/models/tier_analysis.dart';
import 'package:purpose/core/models/integrated_identity.dart';
import 'package:purpose/core/models/purpose_option.dart';
import 'package:purpose/core/models/module_type.dart';
import 'package:purpose/core/services/gemini_service.dart';
import 'package:purpose/core/services/firestore_service.dart';

/// Service to orchestrate identity synthesis from purpose modules
class IdentitySynthesisService {
  final GeminiService _geminiService;
  final FirestoreService _firestoreService;

  IdentitySynthesisService({
    required GeminiService geminiService,
    required FirestoreService firestoreService,
  })  : _geminiService = geminiService,
        _firestoreService = firestoreService;

  /// Build JSON data from user's purpose module answers
  Future<String> buildPurposeDataJson(String userId) async {
    // Fetch all purpose modules
    final modules = await _firestoreService.getQuestionModulesByParent(
      ModuleType.purpose,
    );

    // Build hierarchy
    final List<Map<String, dynamic>> hierarchy = [];

    for (final module in modules) {
      // Get questions for this module
      final questions = await _firestoreService.getQuestionsByModule(module.id);

      // Get user answers for this module
      final answers = await _firestoreService.getUserAnswersByModule(
        userId: userId,
        questionModuleId: module.id,
      );

      // Create answer map for quick lookup
      final answerMap = {for (var a in answers) a.questionId: a};

      // Build questions with answers
      final questionsData = questions.map((q) {
        final answer = answerMap[q.id];
        return {
          'id': q.id,
          'questionText': q.questionText,
          'helperText': q.helperText,
          'questionType': q.questionType.value,
          'order': q.order,
          'isRequired': q.isRequired,
          'answer': answer != null
              ? {
                  'id': answer.id,
                  'textAnswer': answer.textAnswer,
                  'numericAnswer': answer.numericAnswer,
                  'selectedOption': answer.selectedOption,
                  'booleanAnswer': answer.booleanAnswer,
                  'notes': answer.notes,
                  'createdAt': answer.createdAt.toIso8601String(),
                  'updatedAt': answer.updatedAt.toIso8601String(),
                }
              : null,
        };
      }).toList();

      // Add module with questions and answers
      hierarchy.add({
        'id': module.id,
        'name': module.name,
        'description': module.description,
        'questions': questionsData,
      });
    }

    final jsonData = {
      'userId': userId,
      'moduleType': 'purpose',
      'exportedAt': DateTime.now().toIso8601String(),
      'modules': hierarchy,
    };

    return const JsonEncoder.withIndent('  ').convert(jsonData);
  }

  /// Synthesize identity and save result
  Future<IdentitySynthesisResult> synthesizeAndSave(String userId) async {
    try {
      print('=== STARTING IDENTITY SYNTHESIS ===');
      print('User ID: $userId');
      
      // Check if all purpose modules are complete
      final user = await _firestoreService.getUser(userId);
      if (user == null) {
        throw Exception('User not found');
      }

      final modules = await _firestoreService.getQuestionModulesByParent(
        ModuleType.purpose,
      );
      print('Found ${modules.length} purpose modules');

      // Verify all modules are complete by checking if all questions have answers
      for (final module in modules) {
        final questions = await _firestoreService.getQuestionsByModule(module.id);
        final answers = await _firestoreService.getUserAnswersByModule(
          userId: userId,
          questionModuleId: module.id,
        );
        
        if (questions.isEmpty) {
          throw Exception('Module ${module.name} has no questions');
        }
        
        final answeredQuestionIds = answers.map((a) => a.questionId).toSet();
        final isComplete = questions.every((q) => answeredQuestionIds.contains(q.id));
        
        if (!isComplete) {
          final unanswered = questions.where((q) => !answeredQuestionIds.contains(q.id)).length;
          throw Exception('Module "${module.name}" is incomplete ($unanswered of ${questions.length} questions unanswered)');
        }
        
        print('  ✓ ${module.name}: ${questions.length}/${questions.length} questions answered');
      }
      print('All modules verified complete');

      // Build JSON data
      print('Building purpose data JSON...');
      final jsonData = await buildPurposeDataJson(userId);
      print('JSON data built (${jsonData.length} characters)');

      // Calculate answers hash
      final answersHash = await _firestoreService.calculateAnswersHash(userId);
      print('Answers hash: $answersHash');

      // Call AI synthesis
      print('Calling AI synthesis...');
      final synthesisJson = await _geminiService.synthesizeIdentity(
        jsonData: jsonData,
      );
      print('AI synthesis complete, parsing response...');
      print('AI Response JSON: ${synthesisJson.toString()}');

      // Parse the response
      final result = _parseIdentitySynthesisResponse(
        userId: userId,
        answersHash: answersHash,
        synthesisJson: synthesisJson,
      );
      print('Response parsed successfully');

      // Save to Firestore
      print('Saving to Firestore...');
      final id = await _firestoreService.saveIdentitySynthesisResult(result);
      print('Saved with ID: $id');

      return result.copyWith(id: id);
    } catch (e, stackTrace) {
      print('=== IDENTITY SYNTHESIS ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if existing result is stale, and synthesize if needed
  Future<IdentitySynthesisResult> getOrSynthesize(String userId) async {
    try {
      print('=== GET OR SYNTHESIZE IDENTITY ===');
      print('User ID: $userId');
      
      // Get existing result
      final existingResult = await _firestoreService.getIdentitySynthesisResult(
        userId,
      );

      // If no result exists, synthesize
      if (existingResult == null) {
        print('No existing result found, synthesizing...');
        return await synthesizeAndSave(userId);
      }

      print('Found existing result from ${existingResult.createdAt}');

      // Check if stale
      final isStale = await _firestoreService.isIdentitySynthesisStale(
        userId,
        existingResult,
      );

      // If stale, re-synthesize
      if (isStale) {
        print('Result is stale, re-synthesizing...');
        return await synthesizeAndSave(userId);
      }

      print('Using existing result');
      // Return existing result
      return existingResult;
    } catch (e, stackTrace) {
      print('=== GET OR SYNTHESIZE ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Parse AI response into IdentitySynthesisResult model
  IdentitySynthesisResult _parseIdentitySynthesisResponse({
    required String userId,
    required String answersHash,
    required Map<String, dynamic> synthesisJson,
  }) {
    // Parse tier analysis
    final tierAnalysisList = (synthesisJson['tier_analysis'] as List?)
            ?.map((t) => TierAnalysis.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    // Parse integrated identity
    final integratedIdentityJson = synthesisJson['integrated_identity'] as Map<String, dynamic>?;
    final integratedIdentity = integratedIdentityJson != null
        ? IntegratedIdentity.fromJson(integratedIdentityJson)
        : const IntegratedIdentity(
            keyPatterns: [],
            tensions: [],
            summary: 'No integrated identity generated',
          );

    // Parse purpose options
    final purposeOptionsList = (synthesisJson['purpose_options'] as List?)
            ?.map((p) => PurposeOption.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return IdentitySynthesisResult(
      id: '', // Will be set after saving to Firestore
      userId: userId,
      tierAnalysis: tierAnalysisList,
      integratedIdentity: integratedIdentity,
      purposeOptions: purposeOptionsList,
      createdAt: DateTime.now(),
      answersHash: answersHash,
    );
  }

  /// Update result with user's selection
  Future<void> selectPurposeOption({
    required IdentitySynthesisResult result,
    required int optionIndex,
  }) async {
    final updated = result.copyWith(selectedOptionIndex: optionIndex);
    await _firestoreService.updateIdentitySynthesisResult(updated);
  }

  /// Update result with user's edited statement
  Future<void> editPurposeStatement({
    required IdentitySynthesisResult result,
    required String editedStatement,
  }) async {
    final updated = result.copyWith(editedStatement: editedStatement);
    await _firestoreService.updateIdentitySynthesisResult(updated);
  }

  /// Promote purpose statement to user's profile
  Future<void> promotePurposeToProfile({
    required String userId,
    required IdentitySynthesisResult result,
  }) async {
    final statement = result.finalPurposeStatement;
    if (statement == null) {
      throw Exception('No purpose statement selected');
    }

    await _firestoreService.promoteToUserPurpose(
      userId: userId,
      purposeStatement: statement,
      resultId: result.id,
    );
  }
}
