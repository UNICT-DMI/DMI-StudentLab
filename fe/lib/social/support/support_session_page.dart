import 'dart:async';

import 'package:flutter/material.dart';

import '../../local_storage/services/material_sync_service.dart';
import '../../services/auth_session.dart';
import '../../theme/nightTheme.dart';
import 'support_api_service.dart';
import 'support_diagnostic_collector.dart';

class SupportSessionPage extends StatefulWidget {
  final int sessionId;

  const SupportSessionPage({
    super.key,
    required this.sessionId,
  });

  @override
  State<SupportSessionPage> createState() =>
      _SupportSessionPageState();
}

class _SupportSessionPageState
    extends State<SupportSessionPage> {
  final SupportApiService _api =
      SupportApiService();
  final SupportDiagnosticCollector _collector =
      SupportDiagnosticCollector();
  final MaterialSyncService _materialSyncService =
      MaterialSyncService();

  Timer? _timer;
  Map<String, dynamic>? _session;
  bool _loading = true;
  bool _processing = false;
  String? _error;

  int? get _userId =>
      AuthSession.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic> session =
          await _api.getSession(widget.sessionId);

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _loading = false;
        _error = null;
      });

      if (session['status'] == 'active') {
        _startHeartbeat();
      }
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

  Future<void> _grantConsent() async {
    if (_processing) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              AppColors.eleganceMidnight,
          title: const Text(
            'Consenti diagnostica temporanea',
            style: TextStyle(
              color: AppColors.pureWhite,
            ),
          ),
          content: const Text(
            'StudentLab potrà ricevere temporaneamente dati diagnostici '
            'della SQLite dell’app necessari alla risoluzione del problema. '
            'Password, token e percorsi locali dei file non vengono inviati. '
            'Puoi revocare il consenso in qualsiasi momento.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text(
                'Non consentire',
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child: const Text(
                'Consenti',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _run(() async {
      _session = await _api.consent(
        sessionId: widget.sessionId,
        accepted: true,
        scope: 'diagnostic',
      );

      await _sendSnapshot();
      _startHeartbeat();
    });
  }

  void _startHeartbeat() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _tick(),
    );

    _tick();
  }

  Future<void> _tick() async {
    if (_processing || !mounted) {
      return;
    }

    try {
      final Map<String, dynamic> session =
          await _api.heartbeat(
        widget.sessionId,
      );

      final List<Map<String, dynamic>> actions =
          await _api.pendingActions(
        widget.sessionId,
      );

      for (
        final Map<String, dynamic> action
        in actions
      ) {
        await _executeAction(action);
      }

      if (mounted) {
        setState(() {
          _session = session;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendSnapshot() async {
    final Map<String, dynamic> payload =
        await _collector.collect();

    await _api.sendSnapshot(
      sessionId: widget.sessionId,
      payload: payload,
      databaseVersion:
          payload['database_version'] as int?,
    );
  }

  Future<void> _executeAction(
    Map<String, dynamic> action,
  ) async {
    final int? id =
        _asInt(action['id']);
    final String type =
        action['action']?.toString() ?? '';

    if (id == null || type.isEmpty) {
      return;
    }

    await _api.ackAction(
      sessionId: widget.sessionId,
      actionId: id,
      status: 'running',
    );

    try {
      final int? userId = _userId;

      switch (type) {
        case 'collect_diagnostics':
          await _sendSnapshot();
          break;
        case 'force_material_sync':
        case 'refresh_manifest':
          if (userId == null) {
            throw StateError(
              'Utente non autenticato.',
            );
          }

          await _materialSyncService
              .syncMaterials(
            userId: userId,
            forceFull: true,
          );
          break;
        case 'clear_remote_cache':
          if (userId == null) {
            throw StateError(
              'Utente non autenticato.',
            );
          }

          await _materialSyncService
              .clearUserCache(
            userId,
          );
          break;
        case 'purge_stale_remote_materials':
          if (userId == null) {
            throw StateError(
              'Utente non autenticato.',
            );
          }

          await _materialSyncService
              .syncMaterials(
            userId: userId,
            forceFull: true,
          );
          break;
        default:
          throw StateError(
            'Azione di assistenza non supportata.',
          );
      }

      await _api.ackAction(
        sessionId: widget.sessionId,
        actionId: id,
        status: 'completed',
        result: <String, dynamic>{
          'completed_at': DateTime.now()
              .toUtc()
              .toIso8601String(),
        },
      );
    } catch (error) {
      await _api.ackAction(
        sessionId: widget.sessionId,
        actionId: id,
        status: 'failed',
        result: <String, dynamic>{
          'error': _clean(error),
        },
      );
    }
  }

  Future<void> _revoke() async {
    await _run(() async {
      _session = await _api.revoke(
        widget.sessionId,
      );

      _timer?.cancel();
    });
  }

  Future<void> _run(
    Future<void> Function() action,
  ) async {
    if (_processing) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await action();

      if (mounted) {
        setState(() {});
      }
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor:
            AppColors.brandNightBlue,
        foregroundColor:
            AppColors.pureWhite,
        title: const Text(
          'Assistenza StudentLab',
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(),
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
                : ListView(
                    padding:
                        const EdgeInsets.all(20),
                    children: [
                      _statusCard(),
                      const SizedBox(
                        height: 16,
                      ),
                      if (
                        _session?['status'] ==
                            'waiting_consent'
                      )
                        FilledButton.icon(
                          onPressed:
                              _processing
                                  ? null
                                  : _grantConsent,
                          icon: const Icon(
                            Icons
                                .verified_user_outlined,
                          ),
                          label: const Text(
                            'Consenti diagnostica temporanea',
                          ),
                        ),
                      if (
                        _session?['status'] ==
                            'active'
                      ) ...[
                        const Text(
                          'Mantieni questa schermata aperta fino alla conclusione dell’assistenza.',
                          style: TextStyle(
                            color: Colors.amber,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _processing
                                  ? null
                                  : _sendSnapshot,
                          icon: const Icon(
                            Icons.refresh,
                          ),
                          label: const Text(
                            'Aggiorna diagnostica',
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _processing
                                  ? null
                                  : _revoke,
                          icon: const Icon(
                            Icons
                                .stop_circle_outlined,
                          ),
                          label: const Text(
                            'Revoca accesso e chiudi',
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _statusCard() {
    final String status =
        _session?['status']?.toString() ?? '';

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            AppColors.eleganceMidnight,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            _session?['issue_summary']
                    ?.toString() ??
                'Richiesta assistenza',
            style: const TextStyle(
              color:
                  AppColors.pureWhite,
              fontSize: 17,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            'Stato: $status',
            style: const TextStyle(
              color:
                  AppColors.materialSky,
            ),
          ),
          if (
            _session?['assigned_admin_id'] !=
                null
          ) ...[
            const SizedBox(
              height: 6,
            ),
            Text(
              'Operatore assegnato: #${_session!['assigned_admin_id']}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ],
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
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(value),
      ),
    );
  }
}
