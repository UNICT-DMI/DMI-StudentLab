import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';
import '../data/developer_api_repository.dart';
import '../models/developer_models.dart';
import 'developer_dashboard_page.dart';

class DeveloperEntryPage extends StatefulWidget {
  const DeveloperEntryPage({
    super.key,
  });

  @override
  State<DeveloperEntryPage> createState() =>
      _DeveloperEntryPageState();
}

class _DeveloperEntryPageState
    extends State<DeveloperEntryPage> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  bool _loading = true;
  bool _authorized = false;
  String? _role;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  Future<void> _verifyAccess() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final DeveloperAccessResult result =
          await _repository.getAccess();

      if (!mounted) {
        return;
      }

      setState(() {
        _authorized = result.authorized;
        _role = result.role;
        _loading = false;
      });
    } on DeveloperApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authorized = false;
        _loading = false;
        _error = error.statusCode == 403
            ? 'Questa sessione non dispone dei permessi '
                'Developer & System.'
            : error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authorized = false;
        _loading = false;
        _error =
            'Impossibile verificare l’accesso Developer & System.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.darkElegance,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.skyBlue,
          ),
        ),
      );
    }

    if (!_authorized) {
      return Scaffold(
        backgroundColor: AppColors.darkElegance,
        appBar: AppBar(
          backgroundColor: AppColors.brandNightBlue,
          foregroundColor: AppColors.pureWhite,
          elevation: 0,
          title: const Text(
            'Developer & System',
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 480),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.eleganceMidnight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.redAccent
                        .withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.redAccent
                            .withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.gpp_bad_outlined,
                        color: Colors.redAccent,
                        size: 31,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Accesso non autorizzato',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error ??
                          'Il backend non ha autorizzato '
                              'questa sessione.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite
                            .withValues(alpha: 0.52),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _verifyAccess,
                      icon: const Icon(
                        Icons.refresh_rounded,
                      ),
                      label: const Text('Riprova'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DeveloperDashboardPage(
      authorizedRole: _role,
    );
  }
}
