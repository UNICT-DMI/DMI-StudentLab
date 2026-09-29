class QuizModel {
  final String idQuestion;
  final String idCorrect;
  final String text;
  final List<Option> option;
  final Map<String, dynamic> metadata;
  final List<Map<String, dynamic>> attachments;
  final String formalExplanation;
  final String informalExplanation;
  final String questionResponseExplanation;

  QuizModel({
    required this.idQuestion,
    required this.idCorrect,
    required this.text,
    required this.option,
    required this.metadata,
    required this.attachments,
    required this.formalExplanation,
    required this.informalExplanation,
    required this.questionResponseExplanation,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawOptions = json['option'];

    final List<Option> optionList = rawOptions is List
        ? rawOptions
              .whereType<Map>()
              .map(
                (Map item) => Option.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <Option>[];

    final dynamic rawMetadata = json['metadata'];

    final Map<String, dynamic> metadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : <String, dynamic>{};

    final dynamic rawAttachments = json['attachments'];

    final List<Map<String, dynamic>> attachments = rawAttachments is List
        ? rawAttachments
              .whereType<Map>()
              .map((Map item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    final dynamic rawResponseExplanation =
        json['question_response_explanation'];

    final String responseExplanation = rawResponseExplanation is Map
        ? rawResponseExplanation.values
              .map((dynamic value) => value?.toString().trim() ?? '')
              .where((String value) => value.isNotEmpty)
              .toSet()
              .join('\n\n')
        : rawResponseExplanation?.toString() ?? '';

    return QuizModel(
      idQuestion: json['id_question']?.toString() ?? '',
      idCorrect: json['id_correct']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      option: optionList,
      metadata: metadata,
      attachments: attachments,
      formalExplanation: json['formal_explanation']?.toString() ?? '',
      informalExplanation: json['informal_explanation']?.toString() ?? '',
      questionResponseExplanation: responseExplanation,
    );
  }
}

class Option {
  final String id;
  final String text;

  Option({required this.id, required this.text});

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}
