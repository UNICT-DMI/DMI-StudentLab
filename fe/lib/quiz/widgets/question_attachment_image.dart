import 'dart:typed_data';
import 'package:fe/theme/nightTheme.dart';

import 'package:flutter/material.dart';

import '../services/question_attachment_api_service.dart';

class QuestionAttachmentImage extends StatefulWidget {
  final String department;
  final String course;
  final String subject;
  final String questionId;
  final Map<String, dynamic> attachment;

  const QuestionAttachmentImage({
    super.key,
    required this.department,
    required this.course,
    required this.subject,
    required this.questionId,
    required this.attachment,
  });

  @override
  State<QuestionAttachmentImage> createState() =>
      _QuestionAttachmentImageState();
}

class _QuestionAttachmentImageState
    extends State<QuestionAttachmentImage> {
  final QuestionAttachmentApiService _service =
      QuestionAttachmentApiService();

  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Uint8List> _load() {
    return _service.load(
      department: widget.department,
      course: widget.course,
      subject: widget.subject,
      questionId: widget.questionId,
      attachmentId:
          widget.attachment['id']?.toString().trim() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (
        BuildContext context,
        AsyncSnapshot<Uint8List> snapshot,
      ) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (
          snapshot.hasError ||
          snapshot.data == null ||
          snapshot.data!.isEmpty
        ) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.white54,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Immagine non disponibile.',
                    style: TextStyle(
                      color: AppColors.white54,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final Uint8List bytes = snapshot.data!;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _openFullscreen(
              context,
              bytes,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 120,
                maxHeight: 420,
              ),
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.18),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFullscreen(
    BuildContext context,
    Uint8List bytes,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext context) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
            body: SafeArea(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 8,
                boundaryMargin: const EdgeInsets.all(80),
                clipBehavior: Clip.none,
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
