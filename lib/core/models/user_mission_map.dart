import 'package:json_annotation/json_annotation.dart';
import 'package:purpose/core/models/mission_creation_session.dart';

part 'user_mission_map.g.dart';

/// Represents a user's finalized mission map
@JsonSerializable(explicitToJson: true)
class UserMissionMap {
  final String id;
  final String strategyId; // Links to parent strategy
  @Deprecated('Use strategyId instead. Kept for backward compatibility during migration.')
  final String? userId; // Deprecated: Use strategyId
  final List<Mission> missions; // 3-5 sequential missions
  final String? sessionId; // Reference to MissionCreationSession
  final int? currentMissionIndex; // Which mission user is currently working on (0-based)
  final DateTime? strategyStartDate; // When the strategy execution begins
  final DateTime createdAt;
  final DateTime updatedAt;

  UserMissionMap({
    required this.id,
    required this.strategyId,
    @Deprecated('Use strategyId instead') this.userId,
    required this.missions,
    this.sessionId,
    this.currentMissionIndex,
    this.strategyStartDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserMissionMap.fromJson(Map<String, dynamic> json) =>
      _$UserMissionMapFromJson(json);

  Map<String, dynamic> toJson() => _$UserMissionMapToJson(this);

  UserMissionMap copyWith({
    String? id,
    String? strategyId,
    String? userId,
    List<Mission>? missions,
    String? sessionId,
    int? currentMissionIndex,
    DateTime? strategyStartDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserMissionMap(
      id: id ?? this.id,
      strategyId: strategyId ?? this.strategyId,
      userId: userId ?? this.userId,
      missions: missions ?? this.missions,
      sessionId: sessionId ?? this.sessionId,
      currentMissionIndex: currentMissionIndex ?? this.currentMissionIndex,
      strategyStartDate: strategyStartDate ?? this.strategyStartDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get the current mission being worked on
  Mission? get currentMission {
    if (currentMissionIndex == null || currentMissionIndex! >= missions.length) {
      return null;
    }
    return missions[currentMissionIndex!];
  }

  /// Get completion percentage (0.0 to 1.0)
  double get completionPercentage {
    if (missions.isEmpty) return 0.0;
    if (currentMissionIndex == null) return 0.0;
    return (currentMissionIndex! + 1) / missions.length;
  }

  /// Check if all missions are complete
  bool get isComplete {
    if (missions.isEmpty) return false;
    if (currentMissionIndex == null) return false;
    return currentMissionIndex! >= missions.length - 1;
  }
}
