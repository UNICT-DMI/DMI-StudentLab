import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../theme/nightTheme.dart';

class UserBlockAction extends StatefulWidget {
  final int userId;
  final String userName;

  const UserBlockAction({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserBlockAction> createState() => _UserBlockActionState();
}

class _UserBlockActionState extends State<UserBlockAction> {
  final ApiService _apiService = ApiService();

  bool _loading = true;
  bool _changing = false;
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  bool get _isSelf =>
      AuthSession.instance.currentUserId == widget.userId;

  Future<void> _loadStatus() async {
    if (_isSelf || widget.userId <= 0) {
      if (mounted) {
        setState(() {
          _loading = false;
          _blocked = false;
        });
      }
      return;
    }

    try {
      final List<Map<String, dynamic>> items =
          await _apiService.getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blocked = items.any(_matchesUser);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  bool _matchesUser(Map<String, dynamic> item) {
    final int? directId = _toInt(item['blocked_user_id']);
    if (directId == widget.userId) return true;

    final dynamic blocked = item['blocked'];
    if (blocked is Map) {
      return _toInt(blocked['id']) == widget.userId;
    }
    return false;
  }

  Future<void> _toggleBlock() async {
    if (_changing || _isSelf) return;

    if (!_blocked) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.eleganceDeepNavy,
            title: const Text(
              'Blocca utente',
              style: TextStyle(color: AppColors.pureWhite),
            ),
            content: Text(
              'Vuoi bloccare ${widget.userName}? Non riceverai contenuti o comunicazioni dirette da questo utente secondo le regole di StudentLab.',
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.68),
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Blocca'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _changing = true;
    });

    try {
      if (_blocked) {
        await _apiService.unblockUser(widget.userId);
      } else {
        await _apiService.blockUser(widget.userId);
      }
      if (!mounted) return;
      setState(() {
        _blocked = !_blocked;
      });
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _changing = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final String message = error.toString().toLowerCase();

    if (message.contains('409') ||
        message.contains('already') ||
        message.contains('già bloccat')) {
      return 'Questo utente risulta già bloccato.';
    }
    if (message.contains('404') || message.contains('not found')) {
      return 'Questo profilo non è più disponibile.';
    }
    if (message.contains('401') ||
        message.contains('unauthorized') ||
        message.contains('token')) {
      return 'La sessione non è più valida. Accedi nuovamente.';
    }
    if (message.contains('403') || message.contains('forbidden')) {
      return 'Non puoi completare questa operazione.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }
    return _blocked
        ? 'Non è stato possibile sbloccare questo utente.'
        : 'Non è stato possibile bloccare questo utente.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_isSelf) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading || _changing ? null : _toggleBlock,
        icon: _changing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _blocked
                    ? Icons.lock_open_outlined
                    : Icons.block_outlined,
              ),
        label: Text(
          _blocked ? 'Sblocca utente' : 'Blocca utente',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              _blocked ? AppColors.materialSky : Colors.redAccent,
          side: BorderSide(
            color: (_blocked ? AppColors.materialSky : Colors.redAccent)
                .withValues(alpha: 0.35),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
