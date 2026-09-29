import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../material/StudentMaterialPage.dart';
import '../material/admin/drive_file_preview.dart';
import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'faq_api_service.dart';
import 'faq_widgets.dart';

/// Domanda e risposte (canvas: Domande · dettaglio).
///
/// Rispondono anche gli ospiti. Ogni risposta, con testo e un file o un
/// materiale delle Dispense, resta "in attesa di controllo" finché un admin
/// non la approva: l'autore la vede subito, gli altri dopo.
class FaqQuestionPage extends StatefulWidget {
  final int questionId;

  const FaqQuestionPage({super.key, required this.questionId});

  @override
  State<FaqQuestionPage> createState() => _FaqQuestionPageState();
}

class _FaqQuestionPageState extends State<FaqQuestionPage> {
  final FaqApiService _api = FaqApiService();
  final TextEditingController _reply = TextEditingController();
  final TextEditingController _guestName = TextEditingController();

  Map<String, dynamic>? _question;
  List<Map<String, dynamic>> _answers = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _notice;
  String _sort = 'useful';

  // Allegato scelto per la risposta.
  Uint8List? _fileBytes;
  String? _fileName;
  Map<String, dynamic>? _material;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    _guestName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _question == null;
      _error = null;
    });
    try {
      final data = await _api.question(widget.questionId);
      _question = Map<String, dynamic>.from(data['question'] as Map);
      _answers = (data['answers'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _error = faqError(e, 'Domanda non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _sortedAnswers {
    final list = List<Map<String, dynamic>>.of(_answers);
    if (_sort == 'recent') {
      list.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    }
    return list;
  }

  bool _voted(Map<String, dynamic> item, String kind) =>
      item['my_votes'] is List && (item['my_votes'] as List).contains(kind);

  Future<bool> _requireLogin(String action) async {
    if (_api.isAuthenticated) return true;
    setState(() => _notice = 'Per $action serve un account. Da ospite puoi rispondere.');
    return false;
  }

  Future<void> _voteQuestion(String kind) async {
    if (!await _requireLogin(kind == 'useful' ? 'votare' : 'seguire un dubbio')) return;
    try {
      final q = await _api.voteQuestion(widget.questionId, kind);
      setState(() => _question = q);
    } catch (e) {
      setState(() => _notice = faqError(e, 'Voto non registrato.'));
    }
  }

  Future<void> _voteAnswer(Map<String, dynamic> answer) async {
    if (!await _requireLogin('votare')) return;
    try {
      final updated = await _api.voteAnswer(int.parse('${answer['id']}'));
      setState(() {
        final i = _answers.indexWhere((a) => a['id'] == answer['id']);
        if (i >= 0) _answers[i] = {..._answers[i], ...updated};
      });
    } catch (e) {
      setState(() => _notice = faqError(e, 'Voto non registrato.'));
    }
  }

  Future<void> _accept(Map<String, dynamic> answer) async {
    final bool already = answer['is_accepted'] == true;
    try {
      await _api.accept(widget.questionId, already ? null : int.parse('${answer['id']}'));
      await _load();
    } catch (e) {
      setState(() => _notice = faqError(e, 'Operazione non riuscita.'));
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    if (attachment['type'] == 'file') {
      await showDriveFilePreview(
        context,
        load: () => _api.downloadAnswerFile('${attachment['url']}'),
        name: '${attachment['name'] ?? 'allegato'}',
        mimeType: '${attachment['mime_type'] ?? 'application/octet-stream'}',
      );
    } else {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StudentMaterialPage()));
    }
  }

  Future<void> _chooseAttachment() async {
    final p = context.palette;
    final signedIn = _api.isAuthenticated;
    final subjectId = int.tryParse('${_question?['subject_id']}');
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.eleganceDeepNavy,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.upload_file_rounded, color: p.skyBlue),
            title: const Text('Carica un file'),
            subtitle: Text(signedIn ? 'PDF, immagini, TXT, DOCX o PPTX · fino a 4 MB' : 'PDF, PNG o JPG · fino a 2 MB',
                style: SlText.muted(p)),
            onTap: () => Navigator.pop(sheetContext, 'file'),
          ),
          if (signedIn && subjectId != null)
            ListTile(
              leading: Icon(Icons.menu_book_outlined, color: p.adminCyan),
              title: const Text('Scegli dalle Dispense'),
              subtitle: Text('Un materiale della materia che puoi già vedere', style: SlText.muted(p)),
              onTap: () => Navigator.pop(sheetContext, 'material'),
            ),
        ]),
      ),
    );
    if (choice == 'file') {
      final result = await FilePicker.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: signedIn
            ? const ['pdf', 'png', 'jpg', 'jpeg', 'txt', 'docx', 'pptx']
            : const ['pdf', 'png', 'jpg', 'jpeg'],
      );
      final file = result?.files.single;
      if (file?.bytes == null || !mounted) return;
      final limit = signedIn ? 4 * 1024 * 1024 : 2 * 1024 * 1024;
      if (file!.bytes!.length > limit) {
        setState(() => _notice = 'Il file supera ${limit ~/ (1024 * 1024)} MB.');
        return;
      }
      setState(() {
        _fileBytes = file.bytes;
        _fileName = file.name;
        _material = null;
      });
    } else if (choice == 'material' && subjectId != null) {
      List<Map<String, dynamic>> found = [];
      try {
        found = await ApiService().getMaterialRequestSuggestions(subjectId: subjectId, query: '${_question?['title']}');
        if (found.isEmpty) found = await ApiService().getMaterialRequestSuggestions(subjectId: subjectId);
      } catch (_) {}
      if (!mounted) return;
      if (found.isEmpty) {
        setState(() => _notice = 'Nessun materiale delle Dispense disponibile per questa materia.');
        return;
      }
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: p.eleganceDeepNavy,
        builder: (sheetContext) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            for (final m in found)
              ListTile(
                leading: SlFileTile(kind: slFileKind(null, '${m['original_name'] ?? ''}'), size: 36),
                title: Text('${m['title'] ?? m['original_name']}'),
                subtitle: Text(((m['path_segments'] as List?) ?? []).join(' › '), style: SlText.muted(p)),
                onTap: () => Navigator.pop(sheetContext, m),
              ),
          ]),
        ),
      );
      if (picked != null && mounted) {
        setState(() {
          _material = picked;
          _fileBytes = null;
          _fileName = null;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.length < 2) {
      setState(() => _notice = 'Scrivi la risposta.');
      return;
    }
    setState(() {
      _sending = true;
      _notice = null;
    });
    try {
      await _api.answer(
        widget.questionId,
        text,
        materialId: _material == null ? null : int.tryParse('${_material!['id']}'),
        fileBytes: _fileBytes,
        fileName: _fileName,
        guestName: _guestName.text,
      );
      _reply.clear();
      _fileBytes = null;
      _fileName = null;
      _material = null;
      await _load();
      if (mounted) {
        setState(() => _notice = 'Risposta inviata: la vedono gli altri appena StudentLab la controlla.');
      }
    } catch (e) {
      if (mounted) setState(() => _notice = faqError(e, 'Risposta non inviata.'));
    }
    if (mounted) setState(() => _sending = false);
  }

  // --- UI --------------------------------------------------------------------

  Widget _answerCard(Map<String, dynamic> a, bool questionMine) {
    final p = context.palette;
    final bool accepted = a['is_accepted'] == true;
    final bool published = a['status'] == 'published';
    final String name = '${a['author_name'] ?? 'Utente'}';
    final role = faqRoleBadge(a['author_role']?.toString());
    final status = faqStatusBadge(a['status']?.toString());
    final attachment = a['attachment'] is Map ? Map<String, dynamic>.from(a['attachment'] as Map) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.eleganceMidnight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accepted ? p.adminGreen.withValues(alpha: 0.40) : p.pureWhite.withValues(alpha: 0.08),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (accepted || status != null) ...[
            Wrap(spacing: 6, children: [
              if (accepted) const SlStatusBadge(label: 'Risposta accettata', tone: SlTone.success),
              if (status != null) status,
            ]),
            const SizedBox(height: 10),
          ],
          Row(children: [
            faqAvatar(context, name, role: a['author_role']?.toString()),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (role != null) role,
                  Text(faqRelative(a['created_at']), style: SlText.muted(p).copyWith(fontSize: 11)),
                ]),
              ]),
            ),
            if (published)
              FaqVoteButton(
                count: int.tryParse('${a['useful_count']}') ?? 0,
                active: _voted(a, 'useful'),
                onPressed: () => _voteAnswer(a),
              ),
          ]),
          const SizedBox(height: 10),
          SelectableText('${a['body']}', style: SlText.body(p).copyWith(color: p.pureWhite, height: 1.55, fontSize: 14)),
          if (attachment != null) ...[
            const SizedBox(height: 10),
            Material(
              color: p.eleganceDeepNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: p.adminCyan.withValues(alpha: 0.24)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: published || attachment['type'] == 'material' ? () => _openAttachment(attachment) : null,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    SlFileTile(kind: slFileKind(attachment['mime_type']?.toString(), '${attachment['name'] ?? ''}'), size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${attachment['name'] ?? 'Allegato'}',
                            style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          attachment['type'] == 'material'
                              ? 'Nelle Dispense · ${((attachment['path_segments'] as List?) ?? []).join(' › ')}'
                              : (published ? 'File allegato' : 'Visibile dopo il controllo'),
                          style: SlText.muted(p).copyWith(fontSize: 11),
                        ),
                      ]),
                    ),
                    if (published || attachment['type'] == 'material')
                      Text('Apri', style: TextStyle(color: p.adminCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ],
          if (questionMine && published) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _accept(a),
                icon: Icon(accepted ? Icons.close_rounded : Icons.check_rounded, size: 16),
                label: Text(accepted ? 'Non è più la risposta giusta' : 'È la risposta giusta'),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _composer() {
    final p = context.palette;
    final bool guest = !_api.isAuthenticated;
    final String? attachmentName = _fileName ?? (_material == null ? null : '${_material!['title'] ?? _material!['original_name']}');
    return Material(
      color: p.eleganceMidnight,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (guest) ...[
              TextField(
                controller: _guestName,
                maxLength: 60,
                style: TextStyle(color: p.pureWhite, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  counterText: '',
                  labelText: 'Il tuo nome (facoltativo) · rispondi da ospite',
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (attachmentName != null) ...[
              Row(children: [
                Icon(_material != null ? Icons.menu_book_outlined : Icons.attach_file_rounded, size: 16, color: p.adminCyan),
                const SizedBox(width: 6),
                Expanded(child: Text(attachmentName, overflow: TextOverflow.ellipsis, style: SlText.body(p))),
                IconButton(
                  tooltip: 'Togli l’allegato',
                  onPressed: () => setState(() {
                    _fileBytes = null;
                    _fileName = null;
                    _material = null;
                  }),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ]),
              const SizedBox(height: 4),
            ],
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _reply,
                  minLines: 1,
                  maxLines: 6,
                  maxLength: 5000,
                  style: TextStyle(color: p.pureWhite, fontSize: 14),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Scrivi una risposta…',
                    filled: true,
                    fillColor: p.darkElegance,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Allega un file o un materiale',
                onPressed: _sending ? null : _chooseAttachment,
                style: IconButton.styleFrom(
                  minimumSize: const Size(46, 46),
                  side: BorderSide(color: p.adminCyan.withValues(alpha: 0.34)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(Icons.attach_file_rounded, color: p.adminCyan),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Invia',
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(
                  backgroundColor: p.skyBlue,
                  foregroundColor: p.darkElegance,
                  minimumSize: const Size(46, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _sending
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
                    : const Icon(Icons.send_rounded),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Ogni risposta viene controllata da StudentLab prima di essere pubblicata.',
                style: SlText.muted(p).copyWith(fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _question;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(backgroundColor: p.eleganceMidnight, foregroundColor: p.pureWhite, title: const Text('Domanda')),
      bottomNavigationBar: q != null && q['status'] == 'published' ? _composer() : null,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: p.skyBlue))
          : _error != null || q == null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: SlErrorCard(title: 'Domanda non disponibile', message: _error ?? '', onRetry: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                        if (_notice != null) ...[
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                            decoration: BoxDecoration(
                              color: p.eleganceDeepNavy,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.skyBlue.withValues(alpha: 0.24)),
                            ),
                            child: Row(children: [
                              Expanded(child: Text(_notice!, style: SlText.body(p))),
                              IconButton(
                                tooltip: 'Chiudi',
                                onPressed: () => setState(() => _notice = null),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          if (faqStatusBadge(q['status']?.toString()) != null) faqStatusBadge(q['status']?.toString())!,
                          if ('${q['subject_name'] ?? ''}'.isNotEmpty)
                            SlStatusBadge(label: '${q['subject_name']}', tone: SlTone.info),
                          SlStatusBadge(
                              label: faqCategoryLabel(q['category']?.toString()),
                              tone: faqCategoryTone(q['category']?.toString())),
                          if ('${q['course'] ?? ''}'.isNotEmpty) SlStatusBadge(label: '${q['course']}'),
                        ]),
                        const SizedBox(height: 10),
                        Text('${q['title']}',
                            style: TextStyle(color: p.pureWhite, fontSize: 20, fontWeight: FontWeight.w700, height: 1.3)),
                        const SizedBox(height: 8),
                        Row(children: [
                          faqAvatar(context, '${q['author_label']}', size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                '${q['author_label']}${q['is_anonymous'] == true ? ' · anonimo' : ''} · ${faqRelative(q['created_at'])}',
                                style: SlText.muted(p)),
                          ),
                        ]),
                        if ('${q['body'] ?? ''}'.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SelectableText('${q['body']}',
                              style: SlText.body(p).copyWith(color: p.pureWhite, height: 1.55, fontSize: 14)),
                        ],
                        if (q['status'] == 'published') ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            FaqVoteButton(
                              count: int.tryParse('${q['useful_count']}') ?? 0,
                              active: _voted(q, 'useful'),
                              onPressed: () => _voteQuestion('useful'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _voteQuestion('same_doubt'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _voted(q, 'same_doubt') ? p.diamondDust : p.pureWhite.withValues(alpha: 0.86),
                                backgroundColor: _voted(q, 'same_doubt') ? p.skyBlue.withValues(alpha: 0.12) : null,
                                minimumSize: const Size(0, 44),
                                side: BorderSide(
                                    color: _voted(q, 'same_doubt')
                                        ? p.skyBlue.withValues(alpha: 0.40)
                                        : p.pureWhite.withValues(alpha: 0.12)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.notifications_active_outlined, size: 17),
                              label: Text('Ho lo stesso dubbio · ${q['same_doubt_count'] ?? 0}'),
                            ),
                          ]),
                        ] else ...[
                          const SizedBox(height: 12),
                          Text('La tua domanda è in attesa di controllo: sarà visibile a tutti dopo l’approvazione.',
                              style: SlText.muted(p).copyWith(color: p.adminAmber)),
                        ],
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(
                            child: Text('${_answers.where((a) => a['status'] == 'published').length} risposte',
                                style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                          for (final (value, label) in const [('useful', 'Più utili'), ('recent', 'Recenti')])
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: _sort == value,
                                onSelected: (_) => setState(() => _sort = value),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 10),
                        if (_answers.isEmpty)
                          Text('Ancora nessuna risposta. Se sai come funziona, rispondi tu.', style: SlText.muted(p)),
                        for (final a in _sortedAnswers) _answerCard(a, q['is_mine'] == true),
                      ]),
                    ),
                  ),
                ),
    );
  }
}
