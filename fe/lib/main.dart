import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'layers/home.dart';
import 'local_storage/database/database_platform_initializer.dart';
import 'local_storage/local_storage.dart';
import 'services/app_update_service.dart';
import 'theme/nightTheme.dart';
import 'widgets/studentlab_wolf_wave.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureGlobalErrorHandling();

  await initializeDatabasePlatform();

  final LocalStorageService localStorage = LocalStorageService();
  await localStorage.initialize();

  await _applyPreferredSystemUi();

  runApp(const MyApp());
}

Future<void> _applyPreferredSystemUi() async {
  if (kIsWeb) {
    return;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;

    final int sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 36) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      );

      return;
    }

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    return;
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
}

void _configureGlobalErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );

    return kReleaseMode;
  };
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restoreSystemUi();
    }
  }

  Future<void> _restoreSystemUi() async {
    await _applyPreferredSystemUi();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudentLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandNightBlue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.darkElegance,
        appBarTheme: AppColors.nightAppBarTheme,
        cardTheme: AppColors.elegantCardTheme,
        bottomNavigationBarTheme: AppColors.nightBottomNavTheme,
      ),
      home: const AppStartupGate(),
    );
  }
}

class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  final AppUpdateService _updateService = AppUpdateService();

  bool _loading = true;
  bool _optionalUpdateShown = false;
  AppUpdateInfo? _updateInfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkApplicationVersion();
  }

  Future<void> _checkApplicationVersion() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final AppUpdateInfo info = await _updateService.checkForUpdates();

      if (!mounted) {
        return;
      }

      setState(() {
        _updateInfo = info;
        _loading = false;
      });

      if (info.status == AppUpdateStatus.optional && !_optionalUpdateShown) {
        _optionalUpdateShown = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showOptionalUpdate(info);
          }
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _cleanError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _StartupLoadingPage();
    }

    final AppUpdateInfo? info = _updateInfo;

    if (info?.status == AppUpdateStatus.maintenance) {
      return _MaintenancePage(info: info!, onRetry: _checkApplicationVersion);
    }

    if (info?.status == AppUpdateStatus.required) {
      return _RequiredUpdatePage(
        info: info!,
        onUpdate: () async {
          await _openUpdateUrl(info.updateUrl);
        },
        onRetry: _checkApplicationVersion,
      );
    }

    return const HomePage();
  }

  Future<void> _showOptionalUpdate(AppUpdateInfo info) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: const Text(
            'Aggiornamento disponibile',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'È disponibile StudentLab ${info.latestVersion}.',
                style: const TextStyle(color: Colors.white70),
              ),
              if (info.message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  info.message,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Versione installata: ${info.currentVersion}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Più tardi'),
            ),
            FilledButton(
              onPressed: info.updateUrl.isEmpty
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();

                      await _openUpdateUrl(info.updateUrl);
                    },
              child: const Text('Aggiorna'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openUpdateUrl(String updateUrl) async {
    if (updateUrl.isEmpty) {
      _showMessage('Link di aggiornamento non ancora disponibile.');

      return;
    }

    final Uri? uri = Uri.tryParse(updateUrl);

    if (uri == null) {
      _showMessage('Link di aggiornamento non valido.');

      return;
    }

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      _showMessage('Impossibile aprire il link di aggiornamento.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _cleanError(Object error) {
    String message = error.toString();

    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }

    return message;
  }
}

class _StartupLoadingPage extends StatelessWidget {
  const _StartupLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.darkElegance,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [StudentLabWolfSplash(size: 320), SizedBox(height: 20)],
        ),
      ),
    );
  }
}

class _RequiredUpdatePage extends StatelessWidget {
  final AppUpdateInfo info;
  final Future<void> Function() onUpdate;
  final Future<void> Function() onRetry;

  const _RequiredUpdatePage({
    required this.info,
    required this.onUpdate,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.eleganceMidnight,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.skyBlue.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.brandNightBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: AppColors.skyBlue,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Aggiornamento necessario',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Questa versione di StudentLab non è più supportata.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.60),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    if (info.message.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        info.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.materialSky.withValues(alpha: 0.85),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _VersionRow(
                      label: 'Installata',
                      value: info.currentVersion,
                    ),
                    const SizedBox(height: 8),
                    _VersionRow(
                      label: 'Minima richiesta',
                      value: info.minimumVersion,
                    ),
                    const SizedBox(height: 8),
                    _VersionRow(
                      label: 'Disponibile',
                      value: info.latestVersion,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: info.updateUrl.isEmpty
                            ? null
                            : () async {
                                await onUpdate();
                              },
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Aggiorna StudentLab'),
                      ),
                    ),
                    if (info.updateUrl.isEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Il download dell\'aggiornamento non è ancora disponibile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await onRetry();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Controlla di nuovo'),
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

class _MaintenancePage extends StatelessWidget {
  final AppUpdateInfo info;
  final Future<void> Function() onRetry;

  const _MaintenancePage({required this.info, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.eleganceMidnight,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.skyBlue.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.construction_rounded,
                      color: AppColors.skyBlue,
                      size: 56,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'StudentLab è in manutenzione',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      info.message.isNotEmpty
                          ? info.message
                          : 'Stiamo effettuando alcuni aggiornamenti. Riprova tra poco.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.60),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await onRetry();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Riprova'),
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

class _VersionRow extends StatelessWidget {
  final String label;
  final String value;

  const _VersionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.materialSky,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
