import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../services/auth_session.dart';
import '../../../services/blob_upload_service.dart';


class QuestionManagementService {
  static const String _baseUrl =
      'https://dmi-student-lab.vercel.app';

  final StudentLabUploadService _uploadService =
      StudentLabUploadService();


  Uri _uri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final Uri base =
        Uri.parse(
      _baseUrl,
    );

    final String normalizedPath =
        path.startsWith('/')
            ? path
            : '/$path';

    return base.replace(
      path:
          normalizedPath,
      queryParameters:
          queryParameters,
    );
  }


  Map<String, String> get _headers {
    final String? token =
        AuthSession.instance.accessToken;

    if (
      token == null ||
      token.trim().isEmpty
    ) {
      throw Exception(
        'Utente non autenticato.',
      );
    }

    return {
      'Accept':
          'application/json',
      'Content-Type':
          'application/json',
      'Authorization':
          'Bearer ${token.trim()}',
    };
  }


  Future<dynamic> _decodeResponse(
    http.Response response,
    String fallbackMessage,
  ) async {
    dynamic decoded;

    if (
      response.body
          .trim()
          .isNotEmpty
    ) {
      try {
        decoded =
            jsonDecode(
          response.body,
        );
      } catch (_) {
        decoded =
            null;
      }
    }

    if (
      response.statusCode >= 200 &&
      response.statusCode < 300
    ) {
      return decoded;
    }

    String message =
        fallbackMessage;

    if (decoded is Map) {
      final dynamic detail =
          decoded['detail'] ??
          decoded['error'];

      if (
        detail is String &&
        detail.trim().isNotEmpty
      ) {
        message =
            detail.trim();
      }
    }

    throw Exception(
      message,
    );
  }


  Map<String, dynamic> _asMap(
    dynamic value,
    String message,
  ) {
    if (
      value is Map<String, dynamic>
    ) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    throw Exception(
      message,
    );
  }


  List<Map<String, dynamic>> _asMapList(
    dynamic value,
    String message,
  ) {
    if (value is! List) {
      throw Exception(
        message,
      );
    }

    return value
        .whereType<Map>()
        .map(
          (
            Map item,
          ) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }


  String _questionBasePath({
    required String department,
    required String course,
    required String subject,
  }) {
    return '/questions/'
        '${Uri.encodeComponent(department.trim())}/'
        '${Uri.encodeComponent(course.trim())}/'
        '${Uri.encodeComponent(subject.trim())}';
  }


  Future<List<Map<String, dynamic>>>
      getQuestions({
    required String department,
    required String course,
    required String subject,
    bool includeHidden = true,
  }) async {
    final http.Response response =
        await http.get(
      _uri(
        _questionBasePath(
          department:
              department,
          course:
              course,
          subject:
              subject,
        ),
        queryParameters: {
          'include_hidden':
              includeHidden
                  ? 'true'
                  : 'false',
        },
      ),
      headers:
          _headers,
    );

    final dynamic decoded =
        await _decodeResponse(
      response,
      'Non è stato possibile caricare le domande.',
    );

    return _asMapList(
      decoded,
      'Il server ha restituito un elenco domande non valido.',
    );
  }


  Future<Map<String, dynamic>>
      createQuestion({
    required String department,
    required String course,
    required String subject,
    required Map<String, dynamic>
        data,
  }) async {
    final http.Response response =
        await http.post(
      _uri(
        _questionBasePath(
          department:
              department,
          course:
              course,
          subject:
              subject,
        ),
      ),
      headers:
          _headers,
      body:
          jsonEncode(
        data,
      ),
    );

    final dynamic decoded =
        await _decodeResponse(
      response,
      'Non è stato possibile creare la domanda.',
    );

    return _asMap(
      decoded,
      'Il server ha restituito una domanda non valida.',
    );
  }


  Future<Map<String, dynamic>>
      updateQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required Map<String, dynamic>
        data,
  }) async {
    final String normalizedQuestionId =
        questionId.trim();

    if (
      normalizedQuestionId.isEmpty
    ) {
      throw Exception(
        'Identificativo domanda non valido.',
      );
    }

    final http.Response response =
        await http.patch(
      _uri(
        '${_questionBasePath(
          department:
              department,
          course:
              course,
          subject:
              subject,
        )}/'
        '${Uri.encodeComponent(normalizedQuestionId)}',
      ),
      headers:
          _headers,
      body:
          jsonEncode(
        data,
      ),
    );

    final dynamic decoded =
        await _decodeResponse(
      response,
      'Non è stato possibile aggiornare la domanda.',
    );

    return _asMap(
      decoded,
      'Il server ha restituito una domanda non valida.',
    );
  }


  Future<Map<String, dynamic>>
      getQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) async {
    final http.Response response =
        await http.get(
      _uri(
        '${_questionBasePath(
          department:
              department,
          course:
              course,
          subject:
              subject,
        )}/'
        '${Uri.encodeComponent(questionId.trim())}',
      ),
      headers:
          _headers,
    );

    final dynamic decoded =
        await _decodeResponse(
      response,
      'Non è stato possibile caricare la domanda.',
    );

    return _asMap(
      decoded,
      'Il server ha restituito una domanda non valida.',
    );
  }


  Future<void> deleteQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) async {
    final http.Response response =
        await http.delete(
      _uri(
        '${_questionBasePath(
          department:
              department,
          course:
              course,
          subject:
              subject,
        )}/'
        '${Uri.encodeComponent(questionId.trim())}',
      ),
      headers:
          _headers,
    );

    await _decodeResponse(
      response,
      'Non è stato possibile eliminare la domanda.',
    );
  }


  Future<Map<String, dynamic>>
      _postQuestionAction({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required String action,
    required String fallbackMessage,
  }) async {
    final http.Response response =
        await http.post(
      _uri(
        '${_questionBasePath(
          department:
              department,
          course:
              course,
          subject:
              subject,
        )}/'
        '${Uri.encodeComponent(questionId.trim())}/'
        '$action',
      ),
      headers:
          _headers,
    );

    final dynamic decoded =
        await _decodeResponse(
      response,
      fallbackMessage,
    );

    return _asMap(
      decoded,
      'Il server ha restituito una domanda non valida.',
    );
  }


  Future<Map<String, dynamic>>
      hideQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) {
    return _postQuestionAction(
      department:
          department,
      course:
          course,
      subject:
          subject,
      questionId:
          questionId,
      action:
          'hide',
      fallbackMessage:
          'Non è stato possibile nascondere la domanda.',
    );
  }


  Future<Map<String, dynamic>>
      restoreQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) {
    return _postQuestionAction(
      department:
          department,
      course:
          course,
      subject:
          subject,
      questionId:
          questionId,
      action:
          'restore',
      fallbackMessage:
          'Non è stato possibile ripristinare la domanda.',
    );
  }


  Future<Map<String, dynamic>>
      activateQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) {
    return _postQuestionAction(
      department:
          department,
      course:
          course,
      subject:
          subject,
      questionId:
          questionId,
      action:
          'activate',
      fallbackMessage:
          'Non è stato possibile attivare la domanda.',
    );
  }


  Future<Map<String, dynamic>>
      deactivateQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) {
    return _postQuestionAction(
      department:
          department,
      course:
          course,
      subject:
          subject,
      questionId:
          questionId,
      action:
          'deactivate',
      fallbackMessage:
          'Non è stato possibile disattivare la domanda.',
    );
  }


  Future<Map<String, dynamic>>
      importQuestions({
    required String department,
    required String course,
    required String subject,
    required String filePath,
    bool skipDuplicates = true,
  }) async {
    final File file =
        File(
      filePath,
    );

    if (
      !await file.exists()
    ) {
      throw Exception(
        'Il file selezionato non esiste.',
      );
    }

    final int size =
        await file.length();

    if (
      size <= 0
    ) {
      throw Exception(
        'Il file JSON è vuoto.',
      );
    }

    if (
      size >
      10 * 1024 * 1024
    ) {
      throw Exception(
        'Il file JSON supera la dimensione massima consentita di 10 MB.',
      );
    }

    final String fileName =
        file.path
            .replaceAll(
              '\\',
              '/',
            )
            .split(
              '/',
            )
            .last;

    if (
      !fileName
          .toLowerCase()
          .endsWith(
            '.json',
          )
    ) {
      throw Exception(
        'Seleziona un file JSON.',
      );
    }

    final Uri uri =
        _uri(
      '${_questionBasePath(
        department:
            department,
        course:
            course,
        subject:
            subject,
      )}/import',
      queryParameters: {
        'skip_duplicates':
            skipDuplicates
                ? 'true'
                : 'false',
      },
    );

    final http.MultipartRequest request =
        http.MultipartRequest(
      'POST',
      uri,
    );

    final String? token =
        AuthSession.instance.accessToken;

    if (
      token == null ||
      token.trim().isEmpty
    ) {
      throw Exception(
        'Utente non autenticato.',
      );
    }

    request.headers[
      'Accept'
    ] =
        'application/json';

    request.headers[
      'Authorization'
    ] =
        'Bearer ${token.trim()}';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename:
            fileName,
      ),
    );

    final http.StreamedResponse streamed =
        await request.send();

    final http.Response response =
        await http.Response.fromStream(
      streamed,
    );

    final dynamic decoded =
        await _decodeResponse(
      response,
      'Non è stato possibile importare le domande.',
    );

    return _asMap(
      decoded,
      'Il server ha restituito un risultato import non valido.',
    );
  }


  Future<Map<String, dynamic>>
      saveNewQuestionWithAttachments({
    required String department,
    required String course,
    required String subject,
    required Map<String, dynamic>
        data,
    required List<String>
        attachmentFilePaths,
  }) async {
    final Map<String, dynamic>
        createPayload =
        Map<String, dynamic>.from(
      data,
    );

    createPayload[
        'attachments'] =
        <Map<String, dynamic>>[];

    Map<String, dynamic>
        question =
        await createQuestion(
      department:
          department,
      course:
          course,
      subject:
          subject,
      data:
          createPayload,
    );

    final String questionId =
        question[
                'id_question']
            ?.toString()
            .trim() ??
        '';

    if (
      questionId.isEmpty
    ) {
      throw Exception(
        'La domanda è stata creata ma il server non ha restituito un identificativo valido.',
      );
    }

    if (
      attachmentFilePaths.isEmpty
    ) {
      return question;
    }

    final List<Map<String, dynamic>>
        attachments =
        [];

    for (
      final String filePath
      in attachmentFilePaths
    ) {
      final Map<String, dynamic>
          attachment =
          await _uploadService
              .uploadQuestionAttachment(
        department:
            department,
        course:
            course,
        subject:
            subject,
        questionId:
            questionId,
        filePath:
            filePath,
      );

      attachments.add(
        attachment,
      );
    }

    question =
        await updateQuestion(
      department:
          department,
      course:
          course,
      subject:
          subject,
      questionId:
          questionId,
      data: {
        'attachments':
            attachments,
      },
    );

    return question;
  }


  Future<Map<String, dynamic>>
      saveExistingQuestionWithAttachments({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required Map<String, dynamic>
        data,
    required List<Map<String, dynamic>>
        existingAttachments,
    required List<String>
        newAttachmentFilePaths,
  }) async {
    final String normalizedQuestionId =
        questionId.trim();

    if (
      normalizedQuestionId.isEmpty
    ) {
      throw Exception(
        'Identificativo domanda non valido.',
      );
    }

    final List<Map<String, dynamic>>
        attachments =
        existingAttachments
            .map(
              (
                Map<String, dynamic>
                    attachment,
              ) =>
                  Map<String, dynamic>.from(
                attachment,
              ),
            )
            .toList();

    for (
      final String filePath
      in newAttachmentFilePaths
    ) {
      final Map<String, dynamic>
          attachment =
          await _uploadService
              .uploadQuestionAttachment(
        department:
            department,
        course:
            course,
        subject:
            subject,
        questionId:
            normalizedQuestionId,
        filePath:
            filePath,
      );

      attachments.add(
        attachment,
      );
    }

    final Map<String, dynamic>
        updatePayload =
        Map<String, dynamic>.from(
      data,
    );

    updatePayload[
        'attachments'] =
        attachments;

    return updateQuestion(
      department:
          department,
      course:
          course,
      subject:
          subject,
      questionId:
          normalizedQuestionId,
      data:
          updatePayload,
    );
  }
}