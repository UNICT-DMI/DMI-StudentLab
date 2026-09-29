import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

class DrivePlacement {
  final List<String> path;
  final bool allowDuplicate;
  const DrivePlacement(this.path, this.allowDuplicate);
}

class DrivePlacementDialog extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(List<String>? path) inspect;
  final Future<void> Function(String id, String name, String mimeType)? previewExisting;
  final Future<void> Function()? previewProposed;

  const DrivePlacementDialog({super.key, required this.inspect,
    this.previewExisting, this.previewProposed});

  @override
  State<DrivePlacementDialog> createState() => _DrivePlacementDialogState();
}

class _DrivePlacementDialogState extends State<DrivePlacementDialog> {
  final TextEditingController _path = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;
  bool _acknowledged = false;
  String? _error;
  String? _inspectedPath;

  @override
  void initState() {
    super.initState();
    _inspect(null);
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  List<String> get _segments => _path.text.split('/')
      .map((part) => part.trim()).where((part) => part.isNotEmpty).toList();

  Future<void> _inspect(List<String>? path) async {
    setState(() { _loading = true; _result = null; _error = null; _acknowledged = false; });
    try {
      final result = await widget.inspect(path);
      if (!mounted) return;
      final segments = (result['path'] as List).map((value) => value.toString()).toList();
      _path.text = segments.join('/');
      setState(() {
        _result = result; _inspectedPath = _path.text; _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Non siamo riusciti a controllare le cartelle su Drive. Riprova tra poco. La proposta è ancora in attesa.';
        _loading = false;
      });
    }
  }

  Widget _line(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text('$label: ${value ?? '—'}',
      style: TextStyle(color: AppColors.white70, fontSize: 12)));

  @override
  Widget build(BuildContext context) {
    final proposed = _result?['proposed_file'] is Map
        ? Map<String, dynamic>.from(_result!['proposed_file'] as Map)
        : <String, dynamic>{};
    final conflicts = (_result?['conflicts'] as List? ?? const [])
        .whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    final collision = conflicts.any((row) => row['same_folder'] == true &&
        row['name']?.toString().toLowerCase() == proposed['name']?.toString().toLowerCase());
    final ready = _result != null && !_loading &&
        _path.text == _inspectedPath && !collision &&
        (conflicts.isEmpty || _acknowledged);
    return AlertDialog(
      backgroundColor: AppColors.eleganceDeepNavy,
      title: Text('Percorso e duplicati Drive',
        style: TextStyle(color: AppColors.pureWhite)),
      content: SizedBox(width: 570, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Controlla il file e scegli la cartella dentro StudentLab.',
            style: TextStyle(color: AppColors.white70)),
          const SizedBox(height: 10),
          TextField(controller: _path, style: TextStyle(color: AppColors.white),
            onChanged: (_) => setState(() { _result = null; _acknowledged = false; }),
            decoration: const InputDecoration(labelText: 'Cartelle separate da /')),
          const SizedBox(height: 7),
          OutlinedButton.icon(onPressed: _loading || _segments.isEmpty
            ? null : () => _inspect(_segments),
            icon: const Icon(Icons.search), label: const Text('Controlla il percorso')),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orangeAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.orangeAccent.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: AppColors.orangeAccent),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!, style: TextStyle(color: AppColors.white70))),
              TextButton(onPressed: _loading ? null : () => _inspect(_segments.isEmpty ? null : _segments),
                child: const Text('Riprova')),
            ]),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            Text('File proposto', style: TextStyle(color: AppColors.white,
              fontWeight: FontWeight.bold)),
            _line('Percorso', proposed['path']),
            _line('Dimensione', proposed['size']),
            _line('Tipo', proposed['mime_type']),
            _line('SHA-256', proposed['sha256']),
            if (widget.previewProposed != null) TextButton.icon(
              onPressed: widget.previewProposed, icon: const Icon(Icons.visibility_outlined),
              label: const Text('Apri il file proposto')),
            const Divider(),
            _line('Cartelle già presenti', (_result!['existing_path'] as List).join(' / ')),
            _line('Cartelle da creare', (_result!['missing_folders'] as List).join(' / ')),
            if (conflicts.isEmpty) const Text('Nessun nome o hash corrispondente nell’albero Drive.',
              style: TextStyle(color: Colors.lightGreenAccent))
            else ...[
              Text('Possibili corrispondenze trovate', style: TextStyle(
                color: AppColors.orangeAccent, fontWeight: FontWeight.bold)),
              for (final match in conflicts) Card(color: AppColors.eleganceMidnight,
                child: Padding(padding: const EdgeInsets.all(10), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _line('Percorso', match['path']),
                    _line('Motivo', match['reason'] == 'same_content'
                      ? 'Stesso contenuto SHA-256' : 'Nome uguale'),
                    _line('Dimensione', match['size']),
                    _line('Tipo', match['mime_type']),
                    _line('Modificato', match['modified_at']),
                    if (widget.previewExisting != null && match['preview_available'] == true)
                      TextButton.icon(onPressed: () => widget.previewExisting!(
                          match['id'].toString(), match['name']?.toString() ?? 'File Drive',
                          match['mime_type']?.toString() ?? 'application/octet-stream'),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Apri il file trovato')),
                  ]))),
              if (collision) Text('Esiste già un omonimo nella cartella scelta: usa un altro percorso.',
                style: TextStyle(color: AppColors.orangeAccent)),
              CheckboxListTile(value: _acknowledged,
                onChanged: (value) => setState(() => _acknowledged = value == true),
                title: Text('Ho confrontato i file. Confermo il caricamento nel percorso scelto.',
                  style: TextStyle(color: AppColors.white70, fontSize: 13))),
            ],
          ],
        ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(onPressed: ready ? () => Navigator.pop(context,
          DrivePlacement(_segments, conflicts.isNotEmpty && _acknowledged)) : null,
          child: const Text('Continua')),
      ],
    );
  }
}
