import 'package:flutter/material.dart';
import 'package:fe/theme/nightTheme.dart';




class QuizQuestionResult {
  final String question;

  final String givenAnswer;

  final String correctAnswer;

  final String formalExplanation;

  final String informalExplanation;

  final String questionResponseExplanation;

  final Map<String, String> answerExplanations;

  final bool isCorrect;

  const QuizQuestionResult({
    required this.question,
    required this.givenAnswer,
    required this.correctAnswer,
    required this.formalExplanation,
    required this.informalExplanation,
    required this.questionResponseExplanation,
    required this.answerExplanations,
    required this.isCorrect,
  });
}



class QuizResultLayer extends StatelessWidget {
  final List<QuizQuestionResult> results;

  const QuizResultLayer({
    super.key,
    required this.results,
  });


 
  int get correctAnswers {
    return results
        .where((question) => question.isCorrect)
        .length;
  }


 
  int get wrongAnswers {
    return results.length - correctAnswers;
  }


  double get percentage {
    if (results.isEmpty) {
      return 0;
    }

    return (correctAnswers / results.length) * 100;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.eleganceMidnight,
        foregroundColor: AppColors.pearlWhite,
        elevation: AppColors.nightAppBarTheme.elevation,
        centerTitle: AppColors.nightAppBarTheme.centerTitle,

        title: const Text(
          'Risultato Quiz',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 20,
          ),
        ),
      ),

      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {

              // Su desktop limitiamo la larghezza.
              // Su Android/iOS occupiamo invece tutta la larghezza disponibile.
              final bool isLargeScreen =
                  constraints.maxWidth > 700;

              final double contentWidth =
                  isLargeScreen
                      ? 650
                      : constraints.maxWidth;

              return SizedBox(
                width: contentWidth,

                child: ListView(
                  padding: const EdgeInsets.all(16),

                  children: [


                    _buildScoreCard(context),

                    const SizedBox(height: 16),

                    _buildSummaryCard(context),

                    const SizedBox(height: 28),


                    const Text(
                      'Riepilogo delle domande',
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),


                    if (results.isEmpty)
                      _buildEmptyResult()
                    else
                      ...List.generate(
                        results.length,
                        (index) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 16,
                            ),

                            child: _QuestionResultCard(
                              questionNumber: index + 1,
                              result: results[index],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }



  Widget _buildScoreCard(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        children: [

          const Text(
            'Punteggio',
            style: TextStyle(
              color: AppColors.pearlWhite,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '$correctAnswers / ${results.length}',

            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 38,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '${percentage.toStringAsFixed(0)}%',

            style: const TextStyle(
              color: AppColors.skyBlue,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _getResultMessage(),

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.pureWhite
                  .withOpacity(0.65),

              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }



  String _getResultMessage() {
    if (results.isEmpty) {
      return 'Nessuna domanda completata.';
    }

    if (percentage >= 90) {
      return 'Ottimo lavoro! Preparazione eccellente.';
    }

    if (percentage >= 70) {
      return 'Molto bene! Continua così.';
    }

    if (percentage >= 50) {
      return 'Buon risultato, ma puoi ancora migliorare.';
    }

    return 'Continua ad allenarti e riprova.';
  }


  Widget _buildSummaryCard(BuildContext context) {
    return Row(
      children: [

        Expanded(
          child: _SummaryItem(
            icon: Icons.check_circle,
            value: correctAnswers.toString(),
            label: 'Corrette',
            color: Colors.green,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _SummaryItem(
            icon: Icons.cancel,
            value: wrongAnswers.toString(),
            label: 'Errate',
            color: Colors.redAccent,
          ),
        ),
      ],
    );
  }


  Widget _buildEmptyResult() {
    return Container(
      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
      ),

      child: const Center(
        child: Text(
          'Non ci sono risultati da mostrare.',
          textAlign: TextAlign.center,

          style: TextStyle(
            color: AppColors.pearlWhite,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}



class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: color.withOpacity(0.20),
        ),
      ),

      child: Row(
        children: [

          Icon(
            icon,
            color: color,
            size: 28,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  value,

                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  label,

                  style: TextStyle(
                    color: AppColors.pureWhite
                        .withOpacity(0.65),

                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class _QuestionResultCard extends StatelessWidget {
  final int questionNumber;
  final QuizQuestionResult result;

  const _QuestionResultCard({
    required this.questionNumber,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {

    // Colore principale della domanda.
    final Color statusColor =
        result.isCorrect
            ? Colors.green
            : Colors.redAccent;


    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        // Manteniamo il colore principale del tema.
        color: AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(18),

        // Il bordo identifica immediatamente
        // se la domanda è corretta o errata.
        border: Border.all(
          color: statusColor.withOpacity(0.45),
          width: 1.2,
        ),

        // Leggerissimo alone del colore dello stato.
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,

              children: [

                Expanded(
                  child: Text(
                    'Domanda $questionNumber',

                    style: const TextStyle(
                      color: AppColors.pearlWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                _StatusBadge(
                  isCorrect:
                      result.isCorrect,
                ),
              ],
            ),

            const SizedBox(height: 16),


            Text(
              result.question,

              style: const TextStyle(
                color: AppColors.pureWhite,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),


            _AnswerBox(
              title: 'La tua risposta',
              answer: result.givenAnswer,

              color: result.isCorrect
                  ? Colors.green
                  : Colors.redAccent,
            ),


            if (!result.isCorrect) ...[
              const SizedBox(height: 10),

              _AnswerBox(
                title: 'Risposta corretta',
                answer: result.correctAnswer,
                color: Colors.green,
              ),
            ],

            _buildExplanations(),
          ],
        ),
      ),
    );
  }


  Widget _buildExplanations() {

    final bool hasFormal =
        result.formalExplanation.isNotEmpty;

    final bool hasInformal =
        result.informalExplanation.isNotEmpty;

    final bool hasResponse =
        result.questionResponseExplanation.isNotEmpty;

    final bool hasAnswers =
        result.answerExplanations.isNotEmpty;

    if (!hasFormal &&
        !hasInformal &&
        !hasResponse &&
        !hasAnswers) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        const SizedBox(height: 20),

        const Text(
          'Spiegazione',

          style: TextStyle(
            color: AppColors.pearlWhite,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),


        if (hasFormal)
          _ExplanationSection(
            title: 'Definizione formale',
            text: result.formalExplanation,
          ),


        if (hasInformal)
          _ExplanationSection(
            title: 'Definizione informale',
            text: result.informalExplanation,
          ),


        if (hasResponse)
          _ExplanationSection(
            title: 'Capire la risposta',
            text:
                result.questionResponseExplanation,
          ),



        if (hasAnswers) ...[
          const SizedBox(height: 8),

          const Text(
            'Analisi delle risposte',

            style: TextStyle(
              color: AppColors.pearlWhite,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          ...result.answerExplanations.entries.map(
            (entry) {
              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 8,
                ),

                child: Container(
                  width: double.infinity,

                  padding:
                      const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: AppColors.darkElegance
                        .withOpacity(0.45),

                    borderRadius:
                        BorderRadius.circular(10),
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Text(
                        entry.key,

                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,

                          fontWeight:
                              FontWeight.bold,

                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        entry.value,

                        style: TextStyle(
                          color: AppColors
                              .pureWhite
                              .withOpacity(0.65),

                          fontSize: 12,

                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}


class _StatusBadge extends StatelessWidget {
  final bool isCorrect;

  const _StatusBadge({
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {

    final Color color =
        isCorrect
            ? Colors.green
            : Colors.redAccent;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),

      decoration: BoxDecoration(
        color: color.withOpacity(0.15),

        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(
            isCorrect
                ? Icons.check_circle
                : Icons.cancel,

            size: 16,

            color: color,
          ),

          const SizedBox(width: 5),

          Text(
            isCorrect
                ? 'Corretta'
                : 'Errata',

            style: TextStyle(
              color: color,

              fontSize: 12,

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerBox extends StatelessWidget {
  final String title;
  final String answer;
  final Color color;

  const _AnswerBox({
    required this.title,
    required this.answer,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: color.withOpacity(0.10),

        borderRadius:
            BorderRadius.circular(10),

        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Text(
            title,

            style: TextStyle(
              color: color,

              fontSize: 12,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            answer,

            style: const TextStyle(
              color: AppColors.pureWhite,

              fontSize: 13,

              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}



class _ExplanationSection extends StatelessWidget {
  final String title;
  final String text;

  const _ExplanationSection({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 14),

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(
          color: AppColors.darkElegance
              .withOpacity(0.45),

          borderRadius:
              BorderRadius.circular(10),
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Text(
              title,

              style: const TextStyle(
                color: AppColors.pearlWhite,

                fontSize: 12,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              text,

              style: TextStyle(
                color: AppColors.pureWhite
                    .withOpacity(0.70),

                fontSize: 13,

                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}