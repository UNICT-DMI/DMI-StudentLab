import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';

class TeacherMaterialFormPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialSubjects;

  const TeacherMaterialFormPage({
    super.key,
    this.initialSubjects = const [],
  });

  @override
  State<TeacherMaterialFormPage> createState() => _TeacherMaterialFormPageState();
}

class _TeacherMaterialFormPageState extends State<TeacherMaterialFormPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _subjectSearchController = TextEditingController();

  bool _loading = true;
  bool _authorized = false;
  bool _uploading = false;
  String? _error;
  List<Map<String, dynamic>> _subjects = [];
  int? _selectedSubjectId;
  String _visibility = 'students';
  PlatformFile? _selectedFile;
  String? _selectedFilePath;

  @override
  void initState() {
    super.initState();
    _subjects = _normalizeSubjects(widget.initialSubjects);
    if (_subjects.length == 1) {
      _selectedSubjectId = _toInt(_subjects.first['id']);
      _subjectSearchController.text = _subjectLabel(_subjects.first);
    }
    _initialize();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectSearchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final bool authorized = await _apiService.canAccessTeacherArea();
      if (!mounted) return;

      if (!authorized) {
        setState(() {
          _authorized = false;
          _loading = false;
        });
        return;
      }

      List<Map<String, dynamic>> subjects = [];
      try {
        subjects = _normalizeSubjects(await _apiService.getTeacherSubjects());
      } catch (_) {}

      if (subjects.isEmpty && widget.initialSubjects.isNotEmpty) {
        subjects = _normalizeSubjects(widget.initialSubjects);
      }

      if (!mounted) return;

      setState(() {
        _authorized = true;
        _subjects = subjects;
        if (_selectedSubjectId != null &&
            !_subjects.any((Map<String, dynamic> item) => _toInt(item['id']) == _selectedSubjectId)) {
          _selectedSubjectId = null;
          _subjectSearchController.clear();
        }
        if (_subjects.length == 1 && _selectedSubjectId == null) {
          _selectedSubjectId = _toInt(_subjects.first['id']);
          _subjectSearchController.text = _subjectLabel(_subjects.first);
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authorized = false;
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  List<Map<String, dynamic>> _normalizeSubjects(List<Map<String, dynamic>> values) {
    final Map<int, Map<String, dynamic>> result = {};
    for (final Map<String, dynamic> value in values) {
      final int? id = _toInt(value['id'] ?? value['subject_id']);
      if (id == null || id <= 0) continue;
      result[id] = Map<String, dynamic>.from(value)..['id'] = id;
    }
    final List<Map<String, dynamic>> subjects = result.values.toList()
      ..sort((a, b) => _subjectLabel(a).toLowerCase().compareTo(_subjectLabel(b).toLowerCase()));
    return subjects;
  }

  Future<void> _pickSubject() async {
    if (_uploading || _subjects.isEmpty) return;

    String query = '';
    final int? selected = await showModalBottomSheet<int>(
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
            final List<Map<String, dynamic>> visible = _subjects.where((subject) {
              if (normalized.isEmpty) return true;
              return [
                subject['code'],
                subject['name'],
                subject['university'],
                subject['department'],
                subject['course'],
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
                  height: MediaQuery.sizeOf(context).height * 0.72,
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
                        autofocus: false,
                        style: const TextStyle(color: AppColors.pureWhite),
                        decoration: const InputDecoration(
                          hintText: 'Cerca materia, codice, corso...',
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
                                  'Nessuna materia verificata corrispondente.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.separated(
                                itemCount: visible.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                                itemBuilder: (BuildContext context, int index) {
                                  final Map<String, dynamic> subject = visible[index];
                                  final int id = _toInt(subject['id'])!;
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.menu_book_outlined,
                                      color: AppColors.teacherIndigo,
                                    ),
                                    title: Text(
                                      _subjectLabel(subject),
                                      style: const TextStyle(color: AppColors.pureWhite),
                                    ),
                                    subtitle: Text(
                                      _subjectContext(subject),
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                      ),
                                    ),
                                    trailing: _selectedSubjectId == id
                                        ? const Icon(Icons.check_rounded, color: Colors.greenAccent)
                                        : null,
                                    onTap: () => Navigator.pop(sheetContext, id),
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
    final Map<String, dynamic>? subject = _subjectById(selected);
    setState(() {
      _selectedSubjectId = selected;
      _subjectSearchController.text = subject == null ? 'Materia #$selected' : _subjectLabel(subject);
    });
  }

  Future<void> _pickFile() async {
    if (_uploading) return;

    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'txt', 'zip', 'docx', 'pptx'],
      );

      if (result == null) return;

      final PlatformFile file = result.files.single;
      final String? path = file.path;

      if (path == null || path.trim().isEmpty) {
        _showMessage('Impossibile ottenere il percorso del file selezionato.');
        return;
      }
      if (file.size <= 0) {
        _showMessage('Il file selezionato è vuoto.');
        return;
      }
      if (file.size > ApiService.maxMaterialFileSize) {
        _showMessage('Il file supera la dimensione massima consentita di 250 MB.');
        return;
      }

      final File localFile = File(path);
      if (!await localFile.exists()) {
        _showMessage('Il file selezionato non è più disponibile.');
        return;
      }
      if (!mounted) return;

      setState(() {
        _selectedFile = file;
        _selectedFilePath = path;
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = _titleFromFileName(file.name);
        }
      });
    } catch (error) {
      _showMessage(_friendlyFileError(error));
    }
  }

  Future<void> _submit() async {
    if (_uploading) return;

    final int? subjectId = _selectedSubjectId;
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    final String? filePath = _selectedFilePath;

    if (subjectId == null) {
      _showMessage('Seleziona una materia verificata.');
      return;
    }
    if (title.isEmpty) {
      _showMessage('Inserisci il titolo del materiale.');
      return;
    }
    if (title.length > 255) {
      _showMessage('Il titolo non può superare 255 caratteri.');
      return;
    }
    if (description.length > 5000) {
      _showMessage('La descrizione non può superare 5000 caratteri.');
      return;
    }
    if (filePath == null || filePath.isEmpty) {
      _showMessage('Seleziona un file da caricare.');
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final bool authorized = await _apiService.canAccessTeacherArea();
      if (!authorized) {
        throw StateError('Accesso docente non autorizzato.');
      }

      await _apiService.uploadTeacherMaterial(
        subjectId: subjectId,
        title: title,
        description: description,
        visibility: _visibility,
        filePath: filePath,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final String message = _friendlyUploadError(error);
      setState(() {
        _error = message;
      });
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.darkElegance,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teacherIndigo),
        ),
      );
    }

    if (!_authorized) {
      return Scaffold(
        backgroundColor: AppColors.darkElegance,
        appBar: AppBar(
          backgroundColor: AppColors.brandNightBlue,
          foregroundColor: AppColors.pureWhite,
          title: const Text('Carica materiale'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _messageCard(
                icon: Icons.gpp_bad_outlined,
                iconColor: Colors.redAccent,
                title: 'Accesso non autorizzato',
                message: _error ??
                    'Solo un docente verificato e attivo può caricare materiale didattico.',
                actionLabel: 'Riprova',
                onAction: _initialize,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        title: const Text('Carica materiale'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _section(
                  title: 'Materia',
                  icon: Icons.menu_book_outlined,
                  child: _buildSubjectSelector(),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Informazioni',
                  icon: Icons.description_outlined,
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        enabled: !_uploading,
                        maxLength: 255,
                        style: const TextStyle(color: AppColors.pureWhite),
                        decoration: const InputDecoration(
                          labelText: 'Titolo',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        enabled: !_uploading,
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 5000,
                        style: const TextStyle(color: AppColors.pureWhite),
                        decoration: const InputDecoration(
                          labelText: 'Descrizione',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'File',
                  icon: Icons.attach_file_rounded,
                  child: _buildFileSelector(),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Visibilità',
                  icon: Icons.visibility_outlined,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'students',
                        icon: Icon(Icons.groups_outlined),
                        label: Text('Studenti'),
                      ),
                      ButtonSegment(
                        value: 'private',
                        icon: Icon(Icons.lock_outline_rounded),
                        label: Text('Privato'),
                      ),
                    ],
                    selected: {_visibility},
                    onSelectionChanged: _uploading
                        ? null
                        : (Set<String> values) {
                            setState(() {
                              _visibility = values.first;
                            });
                          },
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _buildError(),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _uploading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teacherIndigo,
                      foregroundColor: AppColors.pureWhite,
                    ),
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      _uploading ? 'Caricamento in corso...' : 'Carica materiale',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: AppColors.teacherIndigo.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.teacherIndigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.upload_file_outlined,
              color: AppColors.teacherIndigo,
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Seleziona una materia verificata e un file. Il titolo viene precompilato dal nome del file ma resta modificabile.',
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.55),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector() {
    if (_subjects.isEmpty) {
      return _messageCard(
        icon: Icons.menu_book_outlined,
        iconColor: Colors.orangeAccent,
        title: 'Nessuna materia verificata',
        message:
            'StudentLab non ha ricevuto materie verificabili per questo docente. Aggiorna l’elenco; se resta vuoto va controllata l’assegnazione docente nel backend.',
        actionLabel: 'Aggiorna materie',
        onAction: _initialize,
      );
    }

    return TextField(
      controller: _subjectSearchController,
      readOnly: true,
      enabled: !_uploading,
      onTap: _pickSubject,
      style: const TextStyle(color: AppColors.pureWhite),
      decoration: InputDecoration(
        labelText: 'Materia',
        hintText: 'Seleziona una materia verificata',
        prefixIcon: const Icon(Icons.school_outlined),
        suffixIcon: const Icon(Icons.expand_more_rounded),
        helperText: '${_subjects.length} materie disponibili',
      ),
    );
  }

  Widget _buildFileSelector() {
    final PlatformFile? file = _selectedFile;

    if (file == null) {
      return InkWell(
        onTap: _uploading ? null : _pickFile,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.brandNightBlue.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: AppColors.teacherIndigo.withValues(alpha: 0.22),
            ),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                color: AppColors.teacherIndigo,
                size: 34,
              ),
              SizedBox(height: 9),
              Text(
                'Seleziona un file',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'PDF, TXT, ZIP, DOCX, PPTX · massimo 250 MB',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandNightBlue.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.teacherIndigo.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            color: AppColors.teacherIndigo,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatFileSize(file.size),
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),
          if (!_uploading)
            IconButton(
              tooltip: 'Rimuovi',
              onPressed: () {
                setState(() {
                  _selectedFile = null;
                  _selectedFilePath = null;
                });
              },
              icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
            ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.pureWhite.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.teacherIndigo, size: 19),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _messageCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: iconColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _subjectById(int id) {
    for (final Map<String, dynamic> subject in _subjects) {
      if (_toInt(subject['id']) == id) return subject;
    }
    return null;
  }

  String _subjectLabel(Map<String, dynamic> subject) {
    final String code = subject['code']?.toString().trim() ?? '';
    final String name = subject['name']?.toString().trim() ?? '';
    if (code.isNotEmpty && name.isNotEmpty) return '$code · $name';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
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

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _titleFromFileName(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    return (dot > 0 ? fileName.substring(0, dot) : fileName)
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatFileSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _friendlyError(Object error) {
    final String value = error.toString().toLowerCase();
    if (value.contains('401')) return 'La sessione non è più valida. Accedi nuovamente.';
    if (value.contains('403')) return 'Il tuo account non dispone dei permessi docente richiesti.';
    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection') ||
        value.contains('timeout') ||
        value.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }
    return 'Non è stato possibile caricare i dati del docente.';
  }

  String _friendlyFileError(Object error) {
    final String value = error.toString().toLowerCase();
    if (value.contains('permission')) {
      return 'StudentLab non può accedere al file selezionato. Scegli un altro file.';
    }
    return 'Non è stato possibile selezionare il file.';
  }

  String _friendlyUploadError(Object error) {
    final String value = error.toString().toLowerCase();
    if (value.contains('409') || value.contains('già presente') || value.contains('duplicat')) {
      return 'Questo materiale risulta già presente per la materia selezionata.';
    }
    if (value.contains('401')) return 'La sessione non è più valida. Accedi nuovamente.';
    if (value.contains('403')) return 'Non hai i permessi per pubblicare materiale in questa materia.';
    if (value.contains('mime') || value.contains('tipo') || value.contains('formato')) {
      return 'Il formato del file non è supportato.';
    }
    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection') ||
        value.contains('timeout')) {
      return 'Caricamento non riuscito. Controlla la connessione e riprova.';
    }
    return 'Non è stato possibile caricare il materiale. Riprova.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}