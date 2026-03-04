import 'package:json_annotation/json_annotation.dart';
import 'package:purpose/core/models/mission_creation_session.dart';

part 'mission_document.g.dart';

/// Represents a single mission document in the 'missions' collection
/// 
/// This extends the Mission class with document metadata and references
/// to enable missions to be stored as separate Firestore documents.
@JsonSerializable(explicitToJson: true)
class MissionDocument {
  final String id; // Firestore document ID
  final String missionMapId; // Reference to parent MissionMap
  final String strategyId; // Denormalized for easier querying
  final int sequenceNumber; // 0, 1, 2, 3, 4 (for ordering)
  
  // Mission content (same as Mission class)
  final String mission; // "Mission 1 — Building Local Capacity"
  final String missionSequence; // "1", "2", "3", etc.
  final String focus; // What this mission focuses on
  final String structuralShift; // What structural change occurs
  final String capabilityRequired; // What capabilities need to be developed
  final String riskOrValueGuardrail; // Risk assessment and value constraints
  final String timeHorizon; // "0-2 years", "2-4 years", etc.
  final RiskLevel? riskLevel; // Parsed risk level (low, medium, high)
  final int durationMonths; // Duration of this mission in months (default 12)
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  MissionDocument({
    required this.id,
    required this.missionMapId,
    required this.strategyId,
    required this.sequenceNumber,
    required this.mission,
    required this.missionSequence,
    required this.focus,
    required this.structuralShift,
    required this.capabilityRequired,
    required this.riskOrValueGuardrail,
    required this.timeHorizon,
    this.riskLevel,
    this.durationMonths = 12,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MissionDocument.fromJson(Map<String, dynamic> json) =>
      _$MissionDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$MissionDocumentToJson(this);

  /// Create a MissionDocument from a Mission object
  factory MissionDocument.fromMission({
    required String id,
    required String missionMapId,
    required String strategyId,
    required int sequenceNumber,
    required Mission mission,
  }) {
    final now = DateTime.now();
    return MissionDocument(
      id: id,
      missionMapId: missionMapId,
      strategyId: strategyId,
      sequenceNumber: sequenceNumber,
      mission: mission.mission,
      missionSequence: mission.missionSequence,
      focus: mission.focus,
      structuralShift: mission.structuralShift,
      capabilityRequired: mission.capabilityRequired,
      riskOrValueGuardrail: mission.riskOrValueGuardrail,
      timeHorizon: mission.timeHorizon,
      riskLevel: mission.riskLevel,
      durationMonths: mission.durationMonths,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Convert MissionDocument to Mission object (for backward compatibility)
  Mission toMission() {
    return Mission(
      mission: mission,
      missionSequence: missionSequence,
      focus: focus,
      structuralShift: structuralShift,
      capabilityRequired: capabilityRequired,
      riskOrValueGuardrail: riskOrValueGuardrail,
      timeHorizon: timeHorizon,
      riskLevel: riskLevel,
      durationMonths: durationMonths,
    );
  }

  MissionDocument copyWith({
    String? id,
    String? missionMapId,
    String? strategyId,
    int? sequenceNumber,
    String? mission,
    String? missionSequence,
    String? focus,
    String? structuralShift,
    String? capabilityRequired,
    String? riskOrValueGuardrail,
    String? timeHorizon,
    RiskLevel? riskLevel,
    int? durationMonths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MissionDocument(
      id: id ?? this.id,
      missionMapId: missionMapId ?? this.missionMapId,
      strategyId: strategyId ?? this.strategyId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      mission: mission ?? this.mission,
      missionSequence: missionSequence ?? this.missionSequence,
      focus: focus ?? this.focus,
      structuralShift: structuralShift ?? this.structuralShift,
      capabilityRequired: capabilityRequired ?? this.capabilityRequired,
      riskOrValueGuardrail: riskOrValueGuardrail ?? this.riskOrValueGuardrail,
      timeHorizon: timeHorizon ?? this.timeHorizon,
      riskLevel: riskLevel ?? this.riskLevel,
      durationMonths: durationMonths ?? this.durationMonths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
