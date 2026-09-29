import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../theme/app_palette.dart';
import '../../widgets/studentlab_ui/studentlab_ui.dart';

/// Coda "Corsi aggiuntivi": proposte di corsi fuori dal catalogo ufficiale.
///
/// Un corso approvato diventa un corso del dipartimento con la sola materia
/// "Materiali del corso": gli studenti vedono subito i file, senza scegliere
/// materie o argomenti (vedi `_linkApprovedCourses` in StudentMaterialPage).
class AdminMaterialCourseProposalsPage extends StatefulWidget {
  const AdminMaterialCourseProposalsPage({super.key});

  @override
  State<AdminMaterialCourseProposalsPage> createState() =>
      _AdminMaterialCourseProposalsPageState();
}

class _AdminMaterialCourseProposalsPageState extends State<AdminMaterialCourseProposalsPage> {
  static const double _wideBreakpoint = 960;

  /// Stesso host di ApiService: niente URL duplicati nel codice.
  final String _base = ApiService().baseUrl;
  List<Map<String, dynamic>> _items = [];
  String? _error;
  bool _loading = true;
  int? _busyId;
  int? _selectedId;
  String _status = 'pending';

  final TextEditingController _universityCode = TextEditingController();
  final TextEditingController _departmentCode = TextEditingController();
  final TextEditingController _courseCode = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _universityCode.dispose();
    _departmentCode.dispose();
    _courseCode.dispose();
    super.dispose();
  }

  Map<String, String> get _headers {
    final token = AuthSession.instance.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sessione amministrativa non disponibile.');
    }
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'Accept': 'application/json'};
  }

  String _errorDetail(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map && value['detail'] != null) return value['detail'].toString();
    } catch (_) {}
    return 'Operazione non riuscita. Controlla i dati e riprova.';
  }

  int? _id(Map<String, dynamic> item) => int.tryParse(item['id']?.toString() ?? '');

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(Uri.parse('$_base/materials/course-proposals/admin'), headers: _headers);
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(_errorDetail(response));
      final values = jsonDecode(response.body) as List;
      if (!mounted) return;
      setState(() {
        _items = values.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();
        _loading = false;
        final shown = _shown;
        if (_selectedId == null || !shown.any((i) => _id(i) == _selectedId)) {
          _select(shown.isEmpty ? null : shown.first);
        }
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Non è stato possibile caricare i corsi. Riprova.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _shown => _items
      .where((i) => _status == 'all' || (i['status']?.toString() ?? 'pending') == _status)
      .toList();

  int _count(String status) => _items.where((i) => (i['status']?.toString() ?? 'pending') == status).length;

  /// Propone codici leggibili dai nomi; l'admin li può correggere.
  String _suggestCode(String? value, {int max = 8}) {
    final words = (value ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w.length > 2).toList();
    if (words.isEmpty) return '';
    final String code = words.length == 1 ? words.first : words.map((w) => w[0]).join();
    return code.length > max ? code.substring(0, max) : code;
  }

  void _select(Map<String, dynamic>? item) {
    _selectedId = item == null ? null : _id(item);
    _universityCode.text = item?['university_code']?.toString() ?? _suggestCode(item?['university']?.toString());
    _departmentCode.text = item?['department_code']?.toString() ?? _suggestCode(item?['department']?.toString());
    _courseCode.text = item?['course_code']?.toString() ?? _suggestCode(item?['course']?.toString());
  }

  void _message(String text) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(MaterialBanner(
      content: Text(text), leading: const Icon(Icons.info_outline),
      actions: [TextButton(onPressed: () => messenger.hideCurrentMaterialBanner(),
        child: const Text('Chiudi'))]));
  }

  Future<bool> _approve(Map<String, dynamic> item) async {
    final id = _id(item);
    if (id == null) return false;
    final body = {
      'university_code': _universityCode.text.trim(),
      'department_code': _departmentCode.text.trim(),
      'course_code': _courseCode.text.trim(),
    };
    if (body.values.any((value) => value.length < 2)) {
      _message('Completa i tre codici (almeno 2 caratteri).');
      return false;
    }
    return _post(id, 'approve', body, 'Corso approvato: gli studenti lo trovano tra i corsi del dipartimento.');
  }

  Future<bool> _reject(Map<String, dynamic> item) async {
    final id = _id(item);
    if (id == null) return false;
    final p = context.palette;
    final controller = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: const Text('Rifiuta proposta di corso'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
              for (final preset in const <String>[
                'Il corso esiste già nel catalogo.',
                'Il corso non appartiene al dipartimento indicato.',
                'Servono più informazioni sul corso.',
              ])
                ActionChip(label: Text(preset, style: const TextStyle(fontSize: 12)),
                    onPressed: () => update(() => controller.text = preset)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: controller, onChanged: (_) => update(() {}), minLines: 2, maxLines: 4,
                decoration: const InputDecoration(labelText: 'Motivo del rifiuto')),
          ]),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.adminCoral, foregroundColor: p.darkElegance),
            onPressed: controller.text.trim().length < 3 ? null : () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Rifiuta'),
          ),
        ],
      )),
    );
    controller.dispose();
    if (reason == null) return false;
    return _post(id, 'reject', {'reason': reason}, 'Proposta rifiutata.');
  }

  Future<bool> _post(int id, String action, Map<String, String> body, String success) async {
    setState(() => _busyId = id);
    try {
      final response = await http.post(Uri.parse('$_base/materials/course-proposals/admin/$id/$action'),
          headers: _headers, body: jsonEncode(body));
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(_errorDetail(response));
      _message(success);
      await _load();
      return true;
    } catch (e) {
      _message('Operazione non riuscita. Controlla i dati e riprova.');
      return false;
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pending = _count('pending');
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: slAdminAppBar(context, title: 'Corsi aggiuntivi', actions: <Widget>[
        if (!_loading && pending > 0)
          Center(child: SlStatusBadge(label: '$pending da valutare', tone: SlTone.warning)),
        IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideBreakpoint;
          final filters = Padding(
            padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 0),
            child: SlFilterBar<String>(
              selected: _status,
              options: <SlFilterOption<String>>[
                SlFilterOption(value: 'pending', label: 'Da valutare', count: _loading ? null : pending),
                SlFilterOption(value: 'approved', label: 'Approvati', count: _loading ? null : _count('approved')),
                SlFilterOption(value: 'rejected', label: 'Rifiutati', count: _loading ? null : _count('rejected')),
                const SlFilterOption(value: 'all', label: 'Tutti'),
              ],
              onSelected: (value) => setState(() {
                _status = value;
                final shown = _shown;
                _select(shown.isEmpty ? null : shown.first);
              }),
            ),
          );
          if (_loading && _items.isEmpty) {
            return Column(children: <Widget>[filters, Expanded(child: Center(child: CircularProgressIndicator(color: p.skyBlue)))]);
          }
          if (_error != null) {
            return Column(children: <Widget>[
              filters,
              Padding(padding: const EdgeInsets.all(16), child: SlErrorCard(title: 'Proposte non disponibili', message: _error!, onRetry: _load)),
            ]);
          }
          final shown = _shown;
          final list = RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(wide ? 8 : 16),
              children: <Widget>[
                if (shown.isEmpty)
                  const SlEmptyState(
                    icon: Icons.school_outlined,
                    title: 'Nessuna proposta di corso',
                    message: 'Le proposte arrivano quando uno studente carica materiale per un corso che non è ancora nel catalogo.',
                  )
                else
                  for (final item in shown) _tile(item, wide),
              ],
            ),
          );
          if (!wide) return Column(children: <Widget>[filters, Expanded(child: list)]);
          final matches = shown.where((i) => _id(i) == _selectedId);
          final Map<String, dynamic>? selected = matches.isNotEmpty ? matches.first : null;
          return Column(children: <Widget>[
            filters,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  SizedBox(
                    width: 400,
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.eleganceMidnight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: p.skyBlue.withValues(alpha: 0.12)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: list,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: selected == null
                        ? const SlEmptyState(icon: Icons.touch_app_outlined, title: 'Seleziona una proposta', message: 'I dettagli compaiono qui.')
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

  (String, SlTone) _statusBadge(String? status) => switch (status) {
        'approved' => ('Approvato', SlTone.success),
        'rejected' => ('Rifiutato', SlTone.danger),
        _ => ('Da valutare', SlTone.warning),
      };

  Widget _tile(Map<String, dynamic> item, bool wide) {
    final p = context.palette;
    final selected = wide && _id(item) == _selectedId;
    final (label, tone) = _statusBadge(item['status']?.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? p.skyBlue.withValues(alpha: 0.10) : (wide ? Colors.transparent : p.eleganceMidnight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? p.skyBlue.withValues(alpha: 0.36) : (wide ? Colors.transparent : p.skyBlue.withValues(alpha: 0.12))),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (wide) {
              setState(() => _select(item));
            } else {
              setState(() => _select(item));
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
                backgroundColor: context.palette.darkElegance,
                appBar: slAdminAppBar(context, title: 'Proposta di corso', breadcrumb: 'ADMIN / CORSI AGGIUNTIVI'),
                body: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: _detail(item, popOnDone: true))),
              )));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(item['course']?.toString() ?? 'Corso',
                  style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${item['university'] ?? '—'} › ${item['department'] ?? '—'}', style: SlText.muted(p)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                SlStatusBadge(label: label, tone: tone),
                const SlStatusBadge(label: 'Corso del dipartimento', tone: SlTone.violet),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _detail(Map<String, dynamic> item, {bool popOnDone = false}) {
    final p = context.palette;
    final id = _id(item);
    final busy = id != null && _busyId == id;
    final pending = (item['status']?.toString() ?? 'pending') == 'pending';
    Future<void> run(Future<bool> action) async {
      final ok = await action;
      if (ok && popOnDone && mounted) Navigator.of(context).pop();
    }

    InputDecoration codeDecoration(String label) => InputDecoration(labelText: label, isDense: true, fillColor: p.darkElegance);

    return Container(
      decoration: BoxDecoration(
        color: p.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.skyBlue.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: <Widget>[
            const SlIconTile(icon: Icons.school_outlined, tone: SlTone.violet, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(item['course']?.toString() ?? 'Corso', style: TextStyle(color: p.pureWhite, fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${item['university'] ?? '—'} › ${item['department'] ?? '—'}', style: SlText.muted(p)),
              ]),
            ),
          ]),
        ),
        Divider(height: 1, color: p.pureWhite.withValues(alpha: 0.07)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(builder: (context, c) {
              final codes = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                const SlOverline('Identificativi del catalogo'),
                const SizedBox(height: 8),
                if (pending) ...<Widget>[
                  TextField(controller: _universityCode, decoration: codeDecoration('Codice ateneo'), style: SlText.mono(p, size: 14, color: p.pureWhite)),
                  const SizedBox(height: 10),
                  TextField(controller: _departmentCode, decoration: codeDecoration('Codice dipartimento'), style: SlText.mono(p, size: 14, color: p.pureWhite)),
                  const SizedBox(height: 10),
                  TextField(controller: _courseCode, decoration: codeDecoration('Codice corso'), style: SlText.mono(p, size: 14, color: p.pureWhite)),
                  const SizedBox(height: 8),
                  Text('Codici suggeriti dai nomi: controllali prima di approvare.', style: SlText.muted(p)),
                ] else ...<Widget>[
                  SlKeyValue(label: 'Stato', value: _statusBadge(item['status']?.toString()).$1),
                  if (item['rejection_reason'] != null) SlKeyValue(label: 'Motivo', value: item['rejection_reason'].toString()),
                ],
              ]);
              final preview = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                const SlOverline('Come lo vedranno gli studenti'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.eleganceSoftNight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    _treeLine('ATENEO', item['university']?.toString() ?? '—', 0),
                    _treeLine('DIP.', item['department']?.toString() ?? '—', 1),
                    _treeLine('CORSO', item['course']?.toString() ?? '—', 2, strong: true),
                    Padding(
                      padding: const EdgeInsets.only(left: 42, top: 6),
                      child: Row(children: <Widget>[
                        Icon(Icons.insert_drive_file_outlined, size: 16, color: p.pureWhite.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Text('I file del corso', style: SlText.body(p)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Text('Niente livello “Materia”: i file compaiono appena lo studente apre il corso.', style: SlText.muted(p)),
                  ]),
                ),
              ]);
              return c.maxWidth >= 640
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      Expanded(child: codes), const SizedBox(width: 18), Expanded(child: preview)])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[codes, const SizedBox(height: 18), preview]);
            }),
          ),
        ),
        if (pending) ...<Widget>[
          Divider(height: 1, color: p.pureWhite.withValues(alpha: 0.07)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: <Widget>[
              OutlinedButton(
                onPressed: busy ? null : () => run(_reject(item)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.adminCoral,
                  minimumSize: const Size(0, 44),
                  side: BorderSide(color: p.adminCoral.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Rifiuta…'),
              ),
              FilledButton(
                onPressed: busy ? null : () => run(_approve(item)),
                style: FilledButton.styleFrom(
                  backgroundColor: p.skyBlue,
                  foregroundColor: p.darkElegance,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: busy
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
                    : const Text('Approva corso'),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _treeLine(String level, String value, int depth, {bool strong = false}) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0, top: 4, bottom: 4),
      child: Row(children: <Widget>[
        SizedBox(width: 64, child: Text(level, style: SlText.mono(p, size: 11, color: strong ? p.adminIndigo : p.pureWhite.withValues(alpha: 0.56)))),
        Expanded(child: Text(value, style: SlText.body(p).copyWith(color: p.pureWhite, fontWeight: strong ? FontWeight.w600 : FontWeight.w400))),
      ]),
    );
  }
}
