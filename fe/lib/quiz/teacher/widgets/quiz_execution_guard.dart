import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum QuizExecutionMode { practice, simulation }
enum ExternalActivityPolicy { disabled, structuredDevices }

class QuizExecutionGuard extends StatefulWidget {
  final QuizExecutionMode mode;
  final ExternalActivityPolicy externalActivityPolicy;
  final Future<void> Function(String reason) onForcedSubmit;
  final Widget child;

  const QuizExecutionGuard({
    super.key,
    required this.mode,
    required this.externalActivityPolicy,
    required this.onForcedSubmit,
    required this.child,
  });

  @override
  State<QuizExecutionGuard> createState() => _QuizExecutionGuardState();
}

class _QuizExecutionGuardState extends State<QuizExecutionGuard> with WidgetsBindingObserver {
  bool _submitting = false;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _monitorStructuredDeviceActivity =>
      widget.externalActivityPolicy == ExternalActivityPolicy.structuredDevices &&
      !_isMobile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _submit(String reason) async {
    if (_submitting || widget.mode != QuizExecutionMode.simulation) return;
    _submitting = true;
    try {
      await widget.onForcedSubmit(reason);
    } finally {
      _submitting = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.mode != QuizExecutionMode.simulation) return;

    if (_isMobile) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        unawaited(_submit('app_backgrounded'));
      }
      return;
    }

    if (_monitorStructuredDeviceActivity &&
        (state == AppLifecycleState.inactive ||
         state == AppLifecycleState.hidden ||
         state == AppLifecycleState.paused)) {
      unawaited(_submit('external_activity_detected'));
      return;
    }

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_submit('app_backgrounded'));
    }
  }

  Future<bool> _confirmExit() async {
    if (widget.mode != QuizExecutionMode.simulation) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Uscire dalla simulazione?'),
        content: const Text(
          'Uscendo, il tentativo verrà consegnato definitivamente con le risposte date finora.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continua'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Consegna ed esci'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _submit('user_confirmed_exit');
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.mode != QuizExecutionMode.simulation,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || widget.mode != QuizExecutionMode.simulation) return;
        final canExit = await _confirmExit();
        if (canExit && context.mounted) Navigator.of(context).pop();
      },
      child: widget.child,
    );
  }
}