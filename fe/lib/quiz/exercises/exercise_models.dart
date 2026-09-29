import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';

/// Tipi di esercizio che questa versione dell'app sa mostrare.
/// Si manda al server all'avvio di un'assegnazione (supported_types): le app
/// vecchie non lo mandano e ricevono solo domande a risposta multipla.
const List<String> kExerciseTypes = <String>[
  'scelta',
  'ordina',
  'abbina',
  'completa',
  'errore',
  'diagramma',
  'grafo',
  'flashcard',
  'traccia',
  'numerica',
  'codice',
  // tipi generici (v24): vanno bene per ogni corso
  'caso',
  'vero_falso',
  'categorizza',
  'linea_tempo',
  'risposta_breve',
];

const String kMultipleChoice = 'multiple_choice';

class ExerciseTypeInfo {
  final String type;
  final String label;
  final String category;
  final IconData icon;
  final String purpose;

  const ExerciseTypeInfo(this.type, this.label, this.category, this.icon, this.purpose);
}

const Map<String, ExerciseTypeInfo> kExerciseTypeInfo = <String, ExerciseTypeInfo>{
  'multiple_choice': ExerciseTypeInfo('multiple_choice', 'Risposta multipla', 'pratica', Icons.quiz_outlined,
      'Le domande dei quiz di sempre'),
  'scelta': ExerciseTypeInfo('scelta', 'Scelta con allegati', 'pratica', Icons.attach_file_rounded,
      'Domanda con immagini o file e una o più risposte giuste'),
  'ordina': ExerciseTypeInfo('ordina', 'Ordina i passaggi', 'logico', Icons.format_list_numbered_rounded,
      'Algoritmi, procedure, dimostrazioni'),
  'abbina': ExerciseTypeInfo('abbina', 'Abbina', 'logico', Icons.compare_arrows_rounded,
      'Termini e definizioni, protocolli e livelli'),
  'completa': ExerciseTypeInfo('completa', 'Completa gli spazi', 'pratica', Icons.short_text_rounded,
      'Formule, definizioni, codice'),
  'errore': ExerciseTypeInfo('errore', 'Trova l’errore', 'logico', Icons.bug_report_outlined,
      'Codice, dimostrazioni, calcoli'),
  'diagramma': ExerciseTypeInfo('diagramma', 'Tocca sul diagramma', 'visivo', Icons.touch_app_outlined,
      'Reti, architetture, circuiti, grafici'),
  'grafo': ExerciseTypeInfo('grafo', 'Grafo interattivo', 'strategia', Icons.hub_outlined,
      'Dijkstra, BFS, DFS'),
  'flashcard': ExerciseTypeInfo('flashcard', 'Flashcard', 'memoria', Icons.style_outlined,
      'Termini del Dizionario, ripetizione dilazionata'),
  'traccia': ExerciseTypeInfo('traccia', 'Traccia l’algoritmo', 'strategia', Icons.table_rows_outlined,
      'Stati TCP, scheduling, ordinamenti'),
  'numerica': ExerciseTypeInfo('numerica', 'Risposta numerica', 'pratica', Icons.calculate_outlined,
      'Subnetting, conversioni, calcoli'),
  'codice': ExerciseTypeInfo('codice', 'Scrivi il codice', 'pratica', Icons.code_rounded,
      'Programmazione con test automatici'),
  'caso': ExerciseTypeInfo('caso', 'Caso pratico a passi', 'ragionamento', Icons.work_outline_rounded,
      'Casi clinici, giuridici, aziendali, didattici: un passo alla volta'),
  'vero_falso': ExerciseTypeInfo('vero_falso', 'Vero o falso motivato', 'logico', Icons.rule_rounded,
      'Norme, teoremi, principi: il verdetto e il perché'),
  'categorizza': ExerciseTypeInfo('categorizza', 'Categorizza', 'logico', Icons.category_outlined,
      'Classificazioni: organismi, istituti, farmaci, stili'),
  'linea_tempo': ExerciseTypeInfo('linea_tempo', 'Linea del tempo', 'logico', Icons.timeline_rounded,
      'Storia, fasi di un processo, ere, correnti'),
  'risposta_breve': ExerciseTypeInfo('risposta_breve', 'Risposta breve con griglia', 'ragionamento',
      Icons.edit_note_rounded, 'Spiegare in poche righe, con la griglia del docente'),
};

ExerciseTypeInfo exerciseInfo(String type) =>
    kExerciseTypeInfo[type] ?? ExerciseTypeInfo(type, type, 'pratica', Icons.extension_outlined, '');

/// Colore della categoria. Si distinguono anche per l'icona, mai solo per il colore.
Color categoryColor(BuildContext context, String category) {
  final p = context.palette;
  return switch (category) {
    'logico' => p.skyBlue,
    'visivo' => p.adminAmber,
    'strategia' => const Color(0xFFA9A8FF),
    'memoria' => const Color(0xFFF08CFF),
    'ragionamento' => p.adminCyan,
    _ => p.adminGreen,
  };
}

String categoryLabel(String category) => switch (category) {
      'logico' => 'LOGICO',
      'visivo' => 'VISIVO',
      'strategia' => 'STRATEGIA',
      'memoria' => 'MEMORIA',
      'ragionamento' => 'RAGIONAMENTO',
      _ => 'PRATICA',
    };

Map<String, dynamic> asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(dynamic value) =>
    (value is List ? value : const <dynamic>[]).whereType<Map>().map((Map e) => Map<String, dynamic>.from(e)).toList();

List<String> asStringList(dynamic value) =>
    (value is List ? value : const <dynamic>[]).map((dynamic e) => e.toString()).toList();

/// Filtri della scelta degli esercizi (passo 1). Viaggiano uguali verso
/// /exercises/overview, /exercises/practice e /exercises/start.
class ExerciseChoice {
  final List<String> arguments;
  final int? maxSeconds;                 // durata massima di un esercizio
  final bool onlyNew;
  final bool onlyMistakes;

  const ExerciseChoice({
    this.arguments = const <String>[],
    this.maxSeconds,
    this.onlyNew = false,
    this.onlyMistakes = false,
  });

  ExerciseChoice copyWith({
    List<String>? arguments,
    int? maxSeconds,
    bool clearMaxSeconds = false,
    bool? onlyNew,
    bool? onlyMistakes,
  }) =>
      ExerciseChoice(
        arguments: arguments ?? this.arguments,
        maxSeconds: clearMaxSeconds ? null : (maxSeconds ?? this.maxSeconds),
        onlyNew: onlyNew ?? this.onlyNew,
        onlyMistakes: onlyMistakes ?? this.onlyMistakes,
      );

  bool get isEmpty => arguments.isEmpty && maxSeconds == null && !onlyNew && !onlyMistakes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'arguments': arguments,
        if (maxSeconds != null) 'max_seconds': maxSeconds,
        'only_new': onlyNew,
        'only_mistakes': onlyMistakes,
      };

  /// Riassunto breve per l'intestazione del passo 2 ("3 argomenti · ≤ 1 min").
  List<String> get summary => <String>[
        if (arguments.isNotEmpty) arguments.length == 1 ? arguments.first : '${arguments.length} argomenti',
        if (maxSeconds != null) '≤ ${formatSeconds(maxSeconds!)}',
        if (onlyNew) 'solo nuovi',
        if (onlyMistakes) 'solo da rivedere',
      ];
}

String formatSeconds(int seconds) =>
    seconds < 60 ? '$seconds s' : (seconds % 60 == 0 ? '${seconds ~/ 60} min' : '${(seconds / 60).toStringAsFixed(1)} min');

/// Un esercizio come lo manda il server (senza soluzione). Vale anche per le
/// domande a risposta multipla di un'assegnazione mista (type = multiple_choice).
class ExerciseItem {
  final String id;
  final String type;
  final String text;
  final String hint;
  final String? argument;
  final int estimatedSeconds;
  final int difficulty;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic> data;
  final String? source;

  /// Solo nei tentativi salvati: {tries, final, answer?, result?} per riprendere.
  final Map<String, dynamic> check;

  const ExerciseItem({
    required this.id,
    required this.type,
    required this.text,
    required this.hint,
    required this.argument,
    required this.estimatedSeconds,
    required this.difficulty,
    required this.attachments,
    required this.data,
    this.source,
    this.check = const <String, dynamic>{},
  });

  bool get isMultipleChoice => type == kMultipleChoice;
  ExerciseTypeInfo get info => exerciseInfo(type);

  factory ExerciseItem.fromJson(Map<String, dynamic> json) {
    final String rawType = json['type']?.toString() ?? '';
    final bool mc = rawType.isEmpty || rawType == kMultipleChoice;
    final Map<String, dynamic> metadata = asMap(json['metadata']);
    return ExerciseItem(
      id: (json['id'] ?? json['id_question'] ?? '').toString(),
      type: mc ? kMultipleChoice : rawType,
      text: json['text']?.toString() ?? '',
      hint: json['hint']?.toString() ?? '',
      argument: (json['argument'] ?? metadata['argoment'])?.toString(),
      estimatedSeconds: int.tryParse('${json['estimed_time'] ?? ''}') ?? 60,
      difficulty: int.tryParse('${json['difficulty'] ?? ''}') ?? 2,
      attachments: asMapList(json['attachments']),
      // Per la risposta multipla le opzioni arrivano in "option".
      data: mc ? <String, dynamic>{'options': asMapList(json['option']), 'multiple': false} : asMap(json['data']),
      source: json['source']?.toString(),
      check: asMap(json['check']),
    );
  }
}

/// Esito della correzione (dal server).
class ExerciseResult {
  final bool isCorrect;
  final double score;
  final Map<String, dynamic> feedback;
  final Map<String, dynamic>? solution;
  final String explanation;
  final String solutionText;

  const ExerciseResult({
    required this.isCorrect,
    required this.score,
    required this.feedback,
    required this.solution,
    required this.explanation,
    required this.solutionText,
  });

  bool get isPartial => !isCorrect && score > 0;

  factory ExerciseResult.fromJson(Map<String, dynamic> json) => ExerciseResult(
        isCorrect: json['is_correct'] == true,
        score: (json['score'] as num?)?.toDouble() ?? 0,
        feedback: asMap(json['feedback']),
        solution: json['correct_payload'] is Map ? asMap(json['correct_payload']) : null,
        explanation: json['explanation']?.toString() ?? '',
        solutionText: json['solution_text']?.toString() ?? '',
      );
}

/// Contratto comune dei widget di ogni tipo.
typedef AnswerChanged = void Function(Map<String, dynamic> answer, bool complete);
