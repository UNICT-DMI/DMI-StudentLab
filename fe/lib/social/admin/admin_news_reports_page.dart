import 'package:flutter/material.dart';

import '../../services/news_report_api_service.dart';
import '../../theme/nightTheme.dart';
import '../news/models/news_report.dart';

class AdminNewsReportsPage extends StatefulWidget {
  const AdminNewsReportsPage({
    super.key,
    this.reportApi,
  });

  final NewsReportApiService? reportApi;

  @override
  State<AdminNewsReportsPage> createState() => _AdminNewsReportsPageState();
}

class _AdminNewsReportsPageState extends State<AdminNewsReportsPage> {
  static const Map<String, String> _statusLabels = <String, String>{
    'pending': 'In attesa',
    'under_review': 'In revisione',
    'resolved': 'Risolte',
    'dismissed': 'Archiviate',
  };

  static const Map<String, String> _categoryLabels = <String, String>{
    'avvisi': 'Avviso',
    'gruppi': 'Gruppo',
    'private': 'Messaggio privato',
  };

  static const Map<String, String> _actionLabels = <String, String>{
    'none': 'Nessuna azione',
    'hide_news': 'Nascondi contenuto',
    'remove_news': 'Rimuovi contenuto',
  };

  late final NewsReportApiService _reportApi =
      widget.reportApi ?? NewsReportApiService();

  List<NewsReport> _items = <NewsReport>[];
  final Map<int, NewsReportDisclosure> _disclosures =
      <int, NewsReportDisclosure>{};

  bool _loading = true;
  bool _processing = false;
  String? _error;
  String _status = 'pending';
  String _category = '';

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
      final NewsReportListResult result = await _reportApi.getReports(
        status: _status,
        category: _category,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items = result.items;
        _disclosures.clear();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _openDisclosure(NewsReport report) async {
    if (_processing) {
      return;
    }

    if (report.category == 'private') {
      final bool confirmed = await _confirmPrivateDisclosure(report);

      if (!confirmed) {
        return;
      }
    }

    setState(() {
      _processing = true;
    });

    try {
      final NewsReportDisclosure disclosure = await _reportApi.openDisclosure(
        report.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _disclosures[report.id] = disclosure;
      });
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<bool> _confirmPrivateDisclosure(NewsReport report) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: const Text(
            'Aprire il messaggio privato?',
            style: TextStyle(color: AppColors.pureWhite, fontSize: 16),
          ),
          content: const Text(
            'Il segnalante ha condiviso la chiave di questo singolo '
            'messaggio: non potrai leggere il resto della conversazione. '
            'L’apertura viene registrata con il tuo account e resta '
            'consultabile.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Apri'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _moderate(NewsReport report) async {
    if (_processing) {
      return;
    }

    String status = 'resolved';
    String action = 'none';
    final TextEditingController noteController = TextEditingController(
      text: report.moderationNote,
    );

    final bool? submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setSheetState,
          ) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                18 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Gestisci segnalazione #${report.id}',
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      dropdownColor: AppColors.eleganceDeepNavy,
                      decoration: const InputDecoration(labelText: 'Stato'),
                      items: const [
                        DropdownMenuItem(
                          value: 'under_review',
                          child: Text('In revisione'),
                        ),
                        DropdownMenuItem(
                          value: 'resolved',
                          child: Text('Risolta'),
                        ),
                        DropdownMenuItem(
                          value: 'dismissed',
                          child: Text('Archiviata'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setSheetState(() {
                            status = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: action,
                      dropdownColor: AppColors.eleganceDeepNavy,
                      decoration: const InputDecoration(labelText: 'Azione'),
                      items: _actionLabels.entries
                          .map(
                            (MapEntry<String, String> entry) =>
                                DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          setSheetState(() {
                            action = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: NewsReportApiService.maxDescriptionLength,
                      style: const TextStyle(color: AppColors.pureWhite),
                      decoration: InputDecoration(
                        labelText: action == 'none'
                            ? 'Nota moderazione'
                            : 'Motivazione (obbligatoria)',
                      ),
                    ),
                    if (action != 'none')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'La motivazione resta salvata sul contenuto '
                          'moderato insieme al tuo identificativo.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Salva'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final String note = noteController.text.trim();
    noteController.dispose();

    if (submit != true) {
      return;
    }

    if (action != 'none' && note.isEmpty) {
      _showMessage(
        'Per nascondere o rimuovere un contenuto serve una motivazione.',
      );

      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _reportApi.moderateReport(
        reportId: report.id,
        status: status,
        action: action,
        note: note,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Segnalazione aggiornata.');
      await _load();
    } catch (error) {
      _showMessage(_friendlyError(error));
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
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Segnalazioni bacheche'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading || _processing ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          dropdownColor: AppColors.eleganceDeepNavy,
                          decoration: const InputDecoration(
                            labelText: 'Stato',
                          ),
                          items: _statusLabels.entries
                              .map(
                                (MapEntry<String, String> entry) =>
                                    DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: _processing
                              ? null
                              : (String? value) async {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _status = value;
                                  });
                                  await _load();
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _category,
                          dropdownColor: AppColors.eleganceDeepNavy,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Tutte'),
                            ),
                            ..._categoryLabels.entries.map(
                              (MapEntry<String, String> entry) =>
                                  DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            ),
                          ],
                          onChanged: _processing
                              ? null
                              : (String? value) async {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _category = value;
                                  });
                                  await _load();
                                },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'Nessuna segnalazione in questa sezione.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (
        BuildContext context,
        int index,
      ) =>
          const SizedBox(height: 10),
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        return _buildCard(_items[index]);
      },
    );
  }

  Widget _buildCard(NewsReport report) {
    final NewsReportDisclosure? disclosure = _disclosures[report.id];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.skyBlue.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                color: Colors.orangeAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_categoryLabels[report.category] ?? report.category}'
                  ' · #${report.newsId}',
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _statusLabels[report.status] ?? report.status,
                style: const TextStyle(
                  color: AppColors.materialSky,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report.reasonLabel,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (report.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              report.description,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _metaLabel('Segnalante #${report.reporterUserId}'),
              if (report.reportedUserId != null)
                _metaLabel('Autore #${report.reportedUserId}'),
              if (report.groupId != null)
                _metaLabel('Gruppo #${report.groupId}'),
              _metaLabel(_formatDate(report.createdAt)),
              if (report.moderationAction != 'none')
                _metaLabel(
                  _actionLabels[report.moderationAction] ??
                      report.moderationAction,
                ),
            ],
          ),
          if (report.category == 'private') ...[
            const SizedBox(height: 8),
            Text(
              report.hasDisclosureConsent
                  ? 'Il segnalante ha condiviso la chiave di questo singolo '
                      'messaggio.'
                  : 'Nessuna chiave condivisa: il contenuto non è leggibile.',
              style: TextStyle(
                color: report.hasDisclosureConsent
                    ? Colors.white54
                    : Colors.orangeAccent,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
          if (report.moderationNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nota: ${report.moderationNote}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
          if (disclosure != null) _buildDisclosure(disclosure),
          const SizedBox(height: 6),
          Row(
            children: [
              if (report.category != 'private' || report.hasDisclosureConsent)
                TextButton.icon(
                  onPressed: _processing || disclosure != null
                      ? null
                      : () => _openDisclosure(report),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(
                    disclosure != null ? 'Contenuto aperto' : 'Apri contenuto',
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: _processing ? null : () => _moderate(report),
                icon: const Icon(Icons.gavel_outlined, size: 16),
                label: const Text('Gestisci'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisclosure(NewsReportDisclosure disclosure) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.skyBlue.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                disclosure.verified
                    ? Icons.verified_outlined
                    : Icons.help_outline,
                size: 16,
                color: disclosure.verified
                    ? AppColors.materialSky
                    : Colors.orangeAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  disclosure.authorName.isNotEmpty
                      ? '${disclosure.authorName} · '
                          '${_formatDate(disclosure.createdAt)}'
                      : _formatDate(disclosure.createdAt),
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            disclosure.content,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (disclosure.category == 'private') ...[
            const SizedBox(height: 8),
            Text(
              disclosure.verified
                  ? 'Il tag di autenticazione conferma che il testo è quello '
                      'inviato dall’autore e non è stato alterato.'
                  : 'Contenuto non verificato.',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                height: 1.4,
              ),
            ),
            if (disclosure.wrapTargets.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Destinatari della chiave: '
                '${disclosure.wrapTargets.join(', ')}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _metaLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 9,
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Data non disponibile';
    }

    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} $hour:$minute';
  }

  String _friendlyError(Object error) {
    final String value = error.toString().toLowerCase();

    if (value.contains('401')) {
      return 'La sessione non è più valida. Accedi nuovamente.';
    }
    if (value.contains('403')) {
      return 'Non hai i permessi necessari per questa sezione.';
    }
    if (value.contains('404')) {
      return 'Il contenuto segnalato non è più disponibile.';
    }
    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection')) {
      return 'Non è stato possibile connettersi a StudentLab.';
    }

    final int separator = error.toString().indexOf(': ');

    if (value.contains('400') && separator > 0) {
      return error.toString().substring(separator + 2);
    }

    return 'Non è stato possibile completare l’operazione.';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
