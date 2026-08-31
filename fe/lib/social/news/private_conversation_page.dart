import 'package:flutter/material.dart';

import '../../services/auth_session.dart';
import '../../services/news_report_api_service.dart';
import '../../services/private_news_messenger.dart';
import '../../theme/nightTheme.dart';
import 'widgets/private_news_widgets.dart';

class PrivateConversationPage extends StatefulWidget {
  const PrivateConversationPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.messenger,
    this.reportApi,
  });

  final int otherUserId;

  final String otherUserName;

  final PrivateNewsMessenger? messenger;

  final NewsReportApiService? reportApi;

  @override
  State<PrivateConversationPage> createState() =>
      _PrivateConversationPageState();
}

class _PrivateConversationPageState extends State<PrivateConversationPage> {
  static const int _limit = 30;

  late final PrivateNewsMessenger _messenger =
      widget.messenger ?? PrivateNewsMessenger();

  late final NewsReportApiService _reportApi =
      widget.reportApi ?? NewsReportApiService();

  final TextEditingController _composer = TextEditingController();

  List<PrivateConversationMessage> _messages = <PrivateConversationMessage>[];

  bool _loading = true;

  bool _loadingMore = false;

  bool _sending = false;

  bool _exhausted = false;

  String? _error;

  int? get _viewerId => AuthSession.instance.currentUserId;

  @override
  void initState() {
    super.initState();

    _load();
  }

  @override
  void dispose() {
    _composer.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _exhausted = false;
    });

    await _messenger.flushPendingDeliveries().catchError(
      (Object _) => 0,
    );

    try {
      final List<PrivateConversationMessage> messages =
          await _messenger.conversation(
        otherUserId: widget.otherUserId,
        limit: _limit,
        offset: 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _exhausted = messages.length < _limit;
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

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _exhausted) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final List<PrivateConversationMessage> older =
          await _messenger.conversation(
        otherUserId: widget.otherUserId,
        limit: _limit,
        offset: _messages.length,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = <PrivateConversationMessage>[..._messages, ...older];
        _exhausted = older.length < _limit;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMore = false;
      });

      _showMessage(privateNewsErrorMessage(error));
    }
  }

  Future<void> _send() async {
    final String text = _composer.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final PrivateConversationMessage sent = await _messenger.send(
        recipientId: widget.otherUserId,
        text: text,
      );

      if (!mounted) {
        return;
      }

      _composer.clear();

      setState(() {
        _messages = <PrivateConversationMessage>[sent, ..._messages];
        _sending = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sending = false;
      });

      _showMessage(privateNewsErrorMessage(error));
    }
  }

  Future<void> _delete(PrivateConversationMessage message) async {
    final bool confirmed = await _confirm(
      title: 'Eliminare il messaggio?',
      message: 'Il messaggio verrà eliminato in modo definitivo.',
      confirmLabel: 'Elimina',
    );

    if (!confirmed) {
      return;
    }

    try {
      await _messenger.delete(
        otherUserId: widget.otherUserId,
        message: message,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = _messages
            .where(
              (PrivateConversationMessage item) => item.id != message.id,
            )
            .toList();
      });

      _showMessage('Messaggio eliminato.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(privateNewsErrorMessage(error));
    }
  }

  Future<void> _report(PrivateConversationMessage message) async {
    if (!message.isReadable) {
      _showMessage(
        'Non è possibile segnalare questo messaggio da questo dispositivo.',
      );

      return;
    }

    final ReportRequest? request = await showDialog<ReportRequest>(
      context: context,
      builder: (BuildContext dialogContext) {
        return const ReportConsentDialog();
      },
    );

    if (request == null) {
      return;
    }

    try {
      final String contentKey = await _messenger.discloseContentKey(message);

      await _reportApi.reportPrivateMessage(
        otherUserId: widget.otherUserId,
        newsId: message.id,
        reason: request.reason,
        disclosedContentKey: contentKey,
        description: request.description,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Segnalazione inviata. I moderatori possono leggere solo questo '
        'messaggio.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(privateNewsErrorMessage(error));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: Text(
            title,
            style: const TextStyle(color: AppColors.pureWhite),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.62),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                confirmLabel,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.brandNightBlue,
      ),
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
        title: Text(widget.otherUserName),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: EncryptedBadge()),
          ),
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildMessages(),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return PrivateNewsStateView(
        icon: Icons.error_outline_rounded,
        title: 'Impossibile caricare la conversazione',
        message: _error!,
        actionLabel: 'Riprova',
        onAction: _load,
      );
    }

    if (_messages.isEmpty) {
      return PrivateNewsStateView(
        icon: Icons.lock_outline_rounded,
        title: 'Nessun messaggio',
        message: 'Scrivi il primo messaggio a ${widget.otherUserName}.',
      );
    }

    final int viewerId = _viewerId ?? 0;

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 220) {
          _loadMore();
        }

        return false;
      },
      child: ListView.separated(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _messages.length + 1,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          if (index == _messages.length) {
            return _loadingMore
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : const SizedBox(height: 6);
          }

          final PrivateConversationMessage message = _messages[index];

          return PrivateMessageCard(
            message: message,
            viewerId: viewerId,
            onDelete: message.canDelete ? () => _delete(message) : null,
            onReport: message.isMine(viewerId) || viewerId == 0
                ? null
                : () => _report(message),
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        border: Border(
          top: BorderSide(
            color: AppColors.skyBlue.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _composer,
              minLines: 1,
              maxLines: 5,
              enabled: !_sending,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(color: AppColors.pureWhite),
              decoration: InputDecoration(
                hintText: 'Scrivi un messaggio',
                hintStyle: TextStyle(
                  color: AppColors.pureWhite.withValues(alpha: 0.42),
                ),
                filled: true,
                fillColor: AppColors.brandNightBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Invia',
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.socialBlue.withValues(alpha: 0.22),
              foregroundColor: AppColors.skyBlue,
              padding: const EdgeInsets.all(14),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
