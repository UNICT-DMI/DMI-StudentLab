import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

import 'admin_material_publications_page.dart';

import '../../social/admin/admin_material_storage_api_service.dart';

class AdminMaterialStoragePage extends StatefulWidget {

  const AdminMaterialStoragePage({super.key});

  @override

  State<AdminMaterialStoragePage> createState() =>

      _AdminMaterialStoragePageState();

}

class _AdminMaterialStoragePageState

    extends State<AdminMaterialStoragePage> {

  final AdminMaterialStorageApiService _api =

      AdminMaterialStorageApiService();

  Map<String, dynamic> _overview = <String, dynamic>{};

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  bool _loading = true;

  bool _processing = false;

  String? _error;

  String _source = 'all';

  @override

  void initState() {

super.initState();

    _load();

  }

  Future<void> _load() async {

    if (!mounted) {

      return;

    }

    setState(() {

      _loading = true;

      _error = null;

    });

    try {

      final Map<String, dynamic> overview =

          await _api.getOverview();

      final List<Map<String, dynamic>> items =

          await _api.getItems(

        source: _source == 'all' ? null : _source,

      );

      if (!mounted) {

        return;

      }

      setState(() {

        _overview = overview;

        _items = items;

        _loading = false;

      });

    } catch (error) {

      if (!mounted) {

        return;

      }

      setState(() {

        _loading = false;

        _error = _friendly(error);

      });

    }

  }

  Future<void> _setSource(String value) async {

    if (_loading || _processing || value == _source) {

      return;

    }

    setState(() {

      _source = value;

    });

    await _load();

  }

  Future<void> _rename(Map<String, dynamic> item) async {

    final bool canRename = item['can_rename'] == true;

    if (!canRename || _processing) {

      return;

    }

    final TextEditingController controller =

        TextEditingController(

      text: item['title']?.toString() ?? '',

    );

    final String? value = await showDialog<String>(

      context: context,

      builder: (BuildContext dialogContext) {

        return AlertDialog(

          backgroundColor: AppColors.eleganceMidnight,

          title: const Text(

            'Modifica nome',

            style: TextStyle(color: AppColors.pureWhite),

          ),

          content: TextField(

            controller: controller,

            autofocus: true,

            maxLength: 250,

            style: const TextStyle(color: AppColors.pureWhite),

            decoration: const InputDecoration(

              labelText: 'Nome mostrato',

            ),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(dialogContext),

              child: const Text('Annulla'),

            ),

            FilledButton(

              onPressed: () {

                final String text = controller.text.trim();

                if (text.isNotEmpty) {

                  Navigator.pop(dialogContext, text);

                }

              },

              child: const Text('Salva'),

            ),

          ],

        );

      },

    );

    controller.dispose();

    if (value == null || !mounted) {

      return;

    }

    await _run(

      () => _api.rename(

        source: item['source'].toString(),

        materialId: _id(item),

        displayName: value,

      ),

      success: 'Nome aggiornato.',

    );

  }

  Future<void> _retire(Map<String, dynamic> item) async {

    if (item['can_retire'] != true || _processing) {

      return;

    }

    final TextEditingController controller =

        TextEditingController();

    final String? reason = await showDialog<String>(

      context: context,

      builder: (BuildContext dialogContext) {

        return AlertDialog(

          backgroundColor: AppColors.eleganceMidnight,

          title: const Text(

            'Ritira materiale',

            style: TextStyle(color: AppColors.pureWhite),

          ),

          content: TextField(

            controller: controller,

            autofocus: true,

            minLines: 2,

            maxLines: 4,

            style: const TextStyle(color: AppColors.pureWhite),

            decoration: const InputDecoration(

              labelText: 'Motivo del ritiro',

              helperText:

                  'Le copie remote/offline verranno revocate al prossimo sync.',

            ),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(dialogContext),

              child: const Text('Annulla'),

            ),

            FilledButton(

              onPressed: () {

                final String text = controller.text.trim();

                if (text.isNotEmpty) {

                  Navigator.pop(dialogContext, text);

                }

              },

              child: const Text('Ritira'),

            ),

          ],

        );

      },

    );

    controller.dispose();

    if (reason == null || !mounted) {

      return;

    }

    await _run(

      () => _api.retire(

        source: item['source'].toString(),

        materialId: _id(item),

        reason: reason,

      ),

      success:

          'Materiale ritirato. Il file non viene cancellato finché non lo confermi.',

    );

  }

  Future<void> _deleteBlob(Map<String, dynamic> item) async {

    if (item['safe_to_delete_blob'] != true ||

        item['blob_exists'] != true ||

        _processing) {

      return;

    }

    final bool? confirmed = await showDialog<bool>(

      context: context,

      builder: (BuildContext dialogContext) {

        return AlertDialog(

          backgroundColor: AppColors.eleganceMidnight,

          title: const Text(

            'Elimina file dallo storage',

            style: TextStyle(color: AppColors.pureWhite),

          ),

          content: Text(

            'Il record e lo storico amministrativo resteranno disponibili. '

            'Verrà eliminato soltanto il file fisico (${_bytes(_number(item['blob_size']))}).',

            style: const TextStyle(color: Colors.white70),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(dialogContext, false),

              child: const Text('Annulla'),

            ),

            FilledButton(

              onPressed: () => Navigator.pop(dialogContext, true),

              child: const Text('Elimina file'),

            ),

          ],

        );

      },

    );

    if (confirmed != true || !mounted) {

      return;

    }

    await _run(

      () => _api.deleteBlob(

        source: item['source'].toString(),

        materialId: _id(item),

      ),

      success: 'File eliminato. Lo storico è stato conservato.',

    );

  }

  Future<void> _cleanup() async {

    if (_processing) {

      return;

    }

    try {

      setState(() {

        _processing = true;

      });

      final Map<String, dynamic> dryRun =

          await _api.getCleanupDryRun();

      if (!mounted) {

        return;

      }

      final List<dynamic> records =

          dryRun['record_candidates'] is List

              ? dryRun['record_candidates'] as List<dynamic>

              : <dynamic>[];

      final List<dynamic> orphans =

          dryRun['orphan_candidates'] is List

              ? dryRun['orphan_candidates'] as List<dynamic>

              : <dynamic>[];

      final int reclaimable =

          _number(dryRun['reclaimable_bytes']);

      final TextEditingController confirmation =

          TextEditingController();

      final bool? execute = await showDialog<bool>(

        context: context,

        builder: (BuildContext dialogContext) {

          return AlertDialog(

            backgroundColor: AppColors.eleganceMidnight,

            title: const Text(

              'Dry run pulizia',

              style: TextStyle(color: AppColors.pureWhite),

            ),

            content: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  '${records.length} file collegati a record già rifiutati/ritirati.',

                  style: const TextStyle(color: Colors.white70),

                ),

                const SizedBox(height: 6),

                Text(

                  '${orphans.length} Blob orfani abbastanza vecchi da essere candidati.',

                  style: const TextStyle(color: Colors.white70),

                ),

                const SizedBox(height: 6),

                Text(

                  'Spazio recuperabile: ${_bytes(reclaimable)}',

                  style: const TextStyle(

                    color: AppColors.materialSky,

                    fontWeight: FontWeight.bold,

                  ),

                ),

                const SizedBox(height: 16),

                const Text(

                  'Per questa prima versione gli orfani non vengono cancellati automaticamente. '

                  'Scrivi ELIMINA per rimuovere i file già rifiutati o ritirati.',

                  style: TextStyle(color: Colors.white60, fontSize: 12),

                ),

                const SizedBox(height: 10),

                TextField(

                  controller: confirmation,

                  style: const TextStyle(color: AppColors.pureWhite),

                  decoration: const InputDecoration(

                    labelText: 'Conferma',

                  ),

                ),

              ],

            ),

            actions: [

              TextButton(

                onPressed: () => Navigator.pop(dialogContext, false),

                child: const Text('Chiudi'),

              ),

              FilledButton(

                onPressed: () {

                  Navigator.pop(

                    dialogContext,

                    confirmation.text.trim() == 'ELIMINA',

                  );

                },

                child: const Text('Esegui pulizia'),

              ),

            ],

          );

        },

      );

      confirmation.dispose();

      if (execute == true) {

        await _api.executeCleanup(

          rejectedPublications: true,

          removedMaterials: true,

          orphanBlobs: false,

        );

        if (mounted) {

          _message('Pulizia completata.');

          await _load();

        }

      }

    } catch (error) {

      if (mounted) {

        _message(_friendly(error));

      }

    } finally {

      if (mounted) {

        setState(() {

          _processing = false;

        });

      }

    }

  }

  Future<void> _run(

    Future<Map<String, dynamic>> Function() action, {

    required String success,

  }) async {

    if (_processing) {

      return;

    }

    setState(() {

      _processing = true;

    });

    try {

      await action();

      if (!mounted) {

        return;

      }

      _message(success);

      await _load();

    } catch (error) {

      if (mounted) {

        _message(_friendly(error));

      }

    } finally {

      if (mounted) {

        setState(() {

          _processing = false;

        });

      }

    }

  }

  @override

  Widget build(BuildContext context) {

    final Map<String, dynamic> summary =

        _overview['summary'] is Map

            ? Map<String, dynamic>.from(

                _overview['summary'] as Map,

              )

            : <String, dynamic>{};

    return Scaffold(

      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(

        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        title: const Text('Materiali e Storage'),

        actions: [

          IconButton(

            tooltip: 'Revisioni materiali',

            onPressed: _processing

                ? null

                : () {

                    Navigator.of(context).push(

                      MaterialPageRoute<void>(

                        builder: (_) =>

                            const AdminMaterialPublicationsPage(),

                      ),

                    );

                  },

            icon: const Icon(Icons.fact_check_outlined),

          ),

          IconButton(

            tooltip: 'Analizza e pulisci',

            onPressed:

                _loading || _processing ? null : _cleanup,

            icon: const Icon(Icons.cleaning_services_outlined),

          ),

          IconButton(

            tooltip: 'Aggiorna',

            onPressed:

                _loading || _processing ? null : _load,

            icon: const Icon(Icons.refresh_rounded),

          ),

        ],

      ),

      body: SafeArea(

        child: _loading

            ? const Center(

                child: CircularProgressIndicator(

                  color: AppColors.skyBlue,

                ),

              )

            : _error != null

                ? _ErrorState(

                    message: _error!,

                    onRetry: _load,

                  )

                : RefreshIndicator(

                    onRefresh: _load,

                    child: ListView(

                      padding: const EdgeInsets.all(18),

                      children: [

                        _Overview(

                          summary: summary,

                        ),

                        const SizedBox(height: 18),

                        _SourceFilters(

                          value: _source,

                          onChanged: _setSource,

                        ),

                        const SizedBox(height: 14),

                        if (_items.isEmpty)

                          const _EmptyState()

                        else

                          ..._items.map(_materialCard),

                      ],

                    ),

                  ),

      ),

    );

  }

  Widget _materialCard(Map<String, dynamic> item) {

    final String source = item['source']?.toString() ?? '';

    final String status = item['status']?.toString() ?? '';

    final String title =

        item['title']?.toString().trim().isNotEmpty == true

            ? item['title'].toString().trim()

            : item['original_name']?.toString() ?? 'Materiale';

    final bool blobExists = item['blob_exists'] == true;

    final bool safeDelete = item['safe_to_delete_blob'] == true;

    final bool canRetire = item['can_retire'] == true;

    final bool canRename = item['can_rename'] == true;

    return Card(

      color: AppColors.eleganceMidnight,

      margin: const EdgeInsets.only(bottom: 10),

      child: Padding(

        padding: const EdgeInsets.all(14),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              children: [

                Icon(

                  _sourceIcon(source),

                  color: AppColors.materialSky,

                  size: 20,

                ),

                const SizedBox(width: 9),

                Expanded(

                  child: Text(

                    title,

                    maxLines: 2,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(

                      color: AppColors.pureWhite,

                      fontWeight: FontWeight.w600,

                    ),

                  ),

                ),

                _StatusBadge(status: status),

              ],

            ),

            const SizedBox(height: 10),

            Wrap(

              spacing: 12,

              runSpacing: 6,

              children: [

                _meta(_sourceLabel(source)),

                _meta(_bytes(_number(item['size']))),

                _meta(

                  blobExists

                      ? 'File presente'

                      : 'File eliminato/assente',

                ),

                if (item['group_id'] != null)

                  _meta('Gruppo #${item['group_id']}'),

                if (item['subject_id'] != null)

                  _meta('Materia #${item['subject_id']}'),

              ],

            ),

            if (item['stored_name'] != null) ...[

              const SizedBox(height: 8),

              Text(

                item['stored_name'].toString(),

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(

                  color: Colors.white38,

                  fontSize: 10,

                ),

              ),

            ],

            const SizedBox(height: 10),

            Wrap(

              spacing: 8,

              runSpacing: 8,

              children: [

                if (canRename)

                  OutlinedButton.icon(

                    onPressed:

                        _processing ? null : () => _rename(item),

                    icon: const Icon(Icons.edit_outlined, size: 16),

                    label: const Text('Nome'),

                  ),

                if (canRetire)

                  OutlinedButton.icon(

                    onPressed:

                        _processing ? null : () => _retire(item),

                    icon: const Icon(

                      Icons.visibility_off_outlined,

                      size: 16,

                    ),

                    label: const Text('Ritira'),

                  ),

                if (safeDelete && blobExists)

                  FilledButton.icon(

                    onPressed:

                        _processing ? null : () => _deleteBlob(item),

                    icon: const Icon(Icons.delete_outline, size: 16),

                    label: const Text('Elimina file'),

                  ),

              ],

            ),

          ],

        ),

      ),

    );

  }

  Widget _meta(String value) {

    return Text(

      value,

      style: const TextStyle(

        color: Colors.white60,

        fontSize: 11,

      ),

    );

  }

  int _id(Map<String, dynamic> item) {

    final dynamic value = item['id'];

    if (value is int) {

      return value;

    }

    if (value is num) {

      return value.toInt();

    }

    final int? parsed = int.tryParse(value?.toString() ?? '');

    if (parsed == null || parsed <= 0) {

      throw StateError('Identificativo materiale non valido.');

    }

    return parsed;

  }

  int _number(dynamic value) {

    if (value is int) {

      return value;

    }

    if (value is num) {

      return value.toInt();

    }

    return int.tryParse(value?.toString() ?? '') ?? 0;

  }

  String _bytes(int bytes) {

    if (bytes < 1024) {

      return '$bytes B';

    }

    final double kb = bytes / 1024;

    if (kb < 1024) {

      return '${kb.toStringAsFixed(1)} KB';

    }

    final double mb = kb / 1024;

    if (mb < 1024) {

      return '${mb.toStringAsFixed(1)} MB';

    }

    return '${(mb / 1024).toStringAsFixed(2)} GB';

  }

  String _sourceLabel(String source) {

    switch (source) {

      case 'publication_request':

        return 'Proposta';

      case 'public':

        return 'StudentLab';

      case 'teacher':

        return 'Docente';

      case 'group':

        return 'Gruppo';

      default:

        return source;

    }

  }

  IconData _sourceIcon(String source) {

    switch (source) {

      case 'publication_request':

        return Icons.fact_check_outlined;

      case 'public':

        return Icons.public_outlined;

      case 'teacher':

        return Icons.cast_for_education_outlined;

      case 'group':

        return Icons.groups_outlined;

      default:

        return Icons.insert_drive_file_outlined;

    }

  }

  String _friendly(Object error) {

    final String value = error.toString();

    return value

        .replaceFirst('Exception: ', '')

        .replaceFirst('Bad state: ', '');

  }

  void _message(String value) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(value)),

    );

  }

}

class _Overview extends StatelessWidget {

  final Map<String, dynamic> summary;

  const _Overview({required this.summary});

  @override

  Widget build(BuildContext context) {

    int number(String key) {

      final dynamic value = summary[key];

      if (value is int) {

        return value;

      }

      if (value is num) {

        return value.toInt();

      }

      return int.tryParse(value?.toString() ?? '') ?? 0;

    }

    String bytes(int value) {

      final double mb = value / 1024 / 1024;

      return mb < 1024

          ? '${mb.toStringAsFixed(1)} MB'

          : '${(mb / 1024).toStringAsFixed(2)} GB';

    }

    return Container(

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(16),

      ),

      child: Wrap(

        spacing: 22,

        runSpacing: 14,

        children: [

          _Metric(

            label: 'Storage',

            value: bytes(number('total_bytes')),

          ),

          _Metric(

            label: 'Blob',

            value: '${number('blob_count')}',

          ),

          _Metric(

            label: 'Recuperabile',

            value: bytes(number('reclaimable_bytes')),

          ),

          _Metric(

            label: 'Blob orfani',

            value: '${number('orphan_blob_count')}',

          ),

          _Metric(

            label: 'DB senza Blob',

            value: '${number('missing_blob_count')}',

          ),

        ],

      ),

    );

  }

}

class _Metric extends StatelessWidget {

  final String label;

  final String value;

  const _Metric({

    required this.label,

    required this.value,

  });

  @override

  Widget build(BuildContext context) {

    return SizedBox(

      width: 125,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            value,

            style: const TextStyle(

              color: AppColors.pureWhite,

              fontSize: 18,

              fontWeight: FontWeight.bold,

            ),

          ),

          const SizedBox(height: 3),

          Text(

            label,

            style: const TextStyle(

              color: Colors.white54,

              fontSize: 11,

            ),

          ),

        ],

      ),

    );

  }

}

class _SourceFilters extends StatelessWidget {

  final String value;

  final ValueChanged<String> onChanged;

  const _SourceFilters({

    required this.value,

    required this.onChanged,

  });

  @override

  Widget build(BuildContext context) {

    const Map<String, String> values = <String, String>{

      'all': 'Tutti',

      'publication_request': 'Proposte',

      'public': 'StudentLab',

      'teacher': 'Docenti',

      'group': 'Gruppi',

    };

    return SingleChildScrollView(

      scrollDirection: Axis.horizontal,

      child: Row(

        children: values.entries.map(

          (MapEntry<String, String> entry) {

            return Padding(

              padding: const EdgeInsets.only(right: 7),

              child: ChoiceChip(

                label: Text(entry.value),

                selected: value == entry.key,

                onSelected: (_) => onChanged(entry.key),

              ),

            );

          },

        ).toList(),

      ),

    );

  }

}

class _StatusBadge extends StatelessWidget {

  final String status;

  const _StatusBadge({required this.status});

  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: 8,

        vertical: 4,

      ),

      decoration: BoxDecoration(

        color: AppColors.brandNightBlue,

        borderRadius: BorderRadius.circular(8),

      ),

      child: Text(

        status.isEmpty ? '—' : status,

        style: const TextStyle(

          color: AppColors.materialSky,

          fontSize: 10,

          fontWeight: FontWeight.w600,

        ),

      ),

    );

  }

}

class _ErrorState extends StatelessWidget {

  final String message;

  final VoidCallback onRetry;

  const _ErrorState({

    required this.message,

    required this.onRetry,

  });

  @override

  Widget build(BuildContext context) {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(24),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            const Icon(

              Icons.error_outline,

              color: Colors.orangeAccent,

              size: 36,

            ),

            const SizedBox(height: 12),

            Text(

              message,

              textAlign: TextAlign.center,

              style: const TextStyle(color: Colors.white70),

            ),

            const SizedBox(height: 14),

            OutlinedButton(

              onPressed: onRetry,

              child: const Text('Riprova'),

            ),

          ],

        ),

      ),

    );

  }

}

class _EmptyState extends StatelessWidget {

  const _EmptyState();

  @override

  Widget build(BuildContext context) {

    return const Padding(

      padding: EdgeInsets.symmetric(vertical: 50),

      child: Center(

        child: Text(

          'Nessun materiale per questo filtro.',

          style: TextStyle(color: Colors.white54),

        ),

      ),

    );

  }

}