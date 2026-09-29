import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/picked_file_bridge.dart';
import '../social/social_models.dart';
import '../theme/nightTheme.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import '../developer/theme/developer_ui_style.dart';
import 'StudentMaterialPage.dart';

class MaterialRequestsPage extends StatefulWidget {
  final int? initialSubjectId;
  final String? initialSubjectName;
  final bool hasTeacherMaterials;

  /// Azione da avviare all'apertura: 'teacher' (docenti; StudentLab se la
  /// materia non ne ha), 'studentlab' oppure 'student'. `null` apre solo l'elenco.
  final String? initialAction;

  const MaterialRequestsPage({
    super.key,
    this.initialSubjectId,
    this.initialSubjectName,
    this.hasTeacherMaterials = false,
    this.initialAction,
  });

  @override
  State<MaterialRequestsPage> createState() => _MaterialRequestsPageState();
}

class _MaterialRequestsPageState extends State<MaterialRequestsPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final PickedFileBridge _fileBridge = PickedFileBridge();
  late final TabController _tabs;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;
  bool _noticeIsError = false;
  List<Map<String, dynamic>> _teacherRequests = [];
  List<Map<String, dynamic>> _sentStudentRequests = [];
  List<Map<String, dynamic>> _receivedStudentRequests = [];
  List<SocialUser> _students = [];
  Map<int, String> _subjectNames = {};
  int _statusFilter = 0;
  int? _subjectId;
  String? _subjectName;
  bool _hasTeacherMaterials = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _subjectId = widget.initialSubjectId;
    _subjectName = widget.initialSubjectName;
    _hasTeacherMaterials = widget.hasTeacherMaterials;
    _load().then((_) => _runInitialAction());
  }

  /// Apre subito il modulo scelto dal pannello "Richiedi o pubblica".
  Future<void> _runInitialAction() async {
    final String? action = widget.initialAction;
    if (!mounted || action == null || _busy) return;
    if (!await _ensureSubject() || !mounted) return;
    if (action == 'teacher') {
      await _createTeacherRequest();
    } else if (action == 'studentlab') {
      await _createTeacherRequest(recipientKind: 'studentlab');
    } else if (action == 'student') {
      await _createStudentRequest();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        _api.getMyTeacherMaterialRequests(),
        _api.getMyStudentMaterialRequests(),
        _api.getReceivedStudentMaterialRequests(),
        _api.getSocialUsers().catchError((Object _) => <SocialUser>[]),
        _api.getMaterialRequestSubjects().catchError((Object _) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _teacherRequests = List<Map<String, dynamic>>.from(results[0] as List);
        _sentStudentRequests = List<Map<String, dynamic>>.from(
          results[1] as List,
        );
        _receivedStudentRequests = List<Map<String, dynamic>>.from(
          results[2] as List,
        );
        _students =
            (results[3] as List<SocialUser>)
                .where((user) => user.isStudent && user.isActive)
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        _subjectNames = {
          for (final option in List<Map<String, dynamic>>.from(results[4] as List))
            if (int.tryParse('${option['subject_id']}') != null)
              int.parse('${option['subject_id']}'): '${option['subject_name'] ?? 'Materia'}',
        };
      });
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _ensureSubject() async {
    if (_subjectId != null) return true;
    try {
      final options = await _api.getMaterialRequestSubjects();
      if (!mounted) return false;
      if (options.isEmpty) {
        _message('Nessuna materia disponibile nel tuo percorso accademico.');
        return false;
      }
      final chosen = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: AppColors.eleganceDeepNavy,
        isScrollControlled: true,
        builder: (context) => SafeArea(child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(children: [
            Padding(padding: EdgeInsets.all(18), child: Text('Scegli la materia',
              style: TextStyle(color: AppColors.white, fontSize: 19))),
            Expanded(child: ListView.builder(itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  title: Text(option['subject_name']?.toString() ?? 'Materia',
                    style: TextStyle(color: AppColors.white)),
                  subtitle: Text('${option['course'] ?? ''} · anno ${option['study_year'] ?? '—'} · ${option['recipient_kind'] == 'teachers' ? 'Docenti' : 'StudentLab'}',
                    style: TextStyle(color: AppColors.white70)),
                  onTap: () => Navigator.pop(context, option),
                );
              })),
          ]))),
      );
      if (chosen == null || !mounted) return false;
      setState(() {
        _subjectId = int.tryParse(chosen['subject_id'].toString());
        _subjectName = chosen['subject_name']?.toString();
        _hasTeacherMaterials = false;
      });
      return _subjectId != null;
    } catch (e) {
      if (mounted) _showNotice(_friendly(e), isError: true);
      return false;
    }
  }

  bool _matchesStatus(String status) => switch (_statusFilter) {
    1 => status == 'pending',
    2 => status == 'declined' || status == 'rejected',
    3 => status == 'fulfilled',
    _ => true,
  };

  Future<void> _showRequestActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.school_outlined), title: const Text('Richiedi a un docente'),
          onTap: () => Navigator.pop(context, 'teacher')),
        ListTile(leading: const Icon(Icons.person_outline), title: const Text('Richiedi a uno studente'),
          onTap: () => Navigator.pop(context, 'student')),
        ListTile(leading: const Icon(Icons.upload_file_outlined), title: const Text('Pubblica materiale'),
          onTap: () => Navigator.pop(context, 'publish')),
      ])),
    );
    if (!mounted || action == null) return;
    if (action == 'publish') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const StudentMaterialPage(initialAction: 'publish')));
      return;
    }
    // Ogni richiesta parte dalla scelta della materia del proprio corso.
    setState(() { _subjectId = null; _subjectName = null; });
    if (!await _ensureSubject() || !mounted) return;
    if (action == 'student') {
      await _createStudentRequest();
    } else {
      await _createTeacherRequest();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Richieste materiali'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Le mie richieste'),
            Tab(text: 'Ricevute'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _showRequestActions,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Richiedi o pubblica'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: DeveloperUiStyle.maxContentWidth),
              child: Column(children: [
                if (_notice != null) Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Semantics(liveRegion: true, child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: _noticeIsError
                          ? const Color(0xFF472F39)
                          : AppColors.eleganceMidnight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _noticeIsError
                          ? const Color(0xFFD58C95)
                          : AppColors.materialSky),
                    ),
                    child: Row(children: [
                      Icon(_noticeIsError ? Icons.info_outline_rounded : Icons.check_circle_outline,
                        color: _noticeIsError ? const Color(0xFFFFC2C6) : AppColors.materialSky),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_notice!, style: TextStyle(color: AppColors.white))),
                      IconButton(tooltip: 'Chiudi avviso',
                        onPressed: () => setState(() => _notice = null),
                        icon: Icon(Icons.close_rounded, color: AppColors.white70)),
                    ]),
                  )),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (var i = 0; i < 4; i++) Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(const ['Tutte', 'In attesa', 'Rifiutate', 'Accettate'][i]),
                          selected: _statusFilter == i,
                          onSelected: (_) => setState(() => _statusFilter = i),
                        ),
                      ),
                    ]))),
                Expanded(child: TabBarView(controller: _tabs,
                  children: [_buildSent(), _buildReceived()])),
              ]))),
    );
  }

  Widget _buildSent() {
    final items =
        <_RequestViewItem>[
          ..._teacherRequests.map((e) => _RequestViewItem('teacher', e)),
          ..._sentStudentRequests.map((e) => _RequestViewItem('student', e)),
        ]..sort(
          (a, b) => _date(
            b.data['created_at'],
          ).compareTo(_date(a.data['created_at'])),
        );
    items.removeWhere((item) => !_matchesStatus('${item.data['status'] ?? 'pending'}'));

    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.outbox_outlined,
        title: 'Nessuna richiesta inviata',
        subtitle:
            'Le richieste ai docenti e agli altri studenti compariranno qui.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final data = item.data;
          final status = data['status']?.toString() ?? 'pending';
          final pending = status == 'pending';
          return _RequestCard(
            subject: data['subject_name']?.toString() ?? _subjectNames[_toInt(data['subject_id'])] ?? 'Materia',
            title: item.kind == 'teacher'
                ? (data['recipient_kind'] == 'studentlab' ? 'Richiesta a StudentLab' : 'Richiesta a ${data['teacher_name'] ?? 'docenti della materia'}')
                : 'Richiesta a ${data['recipient_name'] ?? _userName(_toInt(data['recipient_user_id'])) ?? 'studente'}',
            topic: data['topic']?.toString(),
            message: '${data['message']?.toString() ?? ''}${data['staff_response'] == null ? '' : '\n\nRisposta StudentLab: ${data['staff_response']}'}',
            status: status,
            date: _dateLabel(data['created_at']),
            trailing: pending
                ? TextButton(
                    onPressed: _busy ? null : () => _cancel(item),
                    child: const Text('Annulla'),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildReceived() {
    final received = _receivedStudentRequests.where((data) => _matchesStatus('${data['status'] ?? 'pending'}')).toList();
    if (received.isEmpty) {
      return const _EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Nessuna richiesta ricevuta',
        subtitle:
            'Quando uno studente ti chiede del materiale, la richiesta comparirà qui.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: received.length,
        itemBuilder: (context, index) {
          final data = received[index];
          final status = data['status']?.toString() ?? 'pending';
          final requesterId = _toInt(data['requester_user_id']);
          final requester = _userName(requesterId);
          return _RequestCard(
            subject: data['subject_name']?.toString() ?? _subjectNames[_toInt(data['subject_id'])] ?? 'Materia',
            title: requester == null
                ? '${data['requester_name'] ?? 'Uno studente'} ti ha richiesto un materiale'
                : '$requester ti ha richiesto un materiale',
            topic: data['topic']?.toString(),
            message: data['message']?.toString() ?? '',
            status: status,
            date: _dateLabel(data['created_at']),
            trailing: status == 'pending'
                ? Wrap(
                    spacing: 6,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : () => _decline(data),
                        child: const Text('Non ce l’ho'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _fulfill(data),
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Condividi'),
                      ),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }

  Future<void> _createStudentRequest() async {
    if (_students.isEmpty || _subjectId == null) {
      _message('Non ci sono studenti disponibili a cui inviare la richiesta.');
      return;
    }

    int? recipientId;
    final topic = TextEditingController();
    final message = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: Text(
            'Chiedi materiale a uno studente',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((_subjectName ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _subjectName!,
                        style: TextStyle(color: AppColors.white70),
                      ),
                    ),
                  ),
                DropdownButtonFormField<int>(
                  value: recipientId,
                  dropdownColor: AppColors.eleganceDeepNavy,
                  decoration: const InputDecoration(
                    labelText: 'Studente destinatario',
                  ),
                  items: _students
                      .map(
                        (user) => DropdownMenuItem(
                          value: user.id,
                          child: Text(user.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => recipientId = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: topic,
                  decoration: const InputDecoration(
                    labelText: 'Argomento facoltativo',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: message,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Di quale materiale hai bisogno?',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Invia'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || recipientId == null || message.text.trim().isEmpty) {
      topic.dispose();
      message.dispose();
      return;
    }
    if (!await _confirmNoExistingMaterial('${topic.text} ${message.text}')) {
      topic.dispose();
      message.dispose();
      return;
    }

    await _run(() async {
      await _api.createStudentMaterialRequest(
        recipientUserId: recipientId!,
        subjectId: _subjectId,
        topic: topic.text.trim(),
        message: message.text.trim(),
      );
      _message('Richiesta inviata allo studente.');
      await _load();
    });
    topic.dispose();
    message.dispose();
  }

  /// "Forse c'è già": prima di inviare una richiesta cerca, tra i materiali
  /// che lo studente può già leggere, quelli che corrispondono al testo.
  /// Restituisce true se si può inviare la richiesta.
  Future<bool> _confirmNoExistingMaterial(String text) async {
    final int? subjectId = _subjectId;
    if (subjectId == null) return true;
    List<Map<String, dynamic>> found;
    try {
      found = await _api.getMaterialRequestSuggestions(subjectId: subjectId, query: text);
    } catch (_) {
      return true; // la ricerca è un aiuto: se non risponde, la richiesta parte comunque
    }
    if (found.isEmpty || !mounted) return true;
    final String? choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Row(children: [
          Icon(Icons.search_rounded, color: AppColors.adminGreen),
          const SizedBox(width: 8),
          Text('Forse c’è già', style: TextStyle(color: AppColors.adminGreen)),
        ]),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Questi materiali di ${_subjectName ?? 'questa materia'} sono già disponibili per te:',
                    style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.78))),
                const SizedBox(height: 12),
                for (final item in found)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.eleganceMidnight,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.adminGreen.withValues(alpha: 0.24)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['title']?.toString() ?? item['original_name']?.toString() ?? 'Materiale',
                          style: TextStyle(color: AppColors.pureWhite, fontWeight: FontWeight.w600)),
                      if (item['path_segments'] is List && (item['path_segments'] as List).isNotEmpty)
                        Text((item['path_segments'] as List).join(' › '),
                            style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60), fontSize: 12)),
                    ]),
                  ),
                Text('Li trovi nelle Dispense, nella materia.',
                    style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60), fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'open'),
            child: const Text('Vai alle Dispense'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'send'),
            child: const Text('Non è quello, invia'),
          ),
        ],
      ),
    );
    if (choice == 'open' && mounted) {
      Navigator.of(context).pop();
      return false;
    }
    return choice == 'send';
  }

  Future<void> _createTeacherRequest({String? recipientKind}) async {
    final bool toStudentLab = recipientKind == 'studentlab';
    final subjectId = _subjectId;
    if (subjectId == null) return;
    if (_hasTeacherMaterials && !toStudentLab) {
      final proceed = await showDialog<bool>(context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: Text('Materiale docente già disponibile',
            style: TextStyle(color: AppColors.pureWhite)),
          content: Text('Per questa materia ci sono già materiali del docente. Controlla la cartella prima di richiederne altri.',
            style: TextStyle(color: AppColors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vedi materiali')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Richiedi comunque')),
          ]));
      if (proceed != true || !mounted) return;
    }
    // Modulo a pagina intera (canvas "Richiesta al docente"): controlla da solo
    // i materiali già disponibili mentre lo studente scrive.
    final (String, String)? form = await Navigator.of(context).push<(String, String)>(
      MaterialPageRoute(
        builder: (_) => _MaterialRequestFormPage(
          api: _api,
          subjectId: subjectId,
          subjectName: _subjectName,
          toStudentLab: toStudentLab,
        ),
      ),
    );
    if (form == null || !mounted) return;
    final topicText = form.$1;
    final messageText = form.$2;
    await _run(() async {
      final response = await _api.createTeacherMaterialRequest(subjectId: subjectId,
        topic: topicText, message: messageText, recipientKind: recipientKind);
      _message(response['recipient_kind'] == 'studentlab'
        ? (toStudentLab
            ? 'Richiesta inviata a StudentLab.'
            : 'Nessun docente registrato: richiesta inviata a StudentLab.')
        : 'Richiesta inviata ai docenti registrati.');
      await _load();
    });
  }

  Future<void> _cancel(_RequestViewItem item) async {
    final id = _toInt(item.data['id']);
    if (id == null) return;
    await _run(() async {
      if (item.kind == 'teacher') {
        await _api.cancelTeacherMaterialRequest(id);
      } else {
        await _api.cancelStudentMaterialRequest(id);
      }
      await _load();
    });
  }

  Future<void> _decline(Map<String, dynamic> data) async {
    final id = _toInt(data['id']);
    if (id == null) return;
    await _run(() async {
      await _api.resolveStudentMaterialRequest(
        requestId: id,
        action: 'declined',
      );
      await _load();
    });
  }

  Future<void> _fulfill(Map<String, dynamic> data) async {
    final requestId = _toInt(data['id']);
    final requesterId = _toInt(data['requester_user_id']);
    if (requestId == null || requesterId == null) return;

    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'txt',
        'zip',
        'docx',
        'pptx',
        'png',
        'jpg',
        'jpeg',
      ],
    );
    if (result == null || result.files.isEmpty) return;

    await _run(() async {
      final file = result.files.single;
      final bytes = file.bytes;
      final share = bytes != null && bytes.isNotEmpty
          ? await _api.shareMaterialBytesWithUser(
              bytes: bytes,
              originalName: file.name,
              recipientUserId: requesterId,
              subjectId: _toInt(data['subject_id']),
              message: 'Materiale condiviso in risposta alla tua richiesta.',
            )
          : await _api.shareMaterialWithUser(
              filePath: await _fileBridge.materialize(file),
              recipientUserId: requesterId,
              subjectId: _toInt(data['subject_id']),
              message: 'Materiale condiviso in risposta alla tua richiesta.',
            );
      final shareId = _toInt(share['id']);
      if (shareId == null) {
        throw StateError(
          'La condivisione non ha restituito un identificativo valido.',
        );
      }
      await _api.resolveStudentMaterialRequest(
        requestId: requestId,
        action: 'fulfilled',
        fulfilledShareId: shareId,
      );
      _message('Materiale condiviso. La richiesta è stata soddisfatta.');
      await _load();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _showNotice(_friendly(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _userName(int? id) {
    if (id == null) return null;
    for (final user in _students) {
      if (user.id == id) return user.name;
    }
    return null;
  }

  DateTime _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _friendly(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('404') || text.contains('not found') || text.contains('non disponibile')) {
      return 'Questa funzione è temporaneamente non disponibile. Riprova più tardi.';
    }
    if (text.contains('socket') || text.contains('network') ||
        text.contains('connection') || text.contains('timeout') ||
        text.contains('host lookup')) {
      return 'Non riusciamo a contattare StudentLab. Controlla la connessione e riprova.';
    }
    if (text.contains('materia del tuo corso') || text.contains('percorso accademico')) {
      return 'Scegli una materia del tuo percorso accademico e riprova.';
    }
    if (text.contains('sessione') || text.contains('401') || text.contains('token')) {
      return 'La sessione è scaduta. Accedi di nuovo per continuare.';
    }
    final detail = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    return detail.length > 8 && detail.length < 240
        ? detail
        : 'Non è stato possibile completare l’operazione. Riprova.';
  }

  void _message(String text) {
    _showNotice(text);
  }

  void _showNotice(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _notice = text;
      _noticeIsError = isError;
    });
  }
}

class _RequestViewItem {
  final String kind;
  final Map<String, dynamic> data;
  const _RequestViewItem(this.kind, this.data);
}

class _RequestCard extends StatelessWidget {
  final String subject;
  final String title;
  final String? topic;
  final String message;
  final String status;
  final String date;
  final Widget? trailing;

  const _RequestCard({
    required this.subject,
    required this.title,
    required this.topic,
    required this.message,
    required this.status,
    required this.date,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: DeveloperUiStyle.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject, style: TextStyle(color: AppColors.skyBlue, fontSize: 13,
              fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.pureWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            if ((topic ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                topic!,
                style: TextStyle(
                  color: AppColors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: AppColors.white70)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  date,
                  style: TextStyle(color: AppColors.white38, fontSize: 11),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'pending' => 'In attesa',
      'fulfilled' => 'Soddisfatta',
      'rejected' || 'declined' => 'Rifiutata',
      'cancelled' => 'Annullata',
      _ => status,
    };
    final color = switch (status) {
      'pending' => AppColors.pendingAmber,
      'fulfilled' => AppColors.correct,
      'declined' || 'rejected' => AppColors.wrong,
      _ => AppColors.white70,
    };
    return Chip(
      backgroundColor: color.withValues(alpha: 0.16),
      side: BorderSide(color: color.withValues(alpha: 0.55)),
      label: Text(label, style: TextStyle(fontSize: 11, color: color,
        fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.white38),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: AppColors.pureWhite,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.redAccent,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.white70),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Riprova')),
          ],
        ),
      ),
    );
  }
}


/// "Richiesta al docente" / "Richiesta a StudentLab" a pagina intera.
/// Restituisce (argomento, messaggio) quando lo studente preme "Invia richiesta".
class _MaterialRequestFormPage extends StatefulWidget {
  final ApiService api;
  final int subjectId;
  final String? subjectName;
  final bool toStudentLab;

  const _MaterialRequestFormPage({
    required this.api,
    required this.subjectId,
    required this.subjectName,
    required this.toStudentLab,
  });

  @override
  State<_MaterialRequestFormPage> createState() => _MaterialRequestFormPageState();
}

class _MaterialRequestFormPageState extends State<_MaterialRequestFormPage> {
  final TextEditingController _topic = TextEditingController();
  final TextEditingController _message = TextEditingController();
  List<Map<String, dynamic>> _suggestions = const [];
  List<String> _teachers = const [];
  bool _dismissedSuggestions = false;
  int _searchTicket = 0;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _topic.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    if (widget.toStudentLab) return;
    try {
      final options = await widget.api.getMaterialRequestSubjects();
      final match = options.where((o) => '${o['subject_id']}' == '${widget.subjectId}');
      if (match.isEmpty || !mounted) return;
      final teachers = match.first['teachers'];
      setState(() => _teachers = teachers is List
          ? teachers.map((t) => (t is Map ? t['name'] : t)?.toString() ?? '').where((n) => n.isNotEmpty).toList()
          : const []);
    } catch (_) {
      // Solo informativo: la richiesta si può inviare comunque.
    }
  }

  /// Cerca materiali già disponibili poco dopo che lo studente smette di scrivere.
  Future<void> _search() async {
    final int ticket = ++_searchTicket;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (ticket != _searchTicket || !mounted) return;
    final String text = '${_topic.text} ${_message.text}'.trim();
    if (text.length < 4) {
      setState(() => _suggestions = const []);
      return;
    }
    try {
      final found = await widget.api.getMaterialRequestSuggestions(subjectId: widget.subjectId, query: text);
      if (ticket == _searchTicket && mounted) {
        setState(() {
          _suggestions = found;
          _dismissedSuggestions = false;
        });
      }
    } catch (_) {
      // La ricerca è un aiuto: se non risponde, il modulo funziona lo stesso.
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.eleganceMidnight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final String recipient = widget.toStudentLab
        ? 'Redazione StudentLab'
        : (_teachers.isEmpty ? 'Docenti della materia' : _teachers.join(', '));
    final bool showSuggestions = _suggestions.isNotEmpty && !_dismissedSuggestions;
    final bool canSend = _message.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.eleganceMidnight,
        foregroundColor: AppColors.pureWhite,
        leading: IconButton(
          tooltip: 'Chiudi',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.toStudentLab ? 'Richiesta a StudentLab' : 'Richiesta al docente'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.eleganceMidnight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                widget.toStudentLab
                    ? const SlIconTile(icon: Icons.mark_email_unread_outlined, tone: SlTone.cyan, size: 34)
                    : CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.teacherIndigo,
                        child: Text(_teachers.isEmpty ? 'D' : _initials(_teachers.first),
                            style: TextStyle(color: AppColors.pureWhite, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(recipient,
                        style: TextStyle(color: AppColors.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(widget.subjectName ?? 'Materia selezionata',
                        style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60), fontSize: 11)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _topic,
              onChanged: (_) => _search(),
              style: TextStyle(color: AppColors.pureWhite),
              decoration: _decoration('Argomento (facoltativo)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _message,
              onChanged: (_) {
                setState(() {});
                _search();
              },
              minLines: 4,
              maxLines: 8,
              maxLength: 3000,
              style: TextStyle(color: AppColors.pureWhite, height: 1.45),
              decoration: _decoration('Cosa ti serve'),
            ),
            if (showSuggestions) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.adminGreen.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.adminGreen.withValues(alpha: 0.32)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Icon(Icons.search_rounded, size: 17, color: AppColors.adminGreen),
                    const SizedBox(width: 8),
                    Text('Forse c’è già',
                        style: TextStyle(color: AppColors.adminGreen, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  for (final item in _suggestions)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.eleganceMidnight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(children: [
                        SlFileTile(kind: slFileKind(null, item['original_name']?.toString()), size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item['title']?.toString() ?? item['original_name']?.toString() ?? 'Materiale',
                                style: TextStyle(color: AppColors.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              item['path_segments'] is List && (item['path_segments'] as List).isNotEmpty
                                  ? (item['path_segments'] as List).join(' › ')
                                  : 'StudentLab · già disponibile',
                              style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60), fontSize: 11),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.adminGreen,
                          minimumSize: const Size(0, 42),
                          side: BorderSide(color: AppColors.adminGreen.withValues(alpha: 0.40)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                        child: const Text('Apri nelle Dispense'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _dismissedSuggestions = true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.pureWhite.withValues(alpha: 0.86),
                          minimumSize: const Size(0, 42),
                          side: BorderSide(color: AppColors.pureWhite.withValues(alpha: 0.14)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                        child: const Text('Non è quello'),
                      ),
                    ),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              widget.toStudentLab
                  ? 'La redazione vede il tuo nome e il corso. Riceverai una notifica quando risponde.'
                  : 'Il docente vede il tuo nome e il corso. Riceverai una notifica quando risponde.',
              style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60), fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: canSend
                  ? () => Navigator.of(context).pop((_topic.text.trim(), _message.text.trim()))
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.skyBlue,
                foregroundColor: AppColors.darkElegance,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('Invia richiesta'),
            ),
          ],
        ),
      ),
    );
  }
}
