import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/picked_file_bridge.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';

class TeacherMaterialRequestsPage extends StatefulWidget {
  const TeacherMaterialRequestsPage({super.key});

  @override
  State<TeacherMaterialRequestsPage> createState() =>
      _TeacherMaterialRequestsPageState();
}

class _TeacherMaterialRequestsPageState
    extends State<TeacherMaterialRequestsPage> {
  final ApiService _api = ApiService();
  final PickedFileBridge _fileBridge = PickedFileBridge();
  int? _busyId;
  String? _error;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await _api.getTeacherMaterialRequests();
      if (!mounted) return;
      setState(() {
        _items = values;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final int? id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;
    try {
      await _api.resolveTeacherMaterialRequest(requestId: id, action: 'rejected');
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error =
        'Non è stato possibile chiudere la richiesta. Riprova.');
    }
  }

  Future<void> _fulfill(Map<String, dynamic> item) async {
    final requestId = int.tryParse(item['id']?.toString() ?? '');
    final recipientId = int.tryParse(item['student_user_id']?.toString() ?? '');
    final subjectId = int.tryParse(item['subject_id']?.toString() ?? '');
    if (requestId == null || recipientId == null || subjectId == null) return;
    final chosen = await FilePicker.pickFiles(allowMultiple: false,
      withData: true, type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'zip', 'docx', 'pptx', 'png', 'jpg', 'jpeg']);
    if (chosen == null || chosen.files.isEmpty || !mounted) return;
    setState(() { _busyId = requestId; _error = null; });
    try {
      final path = await _fileBridge.materialize(chosen.files.single);
      final share = await _api.shareMaterialWithUser(filePath: path,
        recipientUserId: recipientId, subjectId: subjectId,
        message: 'Materiale condiviso privatamente in risposta alla tua richiesta.');
      final shareId = int.tryParse(share['id']?.toString() ?? '');
      if (shareId == null) throw StateError('Condivisione incompleta.');
      await _api.resolveTeacherMaterialRequest(requestId: requestId,
        action: 'fulfilled', fulfilledShareId: shareId);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error =
        'Non è stato possibile inviare il materiale. Controlla la connessione e riprova.');
    } finally {
      if (mounted) setState(() => _busyId = null);
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16),
                    child: Card(child: ListTile(leading: const Icon(Icons.info_outline),
                      title: Text(_error!)))),
                  if (_items.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Text(
                          'Nessuna richiesta disponibile.',
                          style: TextStyle(color: AppColors.white54),
                        ),
                      ),
                    )
                  else
                    ..._items.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.eleganceMidnight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.teacherIndigo.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              children: [
                                _Badge(text: 'RICHIESTA STUDENTE'),
                                _Badge(
                                  text:
                                      (item['status']?.toString() ?? 'pending')
                                          .toUpperCase(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if ((item['topic']?.toString().trim() ?? '')
                                .isNotEmpty)
                              Text(
                                item['topic'].toString(),
                                style: TextStyle(
                                  color: AppColors.pureWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              item['message']?.toString() ?? '',
                              style: TextStyle(
                                color: AppColors.white70,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (item['status'] == 'pending')
                              Wrap(spacing: 8, children: [
                                OutlinedButton(
                                  onPressed: _busyId == null ? () => _reject(item) : null,
                                  child: const Text('Rifiuta richiesta')),
                                FilledButton.icon(
                                  onPressed: _busyId == null ? () => _fulfill(item) : null,
                                  icon: const Icon(Icons.upload_file_outlined),
                                  label: const Text('Condividi privatamente')),
                              ]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandNightBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.materialSky,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
