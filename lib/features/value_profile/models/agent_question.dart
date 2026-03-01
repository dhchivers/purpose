/// Placeholder model for value profile agent questions
/// TODO: Implement full model when value profile feature is developed
class AgentQuestion {
  final String id;
  final String text;
  final String questionType;
  final String? reasoning;

  const AgentQuestion({
    required this.id,
    required this.text,
    required this.questionType,
    this.reasoning,
  });

  factory AgentQuestion.fromJson(Map<String, dynamic> json) {
    return AgentQuestion(
      id: json['id'] as String,
      text: json['text'] as String,
      questionType: json['questionType'] as String,
      reasoning: json['reasoning'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'questionType': questionType,
      'reasoning': reasoning,
    };
  }
}
