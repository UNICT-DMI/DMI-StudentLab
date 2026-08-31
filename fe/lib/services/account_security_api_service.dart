import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session.dart';

class PasswordResetStartResult {
  final String requestId;
  final String message;

  const PasswordResetStartResult({
    required this.requestId,
    required this.message,
  });
}

class EmailChangeStartResult {
  final String requestId;
  final String newEmail;
  final String message;

  const EmailChangeStartResult({
    required this.requestId,
    required this.newEmail,
    required this.message,
  });
}

class PendingRegistrationUpdateResult {
  final String registrationId;
  final String email;
  final String message;
  final int? expiresIn;

  const PendingRegistrationUpdateResult({
    required this.registrationId,
    required this.email,
    required this.message,
    this.expiresIn,
  });
}

class AccountSecurityApiService {
  static const String _baseUrl =
      'https://dmi-student-lab.vercel.app';

  Uri _uri(String path) {
    final Uri base = Uri.parse(_baseUrl);
    return base.replace(
      path: path.startsWith('/') ? path : '/$path',
    );
  }

  Map<String, String> get _jsonHeaders => const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Map<String, String> get _authHeaders {
    final String? token =
        AuthSession.instance.accessToken;

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'Utente non autenticato.',
      );
    }

    return {
      ..._jsonHeaders,
      'Authorization':
          'Bearer ${token.trim()}',
    };
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
  }) async {
    final http.Response response =
        await http.post(
      _uri(path),
      headers:
          authenticated
              ? _authHeaders
              : _jsonHeaders,
      body: jsonEncode(body),
    );

    dynamic decoded;
    if (response.body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded,
        );
      }
      return <String, dynamic>{};
    }

    String message =
        'Operazione non completata.';

    if (decoded is Map) {
      final dynamic detail =
          decoded['detail'] ??
          decoded['error'];

      if (detail is String &&
          detail.trim().isNotEmpty) {
        message = detail.trim();
      }
    }

    throw Exception(message);
  }

  Future<PasswordResetStartResult>
      startPasswordReset({
    required String email,
  }) async {
    final Map<String, dynamic> data =
        await _post(
      '/auth/password/forgot',
      {
        'email': email.trim(),
      },
    );

    return PasswordResetStartResult(
      requestId:
          data['request_id']
                  ?.toString() ??
              '',
      message:
          data['message']
                  ?.toString() ??
              'Controlla la tua email.',
    );
  }

  Future<String> resetPassword({
    required String requestId,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final Map<String, dynamic> data =
        await _post(
      '/auth/password/reset',
      {
        'request_id': requestId,
        'code': code.trim(),
        'new_password': newPassword,
        'confirm_password':
            confirmPassword,
      },
    );

    return data['message']?.toString() ??
        'Password aggiornata.';
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final Map<String, dynamic> data =
        await _post(
      '/auth/password/change',
      {
        'current_password':
            currentPassword,
        'new_password':
            newPassword,
        'confirm_password':
            confirmPassword,
      },
      authenticated: true,
    );

    return data['message']?.toString() ??
        'Password aggiornata.';
  }

  Future<EmailChangeStartResult>
      startEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    final Map<String, dynamic> data =
        await _post(
      '/auth/email/change/start',
      {
        'current_password':
            currentPassword,
        'new_email': newEmail.trim(),
      },
      authenticated: true,
    );

    return EmailChangeStartResult(
      requestId:
          data['request_id']
                  ?.toString() ??
              '',
      newEmail:
          data['new_email']
                  ?.toString() ??
              newEmail.trim(),
      message:
          data['message']
                  ?.toString() ??
              'Codice inviato.',
    );
  }

  Future<String> completeEmailChange({
    required String requestId,
    required String code,
  }) async {
    final Map<String, dynamic> data =
        await _post(
      '/auth/email/change/complete',
      {
        'request_id': requestId,
        'code': code.trim(),
      },
      authenticated: true,
    );

    return data['email']?.toString() ?? '';
  }

  Future<PendingRegistrationUpdateResult>
      changePendingRegistrationEmail({
    required String registrationId,
    required String currentPassword,
    required String newEmail,
  }) async {
    final Map<String, dynamic> data =
        await _post(
      '/auth/registration/email/change',
      {
        'registration_id':
            registrationId,
        'current_password':
            currentPassword,
        'new_email':
            newEmail.trim(),
      },
    );

    return PendingRegistrationUpdateResult(
      registrationId:
          data['registration_id']
                  ?.toString() ??
              registrationId,
      email:
          data['email']
                  ?.toString() ??
              newEmail.trim(),
      message:
          data['message']
                  ?.toString() ??
              'Email aggiornata.',
      expiresIn:
          _asNullableInt(
        data['expires_in'],
      ),
    );
  }

  Future<PendingRegistrationUpdateResult>
      changePendingRegistrationPassword({
    required String registrationId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final Map<String, dynamic> data =
        await _post(
      '/auth/registration/password/change',
      {
        'registration_id':
            registrationId,
        'current_password':
            currentPassword,
        'new_password':
            newPassword,
        'confirm_password':
            confirmPassword,
      },
    );

    return PendingRegistrationUpdateResult(
      registrationId:
          data['registration_id']
                  ?.toString() ??
              registrationId,
      email:
          data['email']
                  ?.toString() ??
              '',
      message:
          data['message']
                  ?.toString() ??
              'Password aggiornata.',
      expiresIn:
          _asNullableInt(
        data['expires_in'],
      ),
    );
  }

  static int? _asNullableInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(
      value.toString(),
    );
  }
}
