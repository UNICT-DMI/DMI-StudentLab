import 'package:flutter/material.dart';

import '../../developer/pages/developer_entry_page.dart';

import '../../material/admin/admin_material_storage_page.dart';

import '../../services/api_service.dart';

import '../../theme/nightTheme.dart';

import '../news/institutional_news_page.dart';

import '../news/public_news_editor_page.dart';

import '../social_models.dart';

import 'admin_academic_paths_page.dart';

import 'admin_grades_page.dart';

import 'admin_news_reports_page.dart';

import 'admin_public_news_reports_page.dart';

import 'admin_profile_error_reports_page.dart';
import 'admin_community_reports_page.dart';

import 'admin_reviews_page.dart';

import 'admin_security_page.dart';

import 'admin_support_sessions_page.dart';

import 'admin_teachers_page.dart';

import 'admin_teacher_assignments_page.dart';

import 'admin_user_page.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final ApiService _apiService = ApiService();

  bool _loading = true;

  bool _authorized = false;

  String? _error;

  String? _currentUserRole;

  bool get _isCreator => _currentUserRole == 'creator';

  bool get _isDeveloperSystem => _currentUserRole == 'devsyst';

  String get _roleLabel {
    if (_isCreator) return 'Creator';

    if (_isDeveloperSystem) return 'Developer';

    return 'Admin';
  }

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
      String? currentUserRole;

      try {
        final SocialUser currentUser = await _apiService.getCurrentUser();

        currentUserRole = currentUser.role.trim().toLowerCase();
      } catch (_) {
        currentUserRole = null;
      }

      final bool isDeveloper = currentUserRole == 'devsyst';

      final bool authorized =
          isDeveloper || await _apiService.canAccessAdminPanel();

      if (!mounted) return;

      setState(() {
        _authorized = authorized;

        _currentUserRole = currentUserRole;

        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _authorized = false;

        _currentUserRole = null;

        _loading = false;

        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _openProtectedPage(Widget page) async {
    try {
      final bool authorized =
          _isDeveloperSystem || await _apiService.canAccessAdminPanel();

      if (!mounted) return;

      if (!authorized) {
        setState(() {
          _authorized = false;
        });

        return;
      }

      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page));

      if (mounted) await _verifyAccess();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Non è stato possibile aprire questa sezione. Riprova.';
      });
    }
  }

  Future<void> _openDeveloperArea() async {
    if (!mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DeveloperEntryPage()));

    if (mounted) {
      await _verifyAccess();
    }
  }

  Future<void> _openNewsEditor() async {
    final bool authorized =
        _isDeveloperSystem || await _apiService.canAccessAdminPanel();

    if (!mounted) return;

    if (!authorized) {
      setState(() {
        _authorized = false;
      });

      return;
    }

    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PublicNewsEditorPage.admin(),
      ),
    );

    if (!mounted || created != true) return;
  }

  void _showPending(String feature) {}

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.darkElegance,

        body: Center(
          child: CircularProgressIndicator(color: AppColors.skyBlue),
        ),
      );
    }

    if (!_authorized) {
      return _AdminAccessDeniedPage(error: _error, onRetry: _verifyAccess);
    }

    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        elevation: 0,

        title: Text(
          'Admin Panel · $_roleLabel',

          style: const TextStyle(fontWeight: FontWeight.w600),
        ),

        actions: [
          IconButton(
            tooltip: 'Verifica accesso',

            onPressed: _verifyAccess,

            icon: const Icon(Icons.verified_user_outlined),
          ),
        ],
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),

            child: RefreshIndicator(
              onRefresh: _verifyAccess,

              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(20),

                children: [
                  _buildHeader(),

                  const SizedBox(height: 28),

                  const _AdminSectionTitle(
                    title: 'Pubblicazione e contenuti',

                    subtitle:
                        'Gestisci news pubbliche, materiali, storage e pubblicazioni rivolte agli studenti.',
                  ),

                  const SizedBox(height: 14),

                  _buildPublishingGrid(),

                  const SizedBox(height: 30),

                  const _AdminSectionTitle(
                    title: 'Moderazione',

                    subtitle:
                        'Controlla contenuti, verifiche e segnalazioni della community.',
                  ),

                  const SizedBox(height: 14),

                  _buildModerationGrid(),

                  const SizedBox(height: 30),

                  const _AdminSectionTitle(
                    title: 'Supporto e diagnostica',

                    subtitle:
                        'Gestisci richieste di assistenza, sessioni temporanee e diagnostica remota autorizzata.',
                  ),

                  const SizedBox(height: 14),

                  _buildSupportGrid(),

                  const SizedBox(height: 30),

                  const _AdminSectionTitle(
                    title: 'Gestione',

                    subtitle:
                        'Gestisci account, autorizzazioni, sicurezza e strumenti tecnici della piattaforma.',
                  ),

                  const SizedBox(height: 14),

                  _buildManagementGrid(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.14)),
      ),

      child: Row(
        children: [
          Container(
            width: 60,

            height: 60,

            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.08),

              borderRadius: BorderRadius.circular(17),
            ),

            child: const Icon(
              Icons.admin_panel_settings_outlined,

              color: Colors.greenAccent,

              size: 31,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Amministrazione StudentLab',

                  style: TextStyle(
                    color: AppColors.pureWhite,

                    fontSize: 19,

                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Pubblicazione, moderazione, storage, assistenza e gestione della piattaforma.',

                  style: TextStyle(
                    color: AppColors.pureWhite.withValues(alpha: 0.50),

                    fontSize: 11,

                    height: 1.4,
                  ),
                ),

                if (_currentUserRole != null) ...[
                  const SizedBox(height: 9),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,

                      vertical: 5,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.08),

                      borderRadius: BorderRadius.circular(9),

                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.18),
                      ),
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,

                          color: Colors.greenAccent,

                          size: 14,
                        ),

                        SizedBox(width: 6),

                        Text(
                          _roleLabel,

                          style: TextStyle(
                            color: Colors.greenAccent,

                            fontSize: 10,

                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishingGrid() {
    return _AdminGrid(
      children: [
        _AdminModuleCard(
          icon: Icons.campaign_outlined,

          title: 'Pubblica news',

          description: 'Crea una comunicazione pubblica con target accademico.',

          onTap: _openNewsEditor,
        ),

        _AdminModuleCard(
          icon: Icons.newspaper_outlined,

          title: 'Gestisci news',

          description: 'Modera, elimina e controlla le news pubbliche.',

          onTap: () {
            _openProtectedPage(const InstitutionalNewsPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.cloud_outlined,

          title: 'Materiali e Storage',

          description:
              'Gestisci proposte, materiali StudentLab, docenti, gruppi, Blob, ritiro, eliminazione e spazio recuperabile.',

          onTap: () {
            _openProtectedPage(const AdminMaterialStoragePage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.assignment_ind_outlined,

          title: 'Assegnazioni materiali',

          description:
              'Controlla la distribuzione dei materiali a singoli studenti e gruppi.',

          onTap: () => _showPending(
            'La gestione amministrativa centralizzata delle assegnazioni',
          ),

          pending: true,
        ),

        _AdminModuleCard(
          icon: Icons.swap_horiz_outlined,

          title: 'Migrazione storage',

          description:
              'Sposta materiali selezionati verso un altro provider mantenendo riferimenti, hash e integrità.',

          onTap: () => _showPending('La migrazione controllata dello storage'),

          pending: true,
        ),

        _AdminModuleCard(
          icon: Icons.history_outlined,

          title: 'Audit materiali',

          description:
              'Consulta chi ha approvato, ritirato, rinominato, eliminato o migrato un materiale.',

          onTap: () =>
              _showPending('La pagina audit delle operazioni sui materiali'),

          pending: true,
        ),
      ],
    );
  }

  Widget _buildModerationGrid() {
    return _AdminGrid(
      children: [
        _AdminModuleCard(
          icon: Icons.rate_review_outlined,

          title: 'Recensioni',

          description: 'Approva, rifiuta e nascondi le recensioni.',

          onTap: () {
            _openProtectedPage(const AdminReviewsPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.cast_for_education_outlined,

          title: 'Docenti',

          description: 'Verifica gli account dei docenti.',

          onTap: () {
            _openProtectedPage(const AdminTeachersPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.workspace_premium_outlined,

          title: 'Voti',

          description: 'Verifica i voti dichiarati dagli studenti.',

          onTap: () {
            _openProtectedPage(const AdminGradesPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.account_balance_outlined,

          title: 'Percorsi',

          description: 'Verifica lauree e percorsi accademici.',

          onTap: () {
            _openProtectedPage(const AdminAcademicPathsPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.school_outlined,

          title: 'Insegnamenti',

          description: 'Verifica gli insegnamenti dichiarati dai docenti.',

          onTap: () {
            _openProtectedPage(const AdminTeacherAssignmentsPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.flag_outlined,

          title: 'Segnalazioni news',

          description: 'Gestisci segnalazioni e contenuti pubblici contestati.',

          onTap: () {
            _openProtectedPage(const AdminPublicNewsReportsPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.forum_outlined,

          title: 'Segnalazioni bacheche',

          description:
              'Gestisci avvisi, news di gruppo e messaggi privati segnalati, con apertura del contenuto consentita dal segnalante.',

          onTap: () {
            _openProtectedPage(const AdminNewsReportsPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.groups_2_outlined,

          title: 'Segnalazioni gruppi',

          description:
              'Gestisci gruppi segnalati, motivazioni e stato della moderazione.',

          onTap: () {
            _openProtectedPage(const AdminGroupReportsPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.person_off_outlined,

          title: 'Segnalazioni utenti',

          description:
              'Gestisci profili segnalati, motivazioni e stato della moderazione.',

          onTap: () {
            _openProtectedPage(const AdminUserReportsPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.report_problem_outlined,

          title: 'Segnalazioni contenuti',

          description:
              'Gestisci contenuti dei gruppi segnalati e applica azioni di moderazione.',

          onTap: () {
            _openProtectedPage(const AdminGroupContentReportsPage());
          },
        ),
      ],
    );
  }

  Widget _buildSupportGrid() {
    return _AdminGrid(
      children: [
        _AdminModuleCard(
          icon: Icons.support_agent_outlined,

          title: 'Assistenza remota',

          description:
              'Gestisci richieste di malfunzionamento e sessioni temporanee autorizzate con l’utente online.',

          onTap: () {
            _openProtectedPage(const AdminSupportSessionsPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.bug_report_outlined,

          title: 'Segnalazioni errori',

          description:
              'Consulta i problemi segnalati dagli utenti e gestiscine lo stato.',

          onTap: () {
            _openProtectedPage(const AdminProfileErrorReportsPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.storage_outlined,

          title: 'Diagnostica SQLite',

          description:
              'Visualizza snapshot diagnostici autorizzati della SQLite dell’app durante una sessione di supporto.',

          onTap: () => _showPending('La diagnostica SQLite remota autorizzata'),

          pending: true,
        ),

        _AdminModuleCard(
          icon: Icons.sync_problem_outlined,

          title: 'Azioni remote',

          description:
              'Forza sync, pulizia cache remota, verifica file e altre azioni controllate durante l’assistenza.',

          onTap: () =>
              _showPending('Le azioni remote controllate di assistenza'),

          pending: true,
        ),

        _AdminModuleCard(
          icon: Icons.receipt_long_outlined,

          title: 'Storico assistenza',

          description:
              'Consulta sessioni concluse, consensi, operatori, azioni eseguite e risultati.',

          onTap: () => _showPending('Lo storico delle sessioni di assistenza'),

          pending: true,
        ),
      ],
    );
  }

  Widget _buildManagementGrid() {
    return _AdminGrid(
      children: [
        _AdminModuleCard(
          icon: Icons.developer_mode_outlined,

          title: 'Developer & System',

          description:
              'Architettura, repository, funzioni, flussi, sicurezza e strumenti tecnici StudentLab.',

          onTap: _openDeveloperArea,
        ),

        _AdminModuleCard(
          icon: Icons.manage_accounts_outlined,

          title: 'Utenti',

          description:
              'Visualizza, abilita, disabilita ed elimina gli account.',

          onTap: () {
            _openProtectedPage(const AdminUsersPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.shield_outlined,

          title: 'Sicurezza',

          description:
              'Controlla autorizzazioni e sicurezza della piattaforma.',

          onTap: () {
            _openProtectedPage(const AdminSecurityPage());
          },
        ),

        _AdminModuleCard(
          icon: Icons.policy_outlined,

          title: 'Audit amministrativo',

          description:
              'Consulta le operazioni sensibili eseguite da admin, creator e sistemi automatici.',

          onTap: () => _showPending('L’audit amministrativo generale'),

          pending: true,
        ),
      ],
    );
  }

  String _friendlyError(Object error) {
    final String message = error.toString().toLowerCase();

    if (message.contains('401') || message.contains('unauthorized')) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (message.contains('403') || message.contains('forbidden')) {
      return 'Questa sessione non dispone dei permessi amministrativi.';
    }

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('host lookup')) {
      return 'Non è stato possibile verificare i permessi. Controlla la connessione e riprova.';
    }

    return 'Non è stato possibile verificare l’accesso amministrativo.';
  }
}

class _AdminGrid extends StatelessWidget {
  final List<Widget> children;

  const _AdminGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;

        return GridView.count(
          crossAxisCount: columns,

          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          crossAxisSpacing: 12,

          mainAxisSpacing: 12,

          mainAxisExtent: 190,

          children: children,
        );
      },
    );
  }
}

class _AdminSectionTitle extends StatelessWidget {
  final String title;

  final String subtitle;

  const _AdminSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style: const TextStyle(
            color: AppColors.pureWhite,

            fontSize: 18,

            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          subtitle,

          style: TextStyle(
            color: AppColors.pureWhite.withValues(alpha: 0.45),

            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _AdminModuleCard extends StatelessWidget {
  final IconData icon;

  final String title;

  final String description;

  final VoidCallback onTap;

  final bool pending;

  const _AdminModuleCard({
    required this.icon,

    required this.title,

    required this.description,

    required this.onTap,

    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(17),

        child: Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: AppColors.eleganceMidnight,

            borderRadius: BorderRadius.circular(17),

            border: Border.all(
              color: AppColors.skyBlue.withValues(alpha: 0.10),
            ),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  Container(
                    width: 42,

                    height: 42,

                    decoration: BoxDecoration(
                      color: AppColors.brandNightBlue,

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Icon(icon, color: AppColors.skyBlue, size: 22),
                  ),

                  const Spacer(),

                  if (pending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,

                        vertical: 4,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.09),

                        borderRadius: BorderRadius.circular(8),
                      ),

                      child: const Text(
                        'DA COLLEGARE',

                        style: TextStyle(
                          color: Colors.amber,

                          fontSize: 7,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.arrow_forward_ios_rounded,

                      color: Colors.white30,

                      size: 14,
                    ),
                ],
              ),

              const SizedBox(height: 13),

              Text(
                title,

                style: const TextStyle(
                  color: AppColors.pureWhite,

                  fontSize: 14,

                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Expanded(
                child: Text(
                  description,

                  style: const TextStyle(
                    color: Colors.white54,

                    fontSize: 10,

                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAccessDeniedPage extends StatelessWidget {
  final String? error;

  final Future<void> Function() onRetry;

  const _AdminAccessDeniedPage({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        title: const Text('Admin Panel'),
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),

            child: Container(
              width: double.infinity,

              padding: const EdgeInsets.all(26),

              decoration: BoxDecoration(
                color: AppColors.eleganceMidnight,

                borderRadius: BorderRadius.circular(20),

                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.16),
                ),
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(
                    Icons.gpp_bad_outlined,

                    color: Colors.redAccent,

                    size: 44,
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Accesso non autorizzato',

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      color: AppColors.pureWhite,

                      fontSize: 19,

                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 9),

                  Text(
                    error ??
                        'Il server non ha autorizzato questa sessione ad accedere alle funzioni amministrative.',

                    textAlign: TextAlign.center,

                    style: const TextStyle(
                      color: Colors.white54,

                      fontSize: 11,

                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 18),

                  OutlinedButton.icon(
                    onPressed: onRetry,

                    icon: const Icon(Icons.refresh_rounded),

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
}
