import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import 'question_editor_page.dart';
import '../services/question_moderation_service.dart';

class QuestionModerationPage extends StatefulWidget {
  final String? department;
  final String? course;
  final String? subject;
  final Map<String, dynamic>? metadataBase;
  final bool adminMode;

  const QuestionModerationPage.teacher({
    super.key,
    required this.department,
    required this.course,
    required this.subject,
    required this.metadataBase,
  }) : adminMode = false;

  const QuestionModerationPage.admin({super.key})
    : department = null,
      course = null,
      subject = null,
      metadataBase = null,
      adminMode = true;

  @override
  State<QuestionModerationPage> createState() => _QuestionModerationPageState();
}

class _QuestionModerationPageState extends State<QuestionModerationPage> {
  final QuestionModerationService _service = QuestionModerationService();
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _working = false;
  String? _error;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> items = await _service.listItems(
        status: _status,
        department: widget.department,
        course: widget.course,
        subject: widget.subject,
      );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(Object error) {
    String text = error.toString();
    if (text.startsWith('Exception: ')) text = text.substring(11);
    return text.trim().isEmpty ? 'Operazione non riuscita.' : text.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: Text(
          widget.adminMode ? 'Moderazione domande quiz' : 'Revisioni domande',
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _filters(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    const List<MapEntry<String, String>> states = <MapEntry<String, String>>[
      MapEntry<String, String>('pending', 'In attesa'),
      MapEntry<String, String>('under_review', 'In revisione'),
      MapEntry<String, String>('approved', 'Approvate'),
      MapEntry<String, String>('rejected', 'Rifiutate'),
    ];
    return Container(
      width: double.infinity,
      color: AppColors.eleganceDeepNavy,
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: states.map((MapEntry<String, String> item) {
            final bool selected = _status == item.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                label: Text(item.value),
                onSelected: (_) {
                  setState(() => _status = item.key);
                  _load();
                },
                selectedColor: AppColors.brandNightBlue,
                backgroundColor: AppColors.darkElegance,
                labelStyle: TextStyle(color: AppColors.pureWhite),
                side: BorderSide(
                  color: AppColors.skyBlue.withValues(alpha: 0.18),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.redAccent,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.white70),
              ),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: _load, child: const Text('Riprova')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'Nessuna domanda in questo stato.',
          style: TextStyle(color: AppColors.white54),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> item = _items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(item),
          );
        },
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final bool report = item['source_type']?.toString() == 'report';
    final String status = item['status']?.toString() ?? 'pending';
    final dynamic questionRaw = report
        ? item['question']
        : item['proposed_question_payload'];

    final Map<String, dynamic> question = questionRaw is Map
        ? Map<String, dynamic>.from(questionRaw)
        : <String, dynamic>{};
    final Map<String, dynamic> creator = item['created_by_user'] is Map
        ? Map<String, dynamic>.from(item['created_by_user'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> reviewer = item['reviewed_by_user'] is Map
        ? Map<String, dynamic>.from(item['reviewed_by_user'] as Map)
        : <String, dynamic>{};
    final String creatorName =
        '${creator['first_name'] ?? ''} ${creator['last_name'] ?? ''}'.trim();
    final String reviewerName =
        '${reviewer['first_name'] ?? ''} ${reviewer['last_name'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: report
              ? AppColors.redAccent.withValues(alpha: 0.25)
              : AppColors.amber.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _badge(
                report ? 'ERRORE SEGNALATO' : 'PROPOSTA STUDENTE',
                report ? AppColors.redAccent : AppColors.amber,
              ),
              _badge(_statusLabel(status), _statusColor(status)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item['subject']?.toString() ?? '',
            style: TextStyle(
              color: AppColors.skyBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question['text']?.toString().trim().isNotEmpty == true
                ? question['text'].toString()
                : 'Domanda non disponibile',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (report) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Motivo: ${_reasonLabel(item['report_reason']?.toString())}',
              style: TextStyle(color: AppColors.white70, fontSize: 12),
            ),
            if (item['report_message']?.toString().trim().isNotEmpty ==
                true) ...<Widget>[
              const SizedBox(height: 5),
              Text(
                item['report_message'].toString(),
                style: TextStyle(
                  color: AppColors.white60,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Text(
            creatorName.isEmpty
                ? (report
                      ? 'Segnalante non disponibile'
                      : 'Studente non disponibile')
                : '${report ? 'Segnalata da' : 'Proposta da'}: $creatorName',
            style: TextStyle(color: AppColors.white38, fontSize: 10),
          ),
          if (reviewerName.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Revisionata da: $reviewerName${item['reviewer_role'] == null ? '' : ' · ${item['reviewer_role']}'}',
              style: TextStyle(color: AppColors.white38, fontSize: 10),
            ),
          ],
          if (item['resolution_note']?.toString().trim().isNotEmpty ==
              true) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Esito: ${item['resolution_note']}',
              style: TextStyle(color: AppColors.white54, fontSize: 11),
            ),
          ],
          if (status == 'pending' || status == 'under_review') ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : () => _reject(item),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Rifiuta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _working ? null : () => _review(item),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Revisiona'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _review(Map<String, dynamic> rawItem) async {
    final int? id = int.tryParse(rawItem['id']?.toString() ?? '');

    if (id == null) {
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      final Map<String, dynamic> item = await _service.claim(id);

      if (!mounted) {
        return;
      }

      final bool report = item['source_type']?.toString() == 'report';

      final dynamic questionRaw = report
          ? item['question']
          : item['proposed_question_payload'];

      final Map<String, dynamic> question = questionRaw is Map
          ? Map<String, dynamic>.from(questionRaw)
          : <String, dynamic>{};

      if (question.isEmpty) {
        throw Exception('La domanda non è più disponibile.');
      }

      final dynamic metadataRaw = question['metadata'];

      final Map<String, dynamic> metadata = widget.metadataBase != null
          ? Map<String, dynamic>.from(widget.metadataBase!)
          : metadataRaw is Map
          ? Map<String, dynamic>.from(metadataRaw)
          : <String, dynamic>{};

      final Map<String, dynamic>? saved = await Navigator.of(context)
          .push<Map<String, dynamic>>(
            MaterialPageRoute<Map<String, dynamic>>(
              builder: (_) => report
                  ? QuestionEditorPage(
                      department: item['department']?.toString() ?? '',
                      course: item['course']?.toString() ?? '',
                      subject: item['subject']?.toString() ?? '',
                      metadataBase: metadata,
                      question: question,
                    )
                  : QuestionEditorPage.draft(
                      department: item['department']?.toString() ?? '',
                      course: item['course']?.toString() ?? '',
                      subject: item['subject']?.toString() ?? '',
                      metadataBase: metadata,
                      question: question,
                    ),
            ),
          );

      if (!mounted || saved == null) {
        await _load();
        return;
      }

      if (!report) {
        final dynamic payloadRaw = saved['question'];

        if (payloadRaw is! Map) {
          throw Exception('La proposta modificata non è valida.');
        }

        final List<Map<String, dynamic>> newTemporaryAttachments =
            saved['new_temp_attachments'] is List
            ? (saved['new_temp_attachments'] as List)
                  .whereType<Map>()
                  .map((Map value) => Map<String, dynamic>.from(value))
                  .toList()
            : <Map<String, dynamic>>[];

        try {
          await _service.updateProposal(
            itemId: id,
            question: Map<String, dynamic>.from(payloadRaw),
          );
        } catch (_) {
          try {
            await _service.cleanupTemporaryAttachments(newTemporaryAttachments);
          } catch (_) {}
          rethrow;
        }
      }

      final bool approve = await _confirmApproval(proposal: !report);

      if (!approve || !mounted) {
        await _load();
        return;
      }

      await _service.resolve(
        itemId: id,
        status: 'approved',
        resolutionNote: report
            ? 'Domanda revisionata e pubblicata.'
            : 'Proposta revisionata, approvata e pubblicata.',
      );

      if (!mounted) {
        return;
      }

      _message(
        report
            ? 'Domanda revisionata e pubblicata.'
            : 'Proposta approvata e pubblicata.',
      );

      await _load();
    } catch (error) {
      if (mounted) {
        _message(_friendly(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final int? id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;
    final TextEditingController controller = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Text(
          item['source_type']?.toString() == 'proposal'
              ? 'Rifiutare la proposta?'
              : 'Rifiutare la segnalazione?',
          style: TextStyle(color: AppColors.pureWhite),
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          style: TextStyle(color: AppColors.pureWhite),
          decoration: InputDecoration(
            labelText: 'Nota facoltativa',
            labelStyle: TextStyle(color: AppColors.white70),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rifiuta'),
          ),
        ],
      ),
    );
    final String note = controller.text.trim();
    controller.dispose();
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      final bool proposal = item['source_type']?.toString() == 'proposal';

      await _service.resolve(
        itemId: id,
        status: 'rejected',
        resolutionNote: note.isEmpty
            ? proposal
                  ? 'Proposta rifiutata.'
                  : 'Segnalazione rifiutata.'
            : note,
      );

      if (!mounted) {
        return;
      }

      _message(
        proposal
            ? 'Proposta rifiutata. Gli eventuali allegati sono stati rimossi.'
            : 'Segnalazione rifiutata.',
      );
      await _load();
    } catch (error) {
      if (mounted) _message(_friendly(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirmApproval({required bool proposal}) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Text(
          'Approva e pubblica',
          style: TextStyle(color: AppColors.pureWhite),
        ),
        content: Text(
          proposal
              ? 'Vuoi approvare questa proposta e pubblicarla nella banca domande ufficiale? Gli allegati già caricati verranno riutilizzati senza un nuovo upload.'
              : 'Le modifiche sono state salvate. Vuoi chiudere la segnalazione come approvata e pubblicata?',
          style: TextStyle(color: AppColors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Non ancora'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Approva e pubblica'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'under_review':
        return 'IN REVISIONE';
      case 'approved':
        return 'APPROVATA';
      case 'rejected':
        return 'RIFIUTATA';
      default:
        return 'IN ATTESA';
    }
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'under_review':
        return AppColors.blueAccent;
      case 'approved':
        return AppColors.greenAccent;
      case 'rejected':
        return AppColors.white54;
      default:
        return AppColors.amber;
    }
  }

  String _reasonLabel(String? value) {
    switch (value) {
      case 'wrong_correct_answer':
        return 'Risposta corretta errata';
      case 'unclear_question':
        return 'Domanda poco chiara';
      case 'wrong_explanation':
        return 'Spiegazione errata';
      case 'wrong_feedback':
        return 'Feedback errato';
      case 'duplicate_question':
        return 'Domanda duplicata';
      case 'text_error':
        return 'Errore nel testo';
      case 'not_relevant':
        return 'Contenuto non pertinente';
      case 'other':
        return 'Altro';
      default:
        return 'Segnalazione';
    }
  }
}
