import 'dart:typed_data';

import 'package:http/http.dart' as http;

class QuestionAttachmentApiService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';

  Uri _uri({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required String attachmentId,
  }) {
    final Uri base = Uri.parse(_baseUrl);

    return base.replace(
      pathSegments: <String>[
        'question-attachments',
        'content',
        department.trim(),
        course.trim(),
        subject.trim(),
        questionId.trim(),
        attachmentId.trim(),
      ],
    );
  }

  Future<Uint8List> load({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required String attachmentId,
  }) async {
    final http.Response response = await http.get(
      _uri(
        department: department,
        course: course,
        subject: subject,
        questionId: questionId,
        attachmentId: attachmentId,
      ),
      headers: const <String, String>{
        'Accept': 'image/*,application/octet-stream',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Immagine non disponibile.');
    }

    if (response.bodyBytes.isEmpty) {
      throw Exception('Immagine non disponibile.');
    }

    return response.bodyBytes;
  }
}
