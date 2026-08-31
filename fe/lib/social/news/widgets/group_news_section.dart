import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../theme/nightTheme.dart';
import '../../groups/models/study_group.dart';
import '../../social_models.dart';
import '../models/group_news.dart';

class GroupNewsSection extends StatefulWidget {
  final StudyGroup group;
  final List<SocialUser> participants;
  final int? currentUserId;
  final bool isAuthenticated;
  final bool isCurrentUserMember;

  const GroupNewsSection({
    super.key,
    required this.group,
    required this.participants,
    required this.currentUserId,
    required this.isAuthenticated,
    required this.isCurrentUserMember,
  });

  @override
  State<GroupNewsSection> createState() =>
      _GroupNewsSectionState();
}

class _GroupNewsSectionState extends State<GroupNewsSection> {
  final ApiService _apiService = ApiService();

  List<GroupNews> _items = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int _total = 0;
  int _offset = 0;

  static const int _limit = 30;

  bool get _canRead =>
      widget.isAuthenticated && widget.isCurrentUserMember;

  bool get _canPublishGroup =>
      _canRead && widget.group.canPublishNews;

  bool get _canSendPrivate =>
      _canRead && _otherParticipants.isNotEmpty;

  List<SocialUser> get _otherParticipants {
    final int? currentUserId = widget.currentUserId;

    return widget.participants
        .where(
          (SocialUser user) =>
              currentUserId == null || user.id != currentUserId,
        )
        .toList()
      ..sort(
        (SocialUser a, SocialUser b) =>
            a.name.toLowerCase().compareTo(
                  b.name.toLowerCase(),
                ),
      );
  }

  @override
  void initState() {
    super.initState();

    if (_canRead) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(
    covariant GroupNewsSection oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (
      oldWidget.group.id != widget.group.id ||
      oldWidget.currentUserId != widget.currentUserId ||
      oldWidget.isCurrentUserMember != widget.isCurrentUserMember
    ) {
      if (_canRead) {
        _load();
      } else {
        setState(() {
          _items = [];
          _total = 0;
          _offset = 0;
          _loading = false;
          _error = null;
        });
      }
    }
  }

  Future<void> _load() async {
    if (!_canRead || !mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
    });

    try {
      final GroupNewsFeedResult result =
          await _apiService.getGroupNews(
        groupId: widget.group.id,
        limit: _limit,
        offset: 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items = result.items;
        _total = result.total;
        _offset = result.items.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (
      !_canRead ||
      _loading ||
      _sending ||
      _items.length >= _total
    ) {
      return;
    }

    try {
      final GroupNewsFeedResult result =
          await _apiService.getGroupNews(
        groupId: widget.group.id,
        limit: _limit,
        offset: _offset,
      );

      if (!mounted) {
        return;
      }

      final Map<int, GroupNews> merged = {
        for (final GroupNews item in _items) item.id: item,
      };

      for (final GroupNews item in result.items) {
        merged[item.id] = item;
      }

      final List<GroupNews> values = merged.values.toList()
        ..sort(
          (GroupNews a, GroupNews b) =>
              b.createdAt.compareTo(a.createdAt),
        );

      setState(() {
        _items = values;
        _total = result.total;
        _offset = result.offset + result.items.length;
      });
    } catch (e) {
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> _compose() async {
    if (!_canRead || _sending) {
      return;
    }

    final _ComposeResult? result =
        await showModalBottomSheet<_ComposeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (_) => _ComposeNewsSheet(
        canPublishGroup: _canPublishGroup,
        canSendPrivate: _canSendPrivate,
        participants: _otherParticipants,
      ),
    );

    if (result == null) {
      return;
    }

    await _send(
      content: result.content,
      private: result.private,
      recipientUserId: result.recipientUserId,
    );
  }

  Future<void> _send({
    required String content,
    required bool private,
    int? recipientUserId,
    int? parentNewsId,
  }) async {
    if (_sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _apiService.createGroupNews(
        groupId: widget.group.id,
        content: content,
        visibility: private ? 'private' : 'group',
        recipientUserId: private ? recipientUserId : null,
        parentNewsId: parentNewsId,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        private
            ? 'Comunicazione privata inviata.'
            : 'News pubblicata nel gruppo.',
      );

      await _load();
    } catch (e) {
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _reply(GroupNews news) async {
    if (!news.canReply) {
      _showMessage(
        'Non è possibile rispondere a questa comunicazione.',
      );
      return;
    }

    final TextEditingController controller =
        TextEditingController();

    final String? content = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            18 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Rispondi',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 5000,
                style: const TextStyle(
                  color: AppColors.pureWhite,
                ),
                decoration: const InputDecoration(
                  hintText: 'Scrivi una risposta...',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  final String value = controller.text.trim();

                  if (value.isEmpty) {
                    return;
                  }

                  Navigator.pop(sheetContext, value);
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Invia risposta'),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();

    if (content == null || content.trim().isEmpty) {
      return;
    }

    if (news.isPrivate) {
      final int? currentUserId = widget.currentUserId;
      final int? recipientUserId =
          currentUserId == news.authorUserId
              ? news.recipientUserId
              : news.authorUserId;

      if (recipientUserId == null) {
        _showMessage(
          'Il destinatario non è più disponibile.',
        );
        return;
      }

      await _send(
        content: content,
        private: true,
        recipientUserId: recipientUserId,
        parentNewsId: news.id,
      );
      return;
    }

    if (!_canPublishGroup) {
      _showMessage(
        'Non hai il permesso di pubblicare news nel gruppo.',
      );
      return;
    }

    await _send(
      content: content,
      private: false,
      parentNewsId: news.id,
    );
  }

  Future<void> _delete(GroupNews news) async {
    final bool confirmed = await _confirm(
      title: 'Elimina news',
      message:
          'Vuoi eliminare questa news? Non sarà più disponibile nel feed.',
      confirmLabel: 'Elimina',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    try {
      await _apiService.deleteGroupNews(news.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _items.removeWhere(
          (GroupNews item) => item.id == news.id,
        );

        if (_total > 0) {
          _total--;
        }
      });

      _showMessage('News eliminata.');
    } catch (e) {
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> _moderate(GroupNews news) async {
    final TextEditingController controller =
        TextEditingController();

    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        String? error;

        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            return AlertDialog(
              backgroundColor: AppColors.eleganceDeepNavy,
              title: const Text(
                'Rimuovi news',
                style: TextStyle(
                  color: AppColors.pureWhite,
                ),
              ),
              content: TextField(
                controller: controller,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                style: const TextStyle(
                  color: AppColors.pureWhite,
                ),
                decoration: InputDecoration(
                  labelText: 'Motivo',
                  errorText: error,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Annulla'),
                ),
                TextButton(
                  onPressed: () {
                    final String value =
                        controller.text.trim();

                    if (value.isEmpty) {
                      setDialogState(() {
                        error = 'Inserisci il motivo';
                      });
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      value,
                    );
                  },
                  child: const Text(
                    'Rimuovi',
                    style: TextStyle(
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    try {
      await _apiService.moderateGroupNews(
        newsId: news.id,
        reason: reason,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items.removeWhere(
          (GroupNews item) => item.id == news.id,
        );

        if (_total > 0) {
          _total--;
        }
      });

      _showMessage('News rimossa dal gruppo.');
    } catch (e) {
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> _report(GroupNews news) async {
    final _ReportResult? result =
        await showModalBottomSheet<_ReportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (_) => const _ReportSheet(),
    );

    if (result == null) {
      return;
    }

    try {
      await _apiService.createGroupNewsReport(
        newsId: news.id,
        reason: result.reason,
        description: result.description,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Segnalazione inviata ai moderatori.',
      );
    } catch (e) {
      _showMessage(_friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.skyBlue.withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                child: const Icon(
                  Icons.newspaper_rounded,
                  color: AppColors.skyBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'News del gruppo',
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Aggiornamenti del gruppo e comunicazioni private.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (_canRead)
                IconButton(
                  tooltip: 'Aggiorna news',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white60,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!_canRead)
            _buildUnavailable()
          else if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _buildError()
          else ...[
            if (_canPublishGroup || _canSendPrivate) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _compose,
                  icon: _sending
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.edit_note_rounded),
                  label: Text(
                    _sending
                        ? 'Invio...'
                        : 'Nuova comunicazione',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.socialBlue,
                    foregroundColor: AppColors.pureWhite,
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_items.isEmpty)
              _buildEmpty()
            else
              ..._items.map(
                (GroupNews news) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GroupNewsCard(
                    news: news,
                    currentUserId: widget.currentUserId,
                    onReply:
                        news.canReply ? () => _reply(news) : null,
                    onDelete:
                        news.canDelete ? () => _delete(news) : null,
                    onModerate:
                        news.canModerate && !news.isPrivate
                            ? () => _moderate(news)
                            : null,
                    onReport:
                        news.canReport ? () => _report(news) : null,
                  ),
                ),
              ),
            if (_items.length < _total)
              OutlinedButton(
                onPressed: _loadMore,
                child: const Text('Carica altre news'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnavailable() {
    final String message = !widget.isAuthenticated
        ? 'Accedi a StudentLab per vedere le news riservate del gruppo.'
        : 'Le news sono disponibili ai partecipanti del gruppo.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          color: Colors.white38,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: AppColors.pureWhite.withValues(
                alpha: 0.48,
              ),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.pureWhite.withValues(
              alpha: 0.55,
            ),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Riprova'),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 18,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.newspaper_outlined,
            color: Colors.white30,
            size: 38,
          ),
          const SizedBox(height: 9),
          const Text(
            'Nessuna news',
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _canPublishGroup
                ? 'Pubblica il primo aggiornamento del gruppo.'
                : 'Non ci sono ancora comunicazioni disponibili.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.pureWhite.withValues(
                alpha: 0.42,
              ),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.pureWhite,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: AppColors.pureWhite.withValues(
                alpha: 0.62,
              ),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: Text(
                confirmLabel,
                style: TextStyle(
                  color: destructive
                      ? Colors.redAccent
                      : AppColors.skyBlue,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  String _friendlyError(Object error) {
    final String value = error.toString().toLowerCase();

    if (
      value.contains('401') ||
      value.contains('unauthorized')
    ) {
      return 'La sessione non è più valida. Accedi nuovamente.';
    }

    if (
      value.contains('403') ||
      value.contains('forbidden')
    ) {
      return 'Non hai i permessi necessari per questa operazione.';
    }

    if (
      value.contains('404') ||
      value.contains('not found')
    ) {
      return 'La news o il gruppo non sono più disponibili.';
    }

    if (
      value.contains('socket') ||
      value.contains('connection') ||
      value.contains('network') ||
      value.contains('host lookup')
    ) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    return 'Non è stato possibile completare l’operazione. Riprova.';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

class _GroupNewsCard extends StatelessWidget {
  final GroupNews news;
  final int? currentUserId;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final VoidCallback? onModerate;
  final VoidCallback? onReport;

  const _GroupNewsCard({
    required this.news,
    required this.currentUserId,
    required this.onReply,
    required this.onDelete,
    required this.onModerate,
    required this.onReport,
  });

  bool get _isMine =>
      currentUserId != null &&
      news.authorUserId == currentUserId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.brandNightBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: news.isPrivate
              ? AppColors.materialSky.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.eleganceDeepNavy,
                child: Text(
                  _initials(news.author.fullName),
                  style: const TextStyle(
                    color: AppColors.skyBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.author.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _NewsBadge(
                          icon: news.isPrivate
                              ? Icons.lock_outline_rounded
                              : Icons.groups_outlined,
                          label: news.isPrivate
                              ? 'Privato'
                              : 'Gruppo',
                        ),
                        if (news.author.isVerifiedTeacher)
                          const _NewsBadge(
                            icon: Icons.verified_rounded,
                            label: 'Docente verificato',
                          ),
                        if (_isMine)
                          const _NewsBadge(
                            icon: Icons.person_outline_rounded,
                            label: 'Tu',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (
                onDelete != null ||
                onModerate != null ||
                onReport != null
              )
                PopupMenuButton<String>(
                  tooltip: 'Azioni',
                  color: AppColors.eleganceDeepNavy,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white54,
                  ),
                  onSelected: (String value) {
                    if (value == 'delete') {
                      onDelete?.call();
                    } else if (value == 'moderate') {
                      onModerate?.call();
                    } else if (value == 'report') {
                      onReport?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    if (onReport != null)
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Segnala'),
                      ),
                    if (onModerate != null)
                      const PopupMenuItem(
                        value: 'moderate',
                        child: Text('Rimuovi dal gruppo'),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Elimina',
                          style: TextStyle(
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            news.content,
            style: TextStyle(
              color: AppColors.pureWhite.withValues(
                alpha: 0.82,
              ),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _formatDate(news.createdAt),
                style: TextStyle(
                  color: AppColors.pureWhite.withValues(
                    alpha: 0.34,
                  ),
                  fontSize: 9,
                ),
              ),
              const Spacer(),
              if (onReply != null)
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(
                    Icons.reply_rounded,
                    size: 16,
                  ),
                  label: const Text('Rispondi'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String value) => value.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'S';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _formatDate(DateTime date) {
    final DateTime local = date.toLocal();
    final DateTime now = DateTime.now();

    if (
      now.year == local.year &&
      now.month == local.month &&
      now.day == local.day
    ) {
      return 'Oggi '
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

class _ComposeNewsSheet extends StatefulWidget {
  final bool canPublishGroup;
  final bool canSendPrivate;
  final List<SocialUser> participants;

  const _ComposeNewsSheet({
    required this.canPublishGroup,
    required this.canSendPrivate,
    required this.participants,
  });

  @override
  State<_ComposeNewsSheet> createState() =>
      _ComposeNewsSheetState();
}

class _ComposeNewsSheetState extends State<_ComposeNewsSheet> {
  final TextEditingController _controller =
      TextEditingController();

  bool _private = false;
  int? _recipientUserId;
  String? _error;

  @override
  void initState() {
    super.initState();

    if (!widget.canPublishGroup && widget.canSendPrivate) {
      _private = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nuova comunicazione',
              style: TextStyle(
                color: AppColors.pureWhite,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (
              widget.canPublishGroup &&
              widget.canSendPrivate
            )
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.groups_outlined),
                    label: Text('Gruppo'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.lock_outline_rounded),
                    label: Text('Privata'),
                  ),
                ],
                selected: {_private},
                onSelectionChanged: (Set<bool> value) {
                  setState(() {
                    _private = value.first;

                    if (!_private) {
                      _recipientUserId = null;
                    }
                  });
                },
              ),
            if (_private) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _recipientUserId,
                isExpanded: true,
                dropdownColor: AppColors.eleganceDeepNavy,
                decoration: const InputDecoration(
                  labelText: 'Destinatario',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                  ),
                ),
                items: widget.participants
                    .map(
                      (SocialUser user) =>
                          DropdownMenuItem<int>(
                        value: user.id,
                        child: Text(
                          user.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.pureWhite,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (int? value) {
                  setState(() {
                    _recipientUserId = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 5000,
              style: const TextStyle(
                color: AppColors.pureWhite,
              ),
              decoration: InputDecoration(
                hintText: _private
                    ? 'Scrivi una comunicazione privata...'
                    : 'Scrivi una news per il gruppo...',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                final String content =
                    _controller.text.trim();

                if (content.isEmpty) {
                  setState(() {
                    _error = 'Scrivi il contenuto prima di inviare.';
                  });
                  return;
                }

                if (_private && _recipientUserId == null) {
                  setState(() {
                    _error = 'Seleziona il destinatario.';
                  });
                  return;
                }

                Navigator.pop(
                  context,
                  _ComposeResult(
                    content: content,
                    private: _private,
                    recipientUserId: _recipientUserId,
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: Text(
                _private
                    ? 'Invia in privato'
                    : 'Pubblica nel gruppo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() =>
      _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final TextEditingController _controller =
      TextEditingController();

  String _reason = 'spam';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Segnala news',
              style: TextStyle(
                color: AppColors.pureWhite,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _reason,
              dropdownColor: AppColors.eleganceDeepNavy,
              items: const [
                DropdownMenuItem(
                  value: 'spam',
                  child: Text('Spam'),
                ),
                DropdownMenuItem(
                  value: 'harassment',
                  child: Text('Molestie o comportamento offensivo'),
                ),
                DropdownMenuItem(
                  value: 'hate',
                  child: Text('Contenuto discriminatorio'),
                ),
                DropdownMenuItem(
                  value: 'privacy',
                  child: Text('Violazione della privacy'),
                ),
                DropdownMenuItem(
                  value: 'illegal_content',
                  child: Text('Contenuto illecito'),
                ),
                DropdownMenuItem(
                  value: 'other',
                  child: Text('Altro'),
                ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _reason = value;
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              style: const TextStyle(
                color: AppColors.pureWhite,
              ),
              decoration: const InputDecoration(
                labelText: 'Dettagli facoltativi',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _ReportResult(
                    reason: _reason,
                    description: _controller.text.trim(),
                  ),
                );
              },
              child: const Text('Invia segnalazione'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _NewsBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.skyBlue.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: AppColors.materialSky,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.materialSky,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeResult {
  final String content;
  final bool private;
  final int? recipientUserId;

  const _ComposeResult({
    required this.content,
    required this.private,
    required this.recipientUserId,
  });
}

class _ReportResult {
  final String reason;
  final String description;

  const _ReportResult({
    required this.reason,
    required this.description,
  });
}