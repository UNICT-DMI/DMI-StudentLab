import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

import '../../theme/nightTheme.dart';

import '../social_models.dart';

import 'email_verification_page.dart';

import 'forgot_password_page.dart';

import 'registration_intro_page.dart';

class LoginPage extends StatefulWidget {

  const LoginPage({super.key});

  @override

  State<LoginPage> createState() => _LoginPageState();

}

class _LoginPageState extends State<LoginPage> {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;

  bool _passwordVisible = false;

  String? _error;

  @override

  void dispose() {

    _emailController.dispose();

    _passwordController.dispose();

super.dispose();

  }

  Future<void> _login() async {

    if (_loading) return;

    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();

    final String email = _emailController.text.trim();

    final String password = _passwordController.text;

    setState(() {

      _loading = true;

      _error = null;

    });

    try {

      final AuthLoginResult result = await _authService.login(

        email: email,

        password: password,

      );

      if (!mounted) return;

      if (result.user != null) {

        Navigator.pop(context, result.user);

        return;

      }

      if (!result.emailVerificationRequired) {

        throw Exception('Non è stato possibile completare l’accesso.');

      }

      final String registrationId = result.registrationId?.trim() ?? '';

      final String pendingEmail = result.email?.trim() ?? '';

      if (registrationId.isEmpty || pendingEmail.isEmpty) {

        throw Exception(

          'La registrazione esiste ma non è stato possibile riprendere la verifica email.',

        );

      }

      final SocialUser? verifiedUser = await Navigator.of(context)

          .push<SocialUser>(

            MaterialPageRoute(

              builder: (_) => EmailVerificationPage(

                registrationId: registrationId,

                email: pendingEmail,

                expiresIn: result.expiresIn,

              ),

            ),

          );

      if (!mounted || verifiedUser == null) return;

      Navigator.pop(context, verifiedUser);

    } catch (error) {

      if (!mounted) return;

      setState(() {

        _error = _cleanErrorMessage(error);

      });

    } finally {

      if (mounted) {

        setState(() {

          _loading = false;

        });

      }

    }

  }

  Future<void> _forgotPassword() async {

    if (_loading) return;

    await Navigator.of(context).push<void>(

      MaterialPageRoute(

        builder: (_) =>

            ForgotPasswordPage(initialEmail: _emailController.text.trim()),

      ),

    );

  }

  Future<void> _register() async {

    if (_loading) return;

    final SocialUser? user = await Navigator.of(context).push<SocialUser>(

      MaterialPageRoute(

        builder: (_) => const RegistrationIntroPage(),

      ),

    );

    if (!mounted || user == null) return;

    Navigator.pop(context, user);

  }



  String _cleanErrorMessage(Object error) {

    final String message = error.toString().toLowerCase();

    if (message.contains('401') ||

        message.contains('unauthorized') ||

        message.contains('invalid credentials') ||

        message.contains('incorrect password') ||

        message.contains('credenzial') ||

        message.contains('email o password')) {

      return 'Email o password non corretti. Controlla i dati inseriti e riprova.';

    }

    if (message.contains('registrazione') &&

        message.contains('verifica email')) {

      return 'La registrazione è presente, ma non è stato possibile riprendere la verifica dell’email. Riprova tra qualche momento.';

    }

    if (message.contains('403') ||

        message.contains('forbidden') ||

        message.contains('disabled') ||

        message.contains('inactive') ||

        message.contains('disabilitat') ||

        message.contains('non attivo')) {

      return 'Questo account non è attualmente disponibile. Contatta l’assistenza StudentLab se ritieni che si tratti di un errore.';

    }

    if (message.contains('429') ||

        message.contains('too many') ||

        message.contains('troppi tentativi')) {

      return 'Sono stati effettuati troppi tentativi. Attendi qualche momento e riprova.';

    }

    if (message.contains('network') ||

        message.contains('socket') ||

        message.contains('connection') ||

        message.contains('timeout') ||

        message.contains('host lookup')) {

      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';

    }

    if (message.contains('500') ||

        message.contains('502') ||

        message.contains('503') ||

        message.contains('server')) {

      return 'StudentLab non è temporaneamente disponibile. Riprova tra qualche momento.';

    }

    return 'Non è stato possibile effettuare l’accesso. Controlla i dati inseriti e riprova.';

  }

  String? _validateEmail(String? value) {

    if (value == null || value.trim().isEmpty) {

      return 'Inserisci la tua email';

    }

    final String email = value.trim();

    if (email.length > 320 ||

        !RegExp(r'^[^@\s]+@[^@\s]+.[^@\s]+$').hasMatch(email)) {

      return 'Inserisci una email valida';

    }

    return null;

  }

  String? _validatePassword(String? value) {

    if (value == null || value.isEmpty) {

      return 'Inserisci la password';

    }

    return null;

  }

  InputDecoration _decoration({

    required String label,

    required String hint,

    required IconData icon,

  }) {

    return InputDecoration(

      labelText: label,

      hintText: hint,

      labelStyle: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60)),

      hintStyle: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.30)),

      prefixIcon: Icon(icon, color: AppColors.skyBlue),

      filled: true,

      fillColor: AppColors.eleganceMidnight,

      border: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: BorderSide.none,

      ),

      enabledBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: BorderSide(

          color: AppColors.skyBlue.withValues(alpha: 0.08),

        ),

      ),

      focusedBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(color: AppColors.socialBlue),

      ),

      errorBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(color: Colors.redAccent),

      ),

      focusedErrorBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(color: Colors.redAccent),

      ),

    );

  }

  InputDecoration _passwordDecoration() {

    return _decoration(

      label: 'Password',

      hint: 'Inserisci la password',

      icon: Icons.lock_outline_rounded,

    ).copyWith(

      suffixIcon: IconButton(

        tooltip: _passwordVisible ? 'Nascondi password' : 'Mostra password',

        onPressed: _loading

            ? null

            : () {

                setState(() {

                  _passwordVisible = !_passwordVisible;

                });

              },

        icon: Icon(

          _passwordVisible

              ? Icons.visibility_off_outlined

              : Icons.visibility_outlined,

          color: AppColors.pureWhite.withValues(alpha: 0.55),

        ),

      ),

    );

  }

  Widget _buildError() {

    return Container(

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(

        color: Colors.redAccent.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.20)),

      ),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Icon(

            Icons.error_outline_rounded,

            color: Colors.redAccent,

            size: 20,

          ),

          const SizedBox(width: 9),

          Expanded(

            child: Text(

              _error ?? 'Errore durante l’accesso.',

              style: TextStyle(

                color: AppColors.pureWhite.withValues(alpha: 0.75),

                fontSize: 11,

                height: 1.4,

              ),

            ),

          ),

        ],

      ),

    );

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(

        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        elevation: 0,

        title: const Text('Accedi'),

      ),

      body: SafeArea(

        child: Center(

          child: LayoutBuilder(

            builder: (context, constraints) {

              final double width = constraints.maxWidth > 600

                  ? 500

                  : constraints.maxWidth;

              return SizedBox(

                width: width,

                child: SingleChildScrollView(

                  padding: const EdgeInsets.all(20),

                  child: Form(

                    key: _formKey,

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.stretch,

                      children: [

                        const SizedBox(height: 25),

                        Center(

                          child: Container(

                            width: 78,

                            height: 78,

                            decoration: BoxDecoration(

                              color: AppColors.brandNightBlue,

                              borderRadius: BorderRadius.circular(24),

                              border: Border.all(

                                color: AppColors.skyBlue.withValues(

                                  alpha: 0.20,

                                ),

                              ),

                            ),

                            child: const Icon(

                              Icons.lock_open_rounded,

                              color: AppColors.skyBlue,

                              size: 38,

                            ),

                          ),

                        ),

                        const SizedBox(height: 24),

                        const Text(

                          'Bentornato',

                          textAlign: TextAlign.center,

                          style: TextStyle(

                            color: AppColors.pureWhite,

                            fontSize: 26,

                            fontWeight: FontWeight.bold,

                          ),

                        ),

                        const SizedBox(height: 8),

                        Text(

                          'Accedi al tuo account StudentLab per utilizzare le funzionalità riservate.',

                          textAlign: TextAlign.center,

                          style: TextStyle(

                            color: AppColors.pureWhite.withValues(alpha: 0.55),

                            fontSize: 13,

                            height: 1.4,

                          ),

                        ),

                        const SizedBox(height: 32),

                        TextFormField(

                          controller: _emailController,

                          enabled: !_loading,

                          keyboardType: TextInputType.emailAddress,

                          textInputAction: TextInputAction.next,

                          autofillHints: const [AutofillHints.email],

                          autocorrect: false,

                          enableSuggestions: false,

                          style: const TextStyle(color: AppColors.pureWhite),

                          validator: _validateEmail,

                          decoration: _decoration(

                            label: 'Email',

                            hint: 'nome@example.com',

                            icon: Icons.email_outlined,

                          ),

                        ),

                        const SizedBox(height: 16),

                        TextFormField(

                          controller: _passwordController,

                          enabled: !_loading,

                          obscureText: !_passwordVisible,

                          enableSuggestions: false,

                          autocorrect: false,

                          textInputAction: TextInputAction.done,

                          autofillHints: const [AutofillHints.password],

                          style: const TextStyle(color: AppColors.pureWhite),

                          validator: _validatePassword,

                          onFieldSubmitted: (_) => _login(),

                          decoration: _passwordDecoration(),

                        ),

                        Align(

                          alignment: Alignment.centerRight,

                          child: TextButton(

                            onPressed: _loading ? null : _forgotPassword,

                            child: const Text('Password dimenticata?'),

                          ),

                        ),

                        if (_error != null) ...[

                          const SizedBox(height: 10),

                          _buildError(),

                        ],

                        const SizedBox(height: 20),

                        SizedBox(

                          height: 54,

                          child: ElevatedButton.icon(

                            onPressed: _loading ? null : _login,

                            icon: _loading

                                ? const SizedBox(

                                    width: 18,

                                    height: 18,

                                    child: CircularProgressIndicator(

                                      strokeWidth: 2,

                                      color: AppColors.pureWhite,

                                    ),

                                  )

                                : const Icon(Icons.login_rounded),

                            label: Text(

                              _loading ? 'Accesso in corso...' : 'Accedi',

                              style: const TextStyle(

                                fontSize: 16,

                                fontWeight: FontWeight.w600,

                              ),

                            ),

                            style: ElevatedButton.styleFrom(

                              backgroundColor: AppColors.socialBlue,

                              foregroundColor: AppColors.pureWhite,

                              shape: RoundedRectangleBorder(

                                borderRadius: BorderRadius.circular(16),

                              ),

                            ),

                          ),

                        ),

                        const SizedBox(height: 18),

                        Material(

                          color: Colors.transparent,

                          child: InkWell(

                            onTap: _loading ? null : _register,

                            borderRadius: BorderRadius.circular(14),

                            child: Container(

                              padding: const EdgeInsets.all(14),

                              decoration: BoxDecoration(

                                color: AppColors.eleganceMidnight,

                                borderRadius: BorderRadius.circular(14),

                                border: Border.all(

                                  color: AppColors.skyBlue.withValues(alpha: 0.14),

                                ),

                              ),

                              child: Row(

                                children: [

                                  Container(

                                    width: 42,

                                    height: 42,

                                    decoration: BoxDecoration(

                                      color: AppColors.socialBlue.withValues(alpha: 0.10),

                                      borderRadius: BorderRadius.circular(12),

                                    ),

                                    child: const Icon(

                                      Icons.person_add_alt_1_rounded,

                                      color: AppColors.materialSky,

                                      size: 21,

                                    ),

                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        const Text(

                                          'Non hai ancora un account?',

                                          style: TextStyle(

                                            color: AppColors.pureWhite,

                                            fontSize: 12,

                                            fontWeight: FontWeight.w600,

                                          ),

                                        ),

                                        const SizedBox(height: 3),

                                        Text(

                                          'Crea il tuo profilo StudentLab',

                                          style: TextStyle(

                                            color: AppColors.pureWhite.withValues(alpha: 0.52),

                                            fontSize: 10,

                                          ),

                                        ),

                                      ],

                                    ),

                                  ),

                                  const SizedBox(width: 8),

                                  const Text(

                                    'Registrati',

                                    style: TextStyle(

                                      color: AppColors.materialSky,

                                      fontSize: 11,

                                      fontWeight: FontWeight.w700,

                                    ),

                                  ),

                                  const SizedBox(width: 4),

                                  const Icon(

                                    Icons.arrow_forward_ios_rounded,

                                    color: AppColors.materialSky,

                                    size: 13,

                                  ),

                                ],

                              ),

                            ),

                          ),

                        ),

                        const SizedBox(height: 20),

                      ],

                    ),

                  ),

                ),

              );

            },

          ),

        ),

      ),

    );

  }

}