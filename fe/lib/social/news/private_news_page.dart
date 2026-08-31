import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../services/private_news_messenger.dart';
import '../../theme/nightTheme.dart';
import '../social_models.dart';
import 'private_conversation_page.dart';
import 'widgets/private_news_widgets.dart';

typedef PrivateNewsRecipientsLoader = Future<List<SocialUser>> Function();

class PrivateNewsConversation {
  const PrivateNewsConversation({
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.messageCount,
  });

  final int otherUserId;

  final String otherUserName;

  final PrivateConversationMessage lastMessage;

  final int messageCount;
}

class PrivateNewsPage extends StatefulWidget {
  const PrivateNewsPage({
    super.key,
    this.messenger,
    this.recipientsLoader,
  });

  final PrivateNewsMessenger? messenger;

  final PrivateNewsRecipientsLoader? recipientsLoader;

  @override
  State<PrivateNewsPage> createState() => _PrivateNewsPageState();
}

class _PrivateNewsPageState extends State<PrivateNewsPage> {
  static const int _limit = 50;

  late final PrivateNewsMessenger _messenger =
      widget.messenger ?? PrivateNewsMessenger();

  late final PrivateNewsRecipientsLoader _recipientsLoader =
      widget.recipientsLoader ?? ApiService().getSocialUsers;

  List<PrivateNewsConversation> _conversations = <PrivateNewsConversation>[];

  bool _loading = true;

  bool _reachable = true;

  String? _error;

  int? get _currentUserId => AuthSession.instance.currentUserId;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    bool reachable = true;

    try {
      await _messenger.ensureReachable();
    } catch (_) {
      reachable = false;
    }

    await _messenger.flushPendingDeliveries().catchError(
      (Object _) => 0,
    );

    try {
      final List<PrivateConversationMessage> messages =
          await _messenger.inbox(
        limit: _limit,
        offset: 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _conversations = _groupByCounterpart(messages);
        _reachable = reachable;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _reachable = reachable;
        _error = privateNewsErrorMessage(error);
        _loading = false;
      });
    }
  }

  List<PrivateNewsConversation> _groupByCounterpart(
    List<PrivateConversationMessage> messages,
  ) {
    final int viewerId = _currentUserId ?? 0;

    if (viewerId == 0) {
      return <PrivateNewsConversation>[];
    }

    final Map<int, List<PrivateConversationMessage>> grouped =
        <int, List<PrivateConversationMessage>>{};

    for (final PrivateConversationMessage message in messages) {
      grouped
          .putIfAbsent(
            message.counterpartId(viewerId),
            () => <PrivateConversationMessage>[],
          )
          .add(message);
    }

    final List<PrivateNewsConversation> conversations = grouped.entries
        .map(
          (MapEntry<int, List<PrivateConversationMessage>> entry) =>
              PrivateNewsConversation(
            otherUserId: entry.key,
            otherUserName: entry.value.first.counterpartName(viewerId),
            lastMessage: entry.value.first,
            messageCount: entry.value.length,
          ),
        )
        .toList();

    conversations.sort(
      (PrivateNewsConversation a, PrivateNewsConversation b) =>
          b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt),
    );

    return conversations;
  }

  Future<void> _openConversation({
    required int otherUserId,
    required String otherUserName,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PrivateConversationPage(
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          messenger: widget.messenger,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _load();
  }

  Future<void> _startConversation() async {
    final SocialUser? recipient = await showModalBottomSheet<SocialUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      builder: (BuildContext sheetContext) {
        return _RecipientPickerSheet(
          loader: _recipientsLoader,
          excludedUserId: _currentUserId ?? 0,
        );
      },
    );

    if (recipient == null || !mounted) {
      return;
    }

    await _openConversation(
      otherUserId: recipient.id,
      otherUserName: '${recipient.firstName} ${recipient.lastName}'.trim(),
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
        title: const Text('Comunicazioni private'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _startConversation,
        backgroundColor: AppColors.socialBlue,
        foregroundColor: AppColors.pureWhite,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Nuovo messaggio'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_reachable && !_loading) _buildUnreachableBanner(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnreachableBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orangeAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.key_off_outlined,
            color: Colors.orangeAccent,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Non è stato possibile completare la configurazione dei '
              'messaggi su questo dispositivo. Riprova.',
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.78),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            onPressed: _load,
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return PrivateNewsStateView(
        icon: Icons.error_outline_rounded,
        title: 'Impossibile caricare le comunicazioni',
        message: _error!,
        actionLabel: 'Riprova',
        onAction: _load,
      );
    }

    if (_conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 110),
            PrivateNewsStateView(
              icon: Icons.lock_outline_rounded,
              title: 'Nessuna comunicazione privata',
              message:
                  'I messaggi sono cifrati end-to-end: solo tu e il '
                  'destinatario potete leggerli. Usa “Nuovo messaggio” per '
                  'iniziare una conversazione.',
            ),
          ],
        ),
      );
    }

    final int viewerId = _currentUserId ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _conversations.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          return _ConversationCard(
            conversation: _conversations[index],
            viewerId: viewerId,
            onOpen: () => _openConversation(
              otherUserId: _conversations[index].otherUserId,
              otherUserName: _conversations[index].otherUserName,
            ),
          );
        },
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.viewerId,
    required this.onOpen,
  });

  final PrivateNewsConversation conversation;

  final int viewerId;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final PrivateConversationMessage last = conversation.lastMessage;

    final String preview = last.isReadable
        ? last.text
        : 'Messaggio non leggibile su questo dispositivo.';

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.eleganceMidnight,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: AppColors.skyBlue.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: AppColors.brandNightBlue,
              child: Text(
                initialsFrom(conversation.otherUserName),
                style: const TextStyle(
                  color: AppColors.skyBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
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
                      Expanded(
                        child: Text(
                          conversation.otherUserName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatPrivateNewsTimestamp(last.createdAt),
                        style: TextStyle(
                          color: AppColors.pureWhite.withValues(alpha: 0.44),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    last.isMine(viewerId) ? 'Tu: $preview' : preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.pureWhite.withValues(
                        alpha: last.isReadable ? 0.70 : 0.42,
                      ),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.skyBlue,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipientPickerSheet extends StatefulWidget {
  const _RecipientPickerSheet({
    required this.loader,
    required this.excludedUserId,
  });

  final PrivateNewsRecipientsLoader loader;

  final int excludedUserId;

  @override
  State<_RecipientPickerSheet> createState() => _RecipientPickerSheetState();
}

class _RecipientPickerSheetState extends State<_RecipientPickerSheet> {
  final TextEditingController _query = TextEditingController();

  List<SocialUser> _users = <SocialUser>[];

  bool _loading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _load();
  }

  @override
  void dispose() {
    _query.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<SocialUser> users = await widget.loader();

      if (!mounted) {
        return;
      }

      setState(() {
        _users = users
            .where(
              (SocialUser user) =>
                  user.id != widget.excludedUserId && user.isActive,
            )
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = privateNewsErrorMessage(error);
        _loading = false;
      });
    }
  }

  List<SocialUser> get _filtered {
    final String needle = _query.text.trim().toLowerCase();

    if (needle.isEmpty) {
      return _users;
    }

    return _users.where((SocialUser user) {
      final String haystack = <String>[
        user.firstName,
        user.lastName,
        user.email,
        user.course,
        user.department,
      ].join(' ').toLowerCase();

      return haystack.contains(needle);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nuovo messaggio privato',
              style: TextStyle(
                color: AppColors.pureWhite,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              style: const TextStyle(color: AppColors.pureWhite),
              onChanged: (String _) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cerca per nome, corso o email',
                hintStyle: TextStyle(
                  color: AppColors.pureWhite.withValues(alpha: 0.42),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.skyBlue,
                ),
                filled: true,
                fillColor: AppColors.brandNightBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return PrivateNewsStateView(
        icon: Icons.error_outline_rounded,
        title: 'Impossibile caricare gli utenti',
        message: _error!,
        actionLabel: 'Riprova',
        onAction: _load,
      );
    }

    final List<SocialUser> users = _filtered;

    if (users.isEmpty) {
      return const PrivateNewsStateView(
        icon: Icons.person_search_outlined,
        title: 'Nessun utente trovato',
        message: 'Prova con un altro nome, corso o indirizzo email.',
      );
    }

    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final SocialUser user = users[index];
        final String name = '${user.firstName} ${user.lastName}'.trim();

        return ListTile(
          onTap: () => Navigator.pop(context, user),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: CircleAvatar(
            backgroundColor: AppColors.brandNightBlue,
            child: Text(
              initialsFrom(name),
              style: const TextStyle(
                color: AppColors.skyBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          title: Text(
            name.isEmpty ? user.email : name,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            <String>[user.course, user.department]
                .where((String value) => value.trim().isNotEmpty)
                .join(' · '),
            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.52),
              fontSize: 11,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.skyBlue,
          ),
        );
      },
    );
  }
}
