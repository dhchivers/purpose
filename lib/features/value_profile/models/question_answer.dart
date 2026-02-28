import 'package:json_annotation/json_annotation.dart';
import 'package:purpose/features/value_profile/models/agent_question.dart';

part 'question_answer.g.dart';

/// Represents a user's answer to an agent question
@JsonSerializable()
class QuestionAnswer {
  /// Reference to the question ID
  final String questionId;

  /// The full question text (for history display)
  final String questionText;

  /// Type of question that was asked
  final QuestionType questionType;

  /// The option text that was selected
  final String selectedOption;

  /// Index of the selected option (0-based)
  final int optionIndex;

  /// When the question was answered
  final DateTime answeredAt;

  /// Preference weights before this answer
  final Map<String, double> weightsBefore;

  /// Preference weights after this answer
  final Map<String, double> weightsAfter;

  /// Monetary factors before this answer
  final Map<String, double> monetaryBefore;

  /// Monetary factors after this answer
  final Map<String, double> monetaryAfter;

  /// Stability score at the time of this answer
  final double stabilityAtAnswer;

  /// AI-generated explanation of how this answer affected values
  final String? explanation;

  QuestionAnswer({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.selectedOption,
    required this.optionIndex,
    required this.answeredAt,
    required this.weightsBefore,
    required this.weightsAfter,
    required this.monetaryBefore,
    required this.monetaryAfter,
    this.stabilityAtAnswer = 0.0,
    this.explanation,
  });

  /// Calculate the change in weight for a specific preference
  double getWeightChange(String preferenceName) {
    final before = weightsBefore[preferenceName] ?? 0.0;
    final after = weightsAfter[preferenceName] ?? 0.0;
    return after - before;
  }

  /// Calculate the change in monetary factor for a specific preference
  double getMonetaryChange(String preferenceName) {
    final before = monetaryBefore[preferenceName] ?? 0.0;
    final after = monetaryAfter[preferenceName] ?? 0.0;
    return after - before;
  }

  /// Get preferences that were significantly affected (>5% change in weight)
  List<String> getAffectedPreferences() {
    final affected = <String>[];
    for (final key in weightsAfter.keys) {
      if (getWeightChange(key).abs() > 0.05) {
        affected.add(key);
      }
    }
    return affected;
  }

  /// Create a copy with updated fields
  QuestionAnswer copyWith({
    String? questionId,
    String? questionText,
    QuestionType? questionType,
    String? selectedOption,
    int? optionIndex,
    DateTime? answeredAt,
    Map<String, double>? weightsBefore,
    Map<String, double>? weightsAfter,
    Map<String, double>? monetaryBefore,
    Map<String, double>? monetaryAfter,
    double? stabilityAtAnswer,
    String? explanation,
  }) {
    return QuestionAnswer(
      questionId: questionId ?? this.questionId,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      selectedOption: selectedOption ?? this.selectedOption,
      optionIndex: optionIndex ?? this.optionIndex,
      answeredAt: answeredAt ?? this.answeredAt,
      weightsBefore: weightsBefore ?? this.weightsBefore,
      weightsAfter: weightsAfter ?? this.weightsAfter,
      monetaryBefore: monetaryBefore ?? this.monetaryBefore,
      monetaryAfter: monetaryAfter ?? this.monetaryAfter,
      stabilityAtAnswer: stabilityAtAnswer ?? this.stabilityAtAnswer,
      explanation: explanation ?? this.explanation,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$QuestionAnswerToJson(this);

  /// Create from JSON
  factory QuestionAnswer.fromJson(Map<String, dynamic> json) =>
      _$QuestionAnswerFromJson(json);

  @override
  String toString() => 'QuestionAnswer(questionId: $questionId, '
      'selected: $selectedOption, stability: $stabilityAtAnswer)';
}
