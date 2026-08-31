import 'package:flutter/material.dart';

import 'package:fe/widgets/studentlab_coming_soon_badge.dart';

import '../theme/nightTheme.dart';

import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../services/auth_service.dart';

import 'message/message_page.dart';
import 'notifications/notifications_page.dart';

import 'social_models.dart';

import 'auth/login_page.dart';
import 'auth/account_security_page.dart';

import 'admin/admin_panel_page.dart';
import 'teacher/teachear_area_page.dart';

import 'news/private_news_page.dart';
import 'news/institutional_news_page.dart';

import 'groups/models/study_group.dart';
import 'groups/study_group_detail_page.dart';
import 'groups/create_group_page.dart';
import 'groups/public_groups_page.dart';
import 'groups/widgets/study_group_card.dart';

import 'widgets/social_intro.dart';
import 'widgets/social_login_intro.dart';
import 'widgets/student_help_card.dart';
import 'widgets/teacher_help_card.dart';
import 'widgets/social_user_profile_page.dart';
import 'widgets/edit_social_profile_page.dart';
import 'widgets/studentlab_user_avatar.dart';

enum SocialStartDestination { home, groups, colleagues }

class SocialPage extends StatefulWidget {
  final SocialStartDestination startDestination;

  const SocialPage({
    super.key,
    this.startDestination = SocialStartDestination.home,
  });

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final AuthSession _session = AuthSession.instance;
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  int _currentIndex = 0;
  int _unreadNotificationCount = 0;
  bool _loadingNotifications = false;

  @override
  void initState() {
    super.initState();

    _session.addListener(_onSessionChanged);

    if (!_session.isGuest) {
      _loadUnreadNotifications();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _session.isGuest) {
        return;
      }

      switch (widget.startDestination) {
        case SocialStartDestination.groups:
          _openGroupsDirectory();
          break;
        case SocialStartDestination.colleagues:
          _openColleaguesDirectory();
          break;
        case SocialStartDestination.home:
          break;
      }
    });
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);

    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      if (_session.isGuest) {
        _unreadNotificationCount = 0;

        if (_currentIndex > 2) {
          _currentIndex = 0;
        }
      } else if (_currentIndex > 3) {
        _currentIndex = 0;
      }
    });

    if (!_session.isGuest) {
      _loadUnreadNotifications();
    }
  }

  Future<void> _loadUnreadNotifications() async {
    if (_session.isGuest || _loadingNotifications) {
      return;
    }

    _loadingNotifications = true;

    try {
      final int count = await _apiService.getUnreadNotificationCount();

      if (!mounted) {
        return;
      }

      setState(() {
        _unreadNotificationCount = count;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _unreadNotificationCount = 0;
      });
    } finally {
      _loadingNotifications = false;
    }
  }

  Future<void> _openLogin() async {
    final SocialUser? user = await Navigator.of(
      context,
    ).push<SocialUser>(MaterialPageRoute(builder: (_) => const LoginPage()));

    if (!mounted || user == null) {
      return;
    }

    setState(() {
      _currentIndex = 0;
    });

    await _loadUnreadNotifications();
  }

  void _onProfileCreated(SocialUser user) {
    if (!mounted) {
      return;
    }

    _session.updateUser(user);

    setState(() {
      _currentIndex = 0;
    });
  }

  Future<void> _openMessages() async {
    if (_session.isGuest) {
      await _openLogin();
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MessagesPage()));
  }

  Future<void> _openNotifications() async {
    if (_session.isGuest) {
      await _openLogin();
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));

    if (mounted) {
      await _loadUnreadNotifications();
    }
  }

  Future<void> _openMyProfile() async {
    if (_session.isGuest) {
      setState(() {
        _currentIndex = 3;
      });
      return;
    }

    SocialUser? user = _session.currentUser;

    if (user == null) {
      try {
        user = await _apiService.getCurrentUser();

        if (!mounted) {
          return;
        }

        _session.updateUser(user);
      } catch (_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Non è stato possibile aprire il profilo. Riprova.'),
          ),
        );
        return;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SocialUserProfilePage(user: user!)),
    );

    if (!mounted) {
      return;
    }

    try {
      final SocialUser refreshedUser = await _apiService.getCurrentUser();

      if (!mounted) {
        return;
      }

      _session.updateUser(refreshedUser);
    } catch (_) {}
  }

  Future<void> _openGroupsDirectory() async {
    if (_session.isGuest) {
      await _openLogin();
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _SocialGroupsPage()));
  }

  Future<void> _openColleaguesDirectory() async {
    if (_session.isGuest) {
      await _openLogin();
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _SocialUsersPage()));
  }

  Future<void> _openTutorDirectory() async {
    if (_session.isGuest) {
      await _openLogin();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _SocialUsersPage(tutorOnly: true),
      ),
    );
  }

  Future<void> _openAccountSecurity() async {
    if (_session.isGuest) {
      await _openLogin();
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AccountSecurityPage()));
  }

  Future<void> _openTeacherArea() async {
    if (_session.isGuest) {
      await _openLogin();
      return;
    }

    final bool authorized = await _apiService.canAccessTeacherArea();

    if (!mounted) {
      return;
    }

    if (!authorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’area docente non è disponibile per questo account.'),
        ),
      );
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TeacherAreaPage()));
  }

  Future<void> _openAdminPanel() async {
    if (_session.isGuest) {
      await _openLogin();
      return;
    }

    final String role = _session.currentUser?.role.trim().toLowerCase() ?? '';

    final bool isDeveloper = role == 'devsyst';

    final bool authorized =
        isDeveloper || await _apiService.canAccessAdminPanel();

    if (!mounted) {
      return;
    }

    if (!authorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non hai accesso all’Admin Panel.')),
      );
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminPanelPage()));
  }

  Future<void> _logout() async {
    try {
      await _authService.logout();

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non è stato possibile uscire. Riprova.')),
      );
    }
  }

  void _showGuestMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/mascot/guest_profile.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) {
                              return const CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.studentBlue,
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: AppColors.pureWhite,
                                  size: 24,
                                ),
                              );
                            },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Guest',
                            style: TextStyle(
                              color: AppColors.pureWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Profilo temporaneo StudentLab',
                            style: TextStyle(
                              color: AppColors.pureWhite.withValues(
                                alpha: 0.45,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: AppColors.pureWhite.withValues(alpha: 0.08),
              ),
              _SocialUserMenuTile(
                icon: Icons.login_rounded,
                label: 'Accedi',
                subtitle: 'Accedi al tuo account StudentLab',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openLogin();
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  void _showUserMenu() {
    final SocialUser? user = _session.currentUser;

    if (user == null) {
      _showGuestMenu();
      return;
    }

    final String role = user.role.trim().toLowerCase();

    final bool showTeacherArea = user.type == SocialUserType.teacher;

    final bool showAdminPanel =
        role == 'admin' || role == 'creator' || role == 'devsyst';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  child: Row(
                    children: [
                      StudentLabUserAvatar(type: user.type, radius: 24),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.pureWhite.withValues(
                                  alpha: 0.45,
                                ),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  color: AppColors.pureWhite.withValues(alpha: 0.08),
                ),

                _SocialUserMenuTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Profilo',
                  subtitle: 'Visualizza il tuo profilo StudentLab',
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _openMyProfile();
                  },
                ),

                _SocialUserMenuTile(
                  icon: Icons.people_outline_rounded,
                  label: 'Colleghi',
                  subtitle: 'Studenti e insegnanti StudentLab',
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _openColleaguesDirectory();
                  },
                ),

                _SocialUserMenuTile(
                  icon: Icons.groups_2_outlined,
                  label: 'Gruppi',
                  subtitle: 'I tuoi gruppi e quelli pubblici',
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _openGroupsDirectory();
                  },
                ),

                if (showTeacherArea)
                  _SocialUserMenuTile(
                    icon: Icons.cast_for_education_outlined,
                    label: 'Area docente',
                    subtitle: 'Materiali e strumenti docente',
                    onTap: () {
                      Navigator.pop(sheetContext);

                      _openTeacherArea();
                    },
                  ),

                if (showAdminPanel)
                  _SocialUserMenuTile(
                    icon: Icons.admin_panel_settings_outlined,
                    iconColor: Colors.greenAccent,
                    label: 'Admin Panel',
                    subtitle: 'Gestione e strumenti amministrativi',
                    onTap: () {
                      Navigator.pop(sheetContext);

                      _openAdminPanel();
                    },
                  ),

                Divider(
                  height: 1,
                  color: AppColors.pureWhite.withValues(alpha: 0.08),
                ),

                _SocialUserMenuTile(
                  icon: Icons.logout_rounded,
                  label: 'Esci',
                  danger: true,
                  showArrow: false,
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    await _logout();
                  },
                ),

                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final SocialUser? currentUser = _session.currentUser;

    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,

        leading: Navigator.of(context).canPop()
            ? IconButton(
                tooltip: 'Indietro',
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              )
            : null,

        title: const Text(
          'StudentLab Social',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),

        actions: [
          if (!_session.isGuest) ...[
            IconButton(
              tooltip: 'Messaggi',

              onPressed: _openMessages,

              icon: const Icon(Icons.chat_bubble_outline_rounded),
            ),

            _SocialNotificationButton(
              count: _unreadNotificationCount,

              onPressed: _openNotifications,
            ),
          ],

          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),

            child: InkWell(
              onTap: _showUserMenu,

              borderRadius: BorderRadius.circular(20),

              child: Padding(
                padding: const EdgeInsets.all(4),

                child: _session.isGuest
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),

                        child: Image.asset(
                          'assets/mascot/guest_profile.png',

                          width: 32,

                          height: 32,

                          fit: BoxFit.cover,

                          errorBuilder:
                              (
                                BuildContext context,

                                Object error,

                                StackTrace? stackTrace,
                              ) {
                                return const CircleAvatar(
                                  radius: 16,

                                  backgroundColor: AppColors.studentBlue,

                                  child: Icon(
                                    Icons.person_outline_rounded,

                                    color: AppColors.pureWhite,

                                    size: 18,
                                  ),
                                );
                              },
                        ),
                      )
                    : currentUser == null
                    ? const CircleAvatar(
                        radius: 16,

                        backgroundColor: AppColors.studentBlue,

                        child: Icon(
                          Icons.person_outline_rounded,

                          color: AppColors.pureWhite,

                          size: 18,
                        ),
                      )
                    : StudentLabUserAvatar(type: currentUser.type, radius: 16),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _session.isGuest
                        ? [
                            const InstitutionalNewsPage(embedded: true),
                            _TutorHubSection(onLogin: _openLogin),
                            _GuestNetworkSection(
                              onLogin: _openLogin,
                              onProfileCreated: _onProfileCreated,
                            ),
                          ]
                        : [
                            const InstitutionalNewsPage(embedded: true),
                            _TutorHubSection(onLogin: _openLogin),
                            const _ComingSoonSection(
                              icon: Icons.menu_book_outlined,
                              title: 'Libri',
                              description: 'La sezione Libri è in arrivo.',
                            ),
                            const _ComingSoonSection(
                              icon: Icons.work_outline_rounded,
                              title: 'Lavori',
                              description: 'La sezione Lavori è in arrivo.',
                            ),
                          ],
                  ),
                ),
              ),
            ),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _buildNavigation(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    final sections = _session.isGuest
        ? const [
            (
              icon: Icons.newspaper_outlined,
              selectedIcon: Icons.newspaper_rounded,
              label: 'Avvisi',
            ),
            (
              icon: Icons.volunteer_activism_outlined,
              selectedIcon: Icons.volunteer_activism_rounded,
              label: 'Tutor',
            ),
            (
              icon: Icons.hub_outlined,
              selectedIcon: Icons.hub_rounded,
              label: 'Network',
            ),
          ]
        : const [
            (
              icon: Icons.newspaper_outlined,
              selectedIcon: Icons.newspaper_rounded,
              label: 'Avvisi',
            ),
            (
              icon: Icons.volunteer_activism_outlined,
              selectedIcon: Icons.volunteer_activism_rounded,
              label: 'Tutor',
            ),
            (
              icon: Icons.menu_book_outlined,
              selectedIcon: Icons.menu_book_rounded,
              label: 'Libri',
            ),
            (
              icon: Icons.work_outline_rounded,
              selectedIcon: Icons.work_rounded,
              label: 'Lavori',
            ),
          ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),

      height: 52,

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12)),
      ),

      child: Row(
        children: List.generate(sections.length, (index) {
          final bool selected = _currentIndex == index;

          final section = sections[index];

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),

              onTap: () {
                setState(() {
                  _currentIndex = index;
                });
              },

              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),

                margin: const EdgeInsets.all(4),

                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.skyBlue.withValues(alpha: 0.16)
                      : Colors.transparent,

                  borderRadius: BorderRadius.circular(12),
                ),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? section.selectedIcon : section.icon,
                      size: 19,
                      color: selected
                          ? AppColors.materialSky
                          : AppColors.pureWhite.withValues(alpha: 0.45),
                    ),

                    const SizedBox(width: 7),

                    Flexible(
                      child: Text(
                        section.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? AppColors.pureWhite
                              : AppColors.pureWhite.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TutorHubSection extends StatefulWidget {
  final Future<void> Function() onLogin;

  const _TutorHubSection({required this.onLogin});

  @override
  State<_TutorHubSection> createState() => _TutorHubSectionState();
}

class _TutorHubSectionState extends State<_TutorHubSection> {
  final ApiService _apiService = ApiService();

  final TextEditingController _searchController = TextEditingController();

  List<SocialUser> _users = [];

  int _selectedFilter = 0;

  bool _loading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  bool _canHelp(SocialUser user) {
    return user.availableForHelp ||
        user.subjects.any(
          (SocialSubject subject) => subject.isActive && subject.canHelp,
        );
  }

  bool _offersPrivateLessons(SocialUser user) {
    return user.availableForPrivateLessons ||
        user.subjects.any(
          (SocialSubject subject) =>
              subject.isActive && subject.canGivePrivateLessons,
        );
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final List<SocialUser> users = await _apiService.getSocialUsers();

      if (!mounted) {
        return;
      }

      final int? currentUserId = AuthSession.instance.currentUserId;

      setState(() {
        _users = users
            .where(
              (SocialUser user) =>
                  user.id != currentUserId &&
                  (_canHelp(user) || _offersPrivateLessons(user)),
            )
            .toList();

        _loading = false;
      });
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

  List<SocialUser> get _filteredUsers {
    final String query = _searchController.text.trim().toLowerCase();

    return _users.where((SocialUser user) {
      final bool canHelp = _canHelp(user);

      final bool privateLessons = _offersPrivateLessons(user);

      if (_selectedFilter == 1 && !canHelp) {
        return false;
      }

      if (_selectedFilter == 2 && !privateLessons) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final String subjects = user.subjects
          .where((SocialSubject subject) => subject.isActive)
          .map((SocialSubject subject) => subject.name)
          .join(' ');

      final String searchable = [
        user.name,
        user.department,
        user.course,
        subjects,
        user.description,
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  Future<void> _openUser(SocialUser user) async {
    if (AuthSession.instance.isGuest) {
      await widget.onLogin();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SocialUserProfilePage(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<SocialUser> users = _filteredUsers;

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tutor',
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Trova utenti disponibili ad aiutarti nello studio o a offrire lezioni private.',
            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.50),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) {
              setState(() {});
            },
            style: const TextStyle(color: AppColors.pureWhite),
            decoration: InputDecoration(
              hintText: 'Cerca tutor o materia...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.skyBlue,
              ),
              filled: true,
              fillColor: AppColors.eleganceMidnight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(3, (int index) {
                const List<String> labels = [
                  'Tutti',
                  'Aiuto',
                  'Lezioni private',
                ];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _selectedFilter == index,
                    label: Text(labels[index]),
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter = index;
                      });
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 22),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _loadUsers)
          else if (users.isEmpty)
            const _EmptyCard(
              icon: Icons.volunteer_activism_outlined,
              title: 'Nessun tutor disponibile',
              message: 'Non ci sono utenti disponibili con questo filtro.',
            )
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double availableWidth = constraints.maxWidth;

                final int columns = availableWidth >= 1080
                    ? 3
                    : availableWidth >= 700
                    ? 2
                    : 1;

                const double gap = 14;

                final double itemWidth = columns == 1
                    ? availableWidth
                    : (availableWidth - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: users.map((SocialUser user) {
                    return SizedBox(
                      width: itemWidth,
                      child: InkWell(
                        onTap: () {
                          _openUser(user);
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: user.type == SocialUserType.student
                            ? StudentHelpCard(student: user)
                            : TeacherHelpCard(teacher: user),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _GuestProfileIntroPage extends StatelessWidget {
  final Future<void> Function() onLogin;
  final ValueChanged<SocialUser> onProfileCreated;

  const _GuestProfileIntroPage({
    required this.onLogin,
    required this.onProfileCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SocialIntro(onProfileCreated: onProfileCreated),

            const SizedBox(height: 16),

            SocialLoginIntro(onLogin: onLogin),
          ],
        ),
      ),
    );
  }
}

class _GuestNetworkSection extends StatelessWidget {
  final Future<void> Function() onLogin;
  final ValueChanged<SocialUser> onProfileCreated;

  const _GuestNetworkSection({
    required this.onLogin,
    required this.onProfileCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            SocialIntro(onProfileCreated: onProfileCreated),
            const SizedBox(height: 16),
            SocialLoginIntro(onLogin: onLogin),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ComingSoonSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double horizontalPadding = constraints.maxWidth < 600 ? 20 : 28;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.eleganceMidnight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.skyBlue.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.brandNightBlue,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(icon, color: AppColors.skyBlue, size: 28),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.50),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const StudentLabComingSoonBadge(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SocialUserMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool showArrow;
  final Color? iconColor;

  const _SocialUserMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
    this.showArrow = true,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = danger ? Colors.redAccent : AppColors.pureWhite;

    return ListTile(
      leading: Icon(
        icon,
        color: danger ? Colors.redAccent : iconColor ?? AppColors.skyBlue,
      ),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.42),
                fontSize: 10,
              ),
            ),
      trailing: showArrow
          ? const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white30,
              size: 14,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _SocialNotificationButton extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const _SocialNotificationButton({
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifiche',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded),

          if (count > 0)
            Positioned(
              top: -5,
              right: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.brandNightBlue, width: 2),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuestSocialPage extends StatefulWidget {
  final Future<void> Function() onLogin;

  final ValueChanged<SocialUser> onProfileCreated;

  const _GuestSocialPage({
    required this.onLogin,
    required this.onProfileCreated,
  });

  @override
  State<_GuestSocialPage> createState() => _GuestSocialPageState();
}

class _GuestSocialPageState extends State<_GuestSocialPage> {
  final ApiService _apiService = ApiService();

  SocialUserType _selectedType = SocialUserType.student;

  List<SocialUser> _users = [];

  bool _loading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _loading = true;

        _error = null;
      });
    }

    try {
      final List<SocialUser> users = await _apiService.getSocialUsers();

      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanError(e);

        _loading = false;
      });
    }
  }

  Future<void> _openGroups() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PublicGroupsPage()));
  }

  Future<void> _openUser(SocialUser user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SocialUserProfilePage(user: user)),
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

        title: const Text(
          'StudentLab Social',

          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),

        actions: [
          IconButton(
            tooltip: 'News',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const InstitutionalNewsPage(),
                ),
              );
            },
            icon: const Icon(Icons.newspaper_outlined),
          ),
        ],
      ),

      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth > 850
                  ? 850
                  : constraints.maxWidth;

              return SizedBox(
                width: width,

                child: RefreshIndicator(
                  onRefresh: _loadUsers,

                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),

                    padding: const EdgeInsets.all(20),

                    children: [
                      SocialIntro(
                        onProfileCreated: (SocialUser user) {
                          widget.onProfileCreated(user);
                        },
                      ),

                      const SizedBox(height: 16),

                      SocialLoginIntro(onLogin: widget.onLogin),

                      const SizedBox(height: 24),

                      _buildGuestBanner(),

                      const SizedBox(height: 16),

                      _buildGroupsCard(),

                      const SizedBox(height: 28),

                      const Row(
                        children: [
                          Icon(
                            Icons.people_outline_rounded,

                            color: AppColors.skyBlue,

                            size: 20,
                          ),

                          SizedBox(width: 8),

                          Text(
                            'Persone',

                            style: TextStyle(
                              color: AppColors.pureWhite,

                              fontSize: 18,

                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Scopri studenti e insegnanti della community.',

                        style: TextStyle(
                          color: AppColors.pureWhite.withValues(alpha: 0.48),

                          fontSize: 11,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildSelector(),

                      const SizedBox(height: 22),

                      _buildUsers(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGuestBanner() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 46,

            height: 46,

            decoration: BoxDecoration(
              color: AppColors.brandNightBlue,

              borderRadius: BorderRadius.circular(13),
            ),

            child: const Icon(
              Icons.explore_outlined,

              color: AppColors.skyBlue,

              size: 24,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Esplora la community',

                  style: TextStyle(
                    color: AppColors.pureWhite,

                    fontSize: 14,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Come Guest puoi vedere studenti e insegnanti, '
                  'aprire i gruppi pubblici, consultare i partecipanti '
                  'e scaricare il materiale disponibile. '
                  'Accedi per partecipare ai gruppi, accedere alle '
                  'comunicazioni riservate e condividere contenuti.',

                  style: TextStyle(
                    color: AppColors.pureWhite.withValues(alpha: 0.50),

                    fontSize: 11,

                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 46,

                height: 46,

                decoration: BoxDecoration(
                  color: AppColors.brandNightBlue,

                  borderRadius: BorderRadius.circular(13),
                ),

                child: const Icon(
                  Icons.groups_2_outlined,

                  color: AppColors.skyBlue,

                  size: 25,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Gruppi pubblici',

                      style: TextStyle(
                        color: AppColors.pureWhite,

                        fontSize: 15,

                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Esplora gruppi di studio, materiali condivisi, '
                      'appunti, PDF, slide e studenti che seguono '
                      'le tue stesse materie.',

                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.52),

                        fontSize: 11,

                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,

            child: ElevatedButton.icon(
              onPressed: _openGroups,

              icon: const Icon(Icons.search_rounded),

              label: const Text('Esplora i gruppi'),

              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.socialBlue,

                foregroundColor: AppColors.pureWhite,

                padding: const EdgeInsets.symmetric(vertical: 13),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelector() {
    return Row(
      children: [
        Expanded(
          child: _selectorButton(
            title: 'Studenti',

            icon: Icons.school_outlined,

            type: SocialUserType.student,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _selectorButton(
            title: 'Insegnanti',

            icon: Icons.person_outline_rounded,

            type: SocialUserType.teacher,
          ),
        ),
      ],
    );
  }

  Widget _selectorButton({
    required String title,
    required IconData icon,
    required SocialUserType type,
  }) {
    final bool selected = _selectedType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(14),

      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        padding: const EdgeInsets.symmetric(vertical: 14),

        decoration: BoxDecoration(
          color: selected
              ? AppColors.skyBlue.withValues(alpha: 0.16)
              : AppColors.eleganceMidnight,

          borderRadius: BorderRadius.circular(14),

          border: Border.all(
            color: selected
                ? AppColors.skyBlue.withValues(alpha: 0.35)
                : AppColors.skyBlue.withValues(alpha: 0.10),
          ),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,

              color: selected
                  ? AppColors.materialSky
                  : AppColors.pureWhite.withValues(alpha: 0.50),

              size: 19,
            ),

            const SizedBox(width: 7),

            Text(
              title,

              style: TextStyle(
                color: selected
                    ? AppColors.pureWhite
                    : AppColors.pureWhite.withValues(alpha: 0.55),

                fontSize: 12,

                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsers() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),

        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _ErrorCard(message: _error!, onRetry: _loadUsers);
    }

    final List<SocialUser> users = _users
        .where((SocialUser user) => user.type == _selectedType)
        .toList();

    if (users.isEmpty) {
      return const _EmptyCard(
        icon: Icons.people_outline_rounded,

        title: 'Nessun utente',

        message: 'Non sono ancora presenti utenti di questo tipo.',
      );
    }

    return Column(
      children: users.map((SocialUser user) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),

          child: InkWell(
            onTap: () {
              _openUser(user);
            },

            borderRadius: BorderRadius.circular(18),

            child: user.type == SocialUserType.student
                ? StudentHelpCard(student: user)
                : TeacherHelpCard(teacher: user),
          ),
        );
      }).toList(),
    );
  }
}

class _SocialProfilePage extends StatefulWidget {
  const _SocialProfilePage();

  @override
  State<_SocialProfilePage> createState() => _SocialProfilePageState();
}

class _SocialProfilePageState extends State<_SocialProfilePage> {
  final ApiService _apiService = ApiService();

  final AuthSession _session = AuthSession.instance;

  SocialUser? _user;

  bool _loading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final int? currentUserId = _session.currentUserId;

    if (currentUserId == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Utente non autenticato.';

        _loading = false;
      });

      return;
    }

    setState(() {
      _loading = true;

      _error = null;
    });

    try {
      final SocialUser user = await _apiService.getCurrentUser();

      if (!mounted) {
        return;
      }

      _session.updateUser(user);

      setState(() {
        _user = user;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanError(e);

        _loading = false;
      });
    }
  }

  void _openPrivateNews() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivateNewsPage()));
  }

  Future<void> _openFullProfile() async {
    final SocialUser? user = _user;

    if (user == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SocialUserProfilePage(user: user)),
    );

    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _editProfile() async {
    final SocialUser? user = _user;

    if (user == null) {
      return;
    }

    final SocialUser? updatedUser = await Navigator.of(context)
        .push<SocialUser>(
          MaterialPageRoute(builder: (_) => EditSocialProfilePage(user: user)),
        );

    if (!mounted || updatedUser == null) {
      return;
    }

    _session.updateUser(updatedUser);

    setState(() {
      _user = updatedUser;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),

        children: [_ErrorCard(message: _error!, onRetry: _loadProfile)],
      );
    }

    final SocialUser user = _user!;

    return RefreshIndicator(
      onRefresh: _loadProfile,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(20),

        children: [_buildProfileCard(user), const SizedBox(height: 20)],
      ),
    );
  }

  Widget _buildProfileCard(SocialUser user) {
    final bool isTeacher = user.type == SocialUserType.teacher;

    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(22),

        border: Border.all(
          color: (isTeacher ? AppColors.teacherIndigo : AppColors.studentBlue)
              .withValues(alpha: 0.22),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              StudentLabUserAvatar(type: user.type, radius: 35),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      user.name.isEmpty ? 'Profilo StudentLab' : user.name,

                      style: const TextStyle(
                        color: AppColors.pureWhite,

                        fontSize: 21,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Text(
                          isTeacher ? 'Insegnante' : 'Studente',

                          style: TextStyle(
                            color: isTeacher
                                ? AppColors.teacherIndigo
                                : AppColors.studentBlue,

                            fontSize: 13,

                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        if (isTeacher && user.isVerifiedTeacher) ...[
                          const SizedBox(width: 5),

                          const Icon(
                            Icons.verified_rounded,

                            color: Colors.greenAccent,

                            size: 15,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      user.email,

                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.48),

                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              _AvailabilityBadge(available: user.available),
            ],
          ),

          if (user.availableForHelp || user.availableForPrivateLessons) ...[
            const SizedBox(height: 18),

            Wrap(
              spacing: 8,

              runSpacing: 8,

              children: [
                if (user.availableForHelp)
                  const _ProfileCapabilityChip(
                    icon: Icons.volunteer_activism_outlined,

                    label: 'Disponibile ad aiutare',
                  ),

                if (user.availableForPrivateLessons)
                  const _ProfileCapabilityChip(
                    icon: Icons.school_outlined,

                    label: 'Lezioni private',
                  ),
              ],
            ),
          ],

          if (user.academicTitles.isNotEmpty) ...[
            const SizedBox(height: 20),

            Divider(
              height: 1,
              color: AppColors.pureWhite.withValues(alpha: 0.07),
            ),

            const SizedBox(height: 14),

            const Text(
              'Titoli conseguiti',

              style: TextStyle(
                color: AppColors.pureWhite,

                fontSize: 15,

                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...user.academicTitles.map(
              (SocialAcademicTitle title) => Padding(
                padding: const EdgeInsets.only(bottom: 10),

                child: _ProfileAcademicTitleCard(title: title),
              ),
            ),
          ],

          if (user.academicPaths.isNotEmpty) ...[
            const SizedBox(height: 18),

            Divider(
              height: 1,
              color: AppColors.pureWhite.withValues(alpha: 0.07),
            ),

            const SizedBox(height: 14),

            const Text(
              'Percorsi accademici',

              style: TextStyle(
                color: AppColors.pureWhite,

                fontSize: 15,

                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...user.academicPaths.map(
              (SocialAcademicPath path) => Padding(
                padding: const EdgeInsets.only(bottom: 10),

                child: _ProfileAcademicPathCard(path: path),
              ),
            ),
          ],

          const SizedBox(height: 18),

          Divider(
            height: 1,
            color: AppColors.pureWhite.withValues(alpha: 0.07),
          ),

          const SizedBox(height: 14),

          Text(
            isTeacher ? 'Insegnamenti' : 'Materie',

            style: const TextStyle(
              color: AppColors.pureWhite,

              fontSize: 15,

              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          if (isTeacher && user.teacherAssignments.isNotEmpty)
            ...user.teacherAssignments.map(
              (TeacherAssignment assignment) =>
                  _ProfileTeacherAssignmentCard(assignment: assignment),
            )
          else if (!isTeacher && user.subjects.isNotEmpty)
            ...user.subjects.map(
              (SocialSubject subject) => _ProfileSubjectCard(subject: subject),
            )
          else
            Text(
              isTeacher
                  ? 'Nessun insegnamento associato.'
                  : 'Nessuna materia associata.',

              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.45),

                fontSize: 11,
              ),
            ),

          const SizedBox(height: 20),

          Divider(
            height: 1,
            color: AppColors.pureWhite.withValues(alpha: 0.07),
          ),

          const SizedBox(height: 14),

          const Text(
            'Descrizione',

            style: TextStyle(
              color: AppColors.pureWhite,

              fontSize: 15,

              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            user.description.isEmpty
                ? 'Nessuna descrizione.'
                : user.description,

            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.66),

              fontSize: 13,

              height: 1.45,
            ),
          ),

          const SizedBox(height: 18),

          _ProfileReviewSummary(user: user),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openFullProfile,
              icon: const Icon(Icons.person_search_outlined),
              label: const Text('Apri profilo completo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.socialBlue,
                foregroundColor: AppColors.pureWhite,
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,

            child: OutlinedButton.icon(
              onPressed: _editProfile,

              icon: const Icon(Icons.edit_outlined),

              label: const Text('Modifica profilo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialUsersPage extends StatefulWidget {
  final bool tutorOnly;

  const _SocialUsersPage({this.tutorOnly = false});

  @override
  State<_SocialUsersPage> createState() => _SocialUsersPageState();
}

class _SocialUsersPageState extends State<_SocialUsersPage> {
  final ApiService _apiService = ApiService();

  final TextEditingController _searchController = TextEditingController();

  List<SocialUser> _users = [];

  int _selectedFilter = 0;

  bool _loading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;

      _error = null;
    });

    try {
      final List<SocialUser> users = await _apiService.getSocialUsers();

      if (!mounted) {
        return;
      }

      final int? currentUserId = AuthSession.instance.currentUserId;

      setState(() {
        _users = users.where((user) => user.id != currentUserId).toList();

        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanError(e);

        _loading = false;
      });
    }
  }

  bool _canHelp(SocialUser user) {
    return user.availableForHelp ||
        user.subjects.any(
          (SocialSubject subject) => subject.isActive && subject.canHelp,
        );
  }

  bool _offersPrivateLessons(SocialUser user) {
    return user.availableForPrivateLessons ||
        user.subjects.any(
          (SocialSubject subject) =>
              subject.isActive && subject.canGivePrivateLessons,
        );
  }

  List<SocialUser> get _filteredUsers {
    final String query = _searchController.text.trim().toLowerCase();

    return _users.where((SocialUser user) {
      final bool canHelp = _canHelp(user);

      final bool privateLessons = _offersPrivateLessons(user);

      if (widget.tutorOnly) {
        if (!canHelp && !privateLessons) {
          return false;
        }

        if (_selectedFilter == 1 && !canHelp) {
          return false;
        }

        if (_selectedFilter == 2 && !privateLessons) {
          return false;
        }
      } else {
        if (_selectedFilter == 1 && user.type != SocialUserType.student) {
          return false;
        }

        if (_selectedFilter == 2 && user.type != SocialUserType.teacher) {
          return false;
        }

        if (_selectedFilter == 3 && !canHelp && !privateLessons) {
          return false;
        }
      }

      if (query.isEmpty) {
        return true;
      }

      final String subjects = user.subjects
          .map((SocialSubject subject) => subject.name)
          .join(' ');

      final String searchable = [
        user.name,
        user.department,
        user.course,
        subjects,
        user.description,
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  Future<void> _openUser(SocialUser user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SocialUserProfilePage(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        title: Text(widget.tutorOnly ? 'Tutor' : 'Colleghi'),

        actions: [
          IconButton(
            tooltip: 'Aggiorna',

            onPressed: _loadUsers,

            icon: const Icon(Icons.refresh_rounded),
          ),

          IconButton(
            tooltip: 'Comunicazioni private',

            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivateNewsPage()),
              );
            },

            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),

            child: RefreshIndicator(
              onRefresh: _loadUsers,

              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(20),

                children: [
                  TextField(
                    controller: _searchController,

                    onChanged: (_) {
                      setState(() {});
                    },

                    style: const TextStyle(color: AppColors.pureWhite),

                    decoration: InputDecoration(
                      hintText: widget.tutorOnly
                          ? 'Cerca tutor, materie, corsi...'
                          : 'Cerca studenti, insegnanti, materie...',

                      hintStyle: const TextStyle(color: Colors.white38),

                      prefixIcon: const Icon(
                        Icons.search_rounded,

                        color: AppColors.skyBlue,
                      ),

                      filled: true,

                      fillColor: AppColors.eleganceMidnight,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),

                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _buildFilters(),

                  const SizedBox(height: 22),

                  _buildUserList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final List<String> labels = widget.tutorOnly
        ? const ['Tutti', 'Aiuto', 'Lezioni private']
        : const ['Tutti', 'Studenti', 'Insegnanti', 'Disponibili'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: Row(
        children: List.generate(labels.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),

            child: ChoiceChip(
              selected: _selectedFilter == index,

              label: Text(labels[index]),

              onSelected: (_) {
                setState(() {
                  _selectedFilter = index;
                });
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildUserList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),

        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _ErrorCard(message: _error!, onRetry: _loadUsers);
    }

    final List<SocialUser> users = _filteredUsers;

    if (users.isEmpty) {
      return _EmptyCard(
        icon: widget.tutorOnly
            ? Icons.volunteer_activism_outlined
            : Icons.person_search_outlined,

        title: widget.tutorOnly ? 'Nessun tutor disponibile' : 'Nessun utente',

        message: widget.tutorOnly
            ? 'Non ci sono utenti disponibili con questo filtro.'
            : 'Nessun profilo corrisponde alla ricerca.',
      );
    }

    return Column(
      children: users.map((SocialUser user) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),

          child: InkWell(
            onTap: () {
              _openUser(user);
            },

            borderRadius: BorderRadius.circular(18),

            child: user.type == SocialUserType.student
                ? StudentHelpCard(student: user)
                : TeacherHelpCard(teacher: user),
          ),
        );
      }).toList(),
    );
  }
}

enum _UserGroupFilter { all, owned, member }

class _SocialGroupsPage extends StatefulWidget {
  const _SocialGroupsPage();

  @override
  State<_SocialGroupsPage> createState() => _SocialGroupsPageState();
}

class _SocialGroupsPageState extends State<_SocialGroupsPage> {
  final ApiService _apiService = ApiService();

  List<StudyGroup> _groups = [];

  _UserGroupFilter _selectedFilter = _UserGroupFilter.all;

  bool _loading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final int? currentUserId = AuthSession.instance.currentUserId;

    if (currentUserId == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _groups = [];

        _loading = false;

        _error = 'Accedi per visualizzare i tuoi gruppi.';
      });

      return;
    }

    setState(() {
      _loading = true;

      _error = null;
    });

    try {
      final List<StudyGroup> groups = await _loadGroupsFromBackend(
        apiService: _apiService,

        currentUserId: currentUserId,

        onlyUserGroups: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = groups;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanError(e);

        _loading = false;
      });
    }
  }

  List<StudyGroup> get _visibleGroups {
    switch (_selectedFilter) {
      case _UserGroupFilter.all:
        return _groups;

      case _UserGroupFilter.owned:
        return _groups.where((StudyGroup group) => group.isOwner).toList();

      case _UserGroupFilter.member:
        return _groups.where((StudyGroup group) => !group.isOwner).toList();
    }
  }

  int get _ownedCount {
    return _groups.where((StudyGroup group) => group.isOwner).length;
  }

  int get _memberCount {
    return _groups.length - _ownedCount;
  }

  Future<void> _createGroup() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateGroupPage()));

    if (mounted) {
      await _loadGroups();
    }
  }

  Future<void> _exploreGroups() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PublicGroupsPage()));

    if (mounted) {
      await _loadGroups();
    }
  }

  Future<void> _openGroup(StudyGroup group) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudyGroupDetailPage(group: group)),
    );

    if (mounted) {
      await _loadGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        title: const Text('Gruppi'),

        actions: [
          IconButton(
            tooltip: 'Aggiorna',

            onPressed: _loading ? null : _loadGroups,

            icon: const Icon(Icons.refresh_rounded),
          ),

          IconButton(
            tooltip: 'Comunicazioni private',

            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivateNewsPage()),
              );
            },

            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),

            child: RefreshIndicator(
              onRefresh: _loadGroups,

              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(20),

                children: [
                  _buildHeader(),

                  const SizedBox(height: 18),

                  _buildPrimaryActions(),

                  const SizedBox(height: 22),

                  _buildFilterBar(),

                  const SizedBox(height: 16),

                  _buildResultsHeader(),

                  const SizedBox(height: 14),

                  _buildGroups(),

                  const SizedBox(height: 24),
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

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 50,

            height: 50,

            decoration: BoxDecoration(
              color: AppColors.brandNightBlue,

              borderRadius: BorderRadius.circular(14),
            ),

            child: const Icon(
              Icons.groups_2_rounded,

              color: AppColors.skyBlue,

              size: 27,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'I tuoi gruppi',

                  style: TextStyle(
                    color: AppColors.pureWhite,

                    fontSize: 20,

                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Qui trovi i gruppi che hai creato e quelli a cui partecipi.',

                  style: TextStyle(
                    color: AppColors.pureWhite.withValues(alpha: 0.52),

                    fontSize: 11,

                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 470;

        final Widget create = OutlinedButton.icon(
          onPressed: _createGroup,

          icon: const Icon(Icons.add_circle_outline_rounded),

          label: const Text('Crea gruppo'),
        );

        final Widget explore = ElevatedButton.icon(
          onPressed: _exploreGroups,

          icon: const Icon(Icons.search_rounded),

          label: const Text('Esplora gruppi'),

          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.socialBlue,

            foregroundColor: AppColors.pureWhite,

            elevation: 0,
          ),
        );

        if (compact) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: create),

              const SizedBox(height: 10),

              SizedBox(width: double.infinity, child: explore),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: create),

            const SizedBox(width: 10),

            Expanded(child: explore),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: Row(
        children: [
          _UserGroupFilterChip(
            label: 'Tutti',

            count: _groups.length,

            selected: _selectedFilter == _UserGroupFilter.all,

            onTap: () {
              setState(() {
                _selectedFilter = _UserGroupFilter.all;
              });
            },
          ),

          const SizedBox(width: 8),

          _UserGroupFilterChip(
            label: 'Creati da te',

            count: _ownedCount,

            selected: _selectedFilter == _UserGroupFilter.owned,

            onTap: () {
              setState(() {
                _selectedFilter = _UserGroupFilter.owned;
              });
            },
          ),

          const SizedBox(width: 8),

          _UserGroupFilterChip(
            label: 'Partecipi',

            count: _memberCount,

            selected: _selectedFilter == _UserGroupFilter.member,

            onTap: () {
              setState(() {
                _selectedFilter = _UserGroupFilter.member;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    if (_loading || _error != null) {
      return const SizedBox.shrink();
    }

    final int count = _visibleGroups.length;

    return Row(
      children: [
        Expanded(
          child: Text(
            count == 1 ? '1 gruppo' : '$count gruppi',

            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.55),

              fontSize: 11,

              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        Text(
          '${_ownedCount} creati da te',

          style: TextStyle(
            color: AppColors.materialSky.withValues(alpha: 0.78),

            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildGroups() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),

        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _ErrorCard(message: _error!, onRetry: _loadGroups);
    }

    final List<StudyGroup> groups = _visibleGroups;

    if (groups.isEmpty) {
      final bool filtering = _selectedFilter != _UserGroupFilter.all;

      return _EmptyGroupHubCard(
        filtered: filtering,

        onCreate: _createGroup,

        onExplore: _exploreGroups,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        int columns = 2;

        if (constraints.maxWidth < 520) {
          columns = 1;
        } else if (constraints.maxWidth >= 900) {
          columns = 3;
        }

        return GridView.builder(
          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          itemCount: groups.length,

          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,

            crossAxisSpacing: 12,

            mainAxisSpacing: 12,

            mainAxisExtent: 300,
          ),

          itemBuilder: (BuildContext context, int index) {
            final StudyGroup group = groups[index];

            return StudyGroupCard(
              group: group,

              onTap: () {
                _openGroup(group);
              },
            );
          },
        );
      },
    );
  }
}

class _UserGroupFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _UserGroupFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(11),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),

        decoration: BoxDecoration(
          color: selected
              ? AppColors.skyBlue.withValues(alpha: 0.14)
              : AppColors.eleganceMidnight,

          borderRadius: BorderRadius.circular(11),

          border: Border.all(
            color: selected
                ? AppColors.skyBlue.withValues(alpha: 0.32)
                : AppColors.skyBlue.withValues(alpha: 0.10),
          ),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            Text(
              label,

              style: TextStyle(
                color: selected
                    ? AppColors.pureWhite
                    : AppColors.pureWhite.withValues(alpha: 0.58),

                fontSize: 10,

                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),

            const SizedBox(width: 7),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

              decoration: BoxDecoration(
                color: AppColors.brandNightBlue,

                borderRadius: BorderRadius.circular(7),
              ),

              child: Text(
                '$count',

                style: const TextStyle(
                  color: AppColors.materialSky,

                  fontSize: 9,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGroupHubCard extends StatelessWidget {
  final bool filtered;
  final Future<void> Function() onCreate;
  final Future<void> Function() onExplore;

  const _EmptyGroupHubCard({
    required this.filtered,
    required this.onCreate,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.10)),
      ),

      child: Column(
        children: [
          Container(
            width: 58,

            height: 58,

            decoration: BoxDecoration(
              color: AppColors.brandNightBlue,

              borderRadius: BorderRadius.circular(16),
            ),

            child: const Icon(
              Icons.groups_outlined,

              color: AppColors.skyBlue,

              size: 30,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            filtered
                ? 'Nessun gruppo in questa sezione'
                : 'Non partecipi ancora a gruppi',

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: AppColors.pureWhite,

              fontSize: 15,

              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            filtered
                ? 'Prova un altro filtro per visualizzare i tuoi gruppi.'
                : 'Crea un nuovo gruppo di studio oppure esplora quelli disponibili su StudentLab.',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.50),

              fontSize: 11,

              height: 1.4,
            ),
          ),

          if (!filtered) ...[
            const SizedBox(height: 16),

            Wrap(
              spacing: 10,

              runSpacing: 10,

              alignment: WrapAlignment.center,

              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    onCreate();
                  },

                  icon: const Icon(Icons.add_circle_outline_rounded),

                  label: const Text('Crea gruppo'),
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    onExplore();
                  },

                  icon: const Icon(Icons.search_rounded),

                  label: const Text('Esplora'),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.socialBlue,

                    foregroundColor: AppColors.pureWhite,

                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final bool available;

  const _AvailabilityBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    final Color color = available ? Colors.greenAccent : Colors.white30;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 6),

        Text(
          available ? 'Disponibile' : 'Non disponibile',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;

  final String title;

  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Icon(icon, color: AppColors.materialSky, size: 20),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),

              const SizedBox(height: 2),

              Text(
                value,

                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;

  const _SubjectChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),

      decoration: BoxDecoration(
        color: AppColors.brandNightBlue,

        borderRadius: BorderRadius.circular(10),
      ),

      child: Text(
        label,

        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}

class _ProfileCapabilityChip extends StatelessWidget {
  final IconData icon;

  final String label;

  const _ProfileCapabilityChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),

      decoration: BoxDecoration(
        color: AppColors.skyBlue.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(9),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.15)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, color: AppColors.materialSky, size: 15),

          const SizedBox(width: 5),

          Text(
            label,

            style: const TextStyle(
              color: AppColors.materialSky,

              fontSize: 10,

              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAcademicTitleCard extends StatelessWidget {
  final SocialAcademicTitle title;

  const _ProfileAcademicTitleCard({required this.title});

  @override
  Widget build(BuildContext context) {
    final String label = title.titleTypeLabel.trim().isEmpty
        ? 'Titolo accademico'
        : title.titleTypeLabel;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: AppColors.brandNightBlue,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.amber.withValues(alpha: 0.18)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 34,

                height: 34,

                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.10),

                  borderRadius: BorderRadius.circular(10),
                ),

                child: const Icon(
                  Icons.workspace_premium_outlined,

                  color: Colors.amber,

                  size: 19,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      label,

                      style: const TextStyle(
                        color: AppColors.pureWhite,

                        fontSize: 13,

                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (title.course.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),

                      Text(
                        title.course,

                        style: TextStyle(
                          color: AppColors.pureWhite.withValues(alpha: 0.62),

                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              _ProfileVerificationBadge(
                verified: title.isVerified,

                rejected: title.isVerificationRejected,

                pending: title.isVerificationPending,
              ),
            ],
          ),

          if (title.university.trim().isNotEmpty ||
              title.department.trim().isNotEmpty) ...[
            const SizedBox(height: 10),

            Text(
              [
                if (title.university.trim().isNotEmpty) title.university.trim(),

                if (title.department.trim().isNotEmpty) title.department.trim(),
              ].join(' • '),

              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.42),

                fontSize: 10,
              ),
            ),
          ],

          if (title.graduationYear != null || title.isPrimary) ...[
            const SizedBox(height: 9),

            Wrap(
              spacing: 7,

              runSpacing: 7,

              children: [
                if (title.graduationYear != null)
                  _ProfileSmallBadge(
                    label: 'Conseguito ${title.graduationYear}',
                  ),

                if (title.isPrimary)
                  const _ProfileSmallBadge(label: 'Principale'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileAcademicPathCard extends StatelessWidget {
  final SocialAcademicPath path;

  const _ProfileAcademicPathCard({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: AppColors.brandNightBlue,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Icon(
                Icons.account_balance_outlined,

                color: AppColors.skyBlue,

                size: 17,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  path.university.trim().isEmpty
                      ? 'Ateneo non specificato'
                      : path.university,

                  style: const TextStyle(
                    color: AppColors.pureWhite,

                    fontSize: 12,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              _ProfileVerificationBadge(
                verified: path.isVerified,

                rejected: path.isVerificationRejected,

                pending: path.isVerificationPending,
              ),
            ],
          ),

          const SizedBox(height: 10),

          _ProfileAcademicInfoRow(
            label: 'Dipartimento',

            value: path.department.trim().isEmpty
                ? 'Non specificato'
                : path.department,
          ),

          const SizedBox(height: 7),

          _ProfileAcademicInfoRow(
            label: 'Corso',

            value: path.course.trim().isEmpty ? 'Non specificato' : path.course,
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 7,

            runSpacing: 7,

            children: [
              _ProfileAcademicStatusBadge(status: path.status),

              if (path.startYear != null)
                _ProfileSmallBadge(label: 'Dal ${path.startYear}'),

              if (path.isCurrent) const _ProfileSmallBadge(label: 'Corrente'),

              if (path.isPrimary) const _ProfileSmallBadge(label: 'Principale'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileAcademicInfoRow extends StatelessWidget {
  final String label;

  final String value;

  const _ProfileAcademicInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        SizedBox(
          width: 90,

          child: Text(
            label,

            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.38),

              fontSize: 10,
            ),
          ),
        ),

        const SizedBox(width: 7),

        Expanded(
          child: Text(
            value,

            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.72),

              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAcademicStatusBadge extends StatelessWidget {
  final AcademicPathStatus status;

  const _ProfileAcademicStatusBadge({required this.status});

  String get label {
    switch (status) {
      case AcademicPathStatus.enrolled:
        return 'Iscritto';

      case AcademicPathStatus.graduated:
        return 'Laureato';

      case AcademicPathStatus.suspended:
        return 'Percorso sospeso';

      case AcademicPathStatus.withdrawn:
        return 'Percorso interrotto';

      case AcademicPathStatus.transferred:
        return 'Trasferito';
    }
  }

  IconData get icon {
    switch (status) {
      case AcademicPathStatus.enrolled:
        return Icons.school_outlined;

      case AcademicPathStatus.graduated:
        return Icons.workspace_premium_outlined;

      case AcademicPathStatus.suspended:
        return Icons.pause_circle_outline_rounded;

      case AcademicPathStatus.withdrawn:
        return Icons.remove_circle_outline;

      case AcademicPathStatus.transferred:
        return Icons.swap_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),

      decoration: BoxDecoration(
        color: AppColors.skyBlue.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(8),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, color: AppColors.materialSky, size: 12),

          const SizedBox(width: 4),

          Text(
            label,

            style: const TextStyle(
              color: AppColors.materialSky,

              fontSize: 9,

              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSmallBadge extends StatelessWidget {
  final String label;

  const _ProfileSmallBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),

      decoration: BoxDecoration(
        color: AppColors.pureWhite.withValues(alpha: 0.05),

        borderRadius: BorderRadius.circular(8),
      ),

      child: Text(
        label,

        style: TextStyle(
          color: AppColors.pureWhite.withValues(alpha: 0.60),

          fontSize: 9,

          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ProfileVerificationBadge extends StatelessWidget {
  final bool verified;

  final bool rejected;

  final bool pending;

  const _ProfileVerificationBadge({
    required this.verified,
    required this.rejected,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final IconData icon;

    if (verified) {
      label = 'VERIFICATO';
      color = Colors.greenAccent;
      icon = Icons.verified_rounded;
    } else if (rejected) {
      label = 'RIFIUTATO';
      color = Colors.redAccent;
      icon = Icons.cancel_outlined;
    } else if (pending) {
      label = 'DA VERIFICARE';
      color = Colors.amber;
      icon = Icons.schedule_rounded;
    } else {
      label = 'DICHIARATO';
      color = AppColors.materialSky;
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(8),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, color: color, size: 10),

          const SizedBox(width: 3),

          Text(
            label,

            style: TextStyle(
              color: color,

              fontSize: 8,

              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSubjectCard extends StatelessWidget {
  final SocialSubject subject;

  const _ProfileSubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 8),

      padding: const EdgeInsets.all(11),

      decoration: BoxDecoration(
        color: AppColors.socialBlue.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: AppColors.socialBlue.withValues(alpha: 0.18)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_outlined,

                color: AppColors.skyBlue,

                size: 17,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  subject.name,

                  style: const TextStyle(
                    color: AppColors.skyBlue,

                    fontSize: 13,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (subject.grade != null && subject.isGradeVerified)
                _ProfileSubjectBadge(
                  label: '${subject.grade}/30',

                  icon: Icons.verified_rounded,
                ),
            ],
          ),

          if (subject.canHelp || subject.canGivePrivateLessons) ...[
            const SizedBox(height: 8),

            Wrap(
              spacing: 6,

              runSpacing: 6,

              children: [
                if (subject.canHelp)
                  const _ProfileSubjectBadge(
                    label: 'Aiuto',

                    icon: Icons.volunteer_activism_outlined,
                  ),

                if (subject.canGivePrivateLessons)
                  const _ProfileSubjectBadge(
                    label: 'Lezioni private',

                    icon: Icons.school_outlined,
                  ),
              ],
            ),
          ],

          if (subject.note.trim().isNotEmpty) ...[
            const SizedBox(height: 8),

            Text(
              subject.note,

              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.55),

                fontSize: 12,

                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileTeacherAssignmentCard extends StatelessWidget {
  final TeacherAssignment assignment;

  const _ProfileTeacherAssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final SubjectOffering? offering = assignment.offering;

    final List<String> details = [];

    if (offering != null && offering.module.trim().isNotEmpty) {
      details.add(offering.module);
    }

    if (offering != null && offering.channel.trim().isNotEmpty) {
      details.add('Canale ${offering.channel}');
    }

    if (offering != null && offering.academicYear.trim().isNotEmpty) {
      details.add(offering.academicYear);
    }

    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 8),

      padding: const EdgeInsets.all(11),

      decoration: BoxDecoration(
        color: AppColors.teacherIndigo.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(
          color: AppColors.teacherIndigo.withValues(alpha: 0.18),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Icon(
                Icons.school_outlined,

                color: AppColors.skyBlue,

                size: 17,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  assignment.subject.name,

                  style: const TextStyle(
                    color: AppColors.skyBlue,

                    fontSize: 13,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              _ProfileVerificationBadge(
                verified: assignment.isVerified,

                rejected: assignment.isRejected,

                pending: assignment.isPending,
              ),
            ],
          ),

          if (details.isNotEmpty) ...[
            const SizedBox(height: 9),

            Wrap(
              spacing: 6,

              runSpacing: 6,

              children: details
                  .map(
                    (String detail) => _ProfileSubjectBadge(
                      label: detail,

                      icon: Icons.class_outlined,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileSubjectBadge extends StatelessWidget {
  final String label;

  final IconData icon;

  const _ProfileSubjectBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),

      decoration: BoxDecoration(
        color: AppColors.skyBlue.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(8),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, color: AppColors.materialSky, size: 11),

          const SizedBox(width: 4),

          Text(
            label,

            style: const TextStyle(
              color: AppColors.materialSky,

              fontSize: 8,

              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileReviewSummary extends StatelessWidget {
  final SocialUser user;

  const _ProfileReviewSummary({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: AppColors.brandNightBlue,

        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),

          const SizedBox(width: 6),

          if (user.reviews.isEmpty)
            const Text(
              'Nessuna recensione',

              style: TextStyle(color: AppColors.pureWhite, fontSize: 12),
            )
          else ...[
            Text(
              user.averageRating.toStringAsFixed(1),

              style: const TextStyle(
                color: AppColors.pureWhite,

                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(width: 6),

            Text(
              '(${user.reviewCount} '
              '${user.reviewCount == 1 ? 'recensione' : 'recensioni'})',

              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.50),

                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  final IconData icon;

  final String value;

  final String label;

  const _StatisticCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(14),
      ),

      child: Column(
        children: [
          Icon(icon, color: AppColors.skyBlue, size: 20),

          const SizedBox(height: 6),

          Text(
            value,

            style: const TextStyle(
              color: AppColors.pureWhite,

              fontSize: 17,

              fontWeight: FontWeight.bold,
            ),
          ),

          Text(
            label,

            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  final Future<void> Function() onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,

            color: Colors.redAccent,

            size: 35,
          ),

          const SizedBox(height: 10),

          Text(
            message,

            textAlign: TextAlign.center,

            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),

          const SizedBox(height: 14),

          OutlinedButton.icon(
            onPressed: () {
              onRetry();
            },

            icon: const Icon(Icons.refresh_rounded),

            label: const Text('Riprova'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;

  final String title;

  final String message;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(25),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        children: [
          Icon(icon, color: Colors.white30, size: 40),

          const SizedBox(height: 10),

          Text(
            title,

            style: const TextStyle(
              color: AppColors.pureWhite,

              fontSize: 14,

              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            message,

            textAlign: TextAlign.center,

            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

Future<List<StudyGroup>> _loadGroupsFromBackend({
  required ApiService apiService,
  required int currentUserId,
  required bool onlyUserGroups,
}) async {
  final List<Map<String, dynamic>> rawGroups = onlyUserGroups
      ? await apiService.getUserGroups(currentUserId)
      : await apiService.getGroups();

  final Map<int, StudyGroup> groupsById = {};

  for (final Map<String, dynamic> rawGroup in rawGroups) {
    final Map<String, dynamic> merged = Map<String, dynamic>.from(rawGroup);

    final int? groupId = _toInt(rawGroup['id']);

    if (groupId == null || groupId <= 0) {
      continue;
    }

    try {
      final Map<String, dynamic> detail = await apiService.getGroup(groupId);

      merged.addAll(detail);
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> materials = await apiService
          .getGroupMaterials(groupId);

      merged['material_count'] = materials.length;
    } catch (_) {}

    groupsById[groupId] = StudyGroup.fromJson(
      merged,

      currentUserId: currentUserId,
    );
  }

  final List<StudyGroup> result = groupsById.values.toList();

  result.sort((StudyGroup a, StudyGroup b) {
    if (a.isOwner && !b.isOwner) {
      return -1;
    }

    if (!a.isOwner && b.isOwner) {
      return 1;
    }

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return result;
}

int? _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}

String _cleanError(Object error) {
  final String message = error.toString().toLowerCase();

  if (message.contains('socket') ||
      message.contains('network') ||
      message.contains('connection') ||
      message.contains('host lookup') ||
      message.contains('failed host')) {
    return 'Non è stato possibile connettersi a StudentLab. Controlla la connessione e riprova.';
  }

  if (message.contains('timeout') ||
      message.contains('timed out') ||
      message.contains('408')) {
    return 'La richiesta sta impiegando troppo tempo. Riprova tra qualche momento.';
  }

  if (message.contains('401') ||
      message.contains('unauthorized') ||
      (message.contains('token') &&
          (message.contains('expired') || message.contains('invalid')))) {
    return 'La sessione non è più valida. Accedi nuovamente per continuare.';
  }

  if (message.contains('403') || message.contains('forbidden')) {
    return 'Non hai i permessi necessari per completare questa operazione.';
  }

  if (message.contains('404') || message.contains('not found')) {
    return 'Le informazioni richieste non sono più disponibili. Aggiorna la pagina e riprova.';
  }

  if (message.contains('409') ||
      message.contains('conflict') ||
      message.contains('already exists')) {
    return 'Non è stato possibile completare l’operazione perché i dati risultano già aggiornati o presenti.';
  }

  if (message.contains('422') ||
      message.contains('validation') ||
      message.contains('invalid')) {
    return 'Alcune informazioni non risultano valide. Controlla i dati e riprova.';
  }

  if (message.contains('429') ||
      message.contains('too many') ||
      message.contains('rate limit')) {
    return 'Sono state effettuate troppe richieste in poco tempo. Riprova tra qualche momento.';
  }

  if (message.contains('500') ||
      message.contains('502') ||
      message.contains('503') ||
      message.contains('504') ||
      message.contains('internal server')) {
    return 'StudentLab è temporaneamente non disponibile. Riprova tra qualche momento.';
  }

  return 'Non è stato possibile completare l’operazione. Riprova.';
}
