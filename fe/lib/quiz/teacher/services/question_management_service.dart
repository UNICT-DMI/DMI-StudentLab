import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../local_storage/services/local_file_service.dart';
import '../../../services/auth_session.dart';
import '../../../services/blob_upload_service.dart';

class QuestionManagementService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';

  final StudentLabUploadService _uploadService = StudentLabUploadService();
  final LocalFileService _files = LocalFileService();

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    final Uri base = Uri.parse(_baseUrl);

    final String normalizedPath = path.startsWith('/') ? path : '/$path';

    return base.replace(path: normalizedPath, queryParameters: queryParameters);
  }

  Map<String, String> get _headers {
    final String? token = AuthSession.instance.accessToken;

    if (token == null || token.trim().isEmpty) {
      throw Exception('Utente non autenticato.');
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  Future<dynamic> _decodeResponse(
    http.Response response,
    String fallbackMessage,
  ) async {
    dynamic decoded;

    if (response.body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = fallbackMessage;

    if (decoded is Map) {
      final dynamic detail = decoded['detail'] ?? decoded['error'];

      final String? extracted = _extractErrorMessage(detail);

      if (extracted != null && extracted.trim().isNotEmpty) {
        message = extracted.trim();
      }
    }

    throw Exception(message);
  }

  String? _extractErrorMessage(dynamic detail) {
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }

    if (detail is! List || detail.isEmpty) {
      return null;
    }

    final dynamic first = detail.first;

    if (first is! Map) {
      return null;
    }

    final dynamic locationRaw = first['loc'];

    final List<String> location = locationRaw is List
        ? locationRaw.map((dynamic value) => value.toString()).toList()
        : <String>[];

    final String field = location.isEmpty ? '' : location.last;

    switch (field) {
      case 'university':
        return 'I dati accademici della materia sono incompleti: manca l’ateneo associato al profilo docente.';

      case 'argoment':
        return 'Inserisci l’argomento della domanda.';

      case 'text':
        return 'Inserisci il testo della domanda.';

      case 'formal_explanation':
        return 'Inserisci la spiegazione formale della risposta corretta.';

      case 'informal_explanation':
        return 'Inserisci la spiegazione semplice della risposta corretta.';

      case 'question_response_explanation':
        return 'Inserisci una spiegazione per ogni risposta, indicando perché quella corretta è corretta e perché le altre sono errate.';

      case 'id_correct':
        return 'Seleziona una risposta corretta valida.';

      case 'estimed_time':
        return 'Inserisci un tempo stimato valido.';

      case 'option':
        return 'Completa tutte le risposte della domanda.';
    }

    final String rawMessage = first['msg']?.toString().trim() ?? '';

    if (rawMessage.isEmpty) {
      return null;
    }

    final String cleaned = rawMessage
        .replaceFirst(RegExp(r'^Value error,\s*', caseSensitive: false), '')
        .trim();

    if (cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  Map<String, dynamic> _asMap(dynamic value, String message) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw Exception(message);
  }

  List<Map<String, dynamic>> _asMapList(dynamic value, String message) {
    if (value is! List) {
      throw Exception(message);
    }

    return value
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
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

  Future<List<Map<String, dynamic>>> getQuestions({
    required String department,
    required String course,
    required String subject,
    bool includeHidden = true,
  }) async {
    final http.Response response = await http.get(
      _uri(
        _questionBasePath(
          department: department,
          course: course,
          subject: subject,
        ),
        queryParameters: {'include_hidden': includeHidden ? 'true' : 'false'},
      ),
      headers: _headers,
    );

    final dynamic decoded = await _decodeResponse(
      response,
      'Non è stato possibile caricare le domande.',
    );

    final dynamic questions = decoded is Map ? decoded['questions'] : decoded;

    return _asMapList(
      questions,
      'Il server ha restituito un elenco domande non valido.',
    );
  }

  Future<Map<String, dynamic>> createQuestion({
    required String department,
    required String course,
    required String subject,
    required Map<String, dynamic> data,
  }) async {
    final http.Response response = await http.post(
      _uri(
        _questionBasePath(
          department: department,
          course: course,
          subject: subject,
        ),
      ),
      headers: _headers,
      body: jsonEncode(data),
    );

    final dynamic decoded = await _decodeResponse(
      response,
      'Non è stato possibile creare la domanda.',
    );

    return _asMap(decoded, 'Il server ha restituito una domanda non valida.');
  }

  Future<Map<String, dynamic>> updateQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required Map<String, dynamic> data,
  }) async {
    final String normalizedQuestionId = questionId.trim();

    if (normalizedQuestionId.isEmpty) {
      throw Exception('Identificativo domanda non valido.');
    }

    final http.Response response = await http.patch(
      _uri(
        '${_questionBasePath(department: department, course: course, subject: subject)}/'
        '${Uri.encodeComponent(normalizedQuestionId)}',
      ),
      headers: _headers,
      body: jsonEncode(data),
    );

    final dynamic decoded = await _decodeResponse(
      response,
      'Non è stato possibile aggiornare la domanda.',
    );

    return _asMap(decoded, 'Il server ha restituito una domanda non valida.');
  }

  Future<Map<String, dynamic>> getQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) async {
    final http.Response response = await http.get(
      _uri(
        '${_questionBasePath(department: department, course: course, subject: subject)}/'
        '${Uri.encodeComponent(questionId.trim())}',
      ),
      headers: _headers,
    );

    final dynamic decoded = await _decodeResponse(
      response,
      'Non è stato possibile caricare la domanda.',
    );

    return _asMap(decoded, 'Il server ha restituito una domanda non valida.');
  }

  Future<void> deleteQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) async {
    final http.Response response = await http.delete(
      _uri(
        '${_questionBasePath(department: department, course: course, subject: subject)}/'
        '${Uri.encodeComponent(questionId.trim())}',
      ),
      headers: _headers,
    );

    await _decodeResponse(
      response,
      'Non è stato possibile eliminare la domanda.',
    );
  }

  Future<Map<String, dynamic>> _postQuestionAction({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required String action,
    required String fallbackMessage,
  }) async {
    final http.Response response = await http.post(
      _uri(
        '${_questionBasePath(department: department, course: course, subject: subject)}/'
        '${Uri.encodeComponent(questionId.trim())}/'
        '$action',
      ),
      headers: _headers,
    );

    final dynamic decoded = await _decodeResponse(response, fallbackMessage);

    return _asMap(decoded, 'Il server ha restituito una domanda non valida.');
  }

  Future<Map<String, dynamic>> hideQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) {
    return _postQuestionAction(
      department: department,
      course: course,
      subject: subject,
      questionId: questionId,
      action: 'hide',
      fallbackMessage: 'Non è stato possibile nascondere la domanda.',
    );
  }

  Future<Map<String, dynamic>> restoreQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) {
    return _postQuestionAction(
      department: department,
      course: course,
      subject: subject,
      questionId: questionId,
      action: 'restore',
      fallbackMessage: 'Non è stato possibile ripristinare la domanda.',
    );
  }

  Future<Map<String, dynamic>> activateQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) {
    return _postQuestionAction(
      department: department,
      course: course,
      subject: subject,
      questionId: questionId,
      action: 'activate',
      fallbackMessage: 'Non è stato possibile attivare la domanda.',
    );
  }

  Future<Map<String, dynamic>> deactivateQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
  }) {
    return _postQuestionAction(
      department: department,
      course: course,
      subject: subject,
      questionId: questionId,
      action: 'deactivate',
      fallbackMessage: 'Non è stato possibile disattivare la domanda.',
    );
  }

  Future<List<String>> getImportAttachmentNames({
    required String filePath,
  }) async {
    final bytes = await _files.readBytes(filePath);

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Il file selezionato non esiste o è vuoto.');
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw Exception('Il contenuto del file JSON non è valido.');
    }

    if (decoded is! List) {
      throw Exception('Il file JSON deve contenere una lista di domande.');
    }

    final Set<String> names = <String>{};

    for (final dynamic rawQuestion in decoded) {
      if (rawQuestion is! Map) {
        continue;
      }

      final dynamic rawAttachments = rawQuestion['attachments'];

      final List<dynamic> values = rawAttachments == null
          ? <dynamic>[]
          : rawAttachments is List
          ? rawAttachments
          : <dynamic>[rawAttachments];

      for (dynamic value in values) {
        if (value is Map) {
          value = value['original_name'];
        }

        final String name = value?.toString().trim() ?? '';

        if (name.isEmpty) {
          continue;
        }

        if (name.contains('/') ||
            name.contains('\\') ||
            name == '.' ||
            name == '..') {
          throw Exception('Il JSON contiene un nome allegato non valido.');
        }

        names.add(name);
      }
    }

    final List<String> result = names.toList()
      ..sort(
        (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );

    return result;
  }

  Future<void> attachImportedQuestionFiles({
    required String department,
    required String course,
    required String subject,
    required Map<String, dynamic> importResult,
    required List<String> selectedFilePaths,
  }) async {
    final dynamic rawPlan = importResult['attachment_plan'];

    if (rawPlan is! List || rawPlan.isEmpty) {
      return;
    }

    final Map<String, String> fileByName = <String, String>{};

    for (final String path in selectedFilePaths) {
      final String name = path.replaceAll('\\', '/').split('/').last.trim();

      if (name.isNotEmpty) {
        fileByName[name.toLowerCase()] = path;
      }
    }

    final List<String> importedQuestionIds = <String>[];

    final dynamic rawQuestionIds = importResult['question_ids'];

    if (rawQuestionIds is List) {
      importedQuestionIds.addAll(
        rawQuestionIds
            .map((dynamic value) => value?.toString().trim() ?? '')
            .where((String value) => value.isNotEmpty),
      );
    }

    try {
      for (final dynamic rawEntry in rawPlan) {
        if (rawEntry is! Map) {
          continue;
        }

        final String questionId =
            rawEntry['question_id']?.toString().trim() ?? '';

        final dynamic rawFiles = rawEntry['files'];

        if (questionId.isEmpty || rawFiles is! List) {
          continue;
        }

        final List<Map<String, dynamic>> attachments = <Map<String, dynamic>>[];

        for (final dynamic rawName in rawFiles) {
          final String name = rawName?.toString().trim() ?? '';

          final String? path = fileByName[name.toLowerCase()];

          if (path == null) {
            throw Exception('Manca il file allegato "$name".');
          }

          final Map<String, dynamic> attachment = await _uploadService
              .uploadQuestionAttachment(
                department: department,
                course: course,
                subject: subject,
                questionId: questionId,
                filePath: path,
              );

          attachments.add(attachment);
        }

        if (attachments.isNotEmpty) {
          await updateQuestion(
            department: department,
            course: course,
            subject: subject,
            questionId: questionId,
            data: <String, dynamic>{'attachments': attachments},
          );
        }
      }
    } catch (error) {
      for (final String questionId in importedQuestionIds) {
        try {
          await deleteQuestion(
            department: department,
            course: course,
            subject: subject,
            questionId: questionId,
          );
        } catch (_) {}
      }

      rethrow;
    }
  }

  Future<Map<String, dynamic>> importQuestions({
    required String department,
    required String course,
    required String subject,
    required String filePath,
    bool skipDuplicates = true,
  }) async {
    final bytes = await _files.readBytes(filePath);

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Il file JSON è vuoto o non disponibile.');
    }

    final int size = bytes.length;

    if (size > 10 * 1024 * 1024) {
      throw Exception(
        'Il file JSON supera la dimensione massima consentita di 10 MB.',
      );
    }

    final String fileName = _files.getFileName(filePath);

    if (!fileName.toLowerCase().endsWith('.json')) {
      throw Exception('Seleziona un file JSON.');
    }

    final Uri uri = _uri(
      '${_questionBasePath(department: department, course: course, subject: subject)}/import',
      queryParameters: {'skip_duplicates': skipDuplicates ? 'true' : 'false'},
    );

    final http.MultipartRequest request = http.MultipartRequest('POST', uri);

    final String? token = AuthSession.instance.accessToken;

    if (token == null || token.trim().isEmpty) {
      throw Exception('Utente non autenticato.');
    }

    request.headers['Accept'] = 'application/json';

    request.headers['Authorization'] = 'Bearer ${token.trim()}';

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final http.StreamedResponse streamed = await request.send();

    final http.Response response = await http.Response.fromStream(streamed);

    final dynamic decoded = await _decodeResponse(
      response,
      'Non è stato possibile importare le domande.',
    );

    return _asMap(
      decoded,
      'Il server ha restituito un risultato import non valido.',
    );
  }

  Future<Map<String, dynamic>> saveNewQuestionWithAttachments({
    required String department,
    required String course,
    required String subject,
    required Map<String, dynamic> data,
    required List<String> attachmentFilePaths,
  }) async {
    final Map<String, dynamic> createPayload = Map<String, dynamic>.from(data);

    createPayload['attachments'] = <Map<String, dynamic>>[];

    Map<String, dynamic> question = await createQuestion(
      department: department,
      course: course,
      subject: subject,
      data: createPayload,
    );

    final String questionId = question['id_question']?.toString().trim() ?? '';

    if (questionId.isEmpty) {
      throw Exception(
        'La domanda è stata creata ma il server non ha restituito un identificativo valido.',
      );
    }

    if (attachmentFilePaths.isEmpty) {
      return question;
    }

    final List<Map<String, dynamic>> attachments = [];

    for (final String filePath in attachmentFilePaths) {
      final Map<String, dynamic> attachment = await _uploadService
          .uploadQuestionAttachment(
            department: department,
            course: course,
            subject: subject,
            questionId: questionId,
            filePath: filePath,
          );

      attachments.add(attachment);
    }

    question = await updateQuestion(
      department: department,
      course: course,
      subject: subject,
      questionId: questionId,
      data: {'attachments': attachments},
    );

    return question;
  }

  Future<Map<String, dynamic>> saveExistingQuestionWithAttachments({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> existingAttachments,
    required List<String> newAttachmentFilePaths,
  }) async {
    final String normalizedQuestionId = questionId.trim();

    if (normalizedQuestionId.isEmpty) {
      throw Exception('Identificativo domanda non valido.');
    }

    final List<Map<String, dynamic>> attachments = existingAttachments
        .map(
          (Map<String, dynamic> attachment) =>
              Map<String, dynamic>.from(attachment),
        )
        .toList();

    for (final String filePath in newAttachmentFilePaths) {
      final Map<String, dynamic> attachment = await _uploadService
          .uploadQuestionAttachment(
            department: department,
            course: course,
            subject: subject,
            questionId: normalizedQuestionId,
            filePath: filePath,
          );

      attachments.add(attachment);
    }

    final Map<String, dynamic> updatePayload = Map<String, dynamic>.from(data);

    updatePayload['attachments'] = attachments;

    return updateQuestion(
      department: department,
      course: course,
      subject: subject,
      questionId: normalizedQuestionId,
      data: updatePayload,
    );
  }
}
