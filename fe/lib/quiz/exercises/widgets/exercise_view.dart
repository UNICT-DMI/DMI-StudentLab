import 'package:flutter/material.dart';

import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/widgets/flashcard_view.dart';
import 'package:fe/quiz/exercises/widgets/views_generic.dart';
import 'package:fe/quiz/exercises/widgets/views_logic.dart';
import 'package:fe/quiz/exercises/widgets/views_practice.dart';
import 'package:fe/quiz/exercises/widgets/views_visual.dart';

/// Dove si trova l'esercizio (serve per allegati, controllo di una riga, codice).
class ExerciseScope {
  final String department;
  final String course;
  final String subject;

  /// Controllo di una parte (es. una riga di "Traccia"). Null = non disponibile (prova controllata).
  final Future<ExerciseResult> Function(Map<String, dynamic> answer, Map<String, dynamic> scope)? checkPart;

  /// "Esegui" per il codice (solo test visibili). Null = non disponibile.
  final Future<Map<String, dynamic>> Function(String code)? runCode;

  const ExerciseScope({
    required this.department,
    required this.course,
    required this.subject,
    this.checkPart,
    this.runCode,
  });
}

/// Area di gioco dell'esercizio, scelta in base al tipo.
class ExerciseView extends StatelessWidget {
  final ExerciseItem item;
  final ExerciseScope scope;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initialAnswer;
  final AnswerChanged onChanged;

  /// Solo per le flashcard: voto dato con i pulsanti.
  final void Function(int grade)? onGrade;
  final Map<String, dynamic>? flashcardState;

  const ExerciseView({
    super.key,
    required this.item,
    required this.scope,
    required this.onChanged,
    this.result,
    this.locked = false,
    this.initialAnswer,
    this.onGrade,
    this.flashcardState,
  });

  @override
  Widget build(BuildContext context) {
    final Key key = ValueKey<String>('view-${item.id}');
    return switch (item.type) {
      'ordina' => OrdinaView(key: key, item: item, result: result, locked: locked, initial: initialAnswer, onChanged: onChanged),
      'abbina' => AbbinaView(key: key, item: item, result: result, locked: locked, initial: initialAnswer, onChanged: onChanged),
      'errore' => ErroreView(key: key, item: item, result: result, locked: locked, initial: initialAnswer, onChanged: onChanged),
      'completa' => CompletaView(key: key, item: item, result: result, locked: locked, initial: initialAnswer, onChanged: onChanged),
      'numerica' => NumericaView(key: key, item: item, result: result, locked: locked, initial: initialAnswer, onChanged: onChanged),
      'traccia' => TracciaView(key: key, item: item, result: result, locked: locked, initial: initialAnswer, onChanged: onChanged,
          checkPart: scope.checkPart),
      'codice' => CodiceView(key: key, item: item, result: result, locked: locked, initial: initialAnswer, onChanged: onChanged,
          runCode: scope.runCode),
      'diagramma' => DiagrammaView(key: key, item: item, scope: scope, result: result, locked: locked, initial: initialAnswer,
          onChanged: onChanged),
      'grafo' => GrafoView(key: key, item: item, result: result, locked: locked, initial: initialAnswer, onChanged: onChanged),
      // tipi generici (v24)
      'caso' => CasoView(key: key, item: item, result: result, locked: locked, initial: initialAnswer, onChanged: onChanged,
          checkPart: scope.checkPart),
      'vero_falso' => VeroFalsoView(key: key, item: item, result: result, locked: locked, initial: initialAnswer,
          onChanged: onChanged),
      'categorizza' => CategorizzaView(key: key, item: item, result: result, locked: locked, initial: initialAnswer,
          onChanged: onChanged),
      'linea_tempo' => LineaTempoView(key: key, item: item, result: result, locked: locked, initial: initialAnswer,
          onChanged: onChanged),
      'risposta_breve' => RispostaBreveView(key: key, item: item, result: result, locked: locked, initial: initialAnswer,
          onChanged: onChanged),
      'flashcard' => FlashcardView(key: key, item: item, locked: locked, onGrade: onGrade, state: flashcardState,
          onChanged: onChanged),
      _ => SceltaView(key: key, item: item, scope: scope, result: result, locked: locked, initial: initialAnswer,
          onChanged: onChanged),
    };
  }
}
