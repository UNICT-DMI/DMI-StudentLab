import 'package:flutter/material.dart';

import '../../services/api_service.dart';

/// Unknown courses: catalogue association, separate from graduation checks.
class AdminAcademicCatalogPage extends StatefulWidget {
  const AdminAcademicCatalogPage({super.key});

  @override
  State<AdminAcademicCatalogPage> createState() => _AdminAcademicCatalogPageState();
}

class _AdminAcademicCatalogPageState extends State<AdminAcademicCatalogPage> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.getAcademicCatalogRequests(admin: true);
      if (mounted) setState(() => _requests = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _automatic(Map<String, dynamic> row) async {
    try {
      await _api.retryAcademicCatalogRequest(row['id'] as int);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    final note = TextEditingController();
    final String? reason = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Chiedi una correzione'),
      content: TextField(controller: note, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Spiega cosa correggere')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(ctx, note.text.trim()), child: const Text('Invia'))]));
    note.dispose();
    if (reason == null || reason.isEmpty) return;
    try {
      await _api.decideAcademicCatalogRequest(row['id'] as int,
          {'status': 'rejected', 'note': reason});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _assign(Map<String, dynamic> row) async {
    const keys = ['university', 'university_code', 'department', 'department_code',
      'course', 'course_code', 'degree_type'];
    const labels = ['Ateneo', 'Codice ateneo', 'Dipartimento', 'Codice dipartimento',
      'Corso', 'Codice ufficiale del corso', 'Tipo di laurea (facoltativo)'];
    final inputs = <String, TextEditingController>{
      for (final key in keys) key: TextEditingController(text: '${row[key] ?? ''}')};
    final suggestions = (row['suggestions'] as List? ?? [])
        .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    final bool? confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Associa percorso universitario'),
      content: SizedBox(width: 550, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Confronta i dati dichiarati con una fonte ufficiale prima di assegnare i codici.'),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Corrispondenze possibili (da confermare):'),
            for (final match in suggestions)
              TextButton(onPressed: () {
                for (final key in keys) inputs[key]!.text = '${match[key] ?? ''}';
              }, child: Text('${match['course']} · ${match['department']}')),
          ],
          for (var i = 0; i < keys.length; i++) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(controller: inputs[keys[i]],
              decoration: InputDecoration(labelText: labels[i])),
          ),
        ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assegna'))]));
    final data = {for (final key in keys) key: inputs[key]!.text.trim()};
    for (final controller in inputs.values) { controller.dispose(); }
    if (confirmed != true) return;
    if (keys.take(6).any((key) => data[key]!.isEmpty)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compila ateneo, dipartimento, corso e tutti e tre i codici.')));
      return;
    }
    try {
      await _api.decideAcademicCatalogRequest(row['id'] as int,
          {'status': 'assigned', ...data});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Corsi da associare'), actions: [
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Aggiorna')]),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Text(_error!))
      : _requests.isEmpty ? const Center(child: Text('Nessun corso in attesa.'))
      : ListView.builder(itemCount: _requests.length, itemBuilder: (context, index) {
          final row = _requests[index];
          return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(padding: const EdgeInsets.all(14), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${row['course']}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('${row['department']} · ${row['university']}'),
                Text('Dichiarato da ${row['name']} · ${row['email']}'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton(onPressed: () => _automatic(row), child: const Text('Riconosci dal catalogo')),
                  FilledButton(onPressed: () => _assign(row), child: const Text('Associa manualmente')),
                  TextButton(onPressed: () => _reject(row), child: const Text('Chiedi correzione')),
                ]),
              ])));
        }),
  );
}
