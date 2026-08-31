import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../support/support_api_service.dart';

class AdminSupportSessionsPage extends StatefulWidget {
  const AdminSupportSessionsPage({super.key});

  @override
  State<AdminSupportSessionsPage> createState() =>
      _AdminSupportSessionsPageState();
}

class _AdminSupportSessionsPageState
    extends State<AdminSupportSessionsPage> {
  final SupportApiService _api =
      SupportApiService();

  List<Map<String, dynamic>> _sessions =
      <Map<String, dynamic>>[];
  bool _loading = true;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Map<String, dynamic>> sessions =
          await _api.adminSessions();

      if (!mounted) {
        return;
      }

      setState(() {
        _sessions = sessions;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _clean(error);
      });
    }
  }

  Future<void> _accept(
    Map<String, dynamic> item,
  ) async {
    final int? id = _asInt(item['id']);

    if (id == null || _processing) {
      return;
    }

    await _run(
      () => _api.acceptSession(id),
    );
  }

  Future<void> _open(
    Map<String, dynamic> item,
  ) async {
    final int? id = _asInt(item['id']);

    if (id == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _AdminSupportSessionDetailPage(
          sessionId: id,
        ),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  Future<void> _run(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    if (_processing) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) {
        _message(_clean(error));
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
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Assistenza remota'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: _sessions.length,
                    itemBuilder: (
                      BuildContext context,
                      int index,
                    ) {
                      return _sessionCard(
                        _sessions[index],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _sessionCard(
    Map<String, dynamic> item,
  ) {
    final String status =
        item['status']?.toString() ?? '';
    final bool online =
        item['is_online'] == true;

    return Card(
      color: AppColors.eleganceMidnight,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _open(item),
        leading: Icon(
          online
              ? Icons.support_agent
              : Icons.support_agent_outlined,
          color: online
              ? Colors.greenAccent
              : AppColors.skyBlue,
        ),
        title: Text(
          item['issue_summary']?.toString() ??
              'Richiesta assistenza',
          style: const TextStyle(
            color: AppColors.pureWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Utente #${item['user_id']} • $status'
          '${online ? ' • ONLINE' : ''}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        trailing: status == 'requested'
            ? FilledButton(
                onPressed: _processing
                    ? null
                    : () => _accept(item),
                child: const Text('Accetta'),
              )
            : const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white30,
                size: 14,
              ),
      ),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  String _clean(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }
}

class _AdminSupportSessionDetailPage
    extends StatefulWidget {
  final int sessionId;

  const _AdminSupportSessionDetailPage({
    required this.sessionId,
  });

  @override
  State<_AdminSupportSessionDetailPage> createState() =>
      _AdminSupportSessionDetailPageState();
}

class _AdminSupportSessionDetailPageState
    extends State<_AdminSupportSessionDetailPage> {
  final SupportApiService _api =
      SupportApiService();

  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final Map<String, dynamic> data =
        await _api.adminSession(widget.sessionId);

    if (!mounted) {
      return;
    }

    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _action(
    String action,
  ) async {
    if (_processing) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _api.createAction(
        sessionId: widget.sessionId,
        action: action,
      );

      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _close() async {
    await _api.closeSession(
      widget.sessionId,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> session =
        _data?['session'] is Map
            ? Map<String, dynamic>.from(
                _data!['session'] as Map,
              )
            : <String, dynamic>{};

    final Map<String, dynamic>? snapshot =
        _data?['latest_snapshot'] is Map
            ? Map<String, dynamic>.from(
                _data!['latest_snapshot'] as Map,
              )
            : null;

    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: Text(
          'Assistenza #${widget.sessionId}',
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _box(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        session['issue_summary']?.toString() ?? '',
                        style: const TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stato: ${session['status']}'
                        '${session['is_online'] == true ? ' • ONLINE' : ''}',
                        style: TextStyle(
                          color: session['is_online'] == true
                              ? Colors.greenAccent
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _box(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Azioni controllate',
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _actionButton(
                            'Diagnostica',
                            'collect_diagnostics',
                          ),
                          _actionButton(
                            'Full sync',
                            'force_material_sync',
                          ),
                          _actionButton(
                            'Refresh manifest',
                            'refresh_manifest',
                          ),
                          _actionButton(
                            'Pulisci cache remota',
                            'clear_remote_cache',
                          ),
                          _actionButton(
                            'Pulisci record obsoleti',
                            'purge_stale_remote_materials',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _box(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ultimo snapshot SQLite',
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (snapshot == null)
                        const Text(
                          'Nessuno snapshot ricevuto.',
                          style: TextStyle(
                            color: Colors.white54,
                          ),
                        )
                      else
                        SelectableText(
                          _pretty(snapshot['payload']),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _close,
                  icon: const Icon(
                    Icons.check_circle_outline,
                  ),
                  label: const Text(
                    'Chiudi assistenza come risolta',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _actionButton(
    String label,
    String action,
  ) {
    return OutlinedButton(
      onPressed: _processing
          ? null
          : () => _action(action),
      child: Text(label),
    );
  }

  Widget _box({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  String _pretty(dynamic value) {
    if (value == null) {
      return '';
    }

    const JsonEncoder encoder =
        JsonEncoder.withIndent('  ');

    try {
      return encoder.convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}
