import 'package:json_annotation/json_annotation.dart';
import 'package:purpose/core/models/module_type.dart';

part 'question_module.g.dart';

/// A container for related questions within a major module
/// Question modules group questions together and track completion
@JsonSerializable()
class QuestionModule {
  /// Unique identifier for the question module
  final String id;

  /// Parent module type (purpose, vision, mission, goals, objectives)
  @JsonKey(
    fromJson: _moduleTypeFromJson,
    toJson: _moduleTypeToJson,
  )
  final ModuleType parentModule;

  /// Name of the question module
  final String name;

  /// Description of what this question module covers
  final String description;

  /// Order/sequence in which this module should appear
  final int order;

  /// Total number of questions in this module
  final int totalQuestions;

  /// Whether this module is active/visible to users
  final bool isActive;

  /// Name of the measure this module assesses (e.g., "Passion Level", "Goal Clarity")
  final String? measureName;

  /// Description of what the measure represents and how it should be calculated
  final String? measureDescription;

  /// Maximum value for the measure (e.g., "10", "100%") - used in agent prompts
  final String? maxMeasureValue;

  /// Prompt/instructions for the AI agent to process this module's answers
  final String? agentPrompt;

  /// The AI agent's generated response/insights for this module
  final String? agentResponse;

  /// When this question module was created
  final DateTime createdAt;

  /// When this question module was last updated
  final DateTime updatedAt;

  const QuestionModule({
    required this.id,
    required this.parentModule,
    required this.name,
    required this.description,
    required this.order,
    required this.totalQuestions,
    this.isActive = true,
    this.measureName,
    this.measureDescription,
    this.maxMeasureValue,
    this.agentPrompt,
    this.agentResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a QuestionModule from JSON
  factory QuestionModule.fromJson(Map<String, dynamic> json) =>
      _$QuestionModuleFromJson(json);

  /// Converts QuestionModule to JSON
  Map<String, dynamic> toJson() => _$QuestionModuleToJson(this);

  /// Helper to convert ModuleType from JSON
  static ModuleType _moduleTypeFromJson(String value) =>
      ModuleType.fromString(value);

  /// Helper to convert ModuleType to JSON
  static String _moduleTypeToJson(ModuleType type) => type.value;

  /// Creates a copy with updated fields
  QuestionModule copyWith({
    String? id,
    ModuleType? parentModule,
    String? name,
    String? description,
    int? order,
    int? totalQuestions,
    bool? isActive,
    String? measureName,
    String? measureDescription,
    String? maxMeasureValue,
    String? agentPrompt,
    String? agentResponse,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuestionModule(
      id: id ?? this.id,
      parentModule: parentModule ?? this.parentModule,
      name: name ?? this.name,
      description: description ?? this.description,
      order: order ?? this.order,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      isActive: isActive ?? this.isActive,
      measureName: measureName ?? this.measureName,
      measureDescription: measureDescription ?? this.measureDescription,
      maxMeasureValue: maxMeasureValue ?? this.maxMeasureValue,
      agentPrompt: agentPrompt ?? this.agentPrompt,
      agentResponse: agentResponse ?? this.agentResponse,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
