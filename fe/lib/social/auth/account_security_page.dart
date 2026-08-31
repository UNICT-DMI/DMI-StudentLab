import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/account_security_api_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/auth_session.dart';
import '../../theme/nightTheme.dart';
import '../social_models.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final AccountSecurityApiService _securityService =
      AccountSecurityApiService();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  bool _loading = false;

  SocialUser? get _currentUser => AuthSession.instance.currentUser;

  bool _isStrongPassword(String value) {
    if (value.length < 8 || RegExp(r'\s').hasMatch(value)) {
      return false;
    }
    return RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  bool _isValidEmail(String value) {
    final String email = value.trim();
    if (email.isEmpty || email.length > 320) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _changeName() async {
    if (_loading) return;

    final SocialUser? user = _currentUser;
    if (user == null) {
      _showMessage('Profilo non disponibile. Riprova.');
      return;
    }

    final TextEditingController firstNameController =
        TextEditingController(text: user.firstName);
    final TextEditingController lastNameController =
        TextEditingController(text: user.lastName);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: const Text(
            'Modifica nome e cognome',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: AppColors.pureWhite),
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: AppColors.pureWhite),
                  decoration: const InputDecoration(labelText: 'Cognome'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      firstNameController.dispose();
      lastNameController.dispose();
      return;
    }

    final String firstName = firstNameController.text.trim();
    final String lastName = lastNameController.text.trim();
    firstNameController.dispose();
    lastNameController.dispose();

    if (firstName.isEmpty || lastName.isEmpty) {
      _showMessage('Nome e cognome non possono essere vuoti.');
      return;
    }

    setState(() => _loading = true);

    try {
      final SocialUser updatedUser = await _apiService.updateSocialUser(
        userId: user.id,
        firstName: firstName,
        lastName: lastName,
      );

      AuthSession.instance.updateUser(updatedUser);

      if (!mounted) return;
      setState(() {});
      _showMessage('Nome e cognome aggiornati.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_loading) return;

    final TextEditingController currentController = TextEditingController();
    final TextEditingController newController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: const Text(
            'Modifica password',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: AppColors.pureWhite),
                  decoration: const InputDecoration(
                    labelText: 'Password attuale',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: AppColors.pureWhite),
                  decoration: const InputDecoration(
                    labelText: 'Nuova password',
                    helperText:
                        '8+ caratteri, maiuscola, minuscola, numero e simbolo',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: AppColors.pureWhite),
                  decoration: const InputDecoration(
                    labelText: 'Conferma nuova password',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Aggiorna'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
      return;
    }

    final String currentPassword = currentController.text;
    final String newPassword = newController.text;
    final String confirmPassword = confirmController.text;
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();

    if (currentPassword.isEmpty) {
      _showMessage('Inserisci la password attuale.');
      return;
    }

    if (!_isStrongPassword(newPassword)) {
      _showMessage(
        'Usa almeno 8 caratteri con maiuscola, minuscola, numero e simbolo, senza spazi.',
      );
      return;
    }

    if (newPassword == currentPassword) {
      _showMessage('La nuova password deve essere diversa da quella attuale.');
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('Le password non coincidono.');
      return;
    }

    setState(() => _loading = true);

    try {
      final String message = await _securityService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (!mounted) return;
      _showMessage(message);
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeEmail() async {
    if (_loading) return;

    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: const Text(
            'Modifica email',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(color: AppColors.pureWhite),
                  decoration: const InputDecoration(labelText: 'Nuova email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: AppColors.pureWhite),
                  decoration: const InputDecoration(
                    labelText: 'Password attuale',
                    helperText: 'Serve per confermare che sei tu.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Invia codice'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      emailController.dispose();
      passwordController.dispose();
      return;
    }

    final String newEmail = emailController.text.trim();
    final String password = passwordController.text;
    emailController.dispose();
    passwordController.dispose();

    if (!_isValidEmail(newEmail)) {
      _showMessage('Inserisci un indirizzo email valido.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Inserisci la password attuale.');
      return;
    }

    final String currentEmail =
        _currentUser?.email.trim().toLowerCase() ?? '';

    if (currentEmail.isNotEmpty &&
        newEmail.toLowerCase() == currentEmail) {
      _showMessage('La nuova email coincide con quella attuale.');
      return;
    }

    setState(() => _loading = true);

    try {
      final EmailChangeStartResult result =
          await _securityService.startEmailChange(
        currentPassword: password,
        newEmail: newEmail,
      );

      if (!mounted) return;

      await _verifyNewEmail(
        requestId: result.requestId,
        email: result.newEmail,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyNewEmail({
    required String requestId,
    required String email,
  }) async {
    final TextEditingController codeController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: const Text(
            'Verifica nuova email',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Inserisci il codice di 6 cifre inviato a $email.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(color: AppColors.pureWhite),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Codice di verifica',
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Verifica'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      codeController.dispose();
      return;
    }

    final String code = codeController.text.trim();
    codeController.dispose();

    if (code.length != 6 || int.tryParse(code) == null) {
      _showMessage('Inserisci un codice di verifica valido di 6 cifre.');
      return;
    }

    try {
      final String updatedEmail =
          await _securityService.completeEmailChange(
        requestId: requestId,
        code: code,
      );

      await _authService.refreshCurrentUser();

      if (!mounted) return;
      setState(() {});
      _showMessage('Email aggiornata: $updatedEmail');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    }
  }

  String _cleanError(Object error) {
    String value = error.toString();
    if (value.startsWith('Exception: ')) {
      value = value.substring(11);
    }
    return value.trim().isEmpty
        ? 'Operazione non completata. Riprova.'
        : value.trim();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _accountTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      tileColor: AppColors.eleganceMidnight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      leading: Icon(icon, color: AppColors.skyBlue),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.pureWhite,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white54),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.white54,
      ),
      onTap: _loading ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SocialUser? user = _currentUser;
    final String fullName = user == null || user.name.trim().isEmpty
        ? 'Nome e cognome'
        : user.name.trim();
    final String email = user?.email.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Account e sicurezza'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Modifica i dati principali e le credenziali del tuo account.',
                  style: TextStyle(
                    color: AppColors.pureWhite.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 16),
                _accountTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Nome e cognome',
                  subtitle: fullName,
                  onTap: _changeName,
                ),
                const SizedBox(height: 12),
                _accountTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: email.isEmpty ? 'Email account' : email,
                  onTap: _changeEmail,
                ),
                const SizedBox(height: 12),
                _accountTile(
                  icon: Icons.password_outlined,
                  title: 'Password',
                  subtitle: 'Modifica la password di accesso',
                  onTap: _changePassword,
                ),
                if (_loading) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}