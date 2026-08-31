import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../theme/nightTheme.dart';

enum _ErrorReportState { idle, sending, sent, failed }

class StudentLabErrorScreen extends StatefulWidget {
  final Object? error;
  final StackTrace? stackTrace;

  const StudentLabErrorScreen({super.key, this.error, this.stackTrace});

  @override
  State<StudentLabErrorScreen> createState() => _StudentLabErrorScreenState();
}

class _StudentLabErrorScreenState extends State<StudentLabErrorScreen> {
  final ApiService _apiService = ApiService();

  _ErrorReportState _reportState = _ErrorReportState.idle;

  bool get _canReport {
    return AuthSession.instance.isAuthenticated &&
        widget.error != null &&
        _reportState != _ErrorReportState.sending &&
        _reportState != _ErrorReportState.sent;
  }

  String _buildTechnicalReport() {
    final String exception =
        widget.error?.toString().trim() ?? 'Errore Flutter non identificato';

    final String stack = widget.stackTrace?.toString().trim() ?? '';

    final String timestamp = DateTime.now().toUtc().toIso8601String();

    final StringBuffer buffer = StringBuffer()
      ..writeln('[StudentLab runtime]')
      ..writeln('timestamp_utc=$timestamp')
      ..writeln('exception=$exception');

    if (stack.isNotEmpty) {
      buffer
        ..writeln('stack:')
        ..write(stack);
    }

    final String value = buffer.toString();

    if (value.length <= 5000) {
      return value;
    }

    return value.substring(0, 5000);
  }

  Future<void> _sendReport() async {
    if (!_canReport) {
      return;
    }

    setState(() {
      _reportState = _ErrorReportState.sending;
    });

    try {
      await _apiService.createProfileErrorReport(
        category: 'other',
        description: _buildTechnicalReport(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reportState = _ErrorReportState.sent;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _reportState = _ErrorReportState.failed;
      });
    }
  }

  void _goBack() {
    final NavigatorState? navigator = Navigator.maybeOf(context);

    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  IconData get _reportIcon {
    switch (_reportState) {
      case _ErrorReportState.sending:
        return Icons.sync_rounded;
      case _ErrorReportState.sent:
        return Icons.check_rounded;
      case _ErrorReportState.failed:
        return Icons.refresh_rounded;
      case _ErrorReportState.idle:
        return Icons.bug_report_outlined;
    }
  }

  Color get _reportColor {
    switch (_reportState) {
      case _ErrorReportState.sent:
        return Colors.greenAccent;
      case _ErrorReportState.failed:
        return Colors.orangeAccent;
      case _ErrorReportState.sending:
      case _ErrorReportState.idle:
        return AppColors.skyBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkElegance,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.eleganceMidnight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 58,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Torna indietro',
                          onPressed: _goBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 14),
                        if (AuthSession.instance.isAuthenticated)
                          IconButton.filledTonal(
                            tooltip: 'Segnala errore',
                            onPressed: _canReport ? _sendReport : null,
                            icon: _reportState == _ErrorReportState.sending
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _reportColor,
                                    ),
                                  )
                                : Icon(_reportIcon, color: _reportColor),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
