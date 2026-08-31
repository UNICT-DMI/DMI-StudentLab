import 'dart\:async';

import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart';

import 'package:fe/layers/homeLayer.dart';

import 'package:fe/theme/nightTheme.dart';

import 'package:fe/services/api_service.dart';

import 'package:fe/services/auth_service.dart';

import 'package:fe/services/auth_session.dart';

import 'package:fe/services/pending_registration_store.dart';

import 'package:fe/social/social_models.dart';

import 'package:fe/social/auth/email_verification_page.dart';

import 'package:fe/social/social_page.dart';

import 'package:fe/social/auth/login_page.dart';

import 'package:fe/social/auth/registration_intro_page.dart';

import 'package:fe/social/widgets/studentlab_guest_account_button.dart';

import 'package:fe/social/message/message_page.dart';

import 'package:fe/social/notifications/notifications_page.dart';

import 'package:fe/social/admin/admin_panel_page.dart';

import 'package:fe/social/teacher/teachear_area_page.dart';

import 'package:fe/social/widgets/studentlab_user_avatar.dart';

import 'package:fe/social/widgets/social_user_profile_page.dart';

class HomePage extends StatefulWidget {

  const HomePage({super.key});

  @override

  State<HomePage> createState() => _HomePageState();

}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {

  final AuthSession _authSession = AuthSession.instance;

  final AuthService _authService = AuthService();

  final ApiService _apiService = ApiService();

  final PendingRegistrationStore _pendingStore = PendingRegistrationStore();

  PendingRegistration? _pendingToResume;

  VerifiedRegistrationBanner? _verifiedBanner;

  Timer? _verifiedBannerTimer;

  bool _resumingRegistration = false;

  bool _restoringSession = true;

  bool _loadingPermissions = false;

  bool _loadingNotifications = false;

  bool _adminAccess = false;

  bool _teacherAccess = false;

  int _unreadNotificationCount = 0;

  bool _navbarVisible = true;

  @override

  void initState() {

super.initState();

    WidgetsBinding.instance.addObserver(this);

    _authSession.addListener(_onAuthChanged);

    _restoreSession();

  }

  @override

  void dispose() {

    WidgetsBinding.instance.removeObserver(this);

    _verifiedBannerTimer?.cancel();

    _authSession.removeListener(_onAuthChanged);

super.dispose();

  }

  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.resumed && mounted) {

      unawaited(_refreshRegistrationBanners());

    }

  }

  void _onAuthChanged() {

    if (!mounted) {

      return;

    }

    setState(() {});

    if (!_authSession.isAuthenticated) {

      setState(() {

        _adminAccess = false;

        _teacherAccess = false;

        _unreadNotificationCount = 0;

      });

      return;

    }

    _pendingToResume = null;

    unawaited(_refreshVerifiedBanner());

    unawaited(Future.wait([_loadPermissions(), _loadUnreadNotifications()]));

  }

  Future<void> _restoreSession() async {

    try {

      await _authService.restoreSession();

      if (_authSession.isAuthenticated) {

        await Future.wait([_loadPermissions(), _loadUnreadNotifications()]);

      }

      await _handlePendingRegistration();

      await _refreshVerifiedBanner();

    } catch (_) {

      if (mounted) {

        setState(() {

          _adminAccess = false;

          _teacherAccess = false;

          _unreadNotificationCount = 0;

        });

      }

    } finally {

      if (!mounted) {

        return;

      }

      setState(() {

        _restoringSession = false;

      });

    }

  }

  Future<void> _refreshRegistrationBanners() async {

    await _handlePendingRegistration();

    await _refreshVerifiedBanner();

    if (mounted) {

      setState(() {});

    }

  }

  Future<void> _handlePendingRegistration() async {

    if (_authSession.isAuthenticated) {

      final PendingRegistration? pending = await _pendingStore.load();

      if (pending != null) {

        await _authService.completeProfileExtras(pending.draft);

        await _pendingStore.clear();

      }

      _pendingToResume = null;

      return;

    }

    _pendingToResume = await _pendingStore.load();

  }

  Future<void> _refreshVerifiedBanner() async {

    _verifiedBanner = await _pendingStore.loadVerifiedBanner(DateTime.now());

    _scheduleVerifiedBannerExpiry();

  }

  void _scheduleVerifiedBannerExpiry() {

    _verifiedBannerTimer?.cancel();

    final VerifiedRegistrationBanner? banner = _verifiedBanner;

    if (banner == null) {

      return;

    }

    final DateTime expiresAt =

        banner.verifiedAt.add(PendingRegistrationStore.verifiedBannerTtl);

    final Duration remaining = expiresAt.difference(DateTime.now());

    if (remaining <= Duration.zero) {

      _verifiedBanner = null;

      unawaited(_pendingStore.clearVerifiedBanner());

      return;

    }

    _verifiedBannerTimer = Timer(remaining, () async {

      await _pendingStore.clearVerifiedBanner();

      if (mounted) {

        setState(() {

          _verifiedBanner = null;

        });

      }

    });

  }

  Future<void> _dismissVerifiedBanner() async {

    _verifiedBannerTimer?.cancel();

    await _pendingStore.clearVerifiedBanner();

    if (mounted) {

      setState(() {

        _verifiedBanner = null;

      });

    }

  }

  Future<void> _resumePendingRegistration() async {

    final PendingRegistration? pending = _pendingToResume;

    if (pending == null || _resumingRegistration || !mounted) {

      return;

    }

    _resumingRegistration = true;

    try {

      final SocialUser? user = await Navigator.of(context).push<SocialUser>(

        MaterialPageRoute(

          builder: (_) => EmailVerificationPage(

            registrationId: pending.registrationId,

            email: pending.email,

            expiresIn: 0,

            draft: pending.draft,

            onRegistrationUpdated: (String registrationId, String email) {

              _pendingStore.updateIdentity(

                registrationId: registrationId,

                email: email,

              );

            },

            onCancel: () => _pendingStore.clear(),

          ),

        ),

      );

      if (user != null) {

        await _authService.completeProfileExtras(pending.draft);

      }

    } finally {

      _resumingRegistration = false;

      _pendingToResume = null;

      await _handlePendingRegistration();

      await _refreshVerifiedBanner();

      if (mounted) {

        setState(() {});

      }

    }

  }

  Future<void> _loadPermissions() async {

    if (!_authSession.isAuthenticated) {

      if (mounted) {

        setState(() {

          _adminAccess = false;

          _teacherAccess = false;

        });

      }

      return;

    }

    if (_loadingPermissions) {

      return;

    }

    _loadingPermissions = true;

    try {

      final bool isDeveloperSystem =

          _currentUser?.role.trim().toLowerCase() == 'devsyst';

      final List<bool> permissions = await Future.wait<bool>([

        _apiService.canAccessAdminPanel(),

        _apiService.canAccessTeacherArea(),

      ]);

      if (!mounted) {

        return;

      }

      setState(() {

        _adminAccess = isDeveloperSystem || permissions[0];

        _teacherAccess = permissions[1];

      });

    } catch (_) {

      if (!mounted) {

        return;

      }

      setState(() {

        _adminAccess = false;

        _teacherAccess = false;

      });

    } finally {

      _loadingPermissions = false;

    }

  }

  Future<void> _loadUnreadNotifications() async {

    if (!_isAuthenticated) {

      if (mounted) {

        setState(() {

          _unreadNotificationCount = 0;

        });

      }

      return;

    }

    if (_loadingNotifications) {

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

  bool get _isAuthenticated {

    return _authSession.isAuthenticated;

  }

  SocialUser? get _currentUser {

    return _authSession.currentUser;

  }

  String get _displayName {

    final SocialUser? user = _currentUser;

    if (user == null) {

      return 'Utente';

    }

    if (user.firstName.isNotEmpty) {

      return user.firstName;

    }

    if (user.name.isNotEmpty) {

      return user.name;

    }

    return 'Utente';

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.darkElegance,

      body: SafeArea(

        bottom: false,

        child: Column(

          children: [

            AnimatedSize(

              duration: const Duration(milliseconds: 220),

              curve: Curves.easeOutCubic,

              alignment: Alignment.topCenter,

              child: _navbarVisible ? _buildNavbar() : const SizedBox.shrink(),

            ),

            _buildRegistrationBanners(),

            Expanded(

              child: NotificationListener<UserScrollNotification>(

                onNotification: _handleHomeScroll,

                child: HomeLayer(),

              ),

            ),

          ],

        ),

      ),

    );

  }

  Widget _buildRegistrationBanners() {

    final PendingRegistration? pending = _pendingToResume;

    final VerifiedRegistrationBanner? verified = _verifiedBanner;

    final List<Widget> banners = [];

    if (pending != null && !_isAuthenticated) {

      banners.add(_pendingEmailBanner(pending));

    }

    if (verified != null) {

      banners.add(_verifiedEmailBanner(verified));

    }

    if (banners.isEmpty) {

      return const SizedBox.shrink();

    }

    return Padding(

      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: banners,

      ),

    );

  }

  Widget _pendingEmailBanner(PendingRegistration pending) {

    return Container(

      margin: const EdgeInsets.only(bottom: 8),

      decoration: BoxDecoration(

        color: Colors.amber.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: Colors.amber.withValues(alpha: 0.30)),

      ),

      child: Material(

        color: Colors.transparent,

        child: InkWell(

          borderRadius: BorderRadius.circular(14),

          onTap: _resumingRegistration ? null : _resumePendingRegistration,

          child: Padding(

            padding: const EdgeInsets.all(12),

            child: Row(

              children: [

                const Icon(

                  Icons.mark_email_unread_outlined,

                  color: Colors.amber,

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text(

                        'Conferma la tua email',

                        style: TextStyle(

                          color: AppColors.pureWhite,

                          fontWeight: FontWeight.bold,

                          fontSize: 14,

                        ),

                      ),

                      const SizedBox(height: 2),

                      Text(

                        'Verifica ${pending.email} per completare la registrazione.',

                        style: TextStyle(

                          color: AppColors.pureWhite.withValues(alpha: 0.60),

                          fontSize: 12,

                        ),

                      ),

                    ],

                  ),

                ),

                const SizedBox(width: 8),

                _resumingRegistration

                    ? const SizedBox(

                        width: 18,

                        height: 18,

                        child: CircularProgressIndicator(

                          strokeWidth: 2,

                          color: Colors.amber,

                        ),

                      )

                    : const Icon(

                        Icons.chevron_right_rounded,

                        color: Colors.amber,

                      ),

              ],

            ),

          ),

        ),

      ),

    );

  }

  Widget _verifiedEmailBanner(VerifiedRegistrationBanner banner) {

    return Container(

      margin: const EdgeInsets.only(bottom: 8),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(

        color: Colors.green.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: Colors.green.withValues(alpha: 0.30)),

      ),

      child: Row(

        children: [

          const Icon(

            Icons.verified_outlined,

            color: Colors.green,

          ),

          const SizedBox(width: 12),

          const Expanded(

            child: Text(

              'Account verificato con successo.',

              style: TextStyle(

                color: AppColors.pureWhite,

                fontWeight: FontWeight.w600,

                fontSize: 14,

              ),

            ),

          ),

          IconButton(

            tooltip: 'Chiudi',

            icon: Icon(

              Icons.close_rounded,

              color: AppColors.pureWhite.withValues(alpha: 0.60),

              size: 20,

            ),

            onPressed: _dismissVerifiedBanner,

          ),

        ],

      ),

    );

  }

  Widget _buildNavbar() {

    return Container(

      height: 56,

      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),

      padding: const EdgeInsets.symmetric(horizontal: 8),

      decoration: BoxDecoration(

        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12)),

      ),

      child: Row(

        children: [

          _StudentLabNavbarLogo(onPressed: () {}),

          const Spacer(),

          if (_restoringSession)

            const Padding(

              padding: EdgeInsets.symmetric(horizontal: 8),

              child: SizedBox(

                width: 20,

                height: 20,

                child: CircularProgressIndicator(

                  strokeWidth: 2,

                  color: AppColors.skyBlue,

                ),

              ),

            )

          else if (_isAuthenticated) ...[

            _NavbarIconButton(

              tooltip: 'Messaggi',

              icon: Icons.chat_bubble_outline_rounded,

              iconColor: AppColors.socialSky,

              onPressed: _openMessages,

            ),

            const SizedBox(width: 6),

            _NavbarIconButton(

              tooltip: 'Notifiche',

              icon: Icons.notifications_none_rounded,

              iconColor: AppColors.materialSky,

              badge: _unreadNotificationCount,

              onPressed: _openNotifications,

            ),

            const SizedBox(width: 6),

            if (_currentUser != null)

              _UserButton(

                user: _currentUser!,

                name: _displayName,

                onPressed: _showUserMenu,

              ),

          ] else ...[

            StudentLabGuestAccountButton(onPressed: _showGuestMenu),

          ],

        ],

      ),

    );

  }

  bool _handleHomeScroll(UserScrollNotification notification) {

    if (notification.metrics.pixels <= 8) {

      if (!_navbarVisible && mounted) setState(() => _navbarVisible = true);

      return false;

    }

    if (notification.direction == ScrollDirection.reverse && _navbarVisible) {

      setState(() => _navbarVisible = false);

    } else if (notification.direction == ScrollDirection.forward &&

        !_navbarVisible) {

      setState(() => _navbarVisible = true);

    }

    return false;

  }

  Future<void> _openGuestLogin() async {

    final SocialUser? user = await Navigator.of(

      context,

    ).push<SocialUser>(MaterialPageRoute(builder: (_) => const LoginPage()));

    if (!mounted || user == null) {

      return;

    }

    _authSession.updateUser(user);

    await Future.wait([_loadPermissions(), _loadUnreadNotifications()]);

  }


  Future<void> _openGuestRegistration() async {

    final SocialUser? user = await Navigator.of(context).push<SocialUser>(

      MaterialPageRoute(

        builder: (_) => const RegistrationIntroPage(),

      ),

    );

    if (!mounted || user == null) {

      return;

    }

    _authSession.updateUser(user);

    await Future.wait([_loadPermissions(), _loadUnreadNotifications()]);

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

              ListTile(

                leading: const Icon(

                  Icons.login_rounded,

                  color: AppColors.skyBlue,

                ),

                title: const Text(

                  'Accedi',

                  style: TextStyle(

                    color: AppColors.pureWhite,

                    fontWeight: FontWeight.w500,

                  ),

                ),

                subtitle: Text(

                  'Accedi al tuo account StudentLab',

                  style: TextStyle(

                    color: AppColors.pureWhite.withValues(alpha: 0.42),

                    fontSize: 10,

                  ),

                ),

                trailing: const Icon(

                  Icons.arrow_forward_ios_rounded,

                  color: Colors.white30,

                  size: 14,

                ),

                onTap: () async {

                  Navigator.pop(sheetContext);

                  await _openGuestLogin();

                },

              ),

              ListTile(

                leading: const Icon(

                  Icons.person_add_alt_1_rounded,

                  color: AppColors.materialSky,

                ),

                title: const Text(

                  'Registrati',

                  style: TextStyle(

                    color: AppColors.pureWhite,

                    fontWeight: FontWeight.w500,

                  ),

                ),

                subtitle: Text(

                  'Crea il tuo profilo StudentLab',

                  style: TextStyle(

                    color: AppColors.pureWhite.withValues(alpha: 0.42),

                    fontSize: 10,

                  ),

                ),

                trailing: const Icon(

                  Icons.arrow_forward_ios_rounded,

                  color: Colors.white30,

                  size: 14,

                ),

                onTap: () async {

                  Navigator.pop(sheetContext);

                  await _openGuestRegistration();

                },

              ),

              const SizedBox(height: 6),

            ],

          ),

        );

      },

    );

  }

  Future<void> _openMessages() async {

    if (!_isAuthenticated) {

      return;

    }

    await Navigator.of(

      context,

    ).push(MaterialPageRoute(builder: (_) => const MessagesPage()));

  }

  Future<void> _openNotifications() async {

    if (!_isAuthenticated) {

      return;

    }

    await Navigator.of(

      context,

    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));

    if (!mounted) {

      return;

    }

    await _loadUnreadNotifications();

  }

  Future<void> _openProfile() async {

    if (!_isAuthenticated) {

      return;

    }

    SocialUser? user = _currentUser;

    if (user == null) {

      try {

        user = await _apiService.getCurrentUser();

        if (!mounted) {

          return;

        }

        _authSession.updateUser(user);

      } catch (_) {

        return;

      }

    }

    await Navigator.of(context).push(

      MaterialPageRoute(builder: (_) => SocialUserProfilePage(user: user!)),

    );

  }

  Future<void> _openGroupsDirectory() async {

    if (!_isAuthenticated) {

      return;

    }

    await Navigator.of(context).push(

      MaterialPageRoute(

        builder: (_) =>

            const SocialPage(startDestination: SocialStartDestination.groups),

      ),

    );

  }

  Future<void> _openUsersDirectory() async {

    if (!_isAuthenticated) {

      return;

    }

    await Navigator.of(context).push(

      MaterialPageRoute(

        builder: (_) => const SocialPage(

          startDestination: SocialStartDestination.colleagues,

        ),

      ),

    );

  }

  Future<void> _openAdminPanel() async {

    if (!_isAuthenticated) {

      return;

    }

    try {

      final bool isDeveloperSystem =

          _currentUser?.role.trim().toLowerCase() == 'devsyst';

      final bool authorized =

          isDeveloperSystem || await _apiService.canAccessAdminPanel();

      if (!mounted) {

        return;

      }

      if (!authorized) {

        setState(() {

          _adminAccess = false;

        });

        return;

      }

      await Navigator.of(

        context,

      ).push(MaterialPageRoute(builder: (_) => const AdminPanelPage()));

      if (!mounted) {

        return;

      }

      await _loadPermissions();

    } catch (_) {

      if (!mounted) {

        return;

      }

      setState(() {

        _adminAccess = false;

      });

    }

  }

  Future<void> _openTeacherArea() async {

    if (!_isAuthenticated) {

      return;

    }

    try {

      final bool authorized = await _apiService.canAccessTeacherArea();

      if (!mounted) {

        return;

      }

      if (!authorized) {

        setState(() {

          _teacherAccess = false;

        });

        return;

      }

      await Navigator.of(

        context,

      ).push(MaterialPageRoute(builder: (_) => const TeacherAreaPage()));

      if (!mounted) {

        return;

      }

      await _loadPermissions();

    } catch (_) {

      if (!mounted) {

        return;

      }

      setState(() {

        _teacherAccess = false;

      });

    }

  }

  Future<void> _logout() async {

    try {

      await _authService.logout();

      if (!mounted) {

        return;

      }

      setState(() {

        _adminAccess = false;

        _teacherAccess = false;

        _unreadNotificationCount = 0;

      });

    } catch (_) {

      return;

    }

  }

  Future<void> _confirmLogout() async {

    final bool? confirmed = await showDialog<bool>(

      context: context,

      builder: (BuildContext dialogContext) {

        return AlertDialog(

          backgroundColor: AppColors.eleganceDeepNavy,

          title: const Text(

            'Disconnetti account',

            style: TextStyle(color: AppColors.pureWhite),

          ),

          content: Text(

            'Vuoi davvero uscire dal tuo account StudentLab? '

            'I file scaricati offline non verranno eliminati.',

            style: TextStyle(

              color: AppColors.pureWhite.withOpacity(0.65),

              height: 1.4,

            ),

          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(dialogContext, false);

              },

              child: const Text('Annulla'),

            ),

            TextButton(

              onPressed: () {

                Navigator.pop(dialogContext, true);

              },

              child: const Text(

                'Esci',

                style: TextStyle(color: Colors.redAccent),

              ),

            ),

          ],

        );

      },

    );

    if (confirmed != true) {

      return;

    }

    await _logout();

  }

  void _showUserMenu() {

    final SocialUser? user = _currentUser;

    if (user == null) {

      _showGuestMenu();

      return;

    }

    final String role = user.role.trim().toLowerCase();

    final bool showTeacherArea =

        _teacherAccess || user.type == SocialUserType.teacher;

    final bool showAdminPanel =

        _adminAccess ||

        role == 'admin' ||

        role == 'creator' ||

        role == 'devsyst';

    showModalBottomSheet<void>(

      context: context,

      isScrollControlled: true,

      backgroundColor: AppColors.eleganceDeepNavy,

      shape: const RoundedRectangleBorder(

        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),

      ),

      builder: (BuildContext sheetContext) {

        final double maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.86;

        return SafeArea(

          child: ConstrainedBox(

            constraints: BoxConstraints(maxHeight: maxHeight),

            child: SingleChildScrollView(

              physics: const ClampingScrollPhysics(),

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

                  _HomeUserMenuTile(

                    icon: Icons.person_outline_rounded,

                    label: 'Profilo',

                    subtitle: 'Visualizza il tuo profilo StudentLab',

                    onTap: () {

                      Navigator.pop(sheetContext);

                      _openProfile();

                    },

                  ),

                  _HomeUserMenuTile(

                    icon: Icons.people_outline_rounded,

                    label: 'Colleghi',

                    subtitle: 'Studenti e insegnanti StudentLab',

                    onTap: () {

                      Navigator.pop(sheetContext);

                      _openUsersDirectory();

                    },

                  ),

                  _HomeUserMenuTile(

                    icon: Icons.groups_2_outlined,

                    label: 'Gruppi',

                    subtitle: 'I tuoi gruppi e quelli pubblici',

                    onTap: () {

                      Navigator.pop(sheetContext);

                      _openGroupsDirectory();

                    },

                  ),

                  if (showTeacherArea)

                    _HomeUserMenuTile(

                      icon: Icons.cast_for_education_outlined,

                      iconColor: Colors.greenAccent,

                      label: 'Area docente',

                      subtitle: 'Materiali e strumenti docente',

                      onTap: () {

                        Navigator.pop(sheetContext);

                        _openTeacherArea();

                      },

                    ),

                  if (showAdminPanel)

                    _HomeUserMenuTile(

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

                  _HomeUserMenuTile(

                    icon: Icons.logout_rounded,

                    label: 'Esci',

                    danger: true,

                    showArrow: false,

                    onTap: () async {

                      Navigator.pop(sheetContext);

                      await _confirmLogout();

                    },

                  ),

                  const SizedBox(height: 6),

                ],

              ),

            ),

          ),

        );

      },

    );

  }

}

class _StudentLabNavbarLogo extends StatelessWidget {

  final VoidCallback onPressed;

  const _StudentLabNavbarLogo({required this.onPressed});

  @override

  Widget build(BuildContext context) {

    return Tooltip(

      message: 'StudentLab',

      child: InkWell(

        onTap: onPressed,

        borderRadius: BorderRadius.circular(12),

        child: Padding(

          padding: const EdgeInsets.all(4),

          child: ClipRRect(

            borderRadius: BorderRadius.circular(10),

            child: Image.asset(

              'assets/icons/favicon.png',

              width: 38,

              height: 38,

              fit: BoxFit.cover,

            ),

          ),

        ),

      ),

    );

  }

}

class _HomeUserMenuTile extends StatelessWidget {

  final IconData icon;

  final String label;

  final String? subtitle;

  final VoidCallback onTap;

  final bool danger;

  final bool showArrow;

  final Color? iconColor;

  const _HomeUserMenuTile({

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

    final Color textColor = danger ? Colors.redAccent : AppColors.pureWhite;

    return ListTile(

      leading: Icon(

        icon,

        color: danger ? Colors.redAccent : iconColor ?? AppColors.skyBlue,

      ),

      title: Text(

        label,

        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),

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

class _NavbarIconButton extends StatelessWidget {

  final String tooltip;

  final IconData icon;

  final Color iconColor;

  final int badge;

  final VoidCallback onPressed;

  const _NavbarIconButton({

    required this.tooltip,

    required this.icon,

    required this.iconColor,

    required this.onPressed,

this.badge = 0,

  });

  @override

  Widget build(BuildContext context) {

    return Tooltip(

      message: tooltip,

      child: InkWell(

        onTap: onPressed,

        borderRadius: BorderRadius.circular(12),

        child: SizedBox(

          width: 38,

          height: 38,

          child: Stack(

            clipBehavior: Clip.none,

            children: [

              Center(

                child: Container(

                  width: 38,

                  height: 38,

                  decoration: BoxDecoration(

                    color: AppColors.brandNightBlue,

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(

                      color: AppColors.skyBlue.withValues(alpha: 0.10),

                    ),

                  ),

                  child: Icon(icon, color: iconColor, size: 20),

                ),

              ),

              if (badge > 0)

                Positioned(

                  top: -3,

                  right: -3,

                  child: Container(

                    constraints: const BoxConstraints(

                      minWidth: 17,

                      minHeight: 17,

                    ),

                    padding: const EdgeInsets.symmetric(horizontal: 4),

                    alignment: Alignment.center,

                    decoration: BoxDecoration(

                      color: Colors.redAccent,

                      borderRadius: BorderRadius.circular(9),

                      border: Border.all(

                        color: AppColors.eleganceMidnight,

                        width: 2,

                      ),

                    ),

                    child: Text(

                      badge > 99 ? '99+' : '$badge',

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

        ),

      ),

    );

  }

}

class _UserButton extends StatelessWidget {

  final SocialUser user;

  final String name;

  final VoidCallback onPressed;

  const _UserButton({

    required this.user,

    required this.name,

    required this.onPressed,

  });

  @override

  Widget build(BuildContext context) {

    final double screenWidth = MediaQuery.sizeOf(context).width;

    final bool compact = screenWidth < 390;

    return InkWell(

      onTap: onPressed,

      borderRadius: BorderRadius.circular(12),

      child: Container(

        height: 38,

        constraints: BoxConstraints(maxWidth: compact ? 42 : 140),

        padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7),

        decoration: BoxDecoration(

          color: AppColors.brandNightBlue,

          borderRadius: BorderRadius.circular(12),

          border: Border.all(

            color: AppColors.socialSky.withValues(alpha: 0.16),

          ),

        ),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            StudentLabUserAvatar(type: user.type, radius: 12),

            if (!compact) ...[

              const SizedBox(width: 7),

              Flexible(

                child: Text(

                  name,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(

                    color: AppColors.pureWhite,

                    fontSize: 12,

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ),

              const SizedBox(width: 2),

              Icon(

                Icons.keyboard_arrow_down_rounded,

                color: AppColors.socialSky.withValues(alpha: 0.70),

                size: 17,

              ),

            ],

          ],

        ),

      ),

    );

  }

}