import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import 'support_api_service.dart';
import 'support_session_page.dart';

class SupportRequestPage extends StatefulWidget {
  const SupportRequestPage({super.key});

  @override
  State<SupportRequestPage> createState() =>
      _SupportRequestPageState();
}

class _SupportRequestPageState
    extends State<SupportRequestPage> {
  final SupportApiService _api =
      SupportApiService();
  final TextEditingController _summaryController =
      TextEditingController();
  final TextEditingController _detailsController =
      TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _summaryController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) {
      return;
    }

    final String summary =
        _summaryController.text.trim();

    if (summary.length < 3) {
      _message(
        'Descrivi brevemente il problema.',
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final Map<String, dynamic> session =
          await _api.createSession(
        summary: summary,
        details: _detailsController.text,
      );

      final int? id =
          _asInt(session['id']);

      if (!mounted || id == null) {
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SupportSessionPage(
            sessionId: id,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _message(
          error
              .toString()
              .replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor:
            AppColors.brandNightBlue,
        foregroundColor:
            AppColors.pureWhite,
        title: const Text(
          'Richiedi assistenza',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 650,
            ),
            child: ListView(
              padding:
                  const EdgeInsets.all(20),
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color:
                        AppColors.eleganceMidnight,
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Invia la richiesta. Quando un operatore la accetta, '
                    'StudentLab ti chiederà il consenso prima di condividere '
                    'qualsiasi diagnostica locale.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller:
                      _summaryController,
                  maxLength: 500,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                  ),
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Problema riscontrato',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller:
                      _detailsController,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 5000,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                  ),
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Dettagli e passaggi per riprodurlo',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.support_agent,
                        ),
                  label: Text(
                    _sending
                        ? 'Invio richiesta...'
                        : 'Invia richiesta assistenza',
                  ),
                ),
              ],
            ),
          ),
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

  void _message(String value) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(content: Text(value)),
    );
  }
}
