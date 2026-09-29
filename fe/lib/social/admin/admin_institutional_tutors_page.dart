import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';

class AdminInstitutionalTutorsPage extends StatefulWidget {
  const AdminInstitutionalTutorsPage({super.key});

  @override
  State<AdminInstitutionalTutorsPage> createState() => _AdminInstitutionalTutorsPageState();
}

class _AdminInstitutionalTutorsPageState extends State<AdminInstitutionalTutorsPage> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _api.getPendingInstitutionalTutors();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossibile caricare le richieste. Riprova.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(int id, bool approved) async {
    try {
      await _api.decideInstitutionalTutor(id, approved);
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aggiornare la verifica.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.darkElegance,
    appBar: AppBar(title: const Text('Tutor UNICT da verificare'), actions: [
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator()) :
      _error != null ? Center(child: Text(_error!, style: TextStyle(color: AppColors.pureWhite))) :
      _items.isEmpty ? Center(child: Text('Nessuna richiesta in attesa.',
        style: TextStyle(color: AppColors.pureWhite))) :
      ListView(padding: const EdgeInsets.all(16), children: [
        for (final item in _items) Card(color: AppColors.eleganceMidnight,
          child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name']?.toString() ?? '', style: TextStyle(color: AppColors.pureWhite)),
              Text('${item['university'] ?? ''} · ${item['department'] ?? ''}',
                style: TextStyle(color: AppColors.white70)),
              Text('Corso: ${item['course'] ?? ''}', style: TextStyle(color: AppColors.white70)),
              Text('Verifica percorso: ${item['academic_path_verification'] ?? ''}',
                style: TextStyle(color: AppColors.white70)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () => _decide(item['id'] as int, false),
                  child: const Text('Rifiuta')),
                FilledButton(onPressed: () => _decide(item['id'] as int, true),
                  child: const Text('Verifica')),
              ]),
            ]))),
      ]),
  );
}
