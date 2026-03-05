import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/models/goal.dart';
import 'package:purpose/core/models/objective.dart';
import 'package:purpose/core/services/firestore_provider.dart';

// ========== GOAL PROVIDERS ==========

/// Provider for a specific goal by ID (Future)
final goalProvider = FutureProvider.family<Goal?, String>((ref, goalId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getGoal(goalId);
});

/// Provider for all goals for a mission (Future)
final goalsForMissionProvider = FutureProvider.family<List<Goal>, String>((ref, missionId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getGoalsForMission(missionId);
});

/// Provider for all goals for a mission (Stream - real-time updates)
final goalsForMissionStreamProvider = StreamProvider.family<List<Goal>, String>((ref, missionId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.goalsForMissionStream(missionId);
});

/// Provider for all active (not achieved) goals for a strategy (Stream - real-time updates)
final activeGoalsForStrategyProvider = StreamProvider.family<List<Goal>, String>((ref, strategyId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.goalsForStrategyStream(strategyId).map((goals) {
    return goals.where((goal) => !goal.achieved).toList();
  });
});

// ========== OBJECTIVE PROVIDERS ==========

/// Provider for a specific objective by ID (Future)
final objectiveProvider = FutureProvider.family<Objective?, String>((ref, objectiveId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getObjective(objectiveId);
});

/// Provider for all objectives for a goal (Future)
final objectivesForGoalProvider = FutureProvider.family<List<Objective>, String>((ref, goalId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getObjectivesForGoal(goalId);
});

/// Provider for all objectives for a goal (Stream - real-time updates)
final objectivesForGoalStreamProvider = StreamProvider.family<List<Objective>, String>((ref, goalId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.objectivesForGoalStream(goalId);
});

// ========== COMPUTED PROVIDERS ==========

/// Provider to get number of objectives for a goal
final objectiveCountForGoalProvider = FutureProvider.family<int, String>((ref, goalId) async {
  final objectives = await ref.watch(objectivesForGoalProvider(goalId).future);
  return objectives.length;
});

/// Provider to get number of achieved objectives for a goal
final achievedObjectiveCountForGoalProvider = FutureProvider.family<int, String>((ref, goalId) async {
  final objectives = await ref.watch(objectivesForGoalProvider(goalId).future);
  return objectives.where((obj) => obj.achieved).length;
});

/// Provider to get completion percentage for a goal (based on objectives)
final goalCompletionPercentageProvider = FutureProvider.family<double, String>((ref, goalId) async {
  final objectives = await ref.watch(objectivesForGoalProvider(goalId).future);
  if (objectives.isEmpty) return 0.0;
  final achieved = objectives.where((obj) => obj.achieved).length;
  return (achieved / objectives.length) * 100;
});
