import 'package:json_annotation/json_annotation.dart';

part 'mission_map.g.dart';

/// Represents a mission map (metadata only - missions are in separate collection)
/// 
/// This is the refactored version of UserMissionMap where missions are stored
/// as separate documents in the 'missions' collection rather than embedded.
@JsonSerializable(explicitToJson: true)
class MissionMap {
  final String id;
  final String strategyId; // Links to parent strategy
  final String? sessionId; // Reference to MissionCreationSession
  final int? currentMissionIndex; // Which mission user is currently working on (0-based)
  final int totalMissions; // Total number of missions in this map (3-5)
  final DateTime? strategyStartDate; // When the strategy execution begins
  final DateTime createdAt;
  final DateTime updatedAt;

  MissionMap({
    required this.id,
    required this.strategyId,
    this.sessionId,
    this.currentMissionIndex,
    required this.totalMissions,
    this.strategyStartDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MissionMap.fromJson(Map<String, dynamic> json) =>
      _$MissionMapFromJson(json);

  Map<String, dynamic> toJson() => _$MissionMapToJson(this);

  MissionMap copyWith({
    String? id,
    String? strategyId,
    String? sessionId,
    int? currentMissionIndex,
    int? totalMissions,
    DateTime? strategyStartDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MissionMap(
      id: id ?? this.id,
      strategyId: strategyId ?? this.strategyId,
      sessionId: sessionId ?? this.sessionId,
      currentMissionIndex: currentMissionIndex ?? this.currentMissionIndex,
      totalMissions: totalMissions ?? this.totalMissions,
      strategyStartDate: strategyStartDate ?? this.strategyStartDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get completion percentage (0.0 to 1.0)
  double get completionPercentage {
    if (totalMissions == 0) return 0.0;
    if (currentMissionIndex == null) return 0.0;
    return (currentMissionIndex! + 1) / totalMissions;
  }

  /// Check if all missions are complete
  bool get isComplete {
    if (totalMissions == 0) return false;
    if (currentMissionIndex == null) return false;
    return currentMissionIndex! >= totalMissions - 1;
  }
}
