import 'package:flutter/material.dart';

import '../material/admin/drive_file_preview.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'faq_api_service.dart';
import 'faq_widgets.dart';

/// Moderazione delle Domande: domande, risposte (anche di ospiti, con
/// allegati) e racconti d'esame restano nascosti finché non vengono
/// approvati qui.
class AdminFaqModerationPage extends StatefulWidget {
  const AdminFaqModerationPage({super.key});

  @override
  State<AdminFaqModerationPage> createState() => _AdminFaqModerationPageState();
}

class _AdminFaqModerationPageState extends State<AdminFaqModerationPage> {
  final FaqApiService _api = FaqApiService();
  String _kind = 'questions';
  Map<String, dynamic> _counts = {};
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int? _busyId;

  static const Map<String, String> _formats = {
    'scritto': 'Scritto',
    'orale': 'Orale',
    'scritto_orale': 'Scritto + orale',
    'progetto': 'Progetto',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([_api.moderationCounts(), _api.moderationQueue(_kind)]);
      _counts = results[0] as Map<String, dynamic>;
      _items = results[1] as List<Map<String, dynamic>>;
    } catch (e) {
      _error = faqError(e, 'Moderazione non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _act(Map<String, dynamic> item, String action) async {
    final id = int.tryParse('${item['id']}');
    if (id == null) return;
    String? note;
    if (action == 'reject') {
      final p = context.palette;
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: const Text('Non pubblicare'),
          content: SizedBox(
            width: 440,
            child: TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Motivo per l’autore (facoltativo)',
                hintText: 'Es. contiene dati personali o una traccia d’esame in corso.',
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Non pubblicare')),
          ],
        ),
      );
      note = controller.text;
      controller.dispose();
      if (ok != true) return;
    }
    setState(() => _busyId = id);
    try {
      await _api.moderate(_kind, id, action, note: note);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = faqError(e, 'Operazione non riuscita.'));
    }
    if (mounted) setState(() => _busyId = null);
  }

  Widget _card(Map<String, dynamic> item) {
    final p = context.palette;
    final id = int.tryParse('${item['id']}');
    final busy = _busyId == id;
    final attachment = item['attachment'] is Map ? Map<String, dynamic>.from(item['attachment'] as Map) : null;
    final List<Widget> content;
    if (_kind == 'questions') {
      content = [
        Wrap(spacing: 6, runSpacing: 6, children: [
          if ('${item['subject_name'] ?? ''}'.isNotEmpty) SlStatusBadge(label: '${item['subject_name']}', tone: SlTone.info),
          SlStatusBadge(label: faqCategoryLabel(item['category']?.toString()), tone: faqCategoryTone(item['category']?.toString())),
          if (item['ask_teacher'] == true) const SlStatusBadge(label: 'Chiede al docente', tone: SlTone.violet),
          if (item['is_anonymous'] == true) const SlStatusBadge(label: 'Anonima'),
        ]),
        const SizedBox(height: 8),
        Text('${item['title']}', style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
        if ('${item['body'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          SelectableText('${item['body']}', style: SlText.body(p)),
        ],
        const SizedBox(height: 6),
        Text(
          [item['university'], item['department'], item['course']].where((e) => '${e ?? ''}'.isNotEmpty).join(' › '),
          style: SlText.mono(p, size: 11),
        ),
      ];
    } else if (_kind == 'answers') {
      content = [
        Text('Risposta a: ${item['question_title'] ?? 'domanda'}', style: SlText.muted(p)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [
          if (faqRoleBadge(item['author_role']?.toString()) != null) faqRoleBadge(item['author_role']?.toString())!,
          if (item['is_verified'] == true) const SlStatusBadge(label: 'Sarà verificata', tone: SlTone.success),
        ]),
        const SizedBox(height: 6),
        SelectableText('${item['body']}', style: SlText.body(p).copyWith(color: p.pureWhite)),
        if (attachment != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: attachment['type'] == 'file'
                ? () => showDriveFilePreview(
                      context,
                      load: () => _api.downloadAnswerFile('${attachment['url']}'),
                      name: '${attachment['name'] ?? 'allegato'}',
                      mimeType: '${attachment['mime_type'] ?? 'application/octet-stream'}',
                    )
                : null,
            icon: Icon(attachment['type'] == 'file' ? Icons.attach_file_rounded : Icons.menu_book_outlined, size: 16),
            label: Text(attachment['type'] == 'file'
                ? 'Controlla l’allegato: ${attachment['name']}'
                : 'Materiale delle Dispense: ${attachment['name']}'),
          ),
        ],
      ];
    } else {
      content = [
        Wrap(spacing: 6, runSpacing: 6, children: [
          SlStatusBadge(label: '${item['subject_name'] ?? 'Materia'}', tone: SlTone.info),
          SlStatusBadge(label: _formats[item['exam_format']] ?? '${item['exam_format']}'),
          SlStatusBadge(label: 'Difficoltà ${item['difficulty']}/5', tone: SlTone.warning),
          if (item['duration_minutes'] != null) SlStatusBadge(label: '${item['duration_minutes']} min'),
        ]),
        const SizedBox(height: 6),
        Text('Appello del ${item['exam_date']}', style: SlText.muted(p)),
        const SizedBox(height: 6),
        Wrap(spacing: 5, runSpacing: 5, children: [
          for (final t in (item['topics'] as List? ?? [])) SlStatusBadge(label: '$t', tone: SlTone.info),
        ]),
        if ('${item['body'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          SelectableText('${item['body']}', style: SlText.body(p).copyWith(color: p.pureWhite)),
        ],
      ];
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.eleganceMidnight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.adminAmber.withValues(alpha: 0.24)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(
                'Autore: ${item['author_real_name'] ?? item['author_label'] ?? item['author_name'] ?? '—'}'
                '${item['author_label'] != null && item['author_real_name'] != null ? ' · pubblico come “${item['author_label']}”' : ''}',
                style: SlText.muted(p).copyWith(fontSize: 12),
              ),
            ),
            Text(faqRelative(item['created_at']), style: SlText.muted(p).copyWith(fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          ...content,
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => _act(item, 'reject'),
                child: const Text('Non pubblicare'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : () => _act(item, 'approve'),
                style: FilledButton.styleFrom(backgroundColor: p.skyBlue, foregroundColor: p.darkElegance),
                child: busy
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
                    : const Text('Pubblica', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    int count(String key) => int.tryParse('${_counts[key] ?? 0}') ?? 0;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: slAdminAppBar(context, title: 'Domande da controllare', actions: [
        IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SlFilterBar<String>(
                selected: _kind,
                options: [
                  SlFilterOption(value: 'questions', label: 'Domande', count: count('questions')),
                  SlFilterOption(value: 'answers', label: 'Risposte', count: count('answers')),
                  SlFilterOption(value: 'reports', label: 'Racconti d’esame', count: count('reports')),
                ],
                onSelected: (value) {
                  setState(() => _kind = value);
                  _load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: p.skyBlue))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_error != null) ...[
                            SlErrorCard(title: 'Attenzione', message: _error!, onRetry: _load),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            'Niente viene mostrato agli altri prima dell’approvazione. Controlla dati personali, offese, '
                            'tracce di esami in corso e, nelle risposte, l’allegato.',
                            style: SlText.muted(p),
                          ),
                          const SizedBox(height: 12),
                          if (_items.isEmpty)
                            const SlEmptyState(
                              icon: Icons.task_alt_rounded,
                              title: 'Niente da controllare',
                              message: 'Quando arrivano nuovi contenuti compaiono qui.',
                            ),
                          for (final item in _items) _card(item),
                        ],
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
