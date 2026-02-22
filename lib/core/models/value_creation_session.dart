import 'package:json_annotation/json_annotation.dart';

part 'value_creation_session.g.dart';

/// Represents a session of creating a refined value through the 5-phase process
@JsonSerializable(explicitToJson: true)
class ValueCreationSession {
  final String id;
  final String userId;
  final String seedValue;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int currentPhase; // 1-5 for phases, 6 for final selection
  
  // Phase 2: Clarification
  final List<String>? phase2Questions;
  final List<String>? phase2Answers;
  
  // Phase 3: Scope Narrowing
  final List<String>? phase3Questions;
  final List<String>? phase3Answers;
  final String? refinedValuePhase3;
  
  // Phase 4: Friction & Sacrifice
  final List<String>? phase4Questions;
  final List<String>? phase4Answers;
  final String? refinedValuePhase4;
  
  // Phase 5: Operationalization
  final List<String>? phase5Questions;
  final List<String>? phase5Answers;
  
  // Final: Value options
  final List<ValueOption>? finalValueOptions;
  final int? selectedOptionIndex;
  final String? customStatement; // If user edits the selected option

  ValueCreationSession({
    required this.id,
    required this.userId,
    required this.seedValue,
    required this.startedAt,
    this.completedAt,
    this.currentPhase = 1,
    this.phase2Questions,
    this.phase2Answers,
    this.phase3Questions,
    this.phase3Answers,
    this.refinedValuePhase3,
    this.phase4Questions,
    this.phase4Answers,
    this.refinedValuePhase4,
    this.phase5Questions,
    this.phase5Answers,
    this.finalValueOptions,
    this.selectedOptionIndex,
    this.customStatement,
  });

  factory ValueCreationSession.fromJson(Map<String, dynamic> json) =>
      _$ValueCreationSessionFromJson(json);

  Map<String, dynamic> toJson() => _$ValueCreationSessionToJson(this);

  ValueCreationSession copyWith({
    String? id,
    String? userId,
    String? seedValue,
    DateTime? startedAt,
    DateTime? completedAt,
    int? currentPhase,
    List<String>? phase2Questions,
    List<String>? phase2Answers,
    List<String>? phase3Questions,
    List<String>? phase3Answers,
    String? refinedValuePhase3,
    List<String>? phase4Questions,
    List<String>? phase4Answers,
    String? refinedValuePhase4,
    List<String>? phase5Questions,
    List<String>? phase5Answers,
    List<ValueOption>? finalValueOptions,
    int? selectedOptionIndex,
    String? customStatement,
  }) {
    return ValueCreationSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      seedValue: seedValue ?? this.seedValue,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      currentPhase: currentPhase ?? this.currentPhase,
      phase2Questions: phase2Questions ?? this.phase2Questions,
      phase2Answers: phase2Answers ?? this.phase2Answers,
      phase3Questions: phase3Questions ?? this.phase3Questions,
      phase3Answers: phase3Answers ?? this.phase3Answers,
      refinedValuePhase3: refinedValuePhase3 ?? this.refinedValuePhase3,
      phase4Questions: phase4Questions ?? this.phase4Questions,
      phase4Answers: phase4Answers ?? this.phase4Answers,
      refinedValuePhase4: refinedValuePhase4 ?? this.refinedValuePhase4,
      phase5Questions: phase5Questions ?? this.phase5Questions,
      phase5Answers: phase5Answers ?? this.phase5Answers,
      finalValueOptions: finalValueOptions ?? this.finalValueOptions,
      selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
      customStatement: customStatement ?? this.customStatement,
    );
  }
}

@JsonSerializable()
class ValueOption {
  final String label;
  final String statement;

  ValueOption({
    required this.label,
    required this.statement,
  });

  factory ValueOption.fromJson(Map<String, dynamic> json) =>
      _$ValueOptionFromJson(json);

  Map<String, dynamic> toJson() => _$ValueOptionToJson(this);
}
