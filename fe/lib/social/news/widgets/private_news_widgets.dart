import 'package:flutter/material.dart';

import '../../../services/news_report_api_service.dart';
import '../../../services/private_news_crypto.dart';
import '../../../services/private_news_messenger.dart';
import '../../../theme/nightTheme.dart';
import '../models/news_report.dart';

String privateNewsErrorMessage(Object error) {
  if (error is PrivateNewsCryptoException) {
    return error.message;
  }

  if (error is StateError) {
    return error.message;
  }

  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Richiesta non valida.';
  }

  return 'Operazione non riuscita. Riprova più tardi.';
}

String formatPrivateNewsTimestamp(DateTime value) {
  final String day = value.day.toString().padLeft(2, '0');
  final String month = value.month.toString().padLeft(2, '0');
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');

  return '$day/$month/${value.year} $hour:$minute';
}

String initialsFrom(String value) {
  final List<String> parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return '?';
  }

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
      .toUpperCase();
}

class PrivateMessageCard extends StatelessWidget {
  const PrivateMessageCard({
    super.key,
    required this.message,
    required this.viewerId,
    this.onReply,
    this.onDelete,
    this.onReport,
  });

  final PrivateConversationMessage message;
  final int viewerId;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final bool mine = message.isMine(viewerId);
    final String counterpart = message.counterpartName(viewerId);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: mine
            ? AppColors.socialBlue.withValues(alpha: 0.12)
            : AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: mine
              ? AppColors.socialBlue.withValues(alpha: 0.30)
              : AppColors.skyBlue.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.brandNightBlue,
                child: Text(
                  initialsFrom(mine ? 'Tu' : counterpart),
                  style: const TextStyle(
                    color: AppColors.skyBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mine ? 'Tu → $counterpart' : counterpart,
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatPrivateNewsTimestamp(message.createdAt),
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.48),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (mine && message.isPendingDelivery)
                const _StatusChip(
                  label: 'In attesa',
                  icon: Icons.schedule_rounded,
                  color: Colors.orangeAccent,
                )
              else
                const EncryptedBadge(),
            ],
          ),
          const SizedBox(height: 13),
          if (message.isReadable)
            Text(
              message.text,
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.86),
                fontSize: 13,
                height: 1.45,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandNightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_person_outlined,
                    size: 18,
                    color: AppColors.pureWhite.withValues(alpha: 0.52),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Messaggio non disponibile su questo dispositivo.',
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.58),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (mine && message.isPendingDelivery) ...[
            const SizedBox(height: 10),
            Text(
              'Messaggio in attesa di consegna.',
              style: TextStyle(
                color: Colors.orangeAccent.withValues(alpha: 0.86),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          if (onReport != null || onReply != null || onDelete != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReport != null)
                  TextButton.icon(
                    onPressed: onReport,
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Segnala'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.pureWhite.withValues(
                        alpha: 0.66,
                      ),
                    ),
                  ),
                if (onReply != null)
                  TextButton.icon(
                    onPressed: onReply,
                    icon: const Icon(Icons.reply_rounded, size: 18),
                    label: const Text('Rispondi'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.skyBlue,
                    ),
                  ),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Elimina'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
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

class EncryptedBadge extends StatelessWidget {
  const EncryptedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StatusChip(
      label: 'E2E',
      icon: Icons.lock_outline_rounded,
      color: AppColors.materialSky,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class PrivateNewsStateView extends StatelessWidget {
  const PrivateNewsStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 46,
              color: AppColors.skyBlue.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.pureWhite,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.60),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReportRequest {
  const ReportRequest({
    required this.reason,
    required this.description,
  });

  final String reason;
  final String description;
}

class ReportConsentDialog extends StatefulWidget {
  const ReportConsentDialog({super.key});

  @override
  State<ReportConsentDialog> createState() => _ReportConsentDialogState();
}

class _ReportConsentDialogState extends State<ReportConsentDialog> {
  final TextEditingController _description = TextEditingController();

  String _reason = 'harassment';

  bool _consent = false;

  @override
  void dispose() {
    _description.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.eleganceDeepNavy,
      title: const Text(
        'Segnala messaggio',
        style: TextStyle(color: AppColors.pureWhite),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandNightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Questo messaggio è cifrato: nessuno, nemmeno StudentLab, '
                'può leggerlo. Segnalandolo, e solo se acconsenti qui '
                'sotto, la chiave di questo singolo messaggio viene inviata '
                'ai moderatori, che potranno leggerlo. Gli altri messaggi '
                'della conversazione restano illeggibili.',
                style: TextStyle(
                  color: AppColors.pureWhite.withValues(alpha: 0.70),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Motivo',
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              dropdownColor: AppColors.brandNightBlue,
              style: const TextStyle(color: AppColors.pureWhite),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.brandNightBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: NewsReportReasons.labels.entries
                  .map(
                    (MapEntry<String, String> entry) =>
                        DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _reason = value;
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              maxLength: NewsReportApiService.maxDescriptionLength,
              style: const TextStyle(color: AppColors.pureWhite),
              decoration: InputDecoration(
                hintText: 'Dettagli per i moderatori (facoltativo)',
                hintStyle: TextStyle(
                  color: AppColors.pureWhite.withValues(alpha: 0.42),
                ),
                filled: true,
                fillColor: AppColors.brandNightBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            CheckboxListTile(
              value: _consent,
              onChanged: (bool? value) {
                setState(() {
                  _consent = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.socialBlue,
              title: Text(
                'Acconsento a rendere leggibile ai moderatori il contenuto '
                'di questo messaggio.',
                style: TextStyle(
                  color: AppColors.pureWhite.withValues(alpha: 0.78),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: _consent
              ? () => Navigator.pop(
                    context,
                    ReportRequest(
                      reason: _reason,
                      description: _description.text,
                    ),
                  )
              : null,
          child: const Text(
            'Invia segnalazione',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}
