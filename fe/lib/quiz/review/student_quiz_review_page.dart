import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../theme/nightTheme.dart';
import '../quiz.dart';
import 'services/student_quiz_review_service.dart';

class StudentQuizReviewPage extends StatefulWidget {
  const StudentQuizReviewPage({super.key});

  @override
  State<StudentQuizReviewPage> createState() =>
      _StudentQuizReviewPageState();
}

class _StudentQuizReviewPageState
    extends State<StudentQuizReviewPage> {
  final StudentQuizReviewService _service =
      StudentQuizReviewService();
  final AuthSession _session =
      AuthSession.instance;

  Map<String, dynamic> _overall = {};
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _arguments = [];
  List<Map<String, dynamic>> _weakArguments = [];
  List<Map<String, dynamic>> _review = [];

  Map<String, dynamic>? _selectedSubject;
  String? _selectedArgument;

  bool _loading = true;
  bool _filterLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<dynamic> values =
          await Future.wait<dynamic>([
        _service.getOverall(),
        _service.getSubjects(),
        _service.getWeakArguments(),
        _service.getReview(),
      ]);

      if (!mounted) return;

      final List<Map<String, dynamic>> subjects =
          values[1] as List<Map<String, dynamic>>;

      setState(() {
        _overall =
            Map<String, dynamic>.from(values[0] as Map);
        _subjects = subjects;
        _weakArguments =
            values[2] as List<Map<String, dynamic>>;
        _review =
            values[3] as List<Map<String, dynamic>>;
        _selectedSubject =
            subjects.isEmpty ? null : subjects.first;
        _loading = false;
      });

      if (_selectedSubject != null) {
        await _loadSelectedSubject();
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _loadSelectedSubject() async {
    final Map<String, dynamic>? subject =
        _selectedSubject;

    if (subject == null) {
      return;
    }

    setState(() {
      _filterLoading = true;
      _selectedArgument = null;
    });

    final String department =
        _text(subject, 'department');
    final String course =
        _text(subject, 'course');
    final String subjectName =
        _text(subject, 'subject');

    try {
      final List<dynamic> values =
          await Future.wait<dynamic>([
        _service.getArguments(
          department: department,
          course: course,
          subject: subjectName,
        ),
        _service.getWeakArguments(
          department: department,
          course: course,
          subject: subjectName,
        ),
        _service.getReview(
          department: department,
          course: course,
          subject: subjectName,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _arguments =
            values[0] as List<Map<String, dynamic>>;
        _weakArguments =
            values[1] as List<Map<String, dynamic>>;
        _review =
            values[2] as List<Map<String, dynamic>>;
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _filterLoading = false;
        });
      }
    }
  }

  Future<void> _selectArgument(String? argument) async {
    final Map<String, dynamic>? subject =
        _selectedSubject;

    if (subject == null) {
      return;
    }

    setState(() {
      _selectedArgument = argument;
      _filterLoading = true;
    });

    try {
      final List<Map<String, dynamic>> review =
          await _service.getReview(
        department: _text(subject, 'department'),
        course: _text(subject, 'course'),
        subject: _text(subject, 'subject'),
        argument: argument,
      );

      if (!mounted) return;

      setState(() {
        _review = review;
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _filterLoading = false;
        });
      }
    }
  }

  void _trainArgument(
    Map<String, dynamic> argument,
  ) {
    final String department =
        _text(argument, 'department');
    final String course =
        _text(argument, 'course');
    final String subject =
        _text(argument, 'subject');
    final String argumentName =
        _text(argument, 'argument');

    if (department.isEmpty ||
        course.isEmpty ||
        subject.isEmpty ||
        argumentName.isEmpty ||
        argumentName == 'Senza argomento') {
      _showMessage(
        'Questo argomento non può essere utilizzato per avviare un quiz.',
      );
      return;
    }

    final int questions =
        (_toInt(argument['total_questions']) ?? 0)
            .clamp(1, 10);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(
          department: department,
          course: course,
          sub: subject,
          arguments: <String>[argumentName],
          numberOfQuestions: questions,
        ),
      ),
    );
  }

  Future<void> _openQuestion(
    Map<String, dynamic> item,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            _StudentReviewQuestionPage(data: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        title: const Text('Ripasso'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading ? null : _loadInitial,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 1000),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _ReviewErrorState(
        message: _error!,
        onRetry: _loadInitial,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildOverall(),
          const SizedBox(height: 22),
          _sectionTitle(
            'Materia',
            'Seleziona la materia su cui vuoi concentrarti.',
          ),
          const SizedBox(height: 10),
          _buildSubjectSelector(),
          const SizedBox(height: 22),
          _sectionTitle(
            'Argomenti da rafforzare',
            'StudentLab li calcola dai tuoi tentativi visibili nello storico.',
          ),
          const SizedBox(height: 10),
          if (_filterLoading)
            const LinearProgressIndicator()
          else if (_weakArguments.isEmpty)
            const _EmptyReviewCard(
              icon: Icons.verified_outlined,
              title: 'Nessuna lacuna rilevata',
              message:
                  'Non risultano argomenti sotto la soglia di attenzione.',
            )
          else
            ..._weakArguments.map(
              (Map<String, dynamic> item) =>
                  _WeakArgumentCard(
                data: item,
                onReview: () => _selectArgument(
                  _text(item, 'argument'),
                ),
                onTrain: () => _trainArgument(item),
              ),
            ),
          const SizedBox(height: 22),
          _sectionTitle(
            'Domande da rivedere',
            _selectedArgument == null
                ? 'Errori e domande lasciate senza risposta.'
                : 'Filtro: $_selectedArgument',
          ),
          if (_selectedArgument != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _filterLoading
                    ? null
                    : () => _selectArgument(null),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 17,
                ),
                label: const Text(
                  'Rimuovi filtro argomento',
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (_filterLoading)
            const LinearProgressIndicator()
          else if (_review.isEmpty)
            const _EmptyReviewCard(
              icon: Icons.task_alt_rounded,
              title: 'Nessuna domanda da rivedere',
              message:
                  'In questa selezione non risultano errori o risposte mancanti.',
            )
          else
            ..._review.map(
              (Map<String, dynamic> item) =>
                  _ReviewQuestionCard(
                data: item,
                onOpen: () => _openQuestion(item),
              ),
            ),
          if (_arguments.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionTitle(
              'Tutti gli argomenti',
              'Una panoramica della precisione registrata.',
            ),
            const SizedBox(height: 10),
            ..._arguments.map(
              (Map<String, dynamic> item) =>
                  _ArgumentSummaryCard(data: item),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final String name =
        _session.currentUser?.firstName.trim() ?? '';

    final bool guest =
        _session.isGuest;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              AppColors.adminMagenta.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color:
                  AppColors.adminMagenta.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.restart_alt_rounded,
              color: AppColors.adminMagenta,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  guest
                      ? 'Ripasso Guest'
                      : name.isEmpty
                          ? 'Il tuo Ripasso'
                          : 'Ripasso di $name',
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  guest
                      ? 'Il tuo storico resta sul dispositivo: errori, statistiche e lacune vengono calcolati dalla SQLite locale.'
                      : 'Rivedi errori reali, individua gli argomenti deboli e allenati in modo mirato.',
                  style: TextStyle(
                    color:
                        AppColors.pureWhite.withValues(alpha: 0.52),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverall() {
    final int attempts =
        _toInt(_overall['total_attempts']) ?? 0;
    final int questions =
        _toInt(_overall['total_questions']) ?? 0;
    final int wrong =
        _toInt(_overall['wrong_count']) ?? 0;
    final double accuracy =
        _toDouble(_overall['accuracy_percentage']) ?? 0;

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final int columns =
            constraints.maxWidth >= 700 ? 4 : 2;
        const double gap = 10;
        final double width =
            (constraints.maxWidth -
                    gap * (columns - 1)) /
                columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _ReviewMetric(
              width: width,
              icon: Icons.history_rounded,
              value: '$attempts',
              label: 'Quiz',
              color: AppColors.skyBlue,
            ),
            _ReviewMetric(
              width: width,
              icon: Icons.help_outline_rounded,
              value: '$questions',
              label: 'Domande',
              color: AppColors.materialSky,
            ),
            _ReviewMetric(
              width: width,
              icon: Icons.close_rounded,
              value: '$wrong',
              label: 'Errori',
              color: Colors.orangeAccent,
            ),
            _ReviewMetric(
              width: width,
              icon: Icons.insights_rounded,
              value:
                  '${accuracy.toStringAsFixed(1)}%',
              label: 'Precisione',
              color: Colors.greenAccent,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubjectSelector() {
    if (_subjects.isEmpty) {
      return const _EmptyReviewCard(
        icon: Icons.quiz_outlined,
        title: 'Nessun quiz nello storico',
        message:
            'Completa almeno un quiz visibile nello storico per iniziare a costruire il Ripasso.',
      );
    }

    return DropdownButtonFormField<Map<String, dynamic>>(
      initialValue: _selectedSubject,
      isExpanded: true,
      dropdownColor: AppColors.eleganceDeepNavy,
      decoration: InputDecoration(
        labelText: 'Materia',
        prefixIcon: const Icon(
          Icons.menu_book_outlined,
          color: AppColors.skyBlue,
        ),
        filled: true,
        fillColor: AppColors.eleganceMidnight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      items: _subjects.map(
        (Map<String, dynamic> item) {
          return DropdownMenuItem<Map<String, dynamic>>(
            value: item,
            child: Text(
              _text(item, 'subject'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.pureWhite,
              ),
            ),
          );
        },
      ).toList(),
      onChanged: _filterLoading
          ? null
          : (Map<String, dynamic>? value) async {
              if (value == null) return;

              setState(() {
                _selectedSubject = value;
              });

              await _loadSelectedSubject();
            },
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.pureWhite,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color:
                AppColors.pureWhite.withValues(alpha: 0.42),
            fontSize: 10,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  String _friendlyError(Object error) {
    final String value =
        error.toString().toLowerCase();

    if (value.contains('401') ||
        value.contains('non autenticato')) {
      return 'La sessione non è più valida. Accedi nuovamente per utilizzare il Ripasso.';
    }

    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection') ||
        value.contains('timeout') ||
        value.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    return 'Non è stato possibile caricare il Ripasso.';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _WeakArgumentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReview;
  final VoidCallback onTrain;

  const _WeakArgumentCard({
    required this.data,
    required this.onReview,
    required this.onTrain,
  });

  @override
  Widget build(BuildContext context) {
    final String argument =
        _text(data, 'argument', fallback: 'Argomento');
    final double accuracy =
        _toDouble(data['accuracy_percentage']) ?? 0;
    final int correct =
        _toInt(data['correct_count']) ?? 0;
    final int wrong =
        _toInt(data['wrong_count']) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              Colors.orangeAccent.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  argument,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${accuracy.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value:
                (accuracy / 100).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 8),
          Text(
            '$correct corrette · $wrong errate',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onReview,
                icon: const Icon(
                  Icons.visibility_outlined,
                  size: 17,
                ),
                label: const Text(
                  'Vedi errori',
                ),
              ),
              FilledButton.icon(
                onPressed: onTrain,
                icon: const Icon(
                  Icons.quiz_outlined,
                  size: 17,
                ),
                label: const Text(
                  'Allenati',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onOpen;

  const _ReviewQuestionCard({
    required this.data,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final String question =
        _text(
          data,
          'question_text',
          fallback:
              'Domanda #${_text(data, 'question_id', fallback: '?')}',
        );
    final String argument =
        _text(data, 'argument');
    final int wrong =
        _toInt(data['wrong_count']) ?? 0;
    final int unanswered =
        _toInt(data['unanswered_count']) ?? 0;
    final double accuracy =
        _toDouble(data['accuracy_percentage']) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              AppColors.adminMagenta.withValues(alpha: 0.13),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (argument.isNotEmpty)
            Text(
              argument,
              style: const TextStyle(
                color: AppColors.materialSky,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (argument.isNotEmpty)
            const SizedBox(height: 6),
          Text(
            question,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 10,
            runSpacing: 5,
            children: [
              Text(
                '$wrong errori',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 9,
                ),
              ),
              if (unanswered > 0)
                Text(
                  '$unanswered senza risposta',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                  ),
                ),
              Text(
                '${accuracy.toStringAsFixed(1)}% precisione',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(
                Icons.menu_book_outlined,
                size: 17,
              ),
              label: const Text(
                'Rivedi domanda',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentReviewQuestionPage
    extends StatelessWidget {
  final Map<String, dynamic> data;

  const _StudentReviewQuestionPage({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final String question =
        _text(data, 'question_text');
    final String correct =
        _text(data, 'correct_option_text');
    final String selected =
        _text(data, 'last_selected_option_text');
    final String formal =
        _text(data, 'formal_explanation');
    final String informal =
        _text(data, 'informal_explanation');
    final String correctExplanation =
        _text(data, 'correct_answer_explanation');
    final String selectedExplanation =
        _text(
          data,
          'last_selected_answer_explanation',
        );

    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Rivedi domanda'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ReviewDetailSection(
                  icon: Icons.help_outline_rounded,
                  title: 'Domanda',
                  child: SelectableText(
                    question,
                    style: const TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (selected.isNotEmpty)
                  _ReviewDetailSection(
                    icon: Icons.close_rounded,
                    iconColor: Colors.orangeAccent,
                    title: 'Ultima risposta',
                    child: Text(
                      selected,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (selected.isNotEmpty)
                  const SizedBox(height: 12),
                _ReviewDetailSection(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: Colors.greenAccent,
                  title: 'Risposta corretta',
                  child: Text(
                    correct.isEmpty
                        ? 'Non disponibile'
                        : correct,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                if (selectedExplanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ReviewDetailSection(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Perché la risposta scelta non va bene',
                    child: SelectableText(
                      selectedExplanation,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                if (correctExplanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ReviewDetailSection(
                    icon: Icons.lightbulb_outline_rounded,
                    iconColor: Colors.greenAccent,
                    title: 'Spiegazione della risposta corretta',
                    child: SelectableText(
                      correctExplanation,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                if (formal.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ReviewDetailSection(
                    icon: Icons.school_outlined,
                    title: 'Spiegazione formale',
                    child: SelectableText(
                      formal,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                if (informal.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ReviewDetailSection(
                    icon: Icons.auto_stories_outlined,
                    title: 'Spiegazione semplice',
                    child: SelectableText(
                      informal,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewDetailSection extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget child;

  const _ReviewDetailSection({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              AppColors.skyBlue.withValues(alpha: 0.09),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? AppColors.skyBlue,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _ArgumentSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ArgumentSummaryCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final String argument =
        _text(data, 'argument', fallback: 'Argomento');
    final double accuracy =
        _toDouble(data['accuracy_percentage']) ?? 0;
    final int total =
        _toInt(data['total_questions']) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              argument,
              style: const TextStyle(
                color: AppColors.pureWhite,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$total risposte · '
            '${accuracy.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  final double width;
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ReviewMetric({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.eleganceMidnight,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: color.withValues(alpha: 0.11),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyReviewCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.materialSky,
            size: 24,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    height: 1.4,
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

class _ReviewErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReviewErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 38,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

String _text(
  Map<String, dynamic> data,
  String key, {
  String fallback = '',
}) {
  final String value =
      data[key]?.toString().trim() ?? '';

  return value.isEmpty ? fallback : value;
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '');
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();

  return double.tryParse(value?.toString() ?? '');
}
