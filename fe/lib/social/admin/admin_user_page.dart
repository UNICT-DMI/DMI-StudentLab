import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../theme/nightTheme.dart';
import '../social_models.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final ApiService _apiService = ApiService();
  final AuthSession _session = AuthSession.instance;
  final TextEditingController _searchController = TextEditingController();

  List<SocialUser> _users = [];
  final Set<int> _processingIds = {};

  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  int? get _currentUserId => _session.currentUserId;

  List<SocialUser> get _filteredUsers {
    final String query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _users;
    }

    return _users.where((SocialUser user) {
      final String subjects = user.subjects
          .map((SocialSubject subject) => '${subject.name} ${subject.code}')
          .join(' ');

      final String paths = user.academicPaths
          .map(
            (SocialAcademicPath path) =>
                '${path.university} ${path.department} ${path.course} ${path.degreeType}',
          )
          .join(' ');

      final String searchable = [
        user.name,
        user.email,
        user.university,
        user.department,
        user.course,
        user.role,
        subjects,
        paths,
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (refresh) {
      if (_refreshing) {
        return;
      }
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final List<SocialUser> users = await _apiService.getSocialUsers();

      users.sort((SocialUser first, SocialUser second) {
        if (first.isActive != second.isActive) {
          return first.isActive ? -1 : 1;
        }
        return first.name.toLowerCase().compareTo(second.name.toLowerCase());
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = _cleanError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  bool _isProcessing(SocialUser user) => _processingIds.contains(user.id);

  Future<void> _toggleUserStatus(SocialUser user) async {
    if (_processingIds.contains(user.id)) {
      return;
    }

    if (user.id == _currentUserId) {
      _showMessage('Non puoi modificare lo stato del tuo account da questa pagina.');
      return;
    }

    final bool newStatus = !user.isActive;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: Text(
            newStatus ? 'Riattiva account' : 'Disabilita account',
            style: const TextStyle(color: AppColors.pureWhite),
          ),
          content: Text(
            newStatus
                ? 'Vuoi riattivare l\'account di ${user.name}?'
                : 'Vuoi disabilitare l\'account di ${user.name}? L\'utente non potrà utilizzare le funzionalità riservate agli account attivi.',
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                newStatus ? 'Riattiva' : 'Disabilita',
                style: TextStyle(
                  color: newStatus ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _processingIds.add(user.id));

    try {
      await _apiService.setUserActiveStatus(
        userId: user.id,
        isActive: newStatus,
      );

      if (!mounted) {
        return;
      }

      final int index = _users.indexWhere((SocialUser item) => item.id == user.id);

      if (index >= 0) {
        setState(() {
          _users[index] = user.copyWith(isActive: newStatus);
        });
      }

      _showMessage(
        newStatus
            ? 'Account di ${user.name} riattivato.'
            : 'Account di ${user.name} disabilitato.',
      );
    } catch (e) {
      if (mounted) {
        _showMessage(_cleanError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(user.id));
      }
    }
  }

  Future<void> _deleteUser(SocialUser user) async {
    if (_processingIds.contains(user.id)) {
      return;
    }

    if (user.id == _currentUserId) {
      _showMessage(
        'Non puoi eliminare il tuo account amministratore da questa pagina.',
      );
      return;
    }

    final bool? firstConfirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: const Text(
            'Elimina account',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: Text(
            'Vuoi eliminare definitivamente l\'account di ${user.name}?\n\n'
            'I dati personali verranno rimossi o anonimizzati dal backend. '
            'Se l\'utente possiede ancora gruppi, l\'operazione verrà bloccata.',
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Continua',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (firstConfirmation != true || !mounted) {
      return;
    }

    final TextEditingController confirmationController =
        TextEditingController();

    final bool? secondConfirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        String? validationError;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.eleganceDeepNavy,
              title: const Text(
                'Conferma eliminazione definitiva',
                style: TextStyle(color: AppColors.pureWhite),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scrivi ELIMINA per confermare.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmationController,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.pureWhite),
                    decoration: InputDecoration(
                      labelText: 'Conferma',
                      errorText: validationError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annulla'),
                ),
                TextButton(
                  onPressed: () {
                    if (confirmationController.text.trim() != 'ELIMINA') {
                      setDialogState(() {
                        validationError = 'Scrivi ELIMINA esattamente.';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text(
                    'Elimina definitivamente',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    confirmationController.dispose();

    if (secondConfirmation != true || !mounted) {
      return;
    }

    setState(() => _processingIds.add(user.id));

    try {
      await _apiService.deleteAdminUser(user.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _users.removeWhere((SocialUser item) => item.id == user.id);
      });

      _showMessage('Account di ${user.name} eliminato.');
    } catch (e) {
      if (mounted) {
        _showMessage(_deleteError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(user.id));
      }
    }
  }

  String _deleteError(Object error) {
    final String message = error.toString().toLowerCase();

    if (message.contains('409') ||
        message.contains('possiede gruppi') ||
        message.contains('gruppi attivi')) {
      return 'L\'account non può essere eliminato finché l\'utente possiede gruppi. '
          'Trasferisci prima la proprietà dei gruppi.';
    }

    if (message.contains('404')) {
      return 'L\'account non esiste più.';
    }

    if (message.contains('401') || message.contains('403')) {
      return 'Non hai i permessi necessari per eliminare questo account.';
    }

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    return 'Non è stato possibile eliminare l\'account.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        title: const Text(
          'Gestione utenti',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _refreshing
                ? null
                : () => _loadUsers(refresh: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.pureWhite,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _AdminUsersError(
        message: _error!,
        onRetry: _loadUsers,
      );
    }

    return Column(
      children: [
        _buildSearch(),
        _buildSummary(),
        Expanded(child: _buildUsers()),
      ],
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: AppColors.pureWhite,
          fontSize: 12,
        ),
        decoration: InputDecoration(
          hintText: 'Cerca per nome, email, corso, materia...',
          hintStyle: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.skyBlue,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Cancella',
                  onPressed: _searchController.clear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white38,
                  ),
                )
              : null,
          filled: true,
          fillColor: AppColors.eleganceMidnight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.skyBlue,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final int active =
        _users.where((SocialUser user) => user.isActive).length;
    final int disabled = _users.length - active;
    final int teachers =
        _users.where((SocialUser user) => user.isTeacher).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _AdminUserStat(
              icon: Icons.people_outline_rounded,
              label: 'Utenti',
              value: '${_users.length}',
              color: AppColors.skyBlue,
            ),
            const SizedBox(width: 8),
            _AdminUserStat(
              icon: Icons.check_circle_outline_rounded,
              label: 'Attivi',
              value: '$active',
              color: Colors.greenAccent,
            ),
            const SizedBox(width: 8),
            _AdminUserStat(
              icon: Icons.block_outlined,
              label: 'Disabilitati',
              value: '$disabled',
              color: Colors.redAccent,
            ),
            const SizedBox(width: 8),
            _AdminUserStat(
              icon: Icons.cast_for_education_outlined,
              label: 'Docenti',
              value: '$teachers',
              color: AppColors.teacherIndigo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsers() {
    final List<SocialUser> users = _filteredUsers;

    if (users.isEmpty) {
      return const _EmptyUsers();
    }

    return RefreshIndicator(
      onRefresh: () => _loadUsers(refresh: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final SocialUser user = users[index];

          return _AdminUserCard(
            user: user,
            currentUser: user.id == _currentUserId,
            processing: _isProcessing(user),
            onToggleStatus: () => _toggleUserStatus(user),
            onDelete: () => _deleteUser(user),
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _cleanError(Object error) {
    String message = error.toString();

    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }

    return message;
  }
}

class _AdminUserCard extends StatelessWidget {
  final SocialUser user;
  final bool currentUser;
  final bool processing;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _AdminUserCard({
    required this.user,
    required this.currentUser,
    required this.processing,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final SocialAcademicPath? path =
        user.primaryAcademicPath ?? user.currentAcademicPath;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: user.isActive
              ? AppColors.skyBlue.withOpacity(0.10)
              : Colors.redAccent.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: user.isTeacher
                      ? AppColors.teacherIndigo
                      : AppColors.studentBlue,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.pureWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (currentUser) ...[
                          const SizedBox(width: 6),
                          const _CurrentUserBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _UserRoleBadge(teacher: user.isTeacher),
                        _UserStatusBadge(active: user.isActive),
                        if (user.isTeacher)
                          _TeacherVerificationBadge(
                            status: user.teacherVerificationStatus,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (path != null) ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: AppColors.pureWhite.withOpacity(0.06),
            ),
            const SizedBox(height: 12),
            if (path.university.isNotEmpty)
              _UserInfoRow(
                icon: Icons.account_balance_outlined,
                label: 'Ateneo',
                value: path.university,
              ),
            if (path.university.isNotEmpty) const SizedBox(height: 8),
            _UserInfoRow(
              icon: Icons.school_outlined,
              label: 'Corso',
              value: path.course.isEmpty ? 'Non specificato' : path.course,
            ),
            if (path.department.isNotEmpty) ...[
              const SizedBox(height: 8),
              _UserInfoRow(
                icon: Icons.business_outlined,
                label: 'Dipartimento',
                value: path.department,
              ),
            ],
          ],
          const SizedBox(height: 16),
          if (processing)
            const LinearProgressIndicator()
          else
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: user.isActive
                      ? OutlinedButton.icon(
                          onPressed: currentUser ? null : onToggleStatus,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(
                              color: Colors.redAccent.withOpacity(0.35),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.block_outlined),
                          label: Text(
                            currentUser
                                ? 'Account amministratore corrente'
                                : 'Disabilita account',
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: currentUser ? null : onToggleStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: AppColors.eleganceSoftNight,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                          ),
                          label: const Text('Riattiva account'),
                        ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: currentUser ? null : onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(
                        color: Colors.redAccent.withOpacity(0.55),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: Text(
                      currentUser
                          ? 'Eliminazione non disponibile sul tuo account'
                          : 'Elimina definitivamente',
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AdminUserStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AdminUserStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentUserBadge extends StatelessWidget {
  const _CurrentUserBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.skyBlue.withOpacity(0.09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text(
        'Tu',
        style: TextStyle(
          color: AppColors.materialSky,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _UserRoleBadge extends StatelessWidget {
  final bool teacher;

  const _UserRoleBadge({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final Color color =
        teacher ? AppColors.teacherIndigo : AppColors.studentBlue;

    return _CompactBadge(
      icon: teacher
          ? Icons.cast_for_education_outlined
          : Icons.school_outlined,
      label: teacher ? 'Docente' : 'Studente',
      color: color,
    );
  }
}

class _UserStatusBadge extends StatelessWidget {
  final bool active;

  const _UserStatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final Color color = active ? Colors.greenAccent : Colors.redAccent;

    return _CompactBadge(
      icon: active ? Icons.check_circle_outline_rounded : Icons.block_outlined,
      label: active ? 'Attivo' : 'Disabilitato',
      color: color,
    );
  }
}

class _TeacherVerificationBadge extends StatelessWidget {
  final TeacherVerificationStatus status;

  const _TeacherVerificationBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TeacherVerificationStatus.verified:
        return const _CompactBadge(
          icon: Icons.verified_rounded,
          label: 'Docente verificato',
          color: Colors.greenAccent,
        );
      case TeacherVerificationStatus.pending:
        return const _CompactBadge(
          icon: Icons.schedule_rounded,
          label: 'Verifica in attesa',
          color: Colors.amber,
        );
      case TeacherVerificationStatus.rejected:
        return const _CompactBadge(
          icon: Icons.cancel_outlined,
          label: 'Verifica rifiutata',
          color: Colors.redAccent,
        );
      case TeacherVerificationStatus.notRequired:
        return const SizedBox.shrink();
    }
  }
}

class _CompactBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CompactBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _UserInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.materialSky, size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.eleganceMidnight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                color: Colors.white38,
                size: 44,
              ),
              SizedBox(height: 12),
              Text(
                'Nessun utente trovato.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminUsersError extends StatelessWidget {
  final String message;
  final Future<void> Function({bool refresh}) onRetry;

  const _AdminUsersError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.eleganceMidnight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.18),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'Impossibile caricare gli utenti',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}