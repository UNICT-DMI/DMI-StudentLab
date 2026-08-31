import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/nightTheme.dart';
import '../social_models.dart';

enum ContactRequestType { general, help, privateLesson }

class ContactUserPage extends StatefulWidget {
  final SocialUser user;

  const ContactUserPage({super.key, required this.user});

  @override
  State<ContactUserPage> createState() => _ContactUserPageState();
}

class _ContactUserPageState extends State<ContactUserPage> {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  ContactRequestType _requestType = ContactRequestType.general;
  int? _selectedSubjectId;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestType = _initialRequestType();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  ContactRequestType _initialRequestType() {
    if (widget.user.available) return ContactRequestType.general;
    if (widget.user.availableForHelp) return ContactRequestType.help;
    if (widget.user.availableForPrivateLessons) {
      return ContactRequestType.privateLesson;
    }
    return ContactRequestType.general;
  }

  List<SocialSubject> get _availableSubjects {
    switch (_requestType) {
      case ContactRequestType.help:
        return widget.user.subjects
            .where((subject) => subject.canHelp)
            .toList();
      case ContactRequestType.privateLesson:
        return widget.user.subjects
            .where((subject) => subject.canGivePrivateLessons)
            .toList();
      case ContactRequestType.general:
        return const [];
    }
  }

  bool get _requiresSubject =>
      _requestType == ContactRequestType.help ||
      _requestType == ContactRequestType.privateLesson;

  bool get _requestAvailable {
    switch (_requestType) {
      case ContactRequestType.general:
        return widget.user.available;
      case ContactRequestType.help:
        return widget.user.availableForHelp;
      case ContactRequestType.privateLesson:
        return widget.user.availableForPrivateLessons;
    }
  }

  bool get _hasAnyContactOption =>
      widget.user.available ||
      widget.user.availableForHelp ||
      widget.user.availableForPrivateLessons;

  SocialSubject? get _selectedSubject {
    final int? id = _selectedSubjectId;
    if (id == null) return null;

    for (final SocialSubject subject in _availableSubjects) {
      if (subject.id == id) return subject;
    }

    return null;
  }

  String get _requestTypeLabel {
    switch (_requestType) {
      case ContactRequestType.general:
        return 'Messaggio generico';
      case ContactRequestType.help:
        return 'Richiesta di aiuto';
      case ContactRequestType.privateLesson:
        return 'Lezione privata';
    }
  }

  String get _requestTypeApiValue {
    switch (_requestType) {
      case ContactRequestType.general:
        return 'general';
      case ContactRequestType.help:
        return 'help';
      case ContactRequestType.privateLesson:
        return 'private_lesson';
    }
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
          'Contatta',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildUserHeader(),
                  const SizedBox(height: 18),
                  _buildPrivacyInfo(),
                  const SizedBox(height: 24),
                  if (!_hasAnyContactOption)
                    _buildUnavailableState()
                  else ...[
                    _buildSectionTitle(
                      'Tipo di richiesta',
                      'Scegli come vuoi contattare ${widget.user.name}.',
                    ),
                    const SizedBox(height: 12),
                    _buildRequestTypes(),
                    if (_requiresSubject) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        'Materia',
                        'Seleziona una materia per cui l’utente ha dichiarato disponibilità.',
                      ),
                      const SizedBox(height: 12),
                      _buildSubjectSelector(),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      'Messaggio',
                      'StudentLab inoltrerà la richiesta senza mostrare l’indirizzo email del destinatario.',
                    ),
                    const SizedBox(height: 12),
                    _buildMessageCard(),
                    const SizedBox(height: 20),
                    _buildSummary(),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _buildError(),
                    ],
                    const SizedBox(height: 22),
                    _buildSendButton(),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    final bool isTeacher = widget.user.type == SocialUserType.teacher;
    final Color roleColor = isTeacher
        ? AppColors.teacherIndigo
        : AppColors.studentBlue;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: roleColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: roleColor,
            child: Text(
              _initial(),
              style: const TextStyle(
                color: AppColors.pureWhite,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isTeacher && widget.user.isVerifiedTeacher) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.verified_rounded,
                        color: Colors.greenAccent,
                        size: 15,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isTeacher
                      ? (widget.user.isVerifiedTeacher
                            ? 'Docente verificato'
                            : 'Docente')
                      : 'Studente',
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.user.course.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.user.course.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.pureWhite.withValues(alpha: 0.45),
                      fontSize: 10,
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

  Widget _buildPrivacyInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.skyBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.privacy_tip_outlined,
            color: AppColors.materialSky,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'StudentLab non mostra l’indirizzo email del destinatario. '
              'La richiesta viene inviata tramite il servizio StudentLab e il '
              'destinatario potrà risponderti usando l’indirizzo di risposta '
              'associato alla richiesta.',
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.58),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.contact_mail_outlined,
            color: Colors.orangeAccent,
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text(
            'Contatto non disponibile',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Questo utente non ha attivato al momento nessuna modalità di contatto.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.50),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.pureWhite,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.pureWhite.withValues(alpha: 0.46),
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestTypes() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _RequestTypeTile(
            icon: Icons.mail_outline_rounded,
            title: 'Messaggio generico',
            description: 'Contatta l’utente per una richiesta generale.',
            selected: _requestType == ContactRequestType.general,
            enabled: widget.user.available,
            onTap: () => _changeRequestType(ContactRequestType.general),
          ),
          const SizedBox(height: 8),
          _RequestTypeTile(
            icon: Icons.volunteer_activism_outlined,
            title: 'Richiesta di aiuto',
            description:
                'Chiedi supporto su una materia in cui l’utente ha dichiarato disponibilità.',
            selected: _requestType == ContactRequestType.help,
            enabled: widget.user.availableForHelp,
            onTap: () => _changeRequestType(ContactRequestType.help),
          ),
          const SizedBox(height: 8),
          _RequestTypeTile(
            icon: Icons.cast_for_education_outlined,
            title: 'Lezione privata',
            description:
                'Richiedi una lezione su una materia per cui l’utente offre questa disponibilità.',
            selected: _requestType == ContactRequestType.privateLesson,
            enabled: widget.user.availableForPrivateLessons,
            onTap: () => _changeRequestType(ContactRequestType.privateLesson),
          ),
        ],
      ),
    );
  }

  void _changeRequestType(ContactRequestType type) {
    if (_sending) return;

    final bool enabled = switch (type) {
      ContactRequestType.general => widget.user.available,
      ContactRequestType.help => widget.user.availableForHelp,
      ContactRequestType.privateLesson =>
        widget.user.availableForPrivateLessons,
    };

    if (!enabled) {
      _showMessage('L’utente non è disponibile per questo tipo di richiesta.');
      return;
    }

    setState(() {
      _requestType = type;
      _selectedSubjectId = null;
      _error = null;
    });
  }

  Widget _buildSubjectSelector() {
    final List<SocialSubject> subjects = _availableSubjects;

    if (subjects.isEmpty) {
      return const _InfoState(
        message:
            'Non risultano materie disponibili per questo tipo di richiesta.',
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _selectedSubjectId,
      isExpanded: true,
      dropdownColor: AppColors.eleganceDeepNavy,
      decoration: const InputDecoration(
        labelText: 'Materia',
        prefixIcon: Icon(Icons.menu_book_outlined, color: AppColors.skyBlue),
      ),
      validator: (int? value) {
        if (_requiresSubject && value == null) {
          return 'Seleziona una materia';
        }

        if (value != null && !subjects.any((subject) => subject.id == value)) {
          return 'La materia selezionata non è disponibile';
        }

        return null;
      },
      items: subjects
          .map(
            (subject) => DropdownMenuItem<int>(
              value: subject.id,
              child: Text(
                subject.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.pureWhite),
              ),
            ),
          )
          .toList(),
      onChanged: _sending
          ? null
          : (int? value) {
              setState(() {
                _selectedSubjectId = value;
                _error = null;
              });
            },
    );
  }

  Widget _buildMessageCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _subjectController,
            enabled: !_sending,
            maxLength: 160,
            textInputAction: TextInputAction.next,
            autocorrect: true,
            enableSuggestions: true,
            style: const TextStyle(color: AppColors.pureWhite),
            validator: (String? value) {
              final String text = _normalizeSingleLine(value);

              if (text.isEmpty) return 'Inserisci l’oggetto';

              if (value != null &&
                  (value.contains('\n') || value.contains('\r'))) {
                return 'L’oggetto non è valido';
              }

              if (text.length > 160) return 'L’oggetto è troppo lungo';

              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Oggetto',
              hintText: 'Es. Aiuto con gli esercizi',
              prefixIcon: Icon(Icons.subject_rounded, color: AppColors.skyBlue),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _messageController,
            enabled: !_sending,
            minLines: 5,
            maxLines: 8,
            maxLength: 5000,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            autocorrect: true,
            enableSuggestions: true,
            style: const TextStyle(color: AppColors.pureWhite),
            validator: (String? value) {
              final String text = value?.trim() ?? '';

              if (text.isEmpty) return 'Inserisci un messaggio';
              if (text.length > 5000) return 'Il messaggio è troppo lungo';

              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Messaggio',
              hintText: 'Scrivi il tuo messaggio...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riepilogo',
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Destinatario', value: widget.user.name),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Richiesta', value: _requestTypeLabel),
          if (_requiresSubject) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Materia',
              value: _selectedSubject?.name ?? 'Non selezionata',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _sending || !_requestAvailable ? null : _send,
        icon: _sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_rounded),
        label: Text(_sending ? 'Invio...' : 'Invia richiesta'),
      ),
    );
  }

  Future<void> _send() async {
    if (_sending) return;

    FocusScope.of(context).unfocus();

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (!_requestAvailable) {
      _showMessage('L’utente non è disponibile per questo tipo di richiesta.');
      return;
    }

    if (_requiresSubject && _selectedSubject == null) {
      _showMessage('Seleziona una materia disponibile.');
      return;
    }

    final String normalizedSubject = _normalizeSingleLine(
      _subjectController.text,
    );
    final String normalizedMessage = _messageController.text.trim();

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _authService.contactUser(
        userId: widget.user.id,
        requestType: _requestTypeApiValue,
        subjectId: _selectedSubjectId,
        subject: normalizedSubject,
        message: normalizedMessage,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Richiesta inviata correttamente.')),
        );

      Navigator.of(context).pop(true);
      return;
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _sending = false;
        _error = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    final String value = error.toString().toLowerCase();

    if (value.contains('401') ||
        value.contains('non autenticato') ||
        value.contains('sessione')) {
      return 'La sessione non è più valida. Accedi nuovamente.';
    }

    if (value.contains('403') ||
        value.contains('non puoi contattare') ||
        value.contains('non è possibile contattare') ||
        value.contains('blocc')) {
      return 'Non è possibile contattare questo utente.';
    }

    if (value.contains('404') ||
        value.contains('utente non disponibile') ||
        value.contains('non è disponibile')) {
      return 'L’utente non è più disponibile.';
    }

    if (value.contains('429') ||
        value.contains('troppe richieste') ||
        value.contains('rate limit')) {
      return 'Hai inviato troppe richieste. Riprova più tardi.';
    }

    if (value.contains('timeout')) {
      return 'La richiesta sta impiegando troppo tempo. Riprova.';
    }

    if (value.contains('network') ||
        value.contains('socket') ||
        value.contains('connection') ||
        value.contains('host lookup') ||
        value.contains('failed host lookup')) {
      return 'Non è stato possibile connettersi a StudentLab. '
          'Controlla la connessione e riprova.';
    }

    if (value.contains('503') ||
        value.contains('servizio email') ||
        value.contains('email service')) {
      return 'Il servizio di invio non è temporaneamente disponibile. '
          'Riprova tra qualche momento.';
    }

    if (value.contains('400') ||
        value.contains('materia') ||
        value.contains('oggetto') ||
        value.contains('messaggio')) {
      return 'Controlla i dati inseriti e riprova.';
    }

    return 'Non è stato possibile inviare la richiesta. Riprova.';
  }

  String _normalizeSingleLine(String? value) {
    return (value ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  String _initial() {
    final String name = widget.user.name.trim();
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RequestTypeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RequestTypeTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandNightBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.skyBlue.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.skyBlue : Colors.white54,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      enabled ? description : 'Non disponibile sul profilo.',
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.43),
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.skyBlue : Colors.white30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

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
              color: AppColors.pureWhite.withValues(alpha: 0.42),
              fontSize: 10,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoState extends StatelessWidget {
  final String message;

  const _InfoState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.orangeAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.58),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
