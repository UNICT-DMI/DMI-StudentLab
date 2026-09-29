import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../theme/nightTheme.dart';
import 'services/student_quiz_review_service.dart';

class StudyPlanSessionsPage extends StatefulWidget {
  const StudyPlanSessionsPage({super.key});

  @override
  State<StudyPlanSessionsPage> createState() => _StudyPlanSessionsPageState();
}

class _StudyPlanSessionsPageState extends State<StudyPlanSessionsPage> {
  final StudentQuizReviewService _service = StudentQuizReviewService();
  List<Map<String, dynamic>> _sources = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> values = await _service.getSources();
      if (!mounted) return;
      setState(() {
        _sources = values;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Non è stato possibile caricare le sessioni del piano.';
      });
    }
  }

  Future<void> _toggle(Map<String, dynamic> source, bool enabled) async {
    final String sourceKey = source['source_key']?.toString() ?? '';
    final String sessionUuid = source['session_uuid']?.toString() ?? '';
    final bool remote = (source['sync_state']?.toString() ?? '') == 'synced' &&
        AuthSession.instance.isAuthenticated &&
        sessionUuid.isNotEmpty;
    try {
      if (remote) {
        await _service.setRemoteSessionEnabled(sessionUuid, enabled);
      } else {
        await _service.setSourceEnabled(sourceKey, enabled);
      }
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non è stato possibile aggiornare la sessione.')),
      );
    }
  }

  Future<void> _removeLocal(Map<String, dynamic> source) async {
    final String sourceKey = source['source_key']?.toString() ?? '';
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Rimuovere i dati locali?'),
        content: const Text(
          'La copia locale di questa sessione verrà rimossa dal piano su questo dispositivo. '
          'I dati dell’account sul server non verranno eliminati.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.removeLocalSource(sourceKey);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Sessioni del Ripasso'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.error_outline_rounded, color: AppColors.redAccent, size: 38),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.white60)),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Riprova')),
            ],
          ),
        ),
      );
    }

    final List<Map<String, dynamic>> active = _sources.where(_enabled).toList();
    final List<Map<String, dynamic>> disabled = _sources.where((item) => !_enabled(item)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: AppColors.eleganceMidnight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12)),
            ),
            child: Text(
              'Qui scegli quali sessioni contribuiscono al piano condiviso di questo dispositivo. '
              'Dissociare una sessione non elimina i quiz o le statistiche dell’account dal server.',
              style: TextStyle(color: AppColors.white60, fontSize: 11, height: 1.45),
            ),
          ),
          const SizedBox(height: 22),
          _title('Attive'),
          const SizedBox(height: 10),
          if (active.isEmpty)
            _empty('Nessuna sessione attiva.')
          else
            ...active.map((item) => _card(item, enabled: true)),
          if (disabled.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            _title('Dissociate'),
            const SizedBox(height: 10),
            ...disabled.map((item) => _card(item, enabled: false)),
          ],
        ],
      ),
    );
  }

  Widget _title(String value) => Text(
        value,
        style: TextStyle(color: AppColors.pureWhite, fontWeight: FontWeight.bold, fontSize: 17),
      );

  Widget _empty(String value) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.eleganceMidnight, borderRadius: BorderRadius.circular(14)),
        child: Text(value, style: TextStyle(color: AppColors.white54)),
      );

  Widget _card(Map<String, dynamic> source, {required bool enabled}) {
    final String sourceType = source['source_type']?.toString() ?? 'authenticated';
    final String deviceId = source['device_id']?.toString() ?? '';
    final String label = (source['display_label']?.toString().trim().isNotEmpty ?? false)
        ? source['display_label'].toString().trim()
        : sourceType == 'guest'
            ? 'Sessione Guest'
            : 'Sessione account';
    final int? remoteUserId = _int(source['remote_user_id']);
    final bool currentAccount = remoteUserId != null && remoteUserId == AuthSession.instance.currentUserId;
    final bool currentDevice = _int(source['is_current_device']) == 1;
    final DateTime? last = DateTime.tryParse(source['last_activity_at']?.toString() ?? '')?.toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (enabled ? AppColors.skyBlue : AppColors.white38).withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(sourceType == 'guest' ? Icons.person_outline_rounded : Icons.devices_rounded, color: AppColors.materialSky),
              const SizedBox(width: 9),
              Expanded(
                child: Text(label, style: TextStyle(color: AppColors.pureWhite, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _badge(sourceType == 'guest' ? 'GUEST' : currentAccount ? 'TU' : 'ALTRA SESSIONE'),
              if (currentDevice) _badge('QUESTO DISPOSITIVO'),
              _badge(enabled ? 'ASSOCIATA' : 'DISSOCIATA'),
            ],
          ),
          if (last != null) ...<Widget>[
            const SizedBox(height: 9),
            Text('Ultima attività: ${_date(last)}', style: TextStyle(color: AppColors.white38, fontSize: 10)),
          ],
          if (deviceId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text('Dispositivo: ${_shortId(deviceId)}', style: TextStyle(color: AppColors.white30, fontSize: 9)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _toggle(source, !enabled),
                icon: Icon(enabled ? Icons.link_off_rounded : Icons.link_rounded, size: 17),
                label: Text(enabled ? 'Dissocia' : 'Ricollega'),
              ),
              if (!enabled)
                TextButton.icon(
                  onPressed: () => _removeLocal(source),
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  label: const Text('Rimuovi copia locale'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.brandNightBlue,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: TextStyle(color: AppColors.materialSky, fontSize: 8, fontWeight: FontWeight.bold)),
      );

  bool _enabled(Map<String, dynamic> item) => _int(item['contribution_enabled']) != 0;
  int? _int(dynamic value) => value is int ? value : value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  String _shortId(String value) => value.length <= 12 ? value : '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
