import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../services/public_news_api_service.dart';
import '../../theme/nightTheme.dart';
import '../social_models.dart';

enum PublicNewsPublisherMode { teacher, admin }
enum PublicNewsTargetType { all, university, department, course, subject }

class PublicNewsEditorPage extends StatefulWidget {
  final PublicNewsPublisherMode mode;
  final List<Map<String, dynamic>> subjects;

  const PublicNewsEditorPage.teacher({
    super.key,
    required this.subjects,
  }) : mode = PublicNewsPublisherMode.teacher;

  const PublicNewsEditorPage.admin({
    super.key,
    this.subjects = const [],
  }) : mode = PublicNewsPublisherMode.admin;

  @override
  State<PublicNewsEditorPage> createState() => _PublicNewsEditorPageState();
}

class _PublicNewsEditorPageState extends State<PublicNewsEditorPage> {
  final ApiService _apiService = ApiService();
  final PublicNewsApiService _newsApi = PublicNewsApiService();
  final AuthSession _session = AuthSession.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();

  PublicNewsTargetType _targetType = PublicNewsTargetType.subject;
  List<Map<String, dynamic>> _subjects = [];
  int? _subjectId;
  bool _loadingContext = true;
  bool _sending = false;
  String? _error;

  bool get _isAdmin => widget.mode == PublicNewsPublisherMode.admin;

  @override
  void initState() {
    super.initState();
    _subjects = _normalizeSubjects(widget.subjects);
    _targetType = _isAdmin ? PublicNewsTargetType.all : PublicNewsTargetType.subject;
    _prefillFromUser();
    _loadContext();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _cityController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    _courseController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  void _prefillFromUser() {
    final SocialUser? user = _session.currentUser;
    if (user == null) return;

    _universityController.text = user.university.trim();
    _departmentController.text = user.department.trim();
    _courseController.text = user.course.trim();
  }

  Future<void> _loadContext() async {
    try {
      if (!_isAdmin && _subjects.isEmpty) {
        _subjects = _normalizeSubjects(await _apiService.getTeacherSubjects());
      }

      if (_subjects.length == 1 && !_isAdmin) {
        _selectSubject(_subjects.first);
      }

      if (mounted) {
        setState(() {
          _loadingContext = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingContext = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _normalizeSubjects(List<Map<String, dynamic>> values) {
    final Map<int, Map<String, dynamic>> unique = {};
    for (final Map<String, dynamic> item in values) {
      final int? id = _toInt(item['id'] ?? item['subject_id']);
      if (id == null || id <= 0) continue;
      unique[id] = Map<String, dynamic>.from(item)..['id'] = id;
    }
    return unique.values.toList()
      ..sort((a, b) => _subjectLabel(a).toLowerCase().compareTo(_subjectLabel(b).toLowerCase()));
  }

  void _selectSubject(Map<String, dynamic> subject) {
    _subjectId = _toInt(subject['id']);
    _subjectController.text = _subjectLabel(subject);
    _cityController.text = _firstNonEmpty([subject['city'], _cityController.text]);
    _universityController.text =
        _firstNonEmpty([subject['university'], _universityController.text]);
    _departmentController.text =
        _firstNonEmpty([subject['department'], _departmentController.text]);
    _courseController.text =
        _firstNonEmpty([subject['course'], _courseController.text]);
  }

  Future<void> _chooseSubject() async {
    if (_subjects.isEmpty) {
      _showMessage(
        _isAdmin
            ? 'Per pubblicare su una materia devi prima selezionare un contesto del catalogo o fornire una materia riconosciuta dal backend.'
            : 'Non risultano materie verificate disponibili per questo docente.',
      );
      return;
    }

    String query = '';
    final Map<String, dynamic>? selected =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final String normalized = query.trim().toLowerCase();
            final List<Map<String, dynamic>> visible = _subjects.where((item) {
              if (normalized.isEmpty) return true;
              return [
                item['code'],
                item['name'],
                item['university'],
                item['department'],
                item['course'],
              ].join(' ').toLowerCase().contains(normalized);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.70,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seleziona materia',
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        style: const TextStyle(color: AppColors.pureWhite),
                        decoration: const InputDecoration(
                          hintText: 'Cerca materia...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (String value) {
                          setSheetState(() {
                            query = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: visible.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nessuna materia disponibile.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.builder(
                                itemCount: visible.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final Map<String, dynamic> subject = visible[index];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.menu_book_outlined,
                                      color: AppColors.materialSky,
                                    ),
                                    title: Text(
                                      _subjectLabel(subject),
                                      style: const TextStyle(color: AppColors.pureWhite),
                                    ),
                                    subtitle: Text(
                                      _subjectContext(subject),
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 9,
                                      ),
                                    ),
                                    onTap: () => Navigator.pop(sheetContext, subject),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() {
      _selectSubject(selected);
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_sending || !_formKey.currentState!.validate()) return;

    if (_targetType == PublicNewsTargetType.subject && _subjectId == null) {
      _showMessage(
        'Per pubblicare su una materia devi selezionare una materia riconosciuta.',
      );
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final Map<String, dynamic>? subject = _selectedSubject;

      await _newsApi.create(
        targetType: _targetValue(_targetType),
        title: _titleController.text,
        content: _contentController.text,
        subjectId: _subjectId,
        city: _cityController.text,
        university: _universityController.text,
        universityCode: _firstNonEmpty([
          subject?['university_code'],
          subject?['universityCode'],
        ]),
        department: _departmentController.text,
        departmentCode: _firstNonEmpty([
          subject?['department_code'],
          subject?['departmentCode'],
        ]),
        course: _courseController.text,
        courseCode: _firstNonEmpty([
          subject?['course_code'],
          subject?['courseCode'],
        ]),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('News pubblicata correttamente.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _selectedSubject {
    final int? id = _subjectId;
    if (id == null) return null;
    for (final Map<String, dynamic> subject in _subjects) {
      if (_toInt(subject['id']) == id) return subject;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: Text(_isAdmin ? 'Pubblica news' : 'Nuova news docente'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  if (_isAdmin)
                    DropdownButtonFormField<PublicNewsTargetType>(
                      initialValue: _targetType,
                      dropdownColor: AppColors.eleganceDeepNavy,
                      decoration: const InputDecoration(
                        labelText: 'Destinazione',
                        prefixIcon: Icon(Icons.filter_alt_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: PublicNewsTargetType.all,
                          child: Text('Tutta StudentLab'),
                        ),
                        DropdownMenuItem(
                          value: PublicNewsTargetType.university,
                          child: Text('Ateneo'),
                        ),
                        DropdownMenuItem(
                          value: PublicNewsTargetType.department,
                          child: Text('Dipartimento'),
                        ),
                        DropdownMenuItem(
                          value: PublicNewsTargetType.course,
                          child: Text('Corso'),
                        ),
                        DropdownMenuItem(
                          value: PublicNewsTargetType.subject,
                          child: Text('Materia'),
                        ),
                      ],
                      onChanged: _sending
                          ? null
                          : (PublicNewsTargetType? value) {
                              if (value == null) return;
                              setState(() {
                                _targetType = value;
                                if (value != PublicNewsTargetType.subject) {
                                  _subjectId = null;
                                  _subjectController.clear();
                                }
                              });
                            },
                    ),
                  if (_isAdmin) const SizedBox(height: 14),
                  TextFormField(
                    controller: _titleController,
                    enabled: !_sending,
                    maxLength: 160,
                    style: const TextStyle(color: AppColors.pureWhite),
                    decoration: const InputDecoration(
                      labelText: 'Titolo',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (value) =>
                        (value?.trim().isEmpty ?? true) ? 'Inserisci il titolo' : null,
                  ),
                  const SizedBox(height: 14),
                  if (_targetType != PublicNewsTargetType.all) ...[
                    _HybridAcademicField(
                      controller: _cityController,
                      label: 'Città',
                      icon: Icons.location_city_outlined,
                      suggestions: _suggestions('city'),
                      enabled: !_sending,
                    ),
                    const SizedBox(height: 10),
                    _HybridAcademicField(
                      controller: _universityController,
                      label: 'Ateneo',
                      icon: Icons.account_balance_outlined,
                      suggestions: _suggestions('university'),
                      enabled: !_sending,
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'Inserisci l’ateneo' : null,
                    ),
                    if (_targetType == PublicNewsTargetType.department ||
                        _targetType == PublicNewsTargetType.course ||
                        _targetType == PublicNewsTargetType.subject) ...[
                      const SizedBox(height: 10),
                      _HybridAcademicField(
                        controller: _departmentController,
                        label: 'Dipartimento',
                        icon: Icons.domain_outlined,
                        suggestions: _suggestions('department'),
                        enabled: !_sending,
                        validator: (value) =>
                            (value?.trim().isEmpty ?? true) ? 'Inserisci il dipartimento' : null,
                      ),
                    ],
                    if (_targetType == PublicNewsTargetType.course ||
                        _targetType == PublicNewsTargetType.subject) ...[
                      const SizedBox(height: 10),
                      _HybridAcademicField(
                        controller: _courseController,
                        label: 'Corso',
                        icon: Icons.school_outlined,
                        suggestions: _suggestions('course'),
                        enabled: !_sending,
                        validator: (value) =>
                            (value?.trim().isEmpty ?? true) ? 'Inserisci il corso' : null,
                      ),
                    ],
                    if (_targetType == PublicNewsTargetType.subject) ...[
                      const SizedBox(height: 10),
                      if (_subjects.isNotEmpty)
                        TextFormField(
                          controller: _subjectController,
                          readOnly: true,
                          enabled: !_sending && !_loadingContext,
                          onTap: _chooseSubject,
                          style: const TextStyle(color: AppColors.pureWhite),
                          decoration: const InputDecoration(
                            labelText: 'Materia',
                            prefixIcon: Icon(Icons.menu_book_outlined),
                            suffixIcon: Icon(Icons.expand_more_rounded),
                            helperText: 'Selezione riconosciuta dal backend; gli altri campi restano modificabili',
                          ),
                          validator: (_) => _subjectId == null ? 'Seleziona una materia' : null,
                        )
                      else if (_isAdmin)
                        TextFormField(
                          enabled: !_sending,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.pureWhite),
                          decoration: const InputDecoration(
                            labelText: 'ID materia',
                            prefixIcon: Icon(Icons.tag_rounded),
                            helperText: 'Fallback manuale: inserisci l’ID di una materia già presente nel catalogo StudentLab',
                          ),
                          onChanged: (String value) {
                            _subjectId = int.tryParse(value.trim());
                          },
                          validator: (String? value) {
                            final int? id = int.tryParse(value?.trim() ?? '');
                            return id == null || id <= 0 ? 'Inserisci un ID materia valido' : null;
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orangeAccent.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Text(
                            'Non risultano materie verificate disponibili per questo docente.',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contentController,
                    enabled: !_sending,
                    minLines: 7,
                    maxLines: 14,
                    maxLength: 5000,
                    style: const TextStyle(color: AppColors.pureWhite),
                    decoration: const InputDecoration(
                      labelText: 'Contenuto',
                      alignLabelWithHint: true,
                      hintText: 'Scrivi la comunicazione...',
                    ),
                    validator: (value) =>
                        (value?.trim().isEmpty ?? true) ? 'Inserisci il contenuto' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _errorCard(),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _submit,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_sending ? 'Pubblicazione...' : 'Pubblica news'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.teacherIndigo.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            color: AppColors.materialSky,
            size: 27,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isAdmin
                  ? 'I campi accademici vengono precompilati quando possibile, ma puoi sempre modificarli manualmente.'
                  : 'StudentLab precompila il contesto della materia verificata. Puoi correggere città, ateneo, dipartimento e corso; la materia deve restare una materia verificata.',
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.58),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _suggestions(String key) {
    final Set<String> values = {};

    String current = '';
    switch (key) {
      case 'university':
        current = _session.currentUser?.university ?? '';
        break;
      case 'department':
        current = _session.currentUser?.department ?? '';
        break;
      case 'course':
        current = _session.currentUser?.course ?? '';
        break;
    }
    if (current.trim().isNotEmpty) values.add(current.trim());

    for (final Map<String, dynamic> subject in _subjects) {
      final String value = subject[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) values.add(value);
    }

    final List<String> result = values.toList()..sort();
    return result;
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _error!,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }

  String _subjectLabel(Map<String, dynamic> subject) {
    final String code = subject['code']?.toString().trim() ?? '';
    final String name = subject['name']?.toString().trim() ?? '';
    if (code.isNotEmpty && name.isNotEmpty) return '$code · $name';
    if (name.isNotEmpty) return name;
    final int? id = _toInt(subject['id']);
    return id == null ? 'Materia' : 'Materia #$id';
  }

  String _subjectContext(Map<String, dynamic> subject) {
    return [
      subject['university'],
      subject['department'],
      subject['course'],
    ]
        .map((value) => value?.toString().trim() ?? '')
        .where((String value) => value.isNotEmpty)
        .join(' • ');
  }

  String _targetValue(PublicNewsTargetType value) {
    switch (value) {
      case PublicNewsTargetType.all:
        return 'all';
      case PublicNewsTargetType.university:
        return 'university';
      case PublicNewsTargetType.department:
        return 'department';
      case PublicNewsTargetType.course:
        return 'course';
      case PublicNewsTargetType.subject:
        return 'subject';
    }
  }

  String _friendlyError(Object error) {
    final String value = error.toString().toLowerCase();
    if (value.contains('401') || value.contains('non autenticato')) {
      return 'La sessione non è più valida. Accedi nuovamente.';
    }
    if (value.contains('403')) {
      return 'Non hai i permessi necessari per pubblicare in questo contesto.';
    }
    if (value.contains('404')) {
      return 'La materia o il contesto selezionato non è più disponibile.';
    }
    if (value.contains('socket') ||
        value.contains('connection') ||
        value.contains('network') ||
        value.contains('host lookup')) {
      return 'Non è stato possibile connettersi a StudentLab. Controlla la connessione e riprova.';
    }
    return 'Non è stato possibile pubblicare la news. Controlla i dati e riprova.';
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HybridAcademicField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> suggestions;
  final bool enabled;
  final String? Function(String?)? validator;

  const _HybridAcademicField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.suggestions,
    required this.enabled,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (TextEditingValue value) {
        final String query = value.text.trim().toLowerCase();
        if (query.isEmpty) return suggestions;
        return suggestions.where(
          (String item) => item.toLowerCase().contains(query),
        );
      },
      onSelected: (String value) {
        controller.text = value;
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        if (fieldController.text != controller.text && !focusNode.hasFocus) {
          fieldController.text = controller.text;
        }

        void sync() {
          controller.text = fieldController.text;
        }

        fieldController.removeListener(sync);
        fieldController.addListener(sync);

        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          enabled: enabled,
          validator: validator,
          style: const TextStyle(color: AppColors.pureWhite),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: suggestions.isEmpty
                ? const Icon(Icons.edit_outlined, size: 18)
                : const Icon(Icons.auto_awesome_outlined, size: 18),
            helperText: suggestions.isEmpty
                ? 'Inserimento manuale'
                : 'Suggerimenti automatici o inserimento manuale',
          ),
        );
      },
    );
  }
}