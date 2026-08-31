import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../theme/nightTheme.dart';

import '../social_models.dart';


class AdminSecurityPage
    extends StatefulWidget {
  const AdminSecurityPage({
    super.key,
  });

  @override
  State<AdminSecurityPage> createState() =>
      _AdminSecurityPageState();
}


class _AdminSecurityPageState
    extends State<AdminSecurityPage> {
  final AuthSession _session =
      AuthSession.instance;


  @override
  void initState() {
    super.initState();

    _session.addListener(
      _onSessionChanged,
    );
  }


  @override
  void dispose() {
    _session.removeListener(
      _onSessionChanged,
    );

    super.dispose();
  }


  void _onSessionChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }


  SocialUser? get _currentUser {
    return _session.currentUser;
  }


  bool get _authenticated {
    return _session.isAuthenticated;
  }


  bool get _guest {
    return _session.isGuest;
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,

      appBar:
          AppBar(
        backgroundColor:
            AppColors.brandNightBlue,

        foregroundColor:
            AppColors.pureWhite,

        elevation:
            0,

        title:
            const Text(
          'Sicurezza',

          style:
              TextStyle(
            fontSize:
                18,

            fontWeight:
                FontWeight.w500,
          ),
        ),
      ),

      body:
          SafeArea(
        child:
            Center(
          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  900,
            ),

            child:
                ListView(
              padding:
                  const EdgeInsets.all(
                20,
              ),

              children: [
                _buildSecurityHeader(),

                const SizedBox(
                  height:
                      24,
                ),

                const _SecuritySectionTitle(
                  title:
                      'Sessione amministratore',

                  subtitle:
                      'Stato della sessione utilizzata per accedere alle funzioni amministrative.',
                ),

                const SizedBox(
                  height:
                      12,
                ),

                _buildSessionCard(),

                const SizedBox(
                  height:
                      24,
                ),

                const _SecuritySectionTitle(
                  title:
                      'Controlli di accesso',

                  subtitle:
                      'Regole che proteggono le principali funzioni riservate della piattaforma.',
                ),

                const SizedBox(
                  height:
                      12,
                ),

                const _SecurityControlCard(
                  icon:
                      Icons.admin_panel_settings_outlined,

                  title:
                      'Area amministrativa',

                  description:
                      'Le operazioni amministrative devono essere autorizzate dal backend tramite il ruolo dell\'utente autenticato.',

                  status:
                      'Protetta',

                  statusType:
                      _SecurityStatusType.secure,
                ),

                const SizedBox(
                  height:
                      10,
                ),

                const _SecurityControlCard(
                  icon:
                      Icons.cast_for_education_outlined,

                  title:
                      'Area docenti',

                  description:
                      'L\'accesso alle funzioni riservate ai docenti deve essere consentito soltanto agli account docente verificati.',

                  status:
                      'Verifica richiesta',

                  statusType:
                      _SecurityStatusType.secure,
                ),

                const SizedBox(
                  height:
                      10,
                ),

                const _SecurityControlCard(
                  icon:
                      Icons.rate_review_outlined,

                  title:
                      'Moderazione recensioni',

                  description:
                      'Approvazione, rifiuto, occultamento e ripristino delle recensioni sono operazioni riservate agli amministratori.',

                  status:
                      'Protetta',

                  statusType:
                      _SecurityStatusType.secure,
                ),

                const SizedBox(
                  height:
                      10,
                ),

                const _SecurityControlCard(
                  icon:
                      Icons.workspace_premium_outlined,

                  title:
                      'Verifica voti',

                  description:
                      'Un voto dichiarato dall\'utente rimane separato da un voto verificato finché un amministratore non completa il controllo.',

                  status:
                      'Moderata',

                  statusType:
                      _SecurityStatusType.secure,
                ),

                const SizedBox(
                  height:
                      10,
                ),

                const _SecurityControlCard(
                  icon:
                      Icons.account_balance_outlined,

                  title:
                      'Percorsi accademici',

                  description:
                      'La verifica di lauree e percorsi accademici è separata dai dati dichiarati direttamente dall\'utente.',

                  status:
                      'Moderata',

                  statusType:
                      _SecurityStatusType.secure,
                ),

                const SizedBox(
                  height:
                      10,
                ),

                const _SecurityControlCard(
                  icon:
                      Icons.manage_accounts_outlined,

                  title:
                      'Stato account',

                  description:
                      'Gli amministratori possono disabilitare gli account tramite lo stato attivo dell\'utente.',

                  status:
                      'Gestibile',

                  statusType:
                      _SecurityStatusType.secure,
                ),

                const SizedBox(
                  height:
                      24,
                ),

                const _SecuritySectionTitle(
                  title:
                      'Principi applicati',

                  subtitle:
                      'Separazione tra interfaccia, autenticazione e autorizzazione.',
                ),

                const SizedBox(
                  height:
                      12,
                ),

                const _SecurityPrinciplesCard(),

                const SizedBox(
                  height:
                      24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSecurityHeader() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        20,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              Colors.greenAccent
                  .withOpacity(
            0.15,
          ),
        ),
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,

        children: [
          Container(
            width:
                58,

            height:
                58,

            decoration:
                BoxDecoration(
              color:
                  Colors.greenAccent
                      .withOpacity(
                0.08,
              ),

              borderRadius:
                  BorderRadius.circular(
                16,
              ),

              border:
                  Border.all(
                color:
                    Colors.greenAccent
                        .withOpacity(
                  0.15,
                ),
              ),
            ),

            child:
                const Icon(
              Icons.shield_outlined,

              color:
                  Colors.greenAccent,

              size:
                  30,
            ),
          ),

          const SizedBox(
            width:
                14,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'Sicurezza StudentLab',

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite,

                    fontSize:
                        18,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                      5,
                ),

                Text(
                  'Controlla lo stato dei principali livelli di autorizzazione della piattaforma.',

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.52,
                    ),

                    fontSize:
                        11,

                    height:
                        1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSessionCard() {
    final SocialUser? user =
        _currentUser;

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        17,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          17,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.10,
          ),
        ),
      ),

      child:
          Column(
        children: [
          _SecurityInfoRow(
            icon:
                Icons.login_rounded,

            label:
                'Autenticazione',

            value:
                _authenticated
                    ? 'Autenticato'
                    : 'Non autenticato',

            positive:
                _authenticated,
          ),

          const SizedBox(
            height:
                12,
          ),

          _SecurityInfoRow(
            icon:
                Icons.person_outline_rounded,

            label:
                'Modalità Guest',

            value:
                _guest
                    ? 'Attiva'
                    : 'Disattivata',

            positive:
                !_guest,
          ),

          const SizedBox(
            height:
                12,
          ),

          _SecurityInfoRow(
            icon:
                Icons.badge_outlined,

            label:
                'Utente',

            value:
                user?.name ??
                    'Nessun utente',

            positive:
                user != null,
          ),

          const SizedBox(
            height:
                12,
          ),

          _SecurityInfoRow(
            icon:
                Icons.email_outlined,

            label:
                'Email',

            value:
                user?.email ??
                    'Non disponibile',

            positive:
                user != null,
          ),

          const SizedBox(
            height:
                12,
          ),

          _SecurityInfoRow(
            icon:
                Icons.toggle_on_outlined,

            label:
                'Account',

            value:
                user == null
                    ? 'Non disponibile'
                    : user.isActive
                        ? 'Attivo'
                        : 'Disabilitato',

            positive:
                user?.isActive ??
                    false,
          ),
        ],
      ),
    );
  }
}


class _SecuritySectionTitle
    extends StatelessWidget {
  final String title;

  final String subtitle;


  const _SecuritySectionTitle({
    required this.title,
    required this.subtitle,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style:
              const TextStyle(
            color:
                AppColors.pureWhite,

            fontSize:
                18,

            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height:
              4,
        ),

        Text(
          subtitle,

          style:
              TextStyle(
            color:
                AppColors.pureWhite
                    .withOpacity(
              0.46,
            ),

            fontSize:
                11,
          ),
        ),
      ],
    );
  }
}


enum _SecurityStatusType {
  secure,
  warning,
  danger,
}


class _SecurityControlCard
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String description;

  final String status;

  final _SecurityStatusType statusType;


  const _SecurityControlCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.statusType,
  });


  Color get _statusColor {
    switch (statusType) {
      case _SecurityStatusType.secure:
        return Colors.greenAccent;

      case _SecurityStatusType.warning:
        return Colors.amber;

      case _SecurityStatusType.danger:
        return Colors.redAccent;
    }
  }


  IconData get _statusIcon {
    switch (statusType) {
      case _SecurityStatusType.secure:
        return Icons
            .check_circle_outline_rounded;

      case _SecurityStatusType.warning:
        return Icons
            .warning_amber_rounded;

      case _SecurityStatusType.danger:
        return Icons.error_outline_rounded;
    }
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    final Color color =
        _statusColor;

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        border:
            Border.all(
          color:
              color.withOpacity(
            0.10,
          ),
        ),
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            width:
                46,

            height:
                46,

            decoration:
                BoxDecoration(
              color:
                  AppColors.brandNightBlue,

              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),

            child:
                Icon(
              icon,

              color:
                  AppColors.skyBlue,

              size:
                  23,
            ),
          ),

          const SizedBox(
            width:
                12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,

                    fontSize:
                        13,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height:
                      5,
                ),

                Text(
                  description,

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.48,
                    ),

                    fontSize:
                        10,

                    height:
                        1.4,
                  ),
                ),

                const SizedBox(
                  height:
                      9,
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        7,

                    vertical:
                        4,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        color.withOpacity(
                      0.07,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      7,
                    ),
                  ),

                  child:
                      Row(
                    mainAxisSize:
                        MainAxisSize.min,

                    children: [
                      Icon(
                        _statusIcon,

                        color:
                            color,

                        size:
                            11,
                      ),

                      const SizedBox(
                        width:
                            4,
                      ),

                      Text(
                        status,

                        style:
                            TextStyle(
                          color:
                              color,

                          fontSize:
                              8,

                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _SecurityInfoRow
    extends StatelessWidget {
  final IconData icon;

  final String label;

  final String value;

  final bool positive;


  const _SecurityInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.positive,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final Color color =
        positive
            ? Colors.greenAccent
            : Colors.orangeAccent;

    return Row(
      children: [
        Container(
          width:
              36,

          height:
              36,

          decoration:
              BoxDecoration(
            color:
                AppColors.brandNightBlue,

            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),

          child:
              Icon(
            icon,

            color:
                AppColors.materialSky,

            size:
                18,
          ),
        ),

        const SizedBox(
          width:
              10,
        ),

        Expanded(
          child:
              Text(
            label,

            style:
                const TextStyle(
              color:
                  Colors.white54,

              fontSize:
                  10,
            ),
          ),
        ),

        const SizedBox(
          width:
              8,
        ),

        Flexible(
          child:
              Text(
            value,

            textAlign:
                TextAlign.right,

            maxLines:
                2,

            overflow:
                TextOverflow.ellipsis,

            style:
                TextStyle(
              color:
                  color,

              fontSize:
                  10,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}


class _SecurityPrinciplesCard
    extends StatelessWidget {
  const _SecurityPrinciplesCard();


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        17,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          17,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.10,
          ),
        ),
      ),

      child:
          const Column(
        children: [
          _SecurityPrinciple(
            icon:
                Icons
                    .verified_user_outlined,

            title:
                'Autorizzazione backend',

            description:
                'Nascondere una funzione nella UI non sostituisce il controllo dei permessi sul server.',
          ),

          SizedBox(
            height:
                14,
          ),

          _SecurityPrinciple(
            icon:
                Icons.key_outlined,

            title:
                'Identità dal token',

            description:
                'Le operazioni protette devono utilizzare l\'utente autenticato identificato dalla sessione e dal JWT.',
          ),

          SizedBox(
            height:
                14,
          ),

          _SecurityPrinciple(
            icon:
                Icons.person_off_outlined,

            title:
                'Guest separato',

            description:
                'La modalità Guest non deve poter utilizzare operazioni che richiedono un account autenticato.',
          ),

          SizedBox(
            height:
                14,
          ),

          _SecurityPrinciple(
            icon:
                Icons
                    .cast_for_education_outlined,

            title:
                'Docenti verificati',

            description:
                'Il ruolo docente dichiarato non è sufficiente: le funzioni privilegiate richiedono la verifica amministrativa.',
          ),

          SizedBox(
            height:
                14,
          ),

          _SecurityPrinciple(
            icon:
                Icons
                    .admin_panel_settings_outlined,

            title:
                'Privilegi amministrativi',

            description:
                'Moderazione e gestione account devono essere autorizzate esclusivamente dal server.',
          ),
        ],
      ),
    );
  }
}


class _SecurityPrinciple
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String description;


  const _SecurityPrinciple({
    required this.icon,
    required this.title,
    required this.description,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Container(
          width:
              38,

          height:
              38,

          decoration:
              BoxDecoration(
            color:
                AppColors.brandNightBlue,

            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),

          child:
              Icon(
            icon,

            color:
                AppColors.skyBlue,

            size:
                19,
          ),
        ),

        const SizedBox(
          width:
              10,
        ),

        Expanded(
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style:
                    const TextStyle(
                  color:
                      AppColors.pureWhite,

                  fontSize:
                      11,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height:
                    4,
              ),

              Text(
                description,

                style:
                    const TextStyle(
                  color:
                      Colors.white54,

                  fontSize:
                      9,

                  height:
                      1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}