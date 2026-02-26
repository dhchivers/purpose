import 'package:purpose/core/models/user_answer.dart';
import 'package:purpose/core/models/question.dart';
import 'package:purpose/core/models/question_module.dart';
import 'package:purpose/core/services/gemini_service.dart';
import 'package:purpose/core/services/firestore_service.dart';

/// Service to coordinate AI processing of user answers
class AIProcessorService {
  final GeminiService _geminiService;
  final FirestoreService _firestoreService;

  AIProcessorService({
    required GeminiService geminiService,
    required FirestoreService firestoreService,
  })  : _geminiService = geminiService,
        _firestoreService = firestoreService;

  /// Process a single answer through AI
  Future<String> processAnswer({
    required UserAnswer answer,
    required Question question,
    required QuestionModule module,
  }) async {
    try {
      // Generate AI insights
      final insights = await _geminiService.analyzeAnswer(
        answer: answer,
        question: question,
        module: module,
      );

      // Mark answer as processed and store insights
      await _firestoreService.markAnswerProcessed(
        answerId: answer.id,
        aiResponse: insights,
      );

      return insights;
    } catch (e) {
      print('Error processing answer ${answer.id}: $e');
      rethrow;
    }
  }

  /// Process all unprocessed answers in a module
  Future<Map<String, String>> processModuleAnswers({
    required String userId,
    required String strategyId,
    required QuestionModule module,
  }) async {
    try {
      // Get all unprocessed answers for this module (without strategyId filter to include legacy)
      final allAnswers = await _firestoreService.getUnprocessedAnswers(
        userId: userId,
        strategyId: null,
        questionModuleId: module.id,
      );
      
      // Filter to current strategy or null (legacy answers)
      final answers = allAnswers.where((answer) => 
        answer.strategyId == strategyId || answer.strategyId == null
      ).toList();

      if (answers.isEmpty) {
        return {};
      }

      // Get all questions for this module
      final questions = await _firestoreService.getQuestionsByModule(module.id);

      // Create a map to store insights
      final insights = <String, String>{};

      // Process each answer individually
      for (var answer in answers) {
        final question = questions.firstWhere(
          (q) => q.id == answer.questionId,
          orElse: () => questions.first,
        );

        final insight = await processAnswer(
          answer: answer,
          question: question,
          module: module,
        );

        insights[answer.id] = insight;
      }

      return insights;
    } catch (e) {
      print('Error processing module answers: $e');
      rethrow;
    }
  }

  /// Generate comprehensive module analysis
  Future<String> generateModuleAnalysis({
    required String userId,
    required String strategyId,
    required QuestionModule module,
  }) async {
    try {
      // Get all answers for this module (without strategyId filter to include legacy)
      final allAnswers = await _firestoreService.getUserAnswersByModule(
        userId: userId,
        strategyId: null,
        questionModuleId: module.id,
      );
      
      // Filter to current strategy or null (legacy answers)
      final answers = allAnswers.where((answer) => 
        answer.strategyId == strategyId || answer.strategyId == null
      ).toList();

      if (answers.isEmpty) {
        throw Exception('No answers found for this module');
      }

      // Get all questions
      final questions = await _firestoreService.getQuestionsByModule(module.id);

      // Generate comprehensive analysis
      final analysis = await _geminiService.analyzeModuleAnswers(
        answers: answers,
        questions: questions,
        module: module,
      );

      return analysis;
    } catch (e) {
      print('Error generating module analysis: $e');
      rethrow;
    }
  }

  /// Generate complete purpose statement from all user's answers
  Future<String> generatePurposeStatement({
    required String userId,
    required String strategyId,
  }) async {
    try {
      // Get all user's answers across all modules
      final allModules = await _firestoreService.getAllQuestionModules();
      final allAnswers = <UserAnswer>[];
      final allQuestions = <Question>[];
      final modulesMap = <String, QuestionModule>{};

      for (var module in allModules) {
        modulesMap[module.id] = module;
        
        final allModuleAnswers = await _firestoreService.getUserAnswersByModule(
          userId: userId,
          strategyId: null,
          questionModuleId: module.id,
        );
        
        // Filter to current strategy or null (legacy answers)
        final moduleAnswers = allModuleAnswers.where((answer) => 
          answer.strategyId == strategyId || answer.strategyId == null
        ).toList();
        
        allAnswers.addAll(moduleAnswers);

        final moduleQuestions = await _firestoreService.getQuestionsByModule(module.id);
        allQuestions.addAll(moduleQuestions);
      }

      if (allAnswers.isEmpty) {
        throw Exception('No answers found. Please complete at least one module.');
      }

      // Generate comprehensive purpose statement
      final purposeStatement = await _geminiService.generatePurposeStatement(
        allAnswers: allAnswers,
        allQuestions: allQuestions,
        modules: modulesMap,
      );

      return purposeStatement;
    } catch (e) {
      print('Error generating purpose statement: $e');
      rethrow;
    }
  }

  /// Check if module has unprocessed answers
  Future<bool> hasUnprocessedAnswers({
    required String userId,
    required String strategyId,
    required String moduleId,
  }) async {
    final allUnprocessed = await _firestoreService.getUnprocessedAnswers(
      userId: userId,
      strategyId: null,
      questionModuleId: moduleId,
    );
    
    // Filter to current strategy or null (legacy answers)
    final unprocessed = allUnprocessed.where((answer) => 
      answer.strategyId == strategyId || answer.strategyId == null
    ).toList();
    
    return unprocessed.isNotEmpty;
  }

  /// Get count of unprocessed answers for a module
  Future<int> getUnprocessedCount({
    required String userId,
    required String strategyId,
    required String moduleId,
  }) async {
    final allUnprocessed = await _firestoreService.getUnprocessedAnswers(
      userId: userId,
      strategyId: null,
      questionModuleId: moduleId,
    );
    
    // Filter to current strategy or null (legacy answers)
    final unprocessed = allUnprocessed.where((answer) => 
      answer.strategyId == strategyId || answer.strategyId == null
    ).toList();
    
    return unprocessed.length;
  }
}
