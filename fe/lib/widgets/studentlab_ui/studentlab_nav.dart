import 'package:flutter/material.dart';

import '../../theme/studentlab_brand.dart';

import 'package:fe/services/api_service.dart';
import 'package:fe/services/auth_session.dart';
import 'package:fe/social/social_models.dart';
import 'package:fe/social/widgets/studentlab_user_avatar.dart';
import 'package:fe/theme/app_palette.dart';

import 'studentlab_ui.dart';

/// Contatori condivisi di messaggi e notifiche.
///
/// Home, Social e le altre sezioni leggono gli stessi numeri: quando una
/// pagina li aggiorna, tutte le barre si aggiornano insieme.
/// `messages == null` significa "conteggio non disponibile": il badge non compare.
class StudentLabNavCounters extends ChangeNotifier {
  StudentLabNavCounters._();

  static final StudentLabNavCounters instance = StudentLabNavCounters._();

  int _notifications = 0;
  int? _messages;
  bool _loadingNotifications = false;

  int get notifications => _notifications;
  int? get messages => _messages;

  set notifications(int value) {
    final int next = value < 0 ? 0 : value;
    if (next == _notifications) return;
    _notifications = next;
    notifyListeners();
  }

  set messages(int? value) {
    final int? next = value == null ? null : (value < 0 ? 0 : value);
    if (next == _messages) return;
    _messages = next;
    notifyListeners();
  }

  /// Azzera tutto (logout o sessione ospite).
  void clear() {
    if (_notifications == 0 && _messages == null) return;
    _notifications = 0;
    _messages = null;
    notifyListeners();
  }

  /// Legge il numero di notifiche non lette. Chiamate sovrapposte vengono
  /// ignorate; senza sessione il contatore torna a zero.
  Future<int> refreshNotifications([ApiService? api]) async {
    if (!AuthSession.instance.isAuthenticated) {
      clear();
      return 0;
    }
    if (_loadingNotifications) return _notifications;
    _loadingNotifications = true;
    try {
      notifications = await (api ?? ApiService()).getUnreadNotificationCount();
    } catch (_) {
      // Un errore di rete non deve mostrare un numero falso: si tiene l'ultimo valore.
    } finally {
      _loadingNotifications = false;
    }
    return _notifications;
  }
}

/// Colore dell'anello avatar in base al ruolo.
SlTone slRoleTone(SocialUser? user) {
  if (user == null) return SlTone.neutral;
  if (user.isAdmin) return SlTone.warning;
  if (user.isDeveloperSystem) return SlTone.cyan;
  if (user.isTeacher) return SlTone.violet;
  return SlTone.info;
}

/// Etichetta breve del ruolo per la barra.
String slRoleLabel(SocialUser user) {
  if (user.isCreator) return 'Creator';
  if (user.isAdmin) return 'Admin';
  if (user.isDeveloperSystem) return 'Developer';
  if (user.isTeacher) return 'Docente';
  return 'Studente';
}

/// Pulsante icona da 44 px con contatore.
class SlNavIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final int? count;
  final SlTone tone;
  final SlTone badgeTone;
  final bool active;
  final VoidCallback onPressed;
  final Color? borderColorOverride;

  const SlNavIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.count,
    this.tone = SlTone.info,
    this.badgeTone = SlTone.danger,
    this.active = false,
    this.borderColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color color = tone.resolve(p);
    final int value = count ?? 0;
    final bool highlighted = active || value > 0;
    final String label = value > 0 ? '$tooltip, $value non ${value == 1 ? 'letta' : 'lette'}' : tooltip;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: Material(
                  color: highlighted ? color.withValues(alpha: 0.10) : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: highlighted ? color.withValues(alpha: 0.30) : p.pureWhite.withValues(alpha: 0.10),
                    ),
                  ),
                  child: InkWell(
                    onTap: onPressed,
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(icon, size: 21, color: highlighted ? color : p.pureWhite.withValues(alpha: 0.82)),
                  ),
                ),
              ),
              if (value > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: badgeTone.resolve(p),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: borderColorOverride ?? p.eleganceMidnight, width: 2),
                      ),
                      child: Text(
                        value > 99 ? '99+' : '$value',
                        style: SlText.mono(p, size: 11, color: p.darkElegance, weight: FontWeight.w700),
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

/// Azioni Messaggi + Notifiche, da usare in qualsiasi barra.
///
/// ```dart
/// appBar: AppBar(actions: [
///   StudentLabNavActions(onMessages: _openMessages, onNotifications: _openNotifications),
/// ]),
/// ```
class StudentLabNavActions extends StatelessWidget {
  final VoidCallback onMessages;
  final VoidCallback onNotifications;
  final bool notificationsActive;

  /// Colore del fondo su cui sta la barra: serve al bordo dei badge.
  final Color? barColor;

  const StudentLabNavActions({
    super.key,
    required this.onMessages,
    required this.onNotifications,
    this.notificationsActive = false,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final counters = StudentLabNavCounters.instance;
    return ListenableBuilder(
      listenable: counters,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SlNavIconButton(
            tooltip: 'Messaggi',
            icon: Icons.chat_bubble_outline_rounded,
            tone: SlTone.cyan,
            badgeTone: SlTone.cyan,
            count: counters.messages,
            onPressed: onMessages,
            borderColorOverride: barColor,
          ),
          const SizedBox(width: 8),
          SlNavIconButton(
            tooltip: 'Notifiche',
            icon: Icons.notifications_none_rounded,
            tone: SlTone.info,
            badgeTone: SlTone.danger,
            count: counters.notifications,
            active: notificationsActive,
            onPressed: onNotifications,
            borderColorOverride: barColor,
          ),
        ],
      ),
    );
  }
}

/// Avatar con anello colorato in base al ruolo.
class SlRoleAvatar extends StatelessWidget {
  final SocialUser user;
  final double radius;

  const SlRoleAvatar({super.key, required this.user, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: slRoleTone(user).resolve(p), width: 2),
      ),
      child: StudentLabUserAvatar(type: user.type, radius: radius),
    );
  }
}

/// Logo dell'app: icona in riquadro + nome, con sottotitolo facoltativo.
class SlBrandMark extends StatelessWidget {
  final String? subtitle;
  final bool compact;
  final VoidCallback? onPressed;

  const SlBrandMark({super.key, this.subtitle, this.compact = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: onPressed != null,
      label: 'StudentLab',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: p.brandNightBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.skyBlue.withValues(alpha: 0.20)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    StudentLabBrand.logo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, color: p.skyBlue, size: 22),
                  ),
                ),
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('StudentLab',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                      if (subtitle != null && subtitle!.trim().isNotEmpty)
                        Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: SlText.muted(p).copyWith(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsante account: avatar con anello di ruolo, nome e ruolo (solo su schermi larghi).
class SlAccountButton extends StatelessWidget {
  final SocialUser user;
  final String name;
  final VoidCallback onPressed;
  final bool compact;

  const SlAccountButton({
    super.key,
    required this.user,
    required this.name,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (compact) {
      return Semantics(
        button: true,
        label: 'Il tuo account, $name',
        excludeSemantics: true,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 44, height: 44, child: Center(child: SlRoleAvatar(user: user, radius: 17))),
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Il tuo account, $name',
      excludeSemantics: true,
      child: Material(
        color: p.brandNightBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: slRoleTone(user).resolve(p).withValues(alpha: 0.24)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, maxWidth: 240),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SlRoleAvatar(user: user, radius: 15),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          <String>[
                            slRoleLabel(user),
                            if (user.course.trim().isNotEmpty) user.course.trim(),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SlText.muted(p).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: p.pureWhite.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nome breve per la barra: nome proprio, altrimenti il nome completo.
String slDisplayName(SocialUser? user) {
  if (user == null) return 'Utente';
  if (user.firstName.trim().isNotEmpty) return user.firstName.trim();
  if (user.name.trim().isNotEmpty) return user.name.trim();
  return 'Utente';
}

/// Pulsante account dell'ospite: stessa forma di [SlAccountButton], con l'avatar
/// ospite di StudentLab. Su schermi stretti resta solo l'avatar (44 px).
class SlGuestAccountButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool compact;

  const SlGuestAccountButton({super.key, required this.onPressed, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color ring = SlTone.neutral.resolve(p);
    final Widget avatar = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 2)),
      child: StudentLabUserAvatar(radius: compact ? 17 : 15),
    );
    if (compact) {
      return Semantics(
        button: true,
        label: 'Ospite: accedi o registrati',
        excludeSemantics: true,
        child: Tooltip(
          message: 'Ospite · Accedi o registrati',
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(width: 44, height: 44, child: Center(child: avatar)),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Ospite: accedi o registrati',
      excludeSemantics: true,
      child: Material(
        color: p.brandNightBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: ring.withValues(alpha: 0.30)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, maxWidth: 240),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  avatar,
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Ospite',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Accedi o registrati',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.skyBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: p.pureWhite.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsante account per qualsiasi barra: con la sessione mostra avatar, nome e ruolo
/// ([SlAccountButton]); senza, l'avatar ospite ([SlGuestAccountButton]).
/// `compact` = null decide da solo in base alla larghezza (sotto 720 px solo l'avatar).
class StudentLabNavAccount extends StatelessWidget {
  final SocialUser? user;
  final VoidCallback onAccount;
  final VoidCallback onGuest;
  final bool? compact;

  const StudentLabNavAccount({
    super.key,
    required this.user,
    required this.onAccount,
    required this.onGuest,
    this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final bool narrow = compact ?? MediaQuery.sizeOf(context).width < 720;
    final SocialUser? current = user;
    if (current == null) return SlGuestAccountButton(onPressed: onGuest, compact: narrow);
    return SlAccountButton(user: current, name: slDisplayName(current), compact: narrow, onPressed: onAccount);
  }
}
