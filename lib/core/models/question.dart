import 'package:json_annotation/json_annotation.dart';

part 'question.g.dart';

/// Type of question that determines the input method
enum QuestionType {
  shortText('short_text'),
  longText('long_text'),
  multipleChoice('multiple_choice'),
  scale('scale'),
  yesNo('yes_no');

  final String value;
  const QuestionType(this.value);

  static QuestionType fromString(String value) {
    return QuestionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => QuestionType.shortText,
    );
  }
}

/// Individual question within a question module
@JsonSerializable()
class Question {
  /// Unique identifier for the question
  final String id;

  /// ID of the parent question module
  final String questionModuleId;

  /// The question text to display to the user
  final String questionText;

  /// Optional helper text or additional context
  final String? helperText;

  /// Type of question (determines input method)
  @JsonKey(
    fromJson: _questionTypeFromJson,
    toJson: _questionTypeToJson,
  )
  final QuestionType questionType;

  /// Options for multiple choice questions (null for other types)
  final List<String>? options;

  /// Whether multiple selections are allowed for multiple choice questions
  /// true = checkboxes (multiple selections), false = radio buttons (single selection)
  final bool? allowMultipleSelections;

  /// Minimum value for scale questions (null for other types)
  final int? scaleMin;

  /// Maximum value for scale questions (null for other types)
  final int? scaleMax;

  /// Labels for scale endpoints (e.g., ["Not at all", "Extremely"])
  final List<String>? scaleLabels;

  /// Maximum character limit for text answers (null means no limit)
  final int? answerCharacterLimit;

  /// Order/sequence within the question module
  final int order;

  /// Whether this question is required
  final bool isRequired;

  /// Whether this question is currently active
  final bool isActive;

  /// Prompt template for AI agent when this question is answered
  /// Can include placeholders like {answer} to be replaced with user's answer
  final String? aiPromptTemplate;

  /// When this question was created
  final DateTime createdAt;

  /// When this question was last updated
  final DateTime updatedAt;

  const Question({
    required this.id,
    required this.questionModuleId,
    required this.questionText,
    this.helperText,
    required this.questionType,
    this.options,
    this.allowMultipleSelections,
    this.scaleMin,
    this.scaleMax,
    this.scaleLabels,
    this.answerCharacterLimit,
    required this.order,
    this.isRequired = true,
    this.isActive = true,
    this.aiPromptTemplate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a Question from JSON
  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);

  /// Converts Question to JSON
  Map<String, dynamic> toJson() => _$QuestionToJson(this);

  /// Helper to convert QuestionType from JSON
  static QuestionType _questionTypeFromJson(String value) =>
      QuestionType.fromString(value);

  /// Helper to convert QuestionType to JSON
  static String _questionTypeToJson(QuestionType type) => type.value;

  /// Creates a copy with updated fields
  Question copyWith({
    String? id,
    String? questionModuleId,
    String? questionText,
    String? helperText,
    QuestionType? questionType,
    List<String>? options,
    bool? allowMultipleSelections,
    int? scaleMin,
    int? scaleMax,
    List<String>? scaleLabels,
    int? answerCharacterLimit,
    int? order,
    bool? isRequired,
    bool? isActive,
    String? aiPromptTemplate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Question(
      id: id ?? this.id,
      questionModuleId: questionModuleId ?? this.questionModuleId,
      questionText: questionText ?? this.questionText,
      helperText: helperText ?? this.helperText,
      questionType: questionType ?? this.questionType,
      options: options ?? this.options,
      allowMultipleSelections: allowMultipleSelections ?? this.allowMultipleSelections,
      scaleMin: scaleMin ?? this.scaleMin,
      scaleMax: scaleMax ?? this.scaleMax,
      scaleLabels: scaleLabels ?? this.scaleLabels,
      answerCharacterLimit: answerCharacterLimit ?? this.answerCharacterLimit,
      order: order ?? this.order,
      isRequired: isRequired ?? this.isRequired,
      isActive: isActive ?? this.isActive,
      aiPromptTemplate: aiPromptTemplate ?? this.aiPromptTemplate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
