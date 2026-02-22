import 'package:json_annotation/json_annotation.dart';

part 'user_answer.g.dart';

/// User's answer to a specific question
@JsonSerializable()
class UserAnswer {
  /// Unique identifier for this answer
  final String id;

  /// ID of the user who provided this answer
  final String userId;

  /// ID of the question being answered
  final String questionId;

  /// ID of the question module (for easier querying)
  final String questionModuleId;

  /// The user's text answer (for text-based questions)
  final String? textAnswer;

  /// The user's numeric answer (for scale questions)
  final int? numericAnswer;

  /// The user's selected option (for multiple choice)
  final String? selectedOption;

  /// The user's boolean answer (for yes/no questions)
  final bool? booleanAnswer;

  /// Additional notes or context provided by the user
  final String? notes;

  /// Whether this answer has been processed by the AI agent
  final bool processedByAI;

  /// AI agent's response or insights based on this answer
  final String? aiResponse;

  /// When this answer was first created
  final DateTime createdAt;

  /// When this answer was last updated
  final DateTime updatedAt;

  const UserAnswer({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.questionModuleId,
    this.textAnswer,
    this.numericAnswer,
    this.selectedOption,
    this.booleanAnswer,
    this.notes,
    this.processedByAI = false,
    this.aiResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a UserAnswer from JSON
  factory UserAnswer.fromJson(Map<String, dynamic> json) =>
      _$UserAnswerFromJson(json);

  /// Converts UserAnswer to JSON
  Map<String, dynamic> toJson() => _$UserAnswerToJson(this);

  /// Get the primary answer value regardless of type
  dynamic get answer {
    if (textAnswer != null) return textAnswer;
    if (numericAnswer != null) return numericAnswer;
    if (selectedOption != null) return selectedOption;
    if (booleanAnswer != null) return booleanAnswer;
    return null;
  }

  /// Check if this answer has any value
  bool get hasAnswer => answer != null;

  /// Creates a copy with updated fields
  UserAnswer copyWith({
    String? id,
    String? userId,
    String? questionId,
    String? questionModuleId,
    String? textAnswer,
    int? numericAnswer,
    String? selectedOption,
    bool? booleanAnswer,
    String? notes,
    bool? processedByAI,
    String? aiResponse,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAnswer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      questionId: questionId ?? this.questionId,
      questionModuleId: questionModuleId ?? this.questionModuleId,
      textAnswer: textAnswer ?? this.textAnswer,
      numericAnswer: numericAnswer ?? this.numericAnswer,
      selectedOption: selectedOption ?? this.selectedOption,
      booleanAnswer: booleanAnswer ?? this.booleanAnswer,
      notes: notes ?? this.notes,
      processedByAI: processedByAI ?? this.processedByAI,
      aiResponse: aiResponse ?? this.aiResponse,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
