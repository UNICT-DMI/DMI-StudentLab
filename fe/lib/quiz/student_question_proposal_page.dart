import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../social/social_models.dart';
import '../theme/nightTheme.dart';
import '../services/blob_upload_service.dart';
import 'services/free_quiz_api_service.dart';
import 'services/question_moderation_service.dart';
import 'teacher/question_editor_page.dart';

class StudentQuestionProposalPage extends StatefulWidget {
  const StudentQuestionProposalPage({super.key});

  @override
  State<StudentQuestionProposalPage> createState() =>
      _StudentQuestionProposalPageState();
}

class _StudentQuestionProposalPageState
    extends State<StudentQuestionProposalPage> {
  final ApiService _apiService = ApiService();
  final QuestionModerationService _moderationService =
      QuestionModerationService();
  final FreeQuizApiService _quizApiService = FreeQuizApiService();
  final StudentLabUploadService _uploadService = StudentLabUploadService();

  List<AcademicUniversity> _universities = <AcademicUniversity>[];
  List<AcademicDepartment> _departments = <AcademicDepartment>[];
  List<AcademicCourse> _courses = <AcademicCourse>[];
  List<String> _subjects = <String>[];

  AcademicUniversity? _university;
  AcademicDepartment? _department;
  AcademicCourse? _course;
  String? _subject;

  bool _loadingUniversities = false;
  bool _loadingDepartments = false;
  bool _loadingCourses = false;
  bool _loadingSubjects = false;
  bool _working = false;

  String? _jsonPath;
  String? _jsonName;
  final Map<String, String> _jsonAttachmentPaths = <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadUniversities();
  }

  Map<String, dynamic> get _metadataBase {
    return <String, dynamic>{
      if (_university != null) 'university': _university!.name.trim(),
      if (_university != null) 'university_code': _university!.code.trim(),
      if (_department != null) 'department': _department!.name.trim(),
      if (_department != null) 'department_code': _department!.code.trim(),
      if (_course != null) 'course': _course!.name.trim(),
      if (_course != null) 'course_code': _course!.code.trim(),
      if (_subject != null) 'subject': _subject!.trim(),
      'teacher': <String>[],
      'year_of_validity': 'attuale',
    };
  }

  bool get _contextReady =>
      _university != null &&
      _department != null &&
      _course != null &&
      _subject != null &&
      _subject!.trim().isNotEmpty;

  Future<void> _loadUniversities() async {
    setState(() {
      _loadingUniversities = true;
    });
    try {
      final List<AcademicUniversity> values = await _apiService
          .getUniversities();
      if (!mounted) {
        return;
      }
      setState(() {
        _universities = values;
      });
    } catch (_) {
      _message('Non è stato possibile caricare gli atenei.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingUniversities = false;
        });
      }
    }
  }

  Future<void> _changeUniversity(AcademicUniversity? value) async {
    if (value == null) {
      return;
    }
    setState(() {
      _university = value;
      _department = null;
      _course = null;
      _subject = null;
      _departments = <AcademicDepartment>[];
      _courses = <AcademicCourse>[];
      _subjects = <String>[];
      _loadingDepartments = true;
    });
    try {
      final List<AcademicDepartment> values = await _apiService.getDepartments(
        value.code,
      );
      if (!mounted || _university?.code != value.code) {
        return;
      }
      setState(() {
        _departments = values;
      });
    } catch (_) {
      _message('Non è stato possibile caricare i dipartimenti.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingDepartments = false;
        });
      }
    }
  }

  Future<void> _changeDepartment(AcademicDepartment? value) async {
    if (value == null || _university == null) {
      return;
    }
    setState(() {
      _department = value;
      _course = null;
      _subject = null;
      _courses = <AcademicCourse>[];
      _subjects = <String>[];
      _loadingCourses = true;
    });
    try {
      final List<AcademicCourse> values = await _apiService.getCourses(
        universityCode: _university!.code,
        departmentCode: value.code,
      );
      if (!mounted || _department?.code != value.code) {
        return;
      }
      setState(() {
        _courses = values;
      });
    } catch (_) {
      _message('Non è stato possibile caricare i corsi.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingCourses = false;
        });
      }
    }
  }

  String _subjectKey(String value) {
    return value
        .trim()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  String _displaySubject(String value) {
    final String normalized = value
        .trim()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();

    if (normalized.isEmpty) {
      return normalized;
    }

    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  Future<void> _changeCourse(AcademicCourse? value) async {
    final AcademicUniversity? university = _university;
    final AcademicDepartment? department = _department;

    if (value == null || university == null || department == null) {
      return;
    }

    setState(() {
      _course = value;
      _subject = null;
      _subjects = <String>[];
      _loadingSubjects = true;
    });

    final Map<String, String> mergedSubjects = <String, String>{};
    Object? quizError;
    Object? catalogError;

    // 1. PRIMA le materie già presenti nei quiz.
    // Queste sono canoniche e hanno precedenza sul catalogo.
    try {
      final List<String> existingQuizSubjects = await _quizApiService
          .getAvailableSubjects(
            department: department.code,
            course: value.code,
          );

      for (final String subject in existingQuizSubjects) {
        final String label = _displaySubject(subject);
        final String key = _subjectKey(label);

        if (label.isNotEmpty && key.isNotEmpty) {
          mergedSubjects[key] = label;
        }
      }
    } catch (error) {
      quizError = error;
    }

    // 2. POI completiamo con tutte le materie del catalogo.
    // putIfAbsent garantisce che una materia quiz esistente vinca
    // su una voce equivalente del catalogo.
    try {
      final List<SocialSubject> catalogSubjects = await _apiService
          .getCatalogSubjects(
            universityCode: university.code,
            departmentCode: department.code,
            courseCode: value.code,
          );

      for (final SocialSubject subject in catalogSubjects) {
        final String label = _displaySubject(subject.name);
        final String key = _subjectKey(label);

        if (label.isNotEmpty && key.isNotEmpty) {
          mergedSubjects.putIfAbsent(key, () => label);
        }
      }
    } catch (error) {
      catalogError = error;
    }

    if (!mounted ||
        _course?.code != value.code ||
        _department?.code != department.code ||
        _university?.code != university.code) {
      return;
    }

    final List<String> subjects = mergedSubjects.values.toList()
      ..sort(
        (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );

    setState(() {
      _subjects = subjects;
      _loadingSubjects = false;
    });

    if (subjects.isEmpty) {
      if (quizError != null && catalogError != null) {
        _message(
          'Non è stato possibile caricare le materie dal catalogo e dai quiz.',
        );
      } else {
        _message('Non sono state trovate materie per il corso selezionato.');
      }
    } else if (catalogError != null) {
      // Utile durante il collaudo: non nascondiamo più il problema
      // del catalogo dietro alle materie JSON.
      _message(
        'Materie quiz caricate, ma il catalogo accademico non è disponibile.',
      );
    }
  }

  Future<void> _manualProposal() async {
    if (!_contextReady) {
      _message('Seleziona prima ateneo, dipartimento, corso e materia.');
      return;
    }

    final Map<String, dynamic>? draft = await Navigator.of(context)
        .push<Map<String, dynamic>>(
          MaterialPageRoute<Map<String, dynamic>>(
            builder: (_) => QuestionEditorPage.draft(
              department: _department!.code,
              course: _course!.code,
              subject: _subject!,
              metadataBase: _metadataBase,
            ),
          ),
        );

    if (!mounted || draft == null) {
      return;
    }

    final dynamic questionRaw = draft['question'];
    final dynamic uploadedRaw = draft['new_temp_attachments'];

    if (questionRaw is! Map) {
      return;
    }

    final Map<String, dynamic> question = Map<String, dynamic>.from(
      questionRaw,
    );

    final List<Map<String, dynamic>> uploaded = uploadedRaw is List
        ? uploadedRaw
              .whereType<Map>()
              .map((Map item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    setState(() {
      _working = true;
    });

    try {
      await _moderationService.createProposal(
        department: _department!.code,
        course: _course!.code,
        subject: _subject!,
        question: question,
      );
      if (!mounted) {
        return;
      }
      _message(
        'Proposta inviata. Un docente della materia o un amministratore la revisionerà.',
      );
    } catch (error) {
      try {
        await _moderationService.cleanupTemporaryAttachments(uploaded);
      } catch (_) {}
      if (mounted) {
        _message(_friendly(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _pickJson() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }
    setState(() {
      _jsonPath = result.files.first.path;
      _jsonName = result.files.first.name;
      _jsonAttachmentPaths.clear();
    });
  }

  Future<List<Map<String, dynamic>>> _readJsonQuestions() async {
    final String? path = _jsonPath;
    if (path == null) {
      throw Exception('Seleziona un file JSON.');
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(await File(path).readAsString());
    } catch (_) {
      throw Exception('Il file JSON non è valido.');
    }

    final List<dynamic> values = decoded is List
        ? decoded
        : decoded is Map
        ? <dynamic>[decoded]
        : <dynamic>[];

    if (values.isEmpty) {
      throw Exception('Il JSON deve contenere almeno una domanda.');
    }

    final List<Map<String, dynamic>> questions = <Map<String, dynamic>>[];

    for (int index = 0; index < values.length; index++) {
      final dynamic raw = values[index];

      if (raw is! Map) {
        throw Exception('La domanda ${index + 1} non è valida.');
      }

      final Map<String, dynamic> question = Map<String, dynamic>.from(raw);

      final dynamic metadataRaw = question['metadata'];

      final Map<String, dynamic> metadata = metadataRaw is Map
          ? Map<String, dynamic>.from(metadataRaw)
          : <String, dynamic>{};

      metadata.addAll(_metadataBase);

      question['metadata'] = metadata;

      questions.add(question);
    }

    return questions;
  }

  List<String> _attachmentNames(List<Map<String, dynamic>> questions) {
    final Set<String> names = <String>{};

    for (final Map<String, dynamic> question in questions) {
      final dynamic raw = question['attachments'];

      final List<dynamic> values = raw == null
          ? <dynamic>[]
          : raw is List
          ? raw
          : <dynamic>[raw];

      for (dynamic value in values) {
        if (value is Map) {
          value = value['original_name'];
        }

        final String name = value?.toString().trim() ?? '';

        if (name.isEmpty) {
          continue;
        }

        if (name.contains('/') || name.contains('\\')) {
          throw Exception('Il nome allegato "$name" non è valido.');
        }

        names.add(name);
      }
    }

    final List<String> result = names.toList()
      ..sort(
        (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );

    return result;
  }

  Future<void> _pickJsonAttachments() async {
    List<Map<String, dynamic>> questions;

    try {
      questions = await _readJsonQuestions();
    } catch (error) {
      _message(_friendly(error));
      return;
    }

    final List<String> names = _attachmentNames(questions);

    if (names.isEmpty) {
      _message('Il JSON non dichiara allegati.');
      return;
    }

    final FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const <String>[
        'png',
        'jpg',
        'jpeg',
        'webp',
        'pdf',
        'txt',
        'docx',
        'pptx',
      ],
    );

    if (result == null) {
      return;
    }

    final Map<String, String> selected = <String, String>{};

    for (final PlatformFile file in result.files) {
      if (file.path == null) {
        continue;
      }
      selected[file.name.toLowerCase()] = file.path!;
    }

    final List<String> missing = names
        .where((String name) => !selected.containsKey(name.toLowerCase()))
        .toList();

    if (missing.isNotEmpty) {
      _message('Mancano gli allegati: ${missing.join(', ')}.');
      return;
    }

    setState(() {
      _jsonAttachmentPaths
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _submitJson() async {
    if (!_contextReady) {
      _message('Seleziona prima ateneo, dipartimento, corso e materia.');
      return;
    }

    List<Map<String, dynamic>> questions;

    try {
      questions = await _readJsonQuestions();
    } catch (error) {
      _message(_friendly(error));
      return;
    }

    final List<String> declaredNames = _attachmentNames(questions);

    final List<String> missing = declaredNames
        .where(
          (String name) =>
              !_jsonAttachmentPaths.containsKey(name.toLowerCase()),
        )
        .toList();

    if (missing.isNotEmpty) {
      _message(
        'Seleziona gli allegati indicati nel JSON: ${missing.join(', ')}.',
      );
      return;
    }

    final List<Map<String, dynamic>> uploadedAll = <Map<String, dynamic>>[];

    final List<Map<String, dynamic>> proposals = <Map<String, dynamic>>[];

    setState(() {
      _working = true;
    });

    try {
      for (final Map<String, dynamic> rawQuestion in questions) {
        final Map<String, dynamic> question = Map<String, dynamic>.from(
          rawQuestion,
        );

        final dynamic rawAttachments = question['attachments'];

        final List<dynamic> names = rawAttachments == null
            ? <dynamic>[]
            : rawAttachments is List
            ? rawAttachments
            : <dynamic>[rawAttachments];

        final List<Map<String, dynamic>> uploaded = <Map<String, dynamic>>[];

        for (dynamic rawName in names) {
          if (rawName is Map) {
            rawName = rawName['original_name'];
          }

          final String name = rawName?.toString().trim() ?? '';

          if (name.isEmpty) {
            continue;
          }

          final String? path = _jsonAttachmentPaths[name.toLowerCase()];

          if (path == null) {
            throw Exception('Manca il file "$name".');
          }

          final Map<String, dynamic> attachment = await _uploadService
              .uploadQuestionAttachment(
                department: _department!.code,
                course: _course!.code,
                subject: _subject!,
                filePath: path,
              );

          uploaded.add(attachment);

          uploadedAll.add(attachment);
        }

        question['attachments'] = uploaded;

        proposals.add(<String, dynamic>{
          'department': _department!.code,
          'course': _course!.code,
          'subject': _subject!,
          'question': question,
        });
      }

      await _moderationService.createProposalBatch(proposals);

      if (!mounted) {
        return;
      }

      _message(
        '${proposals.length} ${proposals.length == 1 ? 'proposta inviata' : 'proposte inviate'} correttamente.',
      );
    } catch (error) {
      try {
        await _moderationService.cleanupTemporaryAttachments(uploadedAll);
      } catch (_) {}

      if (mounted) {
        _message(_friendly(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _showJsonFormat() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      builder: (BuildContext context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  'Formato JSON',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Il file può contenere una domanda o una lista di domande. Gli allegati sono facoltativi. Se presenti devi indicare soltanto il nome del file con estensione.',
                  style: TextStyle(color: AppColors.white70, height: 1.45),
                ),
                SizedBox(height: 16),
                _FormatRow(
                  label: 'estimed_time',
                  text: 'Tempo stimato in secondi',
                ),
                _FormatRow(
                  label: 'metadata.argoment',
                  text: 'Argomento della domanda',
                ),
                _FormatRow(label: 'text', text: 'Testo della domanda'),
                _FormatRow(label: 'option', text: 'Risposte A, B, C e D'),
                _FormatRow(
                  label: 'id_correct',
                  text: 'ID della risposta corretta',
                ),
                _FormatRow(
                  label: 'formal_explanation',
                  text: 'Spiegazione formale',
                ),
                _FormatRow(
                  label: 'informal_explanation',
                  text: 'Spiegazione semplice',
                ),
                _FormatRow(
                  label: 'question_response_explanation',
                  text: 'Spiegazione per ogni risposta',
                ),
                _FormatRow(
                  label: 'attachments',
                  text:
                      'Facoltativo: solo nomi file, per esempio ["schema.png"]',
                ),
                SizedBox(height: 18),
                SelectableText(
                  '[\n'
                  '  {\n'
                  '    "estimed_time": 30,\n'
                  '    "metadata": {\n'
                  '      "argoment": "Matrici",\n'
                  '      "teacher": [],\n'
                  '      "year_of_validity": "attuale"\n'
                  '    },\n'
                  '    "text": "Quale risposta è corretta?",\n'
                  '    "option": [\n'
                  '      {"id": "a", "text": "Risposta A"},\n'
                  '      {"id": "b", "text": "Risposta B"},\n'
                  '      {"id": "c", "text": "Risposta C"},\n'
                  '      {"id": "d", "text": "Risposta D"}\n'
                  '    ],\n'
                  '    "id_correct": "b",\n'
                  '    "formal_explanation": "...",\n'
                  '    "informal_explanation": "...",\n'
                  '    "question_response_explanation": {\n'
                  '      "a": "A è errata perché...",\n'
                  '      "b": "B è corretta perché...",\n'
                  '      "c": "C è errata perché...",\n'
                  '      "d": "D è errata perché..."\n'
                  '    },\n'
                  '    "attachments": ["schema.png"]\n'
                  '  }\n'
                  ']',
                  style: TextStyle(
                    color: AppColors.white70,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _friendly(Object error) {
    String text = error.toString();
    if (text.startsWith('Exception: ')) {
      text = text.substring(11);
    }
    return text.trim().isEmpty ? 'Operazione non riuscita.' : text.trim();
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Proponi una domanda'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                _InfoCard(),
                const SizedBox(height: 20),
                Text(
                  'Materia',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _Selector<AcademicUniversity>(
                  label: 'Ateneo',
                  value: _university,
                  items: _universities,
                  loading: _loadingUniversities,
                  itemLabel: (AcademicUniversity value) => value.name,
                  onChanged: _changeUniversity,
                ),
                const SizedBox(height: 12),
                _Selector<AcademicDepartment>(
                  label: 'Dipartimento',
                  value: _department,
                  items: _departments,
                  loading: _loadingDepartments,
                  itemLabel: (AcademicDepartment value) => value.name,
                  onChanged: _university == null ? null : _changeDepartment,
                ),
                const SizedBox(height: 12),
                _Selector<AcademicCourse>(
                  label: 'Corso',
                  value: _course,
                  items: _courses,
                  loading: _loadingCourses,
                  itemLabel: (AcademicCourse value) => value.name,
                  onChanged: _department == null ? null : _changeCourse,
                ),
                const SizedBox(height: 12),
                _Selector<String>(
                  label: 'Materia',
                  value: _subject,
                  items: _subjects,
                  loading: _loadingSubjects,
                  itemLabel: (String value) => value,
                  onChanged: _course == null
                      ? null
                      : (String? value) {
                          setState(() {
                            _subject = value;
                          });
                        },
                ),
                const SizedBox(height: 24),
                Text(
                  'Come vuoi proporla?',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.edit_note_rounded,
                  title: 'Inserisci una domanda',
                  description:
                      'Compila il form guidato con risposte, spiegazioni e allegati facoltativi.',
                  onTap: _working ? null : _manualProposal,
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.data_object_rounded,
                  title: 'Importa JSON',
                  description:
                      'Importa una o più domande. Gli allegati sono facoltativi e nel JSON si indica solo il nome del file.',
                  onTap: _working ? null : _pickJson,
                ),
                if (_jsonPath != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.eleganceDeepNavy,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _jsonName ?? 'File JSON',
                          style: TextStyle(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: _pickJsonAttachments,
                              icon: const Icon(Icons.attach_file_rounded),
                              label: const Text('Seleziona allegati'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _showJsonFormat,
                              icon: const Icon(Icons.help_outline_rounded),
                              label: const Text('Formato JSON'),
                            ),
                          ],
                        ),
                        if (_jsonAttachmentPaths.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            '${_jsonAttachmentPaths.length} allegati selezionati',
                            style: TextStyle(
                              color: AppColors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _working ? null : _submitJson,
                            icon: _working
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: const Text('Invia proposte'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _showJsonFormat,
                      icon: const Icon(Icons.help_outline_rounded),
                      label: const Text('Vedi il formato JSON'),
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

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.volunteer_activism_outlined, color: AppColors.skyBlue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'La domanda non viene pubblicata subito. Sarà revisionata da un docente verificato della materia oppure da un amministratore StudentLab.',
              style: TextStyle(
                color: AppColors.white70,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Selector<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final bool loading;
  final String Function(T value) itemLabel;
  final ValueChanged<T?>? onChanged;

  const _Selector({
    required this.label,
    required this.value,
    required this.items,
    required this.loading,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      onChanged: loading ? null : onChanged,
      items: items
          .map(
            (T item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.eleganceDeepNavy,
        border: const OutlineInputBorder(),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      dropdownColor: AppColors.eleganceDeepNavy,
      style: TextStyle(color: AppColors.pureWhite),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.eleganceDeepNavy,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.skyBlue.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: AppColors.brandNightBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.skyBlue),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppColors.white54,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.white38,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatRow extends StatelessWidget {
  final String label;
  final String text;

  const _FormatRow({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 190,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.skyBlue,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.white60, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
