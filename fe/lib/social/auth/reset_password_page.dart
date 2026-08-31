import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../theme/nightTheme.dart';

import '../../services/account_security_api_service.dart';

class ResetPasswordPage extends StatefulWidget {

  final String requestId;

  final String email;

  const ResetPasswordPage({

super.key,

    required this.requestId,

    required this.email,

  });

  @override

  State<ResetPasswordPage> createState() =>

      _ResetPasswordPageState();

}

class _ResetPasswordPageState

    extends State<ResetPasswordPage> {

  final GlobalKey<FormState> _formKey =

      GlobalKey<FormState>();

  final AccountSecurityApiService _service =

      AccountSecurityApiService();

  final TextEditingController _codeController =

      TextEditingController();

  final TextEditingController

      _newPasswordController =

      TextEditingController();

  final TextEditingController

      _confirmPasswordController =

      TextEditingController();

  bool _loading = false;

  bool _newVisible = false;

  bool _confirmVisible = false;

  String? _error;

  String? _message;

  @override

  void dispose() {

    _codeController.dispose();

    _newPasswordController.dispose();

    _confirmPasswordController.dispose();

super.dispose();

  }

  Future<void> _submit() async {

    if (_loading ||

        !_formKey.currentState!.validate()) {

      return;

    }

    setState(() {

      _loading = true;

      _error = null;

      _message = null;

    });

    try {

      final String message =

          await _service.resetPassword(

        requestId:

            widget.requestId,

        code:

            _codeController.text.trim(),

        newPassword:

            _newPasswordController.text,

        confirmPassword:

            _confirmPasswordController.text,

      );

      if (!mounted) return;

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {

      if (!mounted) return;

      setState(() {

        _error = _cleanError(e);

      });

    } finally {

      if (mounted) {

        setState(() {

          _loading = false;

        });

      }

    }

  }

  String? _validatePassword(String? value) {
    final String password = value ?? '';
    if (password.length < 8) {
      return 'Usa almeno 8 caratteri';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Aggiungi almeno una lettera minuscola';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Aggiungi almeno una lettera maiuscola';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Aggiungi almeno un numero';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Aggiungi almeno un carattere speciale';
    }
    return null;
  }

  String _cleanError(Object error) {
    final String message = error.toString().toLowerCase();
    if (message.contains('codice') || message.contains('code')) {
      return 'Il codice non è valido o non è più utilizzabile.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }
    return 'Non è stato possibile aggiornare la password. Riprova.';
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

        title:

            const Text('Nuova password'),

      ),

      body: SafeArea(

        child: Center(

          child: ConstrainedBox(

            constraints:

                const BoxConstraints(

              maxWidth: 520,

            ),

            child: SingleChildScrollView(

              padding:

                  const EdgeInsets.all(20),

              child: Form(

                key: _formKey,

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.stretch,

                  children: [

                    Text(

                      'Codice inviato a ${widget.email}',

                      textAlign:

                          TextAlign.center,

                      style: TextStyle(

                        color:

                            AppColors.pureWhite

                                .withValues(

                          alpha: 0.6,

                        ),

                      ),

                    ),

                    const SizedBox(height: 8),

                    const Text(

                      'Il codice di recupero non ha una scadenza temporale. È monouso e viene invalidato quando ne richiedi uno nuovo.',

                      textAlign:

                          TextAlign.center,

                      style: TextStyle(

                        color:

                            Colors.white54,

                        fontSize: 12,

                        height: 1.4,

                      ),

                    ),

                    const SizedBox(height: 26),

                    TextFormField(

                      controller:

                          _codeController,

                      enabled: !_loading,

                      keyboardType:

                          TextInputType.number,

                      inputFormatters: [

                        FilteringTextInputFormatter

                            .digitsOnly,

                        LengthLimitingTextInputFormatter(

                          6,

                        ),

                      ],

                      validator: (value) {

                        if ((value ?? '')

                                .length !=

                            6) {

                          return 'Inserisci il codice di 6 cifre';

                        }

                        return null;

                      },

                      decoration:

                          const InputDecoration(

                        labelText:

                            'Codice di verifica',

                        prefixIcon: Icon(

                          Icons

                              .pin_outlined,

                        ),

                      ),

                    ),

                    const SizedBox(height: 16),

                    TextFormField(

                      controller:

                          _newPasswordController,

                      enabled: !_loading,

                      obscureText: !_newVisible,

                      validator:

                          _validatePassword,

                      decoration:

                          InputDecoration(

                        labelText:

                            'Nuova password',

                        prefixIcon:

                            const Icon(

                          Icons.lock_outline,

                        ),

                        suffixIcon:

                            IconButton(

                          onPressed: () {

                            setState(() {

                              _newVisible =

                                  !_newVisible;

                            });

                          },

                          icon: Icon(

                            _newVisible

                                ? Icons

                                    .visibility_off_outlined

                                : Icons

                                    .visibility_outlined,

                          ),

                        ),

                      ),

                    ),

                    const SizedBox(height: 16),

                    TextFormField(

                      controller:

                          _confirmPasswordController,

                      enabled: !_loading,

                      obscureText:

                          !_confirmVisible,

                      validator: (value) {

                        if (value !=

                            _newPasswordController

                                .text) {

                          return 'Le password non coincidono';

                        }

                        return _validatePassword(

                          value,

                        );

                      },

                      decoration:

                          InputDecoration(

                        labelText:

                            'Conferma password',

                        prefixIcon:

                            const Icon(

                          Icons.lock_reset_outlined,

                        ),

                        suffixIcon:

                            IconButton(

                          onPressed: () {

                            setState(() {

                              _confirmVisible =

                                  !_confirmVisible;

                            });

                          },

                          icon: Icon(

                            _confirmVisible

                                ? Icons

                                    .visibility_off_outlined

                                : Icons

                                    .visibility_outlined,

                          ),

                        ),

                      ),

                    ),

                    if (_error != null) ...[

                      const SizedBox(height: 14),

                      Text(

                        _error!,

                        style:

                            const TextStyle(

                          color:

                              Colors.redAccent,

                        ),

                      ),

                    ],

                    if (_message != null) ...[

                      const SizedBox(height: 14),

                      Text(

                        _message!,

                        style:

                            const TextStyle(

                          color:

                              Colors.greenAccent,

                        ),

                      ),

                    ],

                    const SizedBox(height: 22),

                    SizedBox(

                      height: 52,

                      child:

                          ElevatedButton(

                        onPressed:

                            _loading

                                ? null

                                : _submit,

                        child: Text(

                          _loading

                              ? 'Aggiornamento...'

                              : 'Imposta nuova password',

                        ),

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