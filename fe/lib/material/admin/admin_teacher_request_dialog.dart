import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../social/admin/admin_material_storage_api_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/studentlab_ui/studentlab_ui.dart';

/// "Richiedi materiale a un docente" (canvas: Gestione materiali admin).
///
/// Se [parentRequest] è indicata, la richiesta resta collegata a quella degli
/// studenti: quando un docente la soddisfa, gli studenti vengono avvisati.
/// Restituisce true se la richiesta è stata inviata.
Future<bool> showAdminTeacherRequestDialog(
  BuildContext context, {
  int? subjectId,
  Map<String, dynamic>? parentRequest,
}) async {
  final bool? sent = await showDialog<bool>(
    context: context,
    builder: (_) => _AdminTeacherRequestDialog(subjectId: subjectId, parentRequest: parentRequest),
  );
  return sent == true;
}

class _AdminTeacherRequestDialog extends StatefulWidget {
  final int? subjectId;
  final Map<String, dynamic>? parentRequest;

  const _AdminTeacherRequestDialog({this.subjectId, this.parentRequest});

  @override
  State<_AdminTeacherRequestDialog> createState() => _AdminTeacherRequestDialogState();
}

class _AdminTeacherRequestDialogState extends State<_AdminTeacherRequestDialog> {
  final ApiService _api = ApiService();
  final AdminMaterialStorageApiService _storage = AdminMaterialStorageApiService();
  final TextEditingController _topic = TextEditingController();
  final TextEditingController _message = TextEditingController();

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _teachers = [];
  final Set<int> _selected = <int>{};
  int? _subjectId;
  DateTime? _due;
  bool _loadingTeachers = false;
  bool _sending = false;
  String? _error;

  int _int(Object? value) => int.tryParse('$value') ?? 0;

  @override
  void initState() {
    super.initState();
    final parent = widget.parentRequest;
    _subjectId = parent != null ? _int(parent['subject_id']) : widget.subjectId;
    if (parent != null) {
      _topic.text = parent['topic']?.toString() ?? '';
      final String original = parent['message']?.toString().trim() ?? '';
      _message.text = original.isEmpty
          ? ''
          : 'Gli studenti chiedono: “$original”. Può condividere il materiale o indicarci dove trovarlo?';
    }
    _loadSubjects();
  }

  @override
  void dispose() {
    _topic.dispose();
    _message.dispose();
    super.dispose();
  }

  String _reason(Object error, String fallback) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.contains('"detail"') || text.contains(' - ')) return slErrorMessage(error, fallback: fallback);
    return text.isEmpty || text.length > 200 ? fallback : text;
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await _storage.getDriveImportOptions();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _subjectId ??= subjects.isEmpty ? null : _int(subjects.first['id']);
      });
      await _loadTeachers();
    } catch (e) {
      if (mounted) setState(() => _error = _reason(e, 'Materie non disponibili.'));
    }
  }

  Future<void> _loadTeachers() async {
    final subjectId = _subjectId;
    if (subjectId == null) return;
    setState(() {
      _loadingTeachers = true;
      _teachers = [];
      _selected.clear();
    });
    try {
      final teachers = await _api.getAdminSubjectTeachers(subjectId);
      if (!mounted) return;
      setState(() {
        _teachers = teachers;
        if (teachers.length == 1) _selected.add(_int(teachers.first['id']));
      });
    } catch (e) {
      if (mounted) setState(() => _error = _reason(e, 'Docenti non disponibili.'));
    }
    if (mounted) setState(() => _loadingTeachers = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _due = picked);
  }

  Future<void> _send() async {
    final subjectId = _subjectId;
    if (subjectId == null || _selected.isEmpty || _message.text.trim().isEmpty) {
      setState(() => _error = 'Scegli almeno un docente e scrivi il messaggio.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _api.createAdminTeacherRequest(
        subjectId: subjectId,
        teacherIds: _selected.toList(),
        message: _message.text.trim(),
        topic: _topic.text.trim(),
        dueDate: _due,
        parentRequestId: widget.parentRequest == null ? null : _int(widget.parentRequest!['id']),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = _reason(e, 'Richiesta non inviata. Riprova.');
        });
      }
    }
  }

  String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty && !p.endsWith('.'))
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final parent = widget.parentRequest;
    return AlertDialog(
      backgroundColor: p.eleganceDeepNavy,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Richiedi materiale a un docente',
            style: TextStyle(color: p.pureWhite, fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Il docente riceve una notifica e trova la richiesta nella sua area.', style: SlText.muted(p)),
      ]),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (parent != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.adminCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.adminCyan.withValues(alpha: 0.24)),
                ),
                child: Row(children: [
                  Icon(Icons.mail_outline_rounded, size: 16, color: p.adminCyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Collegata alla richiesta di ${parent['student_name'] ?? 'uno studente'}: quando il docente la soddisfa, lo avvisiamo.',
                      style: SlText.body(p).copyWith(fontSize: 12),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            if (_error != null) ...[
              SlErrorCard(title: 'Attenzione', message: _error!),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<int>(
              value: _subjects.any((s) => _int(s['id']) == _subjectId) ? _subjectId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Materia'),
              items: [
                for (final s in _subjects)
                  DropdownMenuItem<int>(
                    value: _int(s['id']),
                    child: Text('${s['name']} · ${s['course']}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: parent != null || _sending
                  ? null
                  : (value) {
                      setState(() => _subjectId = value);
                      _loadTeachers();
                    },
            ),
            const SizedBox(height: 14),
            Text('Docenti della materia', style: SlText.muted(p)),
            const SizedBox(height: 8),
            if (_loadingTeachers)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.skyBlue)),
              )
            else if (_teachers.isEmpty)
              Text('Questa materia non ha docenti verificati: rispondi agli studenti o carica tu il materiale.',
                  style: SlText.muted(p).copyWith(color: p.adminAmber))
            else
              for (final t in _teachers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: _selected.contains(_int(t['id'])) ? p.skyBlue.withValues(alpha: 0.08) : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _selected.contains(_int(t['id']))
                            ? p.skyBlue.withValues(alpha: 0.40)
                            : p.pureWhite.withValues(alpha: 0.10),
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _selected.contains(_int(t['id'])),
                      onChanged: _sending
                          ? null
                          : (value) => setState(() => value == true
                              ? _selected.add(_int(t['id']))
                              : _selected.remove(_int(t['id']))),
                      controlAffinity: ListTileControlAffinity.leading,
                      secondary: CircleAvatar(
                        radius: 18,
                        backgroundColor: p.teacherIndigo,
                        child: Text(_initials('${t['name']}'),
                            style: TextStyle(color: p.pureWhite, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      title: Text('${t['name']}', style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600)),
                      subtitle: Text('Docente verificato', style: SlText.muted(p)),
                    ),
                  ),
                ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _topic,
                  decoration: const InputDecoration(labelText: 'Argomento'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: InkWell(
                  onTap: _sending ? null : _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Entro (facoltativo)'),
                    child: Text(
                      _due == null
                          ? 'Nessuna scadenza'
                          : '${_due!.day.toString().padLeft(2, '0')}/${_due!.month.toString().padLeft(2, '0')}/${_due!.year}',
                      style: SlText.body(p),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              minLines: 4,
              maxLines: 8,
              maxLength: 3000,
              decoration: const InputDecoration(labelText: 'Messaggio'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.of(context).pop(false), child: const Text('Annulla')),
        FilledButton(
          onPressed: _sending || _teachers.isEmpty ? null : _send,
          child: _sending
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
              : const Text('Invia al docente'),
        ),
      ],
    );
  }
}
