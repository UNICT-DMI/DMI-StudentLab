import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';

/// Allegati di una domanda o di un esercizio: le immagini si vedono subito
/// (tocca per ingrandire), gli altri file (PDF, TXT, DOCX, PPTX) si aprono.
///
/// Il file arriva dal server tramite l'id dell'allegato: l'app non conosce il
/// percorso nello storage.
class ExerciseAttachments extends StatelessWidget {
  final List<Map<String, dynamic>> attachments;
  final Uri Function(String attachmentId) uriFor;
  final Set<String> exclude;

  const ExerciseAttachments({super.key, required this.attachments, required this.uriFor, this.exclude = const {}});

  /// Allegati di un esercizio della banca (o di un'assegnazione).
  factory ExerciseAttachments.exercise({
    Key? key,
    required List<Map<String, dynamic>> attachments,
    required String department,
    required String course,
    required String subject,
    required String itemId,
    Set<String> exclude = const {},
  }) {
    final ExerciseApiService api = ExerciseApiService();
    return ExerciseAttachments(
      key: key,
      attachments: attachments,
      exclude: exclude,
      uriFor: (String id) => api.exerciseAttachmentUri(department, course, subject, itemId, id),
    );
  }

  /// Allegati delle domande a risposta multipla di sempre.
  factory ExerciseAttachments.question({
    Key? key,
    required List<Map<String, dynamic>> attachments,
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) {
    final ExerciseApiService api = ExerciseApiService();
    return ExerciseAttachments(
      key: key,
      attachments: attachments,
      uriFor: (String id) => api.questionAttachmentUri(department, course, subject, questionId, id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> shown = attachments
        .where((Map<String, dynamic> a) =>
            (a['id']?.toString() ?? '').isNotEmpty &&
            !exclude.contains(a['id'].toString()) &&
            (a['role']?.toString() ?? 'statement') != 'option')
        .toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final List<Map<String, dynamic>> images = shown.where(_isImage).toList();
    final List<Map<String, dynamic>> files = shown.where((Map<String, dynamic> a) => !_isImage(a)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      for (final Map<String, dynamic> image in images)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AttachmentImage(uri: uriFor(image['id'].toString()), caption: image['caption']?.toString()),
        ),
      if (files.isNotEmpty)
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final Map<String, dynamic> file in files)
            AttachmentFileChip(
              name: file['original_name']?.toString() ?? 'Allegato',
              mimeType: file['mime_type']?.toString() ?? '',
              uri: uriFor(file['id'].toString()),
            ),
        ]),
    ]);
  }
}

bool _isImage(Map<String, dynamic> attachment) =>
    attachment['type']?.toString() == 'image' ||
    (attachment['mime_type']?.toString() ?? '').startsWith('image/');

class AttachmentImage extends StatelessWidget {
  final Uri uri;
  final String? caption;
  final double maxHeight;

  const AttachmentImage({super.key, required this.uri, this.caption, this.maxHeight = 360});

  void _open(BuildContext context) {
    final p = context.palette;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: p.darkElegance,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(children: <Widget>[
          InteractiveViewer(
            maxScale: 6,
            child: Center(child: Image.network(uri.toString(), fit: BoxFit.contain)),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              tooltip: 'Chiudi',
              onPressed: () => Navigator.pop(dialogContext),
              icon: Icon(Icons.close_rounded, color: p.pureWhite),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: caption?.isNotEmpty == true ? 'Immagine: $caption. Tocca per ingrandire' : 'Immagine. Tocca per ingrandire',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(minHeight: 100, maxHeight: maxHeight),
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.18),
              child: Image.network(
                uri.toString(),
                fit: BoxFit.contain,
                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) => progress == null
                    ? child
                    : SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: p.skyBlue))),
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: <Widget>[
                    Icon(Icons.broken_image_outlined, color: p.pureWhite.withValues(alpha: 0.6)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Immagine non disponibile.', style: SlText.muted(p))),
                  ]),
                ),
              ),
            ),
          ),
          if (caption != null && caption!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(caption!, style: SlText.muted(p).copyWith(fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}

class AttachmentFileChip extends StatelessWidget {
  final String name;
  final String mimeType;
  final Uri uri;

  const AttachmentFileChip({super.key, required this.name, required this.mimeType, required this.uri});

  IconData get _icon {
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.startsWith('text/')) return Icons.description_outlined;
    if (mimeType.contains('presentation')) return Icons.slideshow_outlined;
    if (mimeType.contains('word')) return Icons.article_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _open(BuildContext context) async {
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossibile aprire il file.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ActionChip(
      avatar: Icon(_icon, size: 18, color: p.skyBlue),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(name, overflow: TextOverflow.ellipsis),
      ),
      tooltip: 'Apri $name',
      onPressed: () => _open(context),
    );
  }
}
