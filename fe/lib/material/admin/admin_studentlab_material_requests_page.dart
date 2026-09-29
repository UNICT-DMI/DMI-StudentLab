import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/studentlab_ui/studentlab_ui.dart';
import 'admin_material_upload_page.dart';
import 'admin_teacher_request_dialog.dart';

/// Richieste di materiale indirizzate a StudentLab (canvas: Richieste v2).
///
/// Colonne Nuove / Chiesto al docente / Chiuse. Nel dettaglio: conversazione,
/// storia (richiesta, studenti con la stessa richiesta, docenti interpellati,
/// chiusura), materiali già disponibili da collegare, e le azioni
/// Carica e soddisfa, Chiedi a un docente, Non disponibile, Soddisfa.
class AdminStudentLabMaterialRequestsPage extends StatefulWidget {
  const AdminStudentLabMaterialRequestsPage({super.key});

  @override
  State<AdminStudentLabMaterialRequestsPage> createState() =>
      _AdminStudentLabMaterialRequestsPageState();
}

class _AdminStudentLabMaterialRequestsPageState extends State<AdminStudentLabMaterialRequestsPage> {
  static const double _wideBreakpoint = 1180;

  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _notice;
  String _filter = 'new';
  int? _selectedId;
  int? _busyId;
  final TextEditingController _reply = TextEditingController();
  final Map<int, Future<List<Map<String, dynamic>>>> _suggestions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  int? _id(Map<String, dynamic> item) => int.tryParse(item['id']?.toString() ?? '');
  bool _isOpen(Map<String, dynamic> item) => (item['status']?.toString() ?? 'pending') == 'pending';
  List<Map<String, dynamic>> _forwarded(Map<String, dynamic> item) => item['forwarded'] is List
      ? (item['forwarded'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : const [];

  /// Colonna di appartenenza: new, teacher, closed.
  String _column(Map<String, dynamic> item) {
    if (!_isOpen(item)) return 'closed';
    return _forwarded(item).any((f) => f['status'] == 'pending') ? 'teacher' : 'new';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getStudentLabMaterialRequests();
      items.sort((a, b) => (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? ''));
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _suggestions.clear();
        if (_selectedId == null || !items.any((i) => _id(i) == _selectedId)) {
          final open = items.where(_isOpen);
          _selectedId = open.isNotEmpty ? _id(open.first) : (items.isNotEmpty ? _id(items.first) : null);
          _reply.clear();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Impossibile caricare le richieste. Controlla la connessione e riprova.';
          _loading = false;
        });
      }
    }
  }

  String _groupKey(Map<String, dynamic> item) =>
      '${item['subject_id'] ?? item['subject_name'] ?? ''}|${(item['topic']?.toString() ?? '').trim().toLowerCase()}';

  /// Altre richieste aperte uguali (stessa materia e argomento): indicazione
  /// calcolata dall'app, le richieste restano separate.
  List<Map<String, dynamic>> _similar(Map<String, dynamic> item) {
    final key = _groupKey(item);
    if ((item['topic']?.toString() ?? '').trim().isEmpty) return const [];
    return _items.where((i) => _id(i) != _id(item) && _isOpen(i) && _groupKey(i) == key).toList();
  }

  String _date(dynamic value, {bool time = false}) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final day = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return time ? '$day · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}' : day;
  }

  String _relative(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes < 1 ? 1 : diff.inMinutes} min fa';
    if (diff.inHours < 24) return '${diff.inHours} h fa';
    if (diff.inDays == 1) return 'ieri';
    if (diff.inDays < 7) return '${diff.inDays} gg fa';
    return _date(value);
  }

  String _reason(Object error, String fallback) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.contains('"detail"') || text.contains(' - ')) return slErrorMessage(error, fallback: fallback);
    return text.isEmpty || text.length > 200 ? fallback : text;
  }

  Future<bool> _send(Map<String, dynamic> item, String action, {int? materialId}) async {
    final id = _id(item);
    String text = _reply.text.trim();
    if (id == null) return false;
    if (text.isEmpty && materialId != null) {
      text = 'Il materiale che cerchi è già disponibile nelle Dispense della materia.';
    }
    if (text.isEmpty) {
      setState(() => _notice = 'Scrivi una risposta per lo studente.');
      return false;
    }
    setState(() {
      _busyId = id;
      _notice = null;
    });
    try {
      await _api.replyStudentLabMaterialRequest(id,
          action: action, message: text, fulfilledPublicMaterialId: materialId);
      _reply.clear();
      await _load();
      if (mounted) {
        setState(() => _notice = action == 'fulfilled'
            ? 'Richiesta soddisfatta: lo studente riceve una notifica.'
            : 'Richiesta chiusa come non disponibile.');
      }
      return true;
    } catch (error) {
      if (mounted) setState(() => _notice = _reason(error, 'Impossibile inviare la risposta. Riprova.'));
      return false;
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _uploadAndFulfil(Map<String, dynamic> item) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminMaterialUploadPage(answerRequest: item)),
    );
    if (done == true && mounted) await _load();
  }

  Future<void> _askTeacher(Map<String, dynamic> item) async {
    final sent = await showAdminTeacherRequestDialog(context, parentRequest: item);
    if (sent && mounted) {
      await _load();
      if (mounted) setState(() => _notice = 'Richiesta inviata al docente: gli studenti sono stati avvisati.');
    }
  }

  Future<List<Map<String, dynamic>>> _suggestionsFor(Map<String, dynamic> item) {
    final id = _id(item) ?? 0;
    return _suggestions.putIfAbsent(id, () async {
      final subjectId = int.tryParse('${item['subject_id']}');
      if (subjectId == null) return const [];
      try {
        final found = await _api.getAdminSubjectMaterials(subjectId,
            query: '${item['topic'] ?? ''} ${item['message'] ?? ''}');
        return found.where((m) => m['visibility_state'] == 'visible').take(3).toList();
      } catch (_) {
        return const [];
      }
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: slAdminAppBar(context, title: 'Richieste a StudentLab', actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: SlActionButton(
            icon: Icons.upload_file_rounded,
            label: 'Carica materiale',
            primary: true,
            onPressed: () async {
              final done = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const AdminMaterialUploadPage()),
              );
              if (done == true && mounted) await _load();
            },
          ),
        ),
        IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: SafeArea(
        child: _loading && _items.isEmpty
            ? Center(child: CircularProgressIndicator(color: p.skyBlue))
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: SlErrorCard(title: 'Richieste non disponibili', message: _error!, onRetry: _load))
                : LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= _wideBreakpoint;
                    final newItems = _items.where((i) => _column(i) == 'new').toList();
                    final teacherItems = _items.where((i) => _column(i) == 'teacher').toList();
                    final closed = _items.where((i) => _column(i) == 'closed').toList();
                    final notice = _notice == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 12, wide ? 24 : 16, 0),
                            child: _noticeBar(_notice!),
                          );
                    if (!wide) {
                      return Column(children: [notice, Expanded(child: _narrow(newItems, teacherItems, closed))]);
                    }
                    final matches = _items.where((i) => _id(i) == _selectedId);
                    final Map<String, dynamic>? selected = matches.isNotEmpty ? matches.first : null;
                    return Column(children: [
                      notice,
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                            Expanded(child: _columnView('Nuove', p.adminAmber, newItems)),
                            const SizedBox(width: 14),
                            Expanded(child: _columnView('Chiesto al docente', p.adminBlue, teacherItems)),
                            const SizedBox(width: 14),
                            Expanded(child: _columnView('Chiuse', p.adminGreen, closed)),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 460,
                              child: selected == null
                                  ? const SlEmptyState(
                                      icon: Icons.mark_email_read_outlined,
                                      title: 'Nessuna richiesta selezionata',
                                      message: 'Scegli una richiesta per rispondere.')
                                  : _detail(selected),
                            ),
                          ]),
                        ),
                      ),
                    ]);
                  }),
      ),
    );
  }

  Widget _noticeBar(String text) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: p.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.skyBlue.withValues(alpha: 0.24)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 18, color: p.skyBlue),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: SlText.body(p))),
        IconButton(
          tooltip: 'Chiudi',
          onPressed: () => setState(() => _notice = null),
          icon: Icon(Icons.close_rounded, size: 18, color: p.pureWhite.withValues(alpha: 0.66)),
        ),
      ]),
    );
  }

  Widget _columnView(String title, Color dot, List<Map<String, dynamic>> items) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(children: <Widget>[
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('${items.length}', style: SlText.mono(p, size: 12, color: p.pureWhite.withValues(alpha: 0.56))),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              if (items.isEmpty)
                Padding(padding: const EdgeInsets.all(12), child: Text('Nessuna richiesta.', style: SlText.muted(p)))
              else
                for (final item in items) _card(item, wide: true),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _narrow(List<Map<String, dynamic>> fresh, List<Map<String, dynamic>> teacher, List<Map<String, dynamic>> closed) {
    final shown = switch (_filter) { 'teacher' => teacher, 'closed' => closed, _ => fresh };
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SlFilterBar<String>(
          selected: _filter,
          options: <SlFilterOption<String>>[
            SlFilterOption(value: 'new', label: 'Nuove', count: fresh.length),
            SlFilterOption(value: 'teacher', label: 'Chiesto al docente', count: teacher.length),
            SlFilterOption(value: 'closed', label: 'Chiuse', count: closed.length),
          ],
          onSelected: (value) => setState(() => _filter = value),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (shown.isEmpty)
                const SlEmptyState(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Nessuna richiesta qui',
                  message: 'Le richieste degli studenti a StudentLab compaiono in questa pagina.',
                )
              else
                for (final item in shown) _card(item, wide: false),
            ],
          ),
        ),
      ),
    ]);
  }

  List<Widget> _badges(Map<String, dynamic> item) {
    final status = item['status']?.toString();
    final similar = _isOpen(item) ? _similar(item).length : 0;
    final forwarded = _forwarded(item);
    return <Widget>[
      if (status == 'fulfilled')
        const SlStatusBadge(label: 'Soddisfatta', tone: SlTone.success)
      else if (status == 'rejected')
        const SlStatusBadge(label: 'Non disponibile')
      else if (forwarded.any((f) => f['status'] == 'pending'))
        const SlStatusBadge(label: 'Chiesto al docente', tone: SlTone.blue)
      else
        const SlStatusBadge(label: 'Nuova', tone: SlTone.warning),
      if (similar > 0) SlStatusBadge(label: '${similar + 1} studenti', tone: SlTone.cyan),
      for (final f in forwarded.where((f) => f['status'] == 'pending').take(1))
        SlStatusBadge(label: '${f['teacher_name'] ?? 'Docente'}', tone: SlTone.violet),
    ];
  }

  Widget _card(Map<String, dynamic> item, {required bool wide}) {
    final p = context.palette;
    final id = _id(item);
    final selected = wide && id == _selectedId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? p.eleganceDeepNavy : p.eleganceMidnight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? p.skyBlue.withValues(alpha: 0.40) : p.pureWhite.withValues(alpha: 0.08)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _selectedId = id;
              _reply.clear();
            });
            if (!wide) {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  backgroundColor: context.palette.darkElegance,
                  appBar: slAdminAppBar(context, title: 'Richiesta', breadcrumb: 'ADMIN / RICHIESTE A STUDENTLAB'),
                  body: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: _detail(item, popOnDone: true))),
                ),
              ));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text((item['topic']?.toString().trim().isNotEmpty ?? false) ? item['topic'].toString() : 'Materiale richiesto',
                  style: TextStyle(
                      color: _isOpen(item) ? p.pureWhite : p.pureWhite.withValues(alpha: 0.80),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(item['subject_name']?.toString() ?? 'Materia', style: SlText.muted(p)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
                ..._badges(item),
                Text(_relative(item['created_at']),
                    style: SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.56))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _timelineRow(Color color, String title, String when) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: p.pureWhite, fontSize: 12, fontWeight: FontWeight.w600)),
            if (when.isNotEmpty) Text(when, style: SlText.mono(p, size: 10, color: p.pureWhite.withValues(alpha: 0.56))),
          ]),
        ),
      ]),
    );
  }

  Widget _detail(Map<String, dynamic> item, {bool popOnDone = false}) {
    final p = context.palette;
    final id = _id(item);
    final busy = id != null && _busyId == id;
    final open = _isOpen(item);
    final similar = open ? _similar(item) : const <Map<String, dynamic>>[];
    final forwarded = _forwarded(item);
    final student = item['student_name']?.toString() ?? 'Studente';
    Future<void> run(Future<bool> action) async {
      final ok = await action;
      if (ok && popOnDone && mounted) Navigator.of(context).pop();
    }

    final history = <Widget>[
      _timelineRow(p.adminAmber, 'Richiesta di $student', _date(item['created_at'], time: true)),
      if (similar.isNotEmpty)
        _timelineRow(p.adminCyan,
            similar.length == 1 ? 'Un altro studente ha chiesto lo stesso' : 'Altri ${similar.length} studenti hanno chiesto lo stesso',
            similar.map((s) => _date(s['created_at'])).where((d) => d.isNotEmpty).toSet().join(' · ')),
      for (final f in forwarded)
        _timelineRow(
          f['status'] == 'fulfilled' ? p.adminGreen : (f['status'] == 'rejected' ? p.adminCoral : p.adminBlue),
          '${f['status'] == 'fulfilled' ? 'Soddisfatta da' : (f['status'] == 'rejected' ? 'Non disponibile per' : 'Chiesta a')} ${f['teacher_name'] ?? 'un docente'}',
          [
            _date(f['created_at'], time: true),
            if (f['due_date'] != null) 'entro ${_date(f['due_date'])}',
          ].where((e) => e.isNotEmpty).join(' · '),
        ),
      if (!open)
        _timelineRow(
          item['status'] == 'fulfilled' ? p.adminGreen : p.pureWhite.withValues(alpha: 0.5),
          '${item['status'] == 'fulfilled' ? 'Soddisfatta' : 'Chiusa come non disponibile'}'
              '${(item['resolved_by_name']?.toString().isNotEmpty ?? false) ? ' da ${item['resolved_by_name']}' : ''}',
          _date(item['resolved_at'], time: true),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: p.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.skyBlue.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Wrap(spacing: 6, runSpacing: 6, children: _badges(item)),
            const SizedBox(height: 8),
            Text((item['topic']?.toString().trim().isNotEmpty ?? false) ? item['topic'].toString() : 'Materiale richiesto',
                style: TextStyle(color: p.pureWhite, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              <String>[
                if ((item['course']?.toString() ?? '').isNotEmpty) item['course'].toString(),
                item['subject_name']?.toString() ?? 'Materia',
                if ((item['topic']?.toString() ?? '').trim().isNotEmpty) item['topic'].toString(),
              ].join(' › '),
              style: SlText.mono(p, size: 11),
            ),
          ]),
        ),
        Divider(height: 1, color: p.pureWhite.withValues(alpha: 0.07)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _bubble(name: student, time: _date(item['created_at']), text: item['message']?.toString() ?? '', mine: false),
              if (item['staff_response'] != null) ...<Widget>[
                const SizedBox(height: 12),
                _bubble(name: 'StudentLab', time: _date(item['resolved_at']), text: item['staff_response'].toString(), mine: true),
              ],
              const SizedBox(height: 16),
              const SlOverline('Storia'),
              const SizedBox(height: 10),
              ...history,
              if (open)
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _suggestionsFor(item),
                  builder: (context, snapshot) {
                    final found = snapshot.data ?? const <Map<String, dynamic>>[];
                    if (found.isEmpty) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.adminGreen.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.adminGreen.withValues(alpha: 0.26)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('Forse è già disponibile',
                            style: TextStyle(color: p.adminGreen, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        for (final m in found)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(m['title']?.toString() ?? m['original_name']?.toString() ?? 'Materiale',
                                      style: SlText.body(p).copyWith(color: p.pureWhite)),
                                  if (m['path_segments'] is List && (m['path_segments'] as List).isNotEmpty)
                                    Text((m['path_segments'] as List).join(' › '), style: SlText.muted(p).copyWith(fontSize: 11)),
                                ]),
                              ),
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => run(_send(item, 'fulfilled', materialId: int.tryParse('${m['id']}'))),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: p.adminGreen,
                                  minimumSize: const Size(0, 34),
                                  side: BorderSide(color: p.adminGreen.withValues(alpha: 0.40)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                child: const Text('Collega e chiudi'),
                              ),
                            ]),
                          ),
                      ]),
                    );
                  },
                ),
            ],
          ),
        ),
        if (open) ...<Widget>[
          Divider(height: 1, color: p.pureWhite.withValues(alpha: 0.07)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              TextField(
                controller: _reply,
                minLines: 2,
                maxLines: 5,
                style: TextStyle(color: p.pureWhite, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Risposta agli studenti',
                  hintText: 'Es. Abbiamo pubblicato gli esercizi svolti in Reti › Livello rete.',
                  fillColor: p.darkElegance,
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: SlActionButton(
                    icon: Icons.upload_file_rounded,
                    label: 'Carica e soddisfa',
                    primary: true,
                    onPressed: busy ? null : () => _uploadAndFulfil(item),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SlActionButton(
                    icon: Icons.school_outlined,
                    label: 'Chiedi a un docente',
                    onPressed: busy ? null : () => _askTeacher(item),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => run(_send(item, 'rejected')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.pureWhite.withValues(alpha: 0.86),
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: p.pureWhite.withValues(alpha: 0.14)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    child: const Text('Non disponibile'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => run(_send(item, 'fulfilled')),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.skyBlue,
                      foregroundColor: p.darkElegance,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: busy
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
                        : const Text('Soddisfa'),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _bubble({required String name, required String time, required String text, required bool mine}) {
    final p = context.palette;
    final initials = name.trim().split(RegExp(r'\s+')).where((v) => v.isNotEmpty).take(2).map((v) => v[0].toUpperCase()).join();
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: mine ? p.brandNightBlue : p.studentBlue,
      child: mine
          ? Icon(Icons.support_agent_rounded, size: 16, color: p.adminAmber)
          : Text(initials.isEmpty ? '?' : initials,
              style: TextStyle(color: p.pureWhite, fontSize: 11, fontWeight: FontWeight.w700)),
    );
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? p.skyBlue.withValues(alpha: 0.10) : p.eleganceMidnight,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(mine ? 12 : 4),
            topRight: Radius.circular(mine ? 4 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(time.isEmpty ? name : '$name · $time',
              style: TextStyle(color: p.pureWhite.withValues(alpha: 0.80), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(text, style: SlText.body(p).copyWith(color: p.pureWhite)),
        ]),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: mine ? <Widget>[bubble, const SizedBox(width: 10), avatar] : <Widget>[avatar, const SizedBox(width: 10), bubble],
    );
  }
}
