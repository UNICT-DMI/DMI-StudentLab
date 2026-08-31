import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../services/account_security_api_service.dart';

import '../../services/api_service.dart';

import '../../services/auth_service.dart';

import '../../theme/nightTheme.dart';

import '../social_models.dart';

class EmailVerificationPage extends StatefulWidget {

  final String registrationId;

  final String email;

  final int expiresIn;

  final SocialProfileDraft? draft;

  final void Function(String registrationId, String email)?
      onRegistrationUpdated;

  final Future<void> Function()? onCancel;

  const EmailVerificationPage({

super.key,

    required this.registrationId,

    required this.email,

    required this.expiresIn,

this.draft,

this.onRegistrationUpdated,

this.onCancel,

  });

  @override

  State<EmailVerificationPage> createState() => _EmailVerificationPageState();

}

class _EmailVerificationPageState extends State<EmailVerificationPage> {

  final AuthService _authService = AuthService();

  final AccountSecurityApiService _securityService =

      AccountSecurityApiService();

  final TextEditingController _codeController = TextEditingController();

  Timer? _timer;

  Timer? _resendCooldownTimer;

  late String _registrationId;

  late String _email;

  late int _remainingSeconds;

  int _resendCooldownSeconds = 0;

  bool _verifying = false;

  bool _resending = false;

  bool _changingEmail = false;

  bool _allowPop = false;

  String? _error;

  String? _message;

  bool get _busy =>
      _verifying || _resending || _changingEmail;

  bool get _resendBlocked => _busy || _resendCooldownSeconds > 0;

  @override

  void initState() {

super.initState();

    _registrationId = widget.registrationId;

    _email = widget.email.trim();

    _remainingSeconds = widget.expiresIn < 0 ? 0 : widget.expiresIn;

    _startTimer();

  }

  @override

  void dispose() {

    _timer?.cancel();

    _resendCooldownTimer?.cancel();

    _codeController.dispose();

super.dispose();

  }

  void _startTimer() {

    _timer?.cancel();

    if (_remainingSeconds <= 0) {

      return;

    }

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {

      if (!mounted) {

        timer.cancel();

        return;

      }

      if (_remainingSeconds <= 1) {

        timer.cancel();

        setState(() {

          _remainingSeconds = 0;

        });

        return;

      }

      setState(() {

        _remainingSeconds--;

      });

    });

  }

  void _startResendCooldown(int seconds) {

    _resendCooldownTimer?.cancel();

    final int normalizedSeconds = seconds < 1 ? 1 : seconds;

    if (!mounted) return;

    setState(() {

      _resendCooldownSeconds = normalizedSeconds;

    });

    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (

      Timer timer,

    ) {

      if (!mounted) {

        timer.cancel();

        return;

      }

      if (_resendCooldownSeconds <= 1) {

        timer.cancel();

        setState(() {

          _resendCooldownSeconds = 0;

        });

        return;

      }

      setState(() {

        _resendCooldownSeconds--;

      });

    });

  }

  String get _remainingTimeLabel {

    final int minutes = _remainingSeconds ~/ 60;

    final int seconds = _remainingSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'

        '${seconds.toString().padLeft(2, '0')}';

  }

  Future<void> _verify() async {

    if (_busy) {

      return;

    }

    final String code = _codeController.text.trim();

    if (code.length != 6 || int.tryParse(code) == null) {

      setState(() {

        _error =

            'Inserisci il codice di verifica di 6 cifre ricevuto via email.';

        _message = null;

      });

      return;

    }

    if (_remainingSeconds <= 0) {

      setState(() {

        _error =

            'Il codice è scaduto. Richiedi un nuovo codice per continuare.';

        _message = null;

      });

      return;

    }

    FocusScope.of(context).unfocus();

    setState(() {

      _verifying = true;

      _error = null;

      _message = null;

    });

    try {

      final SocialUser user = await _authService.verifyEmail(

        registrationId: _registrationId,

        code: code,

        draft: widget.draft,

      );

      if (!mounted) {

        return;

      }

      _timer?.cancel();

      setState(() {

        _allowPop = true;

      });

      if (!mounted) {

        return;

      }

      Navigator.of(context).pop(user);

      return;

    } catch (error) {

      if (!mounted) {

        return;

      }

      setState(() {

        _verifying = false;

        _error = _cleanError(error);

        _message = null;

      });

    }

  }

  Future<void> _resend() async {

    if (_resendBlocked) {

      return;

    }

    setState(() {

      _resending = true;

      _error = null;

      _message = null;

    });

    try {

      final AuthVerificationResendResult result = await _authService

          .resendVerificationCode(registrationId: _registrationId);

      if (!mounted) {

        return;

      }

      setState(() {

        _resending = false;

        _registrationId = result.registrationId;

        _email = result.email;

        _remainingSeconds = result.expiresIn < 0 ? 0 : result.expiresIn;

        _codeController.clear();

        _message = result.message;

        _error = null;

      });

      widget.onRegistrationUpdated?.call(_registrationId, _email);

      _startTimer();

    } on ApiEmailVerificationCooldownException catch (error) {

      if (!mounted) {

        return;

      }

      setState(() {

        _resending = false;

        _error = null;

        _message = null;

      });

      _startResendCooldown(error.retryAfterSeconds);

    } catch (error) {

      if (!mounted) {

        return;

      }

      setState(() {

        _resending = false;

        _error = _cleanError(error);

        _message = null;

      });

    }

  }

  Future<void> _changeEmail() async {

    if (_busy) {

      return;

    }

    final _PendingEmailChangeData? data =

        await showDialog<_PendingEmailChangeData>(

          context: context,

          barrierDismissible: false,

          builder: (_) => _PendingEmailChangeDialog(currentEmail: _email),

        );

    if (!mounted || data == null) {

      return;

    }

    final String newEmail = data.email.trim();

    final String password = data.password;

    if (!_isValidEmail(newEmail)) {

      _showError('Inserisci un indirizzo email valido.');

      return;

    }

    if (newEmail.toLowerCase() == _email.trim().toLowerCase()) {

      _showError('La nuova email coincide con quella attuale.');

      return;

    }

    if (password.isEmpty) {

      _showError('Inserisci la password della registrazione.');

      return;

    }

    setState(() {

      _changingEmail = true;

      _error = null;

      _message = null;

    });

    try {

      final PendingRegistrationUpdateResult result = await _securityService

          .changePendingRegistrationEmail(

            registrationId: _registrationId,

            currentPassword: password,

            newEmail: newEmail,

          );

      if (!mounted) {

        return;

      }

      _resendCooldownTimer?.cancel();

      setState(() {

        _changingEmail = false;

        _registrationId = result.registrationId;

        _email = result.email;

        _remainingSeconds = result.expiresIn ?? 0;

        _resendCooldownSeconds = 0;

        _codeController.clear();

        _message = result.message;

        _error = null;

      });

      widget.onRegistrationUpdated?.call(_registrationId, _email);

      _startTimer();

    } catch (error) {

      if (!mounted) {

        return;

      }

      setState(() {

        _changingEmail = false;

        _error = _cleanError(error);

        _message = null;

      });

    }

  }

  bool _isValidEmail(String value) {

    final String email = value.trim();

    if (email.isEmpty || email.length > 320) {

      return false;

    }

    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  }

  void _showError(String message) {

    if (!mounted) {

      return;

    }

    setState(() {

      _error = message;

      _message = null;

    });

  }

  String _cleanError(Object error) {
    final String message = error.toString().toLowerCase();
    if (message.contains('codice') || message.contains('code')) {
      return 'Il codice non è valido o non è più utilizzabile.';
    }
    if (message.contains('email')) {
      return 'Non è stato possibile completare la verifica dell’email.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }
    return 'Non è stato possibile completare l’operazione. Riprova.';
  }

  Future<void> _cancelRegistration() async {

    final Future<void> Function()? onCancel = widget.onCancel;

    if (_busy || onCancel == null) {

      return;

    }

    await onCancel();

    if (!mounted) {

      return;

    }

    setState(() {

      _allowPop = true;

    });

    Navigator.of(context).pop();

  }

  @override

  Widget build(BuildContext context) {

    final bool expired = _remainingSeconds <= 0;

    return PopScope(

      canPop: _allowPop,

      onPopInvokedWithResult: (bool didPop, dynamic result) {

        if (didPop || _allowPop) {

          return;

        }

        return;

      },

      child: Scaffold(

        backgroundColor: AppColors.darkElegance,

        appBar: AppBar(

          automaticallyImplyLeading: false,

          backgroundColor: AppColors.brandNightBlue,

          foregroundColor: AppColors.pureWhite,

          title: const Text('Verifica email'),

        ),

        body: SafeArea(

          child: Center(

            child: ConstrainedBox(

              constraints: const BoxConstraints(maxWidth: 520),

              child: SingleChildScrollView(

                padding: const EdgeInsets.all(20),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [

                    const Icon(

                      Icons.mark_email_read_outlined,

                      color: AppColors.skyBlue,

                      size: 58,

                    ),

                    const SizedBox(height: 18),

                    const Text(

                      'Controlla la tua email',

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        color: AppColors.pureWhite,

                        fontSize: 23,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                    const SizedBox(height: 8),

                    Text(

                      'Abbiamo inviato un codice a $_email',

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        color: AppColors.pureWhite.withValues(alpha: 0.55),

                      ),

                    ),

                    const SizedBox(height: 8),

                    Text(

                      expired

                          ? 'Il codice non è più valido.'

                          : 'Codice valido ancora per $_remainingTimeLabel',

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        color: expired

                            ? Colors.orangeAccent

                            : AppColors.materialSky,

                        fontSize: 12,

                      ),

                    ),

                    const SizedBox(height: 26),

                    TextField(

                      controller: _codeController,

                      enabled: !_busy,

                      keyboardType: TextInputType.number,

                      inputFormatters: [

                        FilteringTextInputFormatter.digitsOnly,

                        LengthLimitingTextInputFormatter(6),

                      ],

                      textAlign: TextAlign.center,

                      textInputAction: TextInputAction.done,

                      onSubmitted: (_) => _verify(),

                      style: const TextStyle(

                        color: AppColors.pureWhite,

                        fontSize: 22,

                        letterSpacing: 8,

                      ),

                      decoration: const InputDecoration(

                        labelText: 'Codice di verifica',

                        counterText: '',

                      ),

                    ),

                    if (_error != null) ...[

                      const SizedBox(height: 14),

                      Text(

                        _error!,

                        style: const TextStyle(color: Colors.redAccent),

                      ),

                    ],

                    if (_message != null) ...[

                      const SizedBox(height: 14),

                      Text(

                        _message!,

                        style: const TextStyle(color: Colors.greenAccent),

                      ),

                    ],

                    const SizedBox(height: 20),

                    SizedBox(

                      height: 52,

                      child: ElevatedButton(

                        onPressed: _busy || expired ? null : _verify,

                        child: Text(

                          _verifying ? 'Verifica...' : 'Verifica email',

                        ),

                      ),

                    ),

                    const SizedBox(height: 12),

                    TextButton(

                      onPressed: _resendBlocked ? null : _resend,

                      child: Text(_resending ? 'Invio...' : 'Reinvia codice'),

                    ),

                    if (_resendCooldownSeconds > 0) ...[

                      const SizedBox(height: 4),

                      Text(

                        'Potrai richiedere un nuovo codice tra '

                        '$_resendCooldownSeconds '

                        '${_resendCooldownSeconds == 1 ? 'secondo' : 'secondi'}.',

                        textAlign: TextAlign.center,

                        style: const TextStyle(

                          color: Colors.orangeAccent,

                          fontSize: 12,

                        ),

                      ),

                    ],

                    const Divider(height: 32),

                    Text(

                      'Hai inserito un dato sbagliato?',

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        color: AppColors.pureWhite.withValues(alpha: 0.55),

                      ),

                    ),

                    const SizedBox(height: 8),

                    OutlinedButton.icon(

                      onPressed: _busy ? null : _changeEmail,

                      icon: const Icon(Icons.email_outlined),

                      label: Text(

                        _changingEmail ? 'Aggiornamento...' : 'Modifica email',

                      ),

                    ),

                    if (widget.onCancel != null) ...[

                      const SizedBox(height: 8),

                      TextButton(

                        onPressed: _busy ? null : _cancelRegistration,

                        child: Text(

                          'Annulla registrazione',

                          style: TextStyle(

                            color: AppColors.pureWhite.withValues(alpha: 0.55),

                          ),

                        ),

                      ),

                    ],


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

class _PendingEmailChangeData {

  final String email;

  final String password;

  const _PendingEmailChangeData({required this.email, required this.password});

}

class _PendingEmailChangeDialog extends StatefulWidget {

  final String currentEmail;

  const _PendingEmailChangeDialog({required this.currentEmail});

  @override

  State<_PendingEmailChangeDialog> createState() =>

      _PendingEmailChangeDialogState();

}

class _PendingEmailChangeDialogState extends State<_PendingEmailChangeDialog> {

  late final TextEditingController _emailController;

  final TextEditingController _passwordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _passwordVisible = false;

  @override

  void initState() {

    super.initState();

    _emailController = TextEditingController(text: widget.currentEmail);

  }

  @override

  void dispose() {

    _emailController.dispose();

    _passwordController.dispose();

    super.dispose();

  }

  void _submit() {

    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {

      return;

    }

    Navigator.of(context).pop(

      _PendingEmailChangeData(

        email: _emailController.text.trim(),

        password: _passwordController.text,

      ),

    );

  }

  @override

  Widget build(BuildContext context) {

    return AlertDialog(

      title: const Text('Modifica email'),

      content: Form(

        key: _formKey,

        child: SingleChildScrollView(

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              TextFormField(

                controller: _emailController,

                keyboardType: TextInputType.emailAddress,

                textInputAction: TextInputAction.next,

                autocorrect: false,

                enableSuggestions: false,

                validator: (value) {

                  final String email = value?.trim() ?? '';

                  if (email.isEmpty) {

                    return 'Inserisci la nuova email';

                  }

                  if (email.length > 320 ||

                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {

                    return 'Inserisci una email valida';

                  }

                  return null;

                },

                decoration: const InputDecoration(labelText: 'Nuova email'),

              ),

              const SizedBox(height: 12),

              TextFormField(

                controller: _passwordController,

                obscureText: !_passwordVisible,

                textInputAction: TextInputAction.done,

                onFieldSubmitted: (_) => _submit(),

                validator: (value) {

                  if (value == null || value.isEmpty) {

                    return 'Inserisci la password';

                  }

                  return null;

                },

                decoration: InputDecoration(

                  labelText: 'Password corrente',

                  helperText: 'Serve per confermare che sei tu.',

                  suffixIcon: IconButton(

                    onPressed: () {

                      setState(() {

                        _passwordVisible = !_passwordVisible;

                      });

                    },

                    icon: Icon(

                      _passwordVisible

                          ? Icons.visibility_off_outlined

                          : Icons.visibility_outlined,

                    ),

                  ),

                ),

              ),

            ],

          ),

        ),

      ),

      actions: [

        TextButton(

          onPressed: () => Navigator.of(context).pop(),

          child: const Text('Annulla'),

        ),

        FilledButton(onPressed: _submit, child: const Text('Aggiorna')),

      ],

    );

  }

}
