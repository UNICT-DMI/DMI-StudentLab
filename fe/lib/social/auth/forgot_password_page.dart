import 'package:flutter/material.dart';

import '../../services/account_security_api_service.dart';
import '../../theme/nightTheme.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordPage({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AccountSecurityApiService _service = AccountSecurityApiService();

  late final TextEditingController _emailController;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.initialEmail.trim(),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final String email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Inserisci la tua email';
    }

    if (email.length > 320 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Inserisci una email valida';
    }

    return null;
  }

  Future<void> _submit() async {
    if (_loading) return;

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();

    final String email = _emailController.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final PasswordResetStartResult result =
          await _service.startPasswordReset(email: email);

      if (!mounted) return;

      if (result.requestId.trim().isEmpty) {
        throw Exception(
          'Non è stato possibile avviare il recupero password.',
        );
      }

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(
            requestId: result.requestId,
            email: email,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _cleanError(Object error) {
    final String raw = error.toString();
    final String message = raw.toLowerCase();

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    if (message.contains('429') ||
        message.contains('too many') ||
        message.contains('attendi')) {
      return 'Hai effettuato troppe richieste. Attendi qualche momento e riprova.';
    }

    if (message.contains('500') ||
        message.contains('502') ||
        message.contains('503') ||
        message.contains('server')) {
      return 'Il servizio di recupero password non è temporaneamente disponibile. Riprova tra qualche momento.';
    }

    String cleaned = raw;
    if (cleaned.startsWith('Exception: ')) {
      cleaned = cleaned.substring(11);
    }

    return cleaned.trim().isEmpty
        ? 'Non è stato possibile avviare il recupero password.'
        : cleaned.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Recupera password'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.skyBlue,
                      size: 58,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Password dimenticata?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Inserisci l’email associata al tuo account. '
                      'Se l’indirizzo è registrato su StudentLab, riceverai un codice per impostare una nuova password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.55),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                      ),
                      validator: _validateEmail,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.pureWhite,
                                ),
                              )
                            : const Icon(
                                Icons.mark_email_read_outlined,
                              ),
                        label: Text(
                          _loading ? 'Invio...' : 'Invia codice',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Per motivi di sicurezza StudentLab non conferma se un indirizzo email è registrato.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.38),
                        fontSize: 11,
                        height: 1.4,
                      ),
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