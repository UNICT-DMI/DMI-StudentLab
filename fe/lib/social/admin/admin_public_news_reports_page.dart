import 'package:flutter/material.dart';

import '../../services/public_news_api_service.dart';
import '../../theme/nightTheme.dart';
import '../news/models/public_news.dart';

class AdminPublicNewsReportsPage extends StatefulWidget {
  const AdminPublicNewsReportsPage({super.key});

  @override
  State<AdminPublicNewsReportsPage> createState() =>
      _AdminPublicNewsReportsPageState();
}

class _AdminPublicNewsReportsPageState
    extends State<AdminPublicNewsReportsPage> {
  final PublicNewsApiService _apiService = PublicNewsApiService();

  List<PublicNewsReport> _items = [];
  bool _loading = true;
  bool _processing = false;
  String? _error;
  String _status = 'pending';

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
      final PublicNewsReportsResult result = await _apiService.getReports(
        status: _status,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items = result.items;
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

  Future<void> _moderate(PublicNewsReport report) async {
    if (_processing) {
      return;
    }

    String status = 'resolved';
    String action = 'none';
    final TextEditingController noteController = TextEditingController();

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
                    const Text(
                      'Gestisci segnalazione',
                      style: TextStyle(
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
                      items: const [
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('Nessuna azione'),
                        ),
                        DropdownMenuItem(
                          value: 'remove_news',
                          child: Text('Rimuovi news'),
                        ),
                        DropdownMenuItem(
                          value: 'warn_user',
                          child: Text('Avverti utente'),
                        ),
                        DropdownMenuItem(
                          value: 'suspend_user',
                          child: Text('Sospendi utente'),
                        ),
                        DropdownMenuItem(
                          value: 'deactivate_user',
                          child: Text('Disattiva utente'),
                        ),
                      ],
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
                      maxLength: 2000,
                      style: const TextStyle(color: AppColors.pureWhite),
                      decoration: const InputDecoration(
                        labelText: 'Nota moderazione',
                      ),
                    ),
                    const SizedBox(height: 14),
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

    setState(() {
      _processing = true;
    });

    try {
      await _apiService.moderateReport(
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
        title: const Text('Segnalazioni news'),
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
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    dropdownColor: AppColors.eleganceDeepNavy,
                    decoration: const InputDecoration(
                      labelText: 'Stato segnalazioni',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('In attesa'),
                      ),
                      DropdownMenuItem(
                        value: 'under_review',
                        child: Text('In revisione'),
                      ),
                      DropdownMenuItem(
                        value: 'resolved',
                        child: Text('Risolte'),
                      ),
                      DropdownMenuItem(
                        value: 'dismissed',
                        child: Text('Archiviate'),
                      ),
                    ],
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        final PublicNewsReport report = _items[index];

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
                      'News #${report.newsId}',
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    report.status,
                    style: const TextStyle(
                      color: AppColors.materialSky,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                report.reason,
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
              Row(
                children: [
                  Text(
                    'Segnalante #${report.reporterUserId}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
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
      },
    );
  }

  String _friendlyError(Object error) {
    final String value = error.toString().toLowerCase();
    if (value.contains('401')) {
      return 'La sessione non è più valida. Accedi nuovamente.';
    }
    if (value.contains('403')) {
      return 'Non hai i permessi necessari per questa sezione.';
    }
    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection')) {
      return 'Non è stato possibile connettersi a StudentLab.';
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
