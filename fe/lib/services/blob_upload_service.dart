import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../local_storage/services/local_file_service.dart';
import 'auth_session.dart';

class StudentLabUploadService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';
  static const String _host = 'dmi-student-lab.vercel.app';
  static const int groupMaterialMaxSize = 250 * 1024 * 1024;
  static const int teacherMaterialMaxSize = 250 * 1024 * 1024;
  static const int questionAttachmentMaxSize = 50 * 1024 * 1024;
  static const int materialPublicationMaxSize = 250 * 1024 * 1024;

  final LocalFileService _files;

  StudentLabUploadService({LocalFileService? files})
      : _files = files ?? LocalFileService();

  Uri _uri(String path) {
    final Uri base = Uri.parse(_baseUrl);
    final Uri uri = base.replace(path: path.startsWith('/') ? path : '/$path');
    if (uri.scheme != 'https' || uri.host != _host) {
      throw StateError('Endpoint di caricamento non autorizzato.');
    }
    return uri;
  }

  Map<String, String> get _jsonHeaders {
    final String? token = AuthSession.instance.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Utente non autenticato.');
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
    String fallback,
  ) async {
    final http.Response response = await http.post(
      _uri(path),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    return _decodeMap(response, fallback);
  }

  Map<String, dynamic> _decodeMap(http.Response response, String fallback) {
    dynamic decoded;
    if (response.body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {}
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded == null) return <String, dynamic>{};
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw Exception('$fallback: risposta non valida.');
    }
    if (decoded is Map) {
      final String detail = (decoded['detail'] ?? decoded['error'])?.toString().trim() ?? '';
      if (detail.isNotEmpty) throw Exception(detail);
    }
    throw Exception(fallback);
  }

  Future<_UploadFile> _fromPath(
    String path, {
    String? originalName,
    String? mimeType,
  }) async {
    final Uint8List? bytes = await _files.readBytes(path);
    if (bytes == null) throw Exception('Il file selezionato non esiste.');
    final String name = originalName?.trim().isNotEmpty == true
        ? originalName!.trim()
        : _files.getFileName(path);
    return _UploadFile(name: name, bytes: bytes, mimeType: mimeType);
  }

  String _sha256(Uint8List bytes) => sha256.convert(bytes).toString().toLowerCase();

  Future<void> _putBytes({
    required Uint8List bytes,
    required String mimeType,
    required String presignedUrl,
  }) async {
    final Uri uri = Uri.parse(presignedUrl);
    if (uri.scheme.toLowerCase() != 'https') {
      throw Exception('Connessione di caricamento non valida.');
    }
    final http.Response response = await http.put(
      uri,
      headers: <String, String>{'Content-Type': mimeType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Non è stato possibile caricare il file.');
    }
  }

  Future<Map<String, dynamic>> _requestBlobUpload({
    required String uploadKind,
    required String pathname,
    required String mimeType,
    required int size,
    required String fileHash,
    required String uploadToken,
    int? groupId,
    int? subjectId,
    String? attachmentId,
  }) {
    return _postJson(
      '/api/blob-upload',
      <String, dynamic>{
        'upload_kind': uploadKind,
        'pathname': pathname,
        'content_type': mimeType,
        'size': size,
        'file_hash': fileHash,
        'upload_token': uploadToken,
        if (groupId != null) 'group_id': groupId,
        if (subjectId != null) 'subject_id': subjectId,
        if (attachmentId != null) 'attachment_id': attachmentId,
      },
      'Non è stato possibile autorizzare il caricamento.',
    );
  }

  Future<Map<String, dynamic>> uploadGroupMaterial({
    required int groupId,
    required String filePath,
    String? originalName,
    String? mimeType,
  }) async {
    final _UploadFile file = await _fromPath(
      filePath,
      originalName: originalName,
      mimeType: mimeType,
    );
    return uploadGroupMaterialBytes(
      groupId: groupId,
      bytes: file.bytes,
      originalName: file.name,
      mimeType: file.mimeType,
    );
  }

  Future<Map<String, dynamic>> uploadGroupMaterialBytes({
    required int groupId,
    required Uint8List bytes,
    required String originalName,
    String? mimeType,
  }) async {
    if (groupId <= 0) throw Exception('Gruppo non valido.');
    _validateSize(bytes, groupMaterialMaxSize, 250);
    final String name = _requiredName(originalName);
    final String type = mimeType?.trim().isNotEmpty == true
        ? mimeType!.trim().toLowerCase()
        : _groupMimeType(name);
    final String hash = _sha256(bytes);
    final Map<String, dynamic> authorization = await _postJson(
      '/group_material_upload_request/$groupId',
      <String, dynamic>{
        'original_name': name,
        'mime_type': type,
        'size': bytes.length,
        'file_hash': hash,
      },
      'Non è stato possibile autorizzare il materiale.',
    );
    if (authorization['allowed'] != true) {
      throw Exception('Il caricamento del materiale non è autorizzato.');
    }
    final String pathname = _requiredString(authorization, 'pathname');
    final String token = _requiredString(authorization, 'upload_token');
    final int maxSize = _positiveInt(authorization['max_file_size']) ?? groupMaterialMaxSize;
    if (bytes.length > maxSize) throw Exception('Il file supera la dimensione massima consentita.');
    final Map<String, dynamic> blob = await _requestBlobUpload(
      uploadKind: 'group_material',
      pathname: pathname,
      mimeType: type,
      size: bytes.length,
      fileHash: hash,
      uploadToken: token,
      groupId: groupId,
    );
    await _putBytes(
      bytes: bytes,
      mimeType: type,
      presignedUrl: _requiredString(blob, 'presigned_url'),
    );
    return _postJson(
      '/group_material_complete/$groupId',
      <String, dynamic>{
        'original_name': name,
        'stored_name': pathname,
        'file_path': pathname,
        'mime_type': type,
        'size': bytes.length,
        'file_hash': hash,
        'upload_token': token,
      },
      'Non è stato possibile registrare il materiale.',
    );
  }

  Future<Map<String, dynamic>> uploadTeacherMaterial({
    required int subjectId,
    required String title,
    required String description,
    required String filePath,
    String visibility = 'students',
  }) async {
    final _UploadFile file = await _fromPath(filePath);
    return uploadTeacherMaterialBytes(
      subjectId: subjectId,
      title: title,
      description: description,
      bytes: file.bytes,
      originalName: file.name,
      visibility: visibility,
    );
  }

  Future<Map<String, dynamic>> uploadTeacherMaterialBytes({
    required int subjectId,
    required String title,
    required String description,
    required Uint8List bytes,
    required String originalName,
    String visibility = 'students',
  }) async {
    if (subjectId <= 0) throw Exception('Materia non valida.');
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) throw Exception('Titolo del materiale obbligatorio.');
    final String normalizedVisibility = visibility.trim().toLowerCase();
    if (!{'students', 'private'}.contains(normalizedVisibility)) {
      throw Exception('Visibilità materiale non valida.');
    }
    _validateSize(bytes, teacherMaterialMaxSize, 250);
    final String name = _requiredName(originalName);
    final String type = _teacherMimeType(name);
    final String hash = _sha256(bytes);
    final Map<String, dynamic> authorization = await _postJson(
      '/teacher/materials/upload-request',
      <String, dynamic>{
        'subject_id': subjectId,
        'original_name': name,
        'mime_type': type,
        'size': bytes.length,
        'file_hash': hash,
      },
      'Non è stato possibile autorizzare il materiale docente.',
    );
    if (authorization['allowed'] != true) throw Exception('Il caricamento del materiale docente non è autorizzato.');
    final String pathname = _requiredString(authorization, 'pathname');
    final String token = _requiredString(authorization, 'upload_token');
    final Map<String, dynamic> blob = await _requestBlobUpload(
      uploadKind: 'teacher_material',
      pathname: pathname,
      mimeType: type,
      size: bytes.length,
      fileHash: hash,
      uploadToken: token,
      subjectId: subjectId,
    );
    await _putBytes(bytes: bytes, mimeType: type, presignedUrl: _requiredString(blob, 'presigned_url'));
    return _postJson(
      '/teacher/materials/complete',
      <String, dynamic>{
        'subject_id': subjectId,
        'title': normalizedTitle,
        'description': description.trim(),
        'original_name': name,
        'stored_name': pathname,
        'file_path': pathname,
        'mime_type': type,
        'size': bytes.length,
        'file_hash': hash,
        'visibility': normalizedVisibility,
        'upload_token': token,
      },
      'Non è stato possibile registrare il materiale docente.',
    );
  }

  Future<Map<String, dynamic>> uploadQuestionAttachment({
    required String department,
    required String course,
    required String subject,
    required String filePath,
    required String questionId,
  }) async {
    final _UploadFile file = await _fromPath(filePath);
    return uploadQuestionAttachmentBytes(
      department: department,
      course: course,
      subject: subject,
      questionId: questionId,
      bytes: file.bytes,
      originalName: file.name,
    );
  }

  Future<Map<String, dynamic>> uploadQuestionAttachmentBytes({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required Uint8List bytes,
    required String originalName,
  }) async {
    final String dep = department.trim();
    final String courseValue = course.trim();
    final String subjectValue = subject.trim();
    final String question = questionId.trim();
    if (dep.isEmpty || courseValue.isEmpty || subjectValue.isEmpty) throw Exception('Dati della materia non validi.');
    if (question.isEmpty) throw Exception('La domanda deve essere salvata prima di aggiungere allegati.');
    _validateSize(bytes, questionAttachmentMaxSize, 50);
    final String name = _requiredName(originalName);
    final String type = _questionMimeType(name);
    final String hash = _sha256(bytes);
    final Map<String, dynamic> authorization = await _postJson(
      '/question-attachments/upload-request',
      <String, dynamic>{
        'department': dep,
        'course': courseValue,
        'subject': subjectValue,
        'question_id': question,
        'original_name': name,
        'mime_type': type,
        'size': bytes.length,
        'file_hash': hash,
      },
      'Non è stato possibile autorizzare l’allegato.',
    );
    if (authorization['allowed'] != true) throw Exception('Il caricamento dell’allegato non è autorizzato.');
    final String attachmentId = _requiredString(authorization, 'attachment_id');
    final String pathname = _requiredString(authorization, 'pathname');
    final String token = _requiredString(authorization, 'upload_token');
    final Map<String, dynamic> blob = await _requestBlobUpload(
      uploadKind: 'question_attachment',
      pathname: pathname,
      mimeType: type,
      size: bytes.length,
      fileHash: hash,
      uploadToken: token,
      attachmentId: attachmentId,
    );
    await _putBytes(bytes: bytes, mimeType: type, presignedUrl: _requiredString(blob, 'presigned_url'));
    return _postJson(
      '/question-attachments/complete',
      <String, dynamic>{
        'department': dep,
        'course': courseValue,
        'subject': subjectValue,
        'attachment_id': attachmentId,
        'original_name': name,
        'mime_type': type,
        'pathname': pathname,
        'size': bytes.length,
        'file_hash': hash,
        'upload_token': token,
      },
      'Non è stato possibile completare l’allegato.',
    );
  }

  Future<Map<String, dynamic>> uploadMaterialPublication({
    required int subjectId,
    required String title,
    required String description,
    required String filePath,
    Future<void> Function()? onPossibleDuplicate,
  }) async {
    final _UploadFile file = await _fromPath(filePath);
    return uploadMaterialPublicationBytes(
      subjectId: subjectId,
      title: title,
      description: description,
      bytes: file.bytes,
      originalName: file.name,
      onPossibleDuplicate: onPossibleDuplicate,
    );
  }

  Future<Map<String, dynamic>> uploadMaterialPublicationBytes({
    required int subjectId,
    required String title,
    required String description,
    required Uint8List bytes,
    required String originalName,
    Future<void> Function()? onPossibleDuplicate,
  }) async {
    if (subjectId <= 0) throw Exception('Materia non valida.');
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) throw Exception('Titolo del materiale obbligatorio.');
    _validateSize(bytes, materialPublicationMaxSize, 250);
    final String name = _requiredName(originalName);
    final String type = _groupMimeType(name);
    final String hash = _sha256(bytes);
    final Map<String, dynamic> authorization = await _postJson(
      '/material_publication/upload-request',
      <String, dynamic>{
        'subject_id': subjectId,
        'title': normalizedTitle,
        'description': description.trim(),
        'original_name': name,
        'mime_type': type,
        'size': bytes.length,
        'file_hash': hash,
      },
      'Non è stato possibile autorizzare la condivisione del materiale.',
    );
    if (authorization['allowed'] != true) throw Exception('La condivisione del materiale non è autorizzata.');
    final bool duplicate = authorization['possible_duplicate'] == true;
    final int? duplicateId = _positiveInt(authorization['possible_duplicate_material_id']);
    if (duplicate && onPossibleDuplicate != null) await onPossibleDuplicate();
    final String pathname = _requiredString(authorization, 'pathname');
    final String token = _requiredString(authorization, 'upload_token');
    final Map<String, dynamic> blob = await _requestBlobUpload(
      uploadKind: 'material_publication',
      pathname: pathname,
      mimeType: type,
      size: bytes.length,
      fileHash: hash,
      uploadToken: token,
      subjectId: subjectId,
    );
    await _putBytes(bytes: bytes, mimeType: type, presignedUrl: _requiredString(blob, 'presigned_url'));
    final Map<String, dynamic> result = await _postJson(
      '/material_publication/complete',
      <String, dynamic>{
        'subject_id': subjectId,
        'title': normalizedTitle,
        'description': description.trim(),
        'original_name': name,
        'stored_name': pathname,
        'file_path': pathname,
        'mime_type': type,
        'size': bytes.length,
        'file_hash': hash,
      },
      'Non è stato possibile inviare il materiale in revisione.',
    );
    return <String, dynamic>{
      ...result,
      'possible_duplicate': duplicate,
      'possible_duplicate_material_id': duplicateId,
    };
  }

  void _validateSize(Uint8List bytes, int max, int maxMb) {
    if (bytes.isEmpty) throw Exception('Il file è vuoto.');
    if (bytes.length > max) throw Exception('Il file supera la dimensione massima consentita di $maxMb MB.');
  }

  String _requiredName(String value) {
    final String name = value.trim();
    if (name.isEmpty || name == '.' || name == '..') throw Exception('Nome del file non valido.');
    return name;
  }

  String _requiredString(Map<String, dynamic> data, String key) {
    final String value = data[key]?.toString().trim() ?? '';
    if (value.isEmpty) throw Exception('Il server non ha restituito $key.');
    return value;
  }

  int? _positiveInt(dynamic value) {
    final int? parsed = value is int
        ? value
        : value is num
            ? value.toInt()
            : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  String _groupMimeType(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    throw Exception('Tipo di file non supportato.');
  }

  String _teacherMimeType(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    throw Exception('Tipo di file non supportato.');
  }

  String _questionMimeType(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    throw Exception('Tipo di allegato non supportato.');
  }
}

class _UploadFile {
  final String name;
  final Uint8List bytes;
  final String? mimeType;

  const _UploadFile({
    required this.name,
    required this.bytes,
    this.mimeType,
  });
}
