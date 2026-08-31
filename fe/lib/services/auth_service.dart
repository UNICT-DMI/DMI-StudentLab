import '../local_storage/local_storage.dart';

import '../social/social_models.dart';

import 'api_service.dart';

import 'auth_session.dart';

import 'device_key_service.dart';

import 'pending_registration_store.dart';

class AuthRegistrationResult {

  final String registrationId;

  final String email;

  final bool emailVerificationRequired;

  final int expiresIn;

  const AuthRegistrationResult({

    required this.registrationId,

    required this.email,

    required this.emailVerificationRequired,

    required this.expiresIn,

  });

}

class AuthLoginResult {

  final SocialUser? user;

  final bool emailVerificationRequired;

  final String? registrationId;

  final String? email;

  final int expiresIn;

  const AuthLoginResult({

this.user,

    required this.emailVerificationRequired,

this.registrationId,

this.email,

    required this.expiresIn,

  });

  bool get isAuthenticated {

    return user != null;

  }

}

class AuthVerificationResendResult {

  final String registrationId;

  final String email;

  final int expiresIn;

  final String message;

  const AuthVerificationResendResult({

    required this.registrationId,

    required this.email,

    required this.expiresIn,

    required this.message,

  });

}

class AuthService {

  final ApiService _apiService;

  final AuthSession _session;

  final LocalStorageService

      _localStorage;

  final PendingRegistrationStore

      _pendingStore;

  final DeviceKeyService

      _deviceKeys;

  AuthService({

    ApiService? apiService,

    AuthSession? session,

    LocalStorageService? localStorage,

    PendingRegistrationStore? pendingStore,

    DeviceKeyService? deviceKeys,

  })  : _apiService =

            apiService ??

                ApiService(),

        _session =

            session ??

                AuthSession.instance,

        _localStorage =

            localStorage ??

                LocalStorageService(),

        _pendingStore =

            pendingStore ??

                PendingRegistrationStore(),

        _deviceKeys =

            deviceKeys ??

                DeviceKeyService();

  Future<void> _publishDeviceKey() async {

    try {

      await _deviceKeys

          .publishDeviceKey();

    } catch (_) {

      return;

    }

  }

  Future<AuthRegistrationResult>

      register(

    SocialProfileDraft draft, {

    required String policyVersion,

    required bool privacyAcknowledged,

    required bool termsAccepted,

  }) async {

    final ApiRegistrationResponse

        registration =

        await _apiService

            .registerDraft(

      draft,

      policyVersion:

          policyVersion,

      privacyAcknowledged:

          privacyAcknowledged,

      termsAccepted:

          termsAccepted,

    );

    return AuthRegistrationResult(

      registrationId:

          registration.registrationId,

      email:

          registration.email,

      emailVerificationRequired:

          registration

              .emailVerificationRequired,

      expiresIn:

          registration.expiresIn,

    );

  }

  Future<SocialUser> verifyEmail({

    required String registrationId,

    required String code,

    SocialProfileDraft? draft,

  }) async {

    final String accessToken =

        await _apiService

            .verifyEmail(

      registrationId:

          registrationId,

      code:

          code,

    );

    final SocialUser user =

        await _apiService.getCurrentUser(

      token:

          accessToken,

    );

    await _pendingStore.markVerified(

      user.email,

      DateTime.now(),

    );

    await _session.setSession(

      accessToken:

          accessToken,

      user:

          user,

    );

    await _localStorage.prepareUserSession(

      user.id,

    );

    _publishDeviceKey();

    if (draft != null) {

      for (

        final SocialSubject subject

        in draft.subjects

      ) {

        await _apiService

            .addUserSubject(

          userId:

              user.id,

          subjectId:

              subject.id,

          grade:

              subject.grade,

          note:

              subject.note,

          canHelp:

              subject.canHelp,

          canGivePrivateLessons:

              subject

                  .canGivePrivateLessons,

        );

      }

      final SocialUser completeUser =

          await _apiService

              .getCurrentUser();

      _session.updateUser(

        completeUser,

      );

      return completeUser;

    }

    return user;

  }

  Future<SocialUser?> completeProfileExtras(
    SocialProfileDraft draft,
  ) async {
    for (
      final SocialAcademicPathDraft path
      in draft.additionalAcademicPaths
    ) {
      try {
        await _apiService.createAcademicPath(
          university: path.university,
          universityCode: path.universityCode,
          department: path.department,
          departmentCode: path.departmentCode,
          course: path.course,
          courseCode: path.courseCode,
          degreeType: path.degreeType,
          status: path.status,
          startYear: path.startYear,
          graduationYear: path.graduationYear,
          isCurrent: path.isCurrent,
          isPrimary: path.isPrimary,
        );
      } catch (_) {}
    }

    if (draft.type == SocialUserType.teacher) {
      for (
        final TeacherAssignmentDraft assignment
        in draft.teacherAssignments
      ) {
        try {
          await _apiService.createTeacherAssignment(
            subjectId: assignment.subjectId,
            offeringId: assignment.offeringId,
            isCurrent: assignment.isCurrent,
          );
        } catch (_) {}
      }
    }

    try {
      final SocialUser user =
          await _apiService.getCurrentUser();

      _session.updateUser(
        user,
      );

      return user;
    } catch (_) {
      return _session.currentUser;
    }
  }

  Future<AuthVerificationResendResult>

      resendVerificationCode({

    required String registrationId,

  }) async {

    final ApiEmailVerificationResendResponse

        response =

        await _apiService

            .resendEmailVerification(

      registrationId:

          registrationId,

    );

    return AuthVerificationResendResult(

      registrationId:

          response.registrationId,

      email:

          response.email,

      expiresIn:

          response.expiresIn,

      message:

          response.message,

    );

  }

  Future<AuthLoginResult> login({

    required String email,

    required String password,

  }) async {

    final ApiLoginResponse response =

        await _apiService.login(

      email:

          email,

      password:

          password,

    );

    if (response.authenticated) {

      final String? accessToken =

          response.accessToken;

      if (

        accessToken == null ||

        accessToken.isEmpty

      ) {

        throw Exception(

          'Token di accesso non disponibile.',

        );

      }

      final SocialUser user =

          await _completeAuthentication(

        accessToken,

      );

      return AuthLoginResult(

        user:

            user,

        emailVerificationRequired:

            false,

        expiresIn:

            0,

      );

    }

    if (

      response.emailVerificationRequired

    ) {

      return AuthLoginResult(

        emailVerificationRequired:

            true,

        registrationId:

            response.registrationId,

        email:

            response.email,

        expiresIn:

            response.expiresIn,

      );

    }

    throw Exception(

      'Non è stato possibile completare l’accesso.',

    );

  }

  Future<SocialUser>

      _completeAuthentication(

    String accessToken,

  ) async {

    final SocialUser user =

        await _apiService

            .getCurrentUser(

      token:

          accessToken,

    );

    await _session.setSession(

      accessToken:

          accessToken,

      user:

          user,

    );

    await _localStorage

        .prepareUserSession(

      user.id,

    );

    _publishDeviceKey();

    return user;

  }

  Future<SocialUser?>

      restoreSession() async {

    final String? token =

        await _session

            .loadStoredToken();

    if (

      token == null ||

      token.isEmpty

    ) {

      _session.markInitialized();

      return null;

    }

    try {

      final SocialUser user =

          await _apiService

              .getCurrentUser(

        token:

            token,

      );

      _session.setRestoredSession(

        accessToken:

            token,

        user:

            user,

      );

      await _localStorage

          .prepareUserSession(

        user.id,

      );

      _publishDeviceKey();

      return user;

    } catch (_) {

      await _session.clear();

      return null;

    }

  }

  Future<SocialUser?>

      refreshCurrentUser() async {

    if (!_session.isAuthenticated) {

      return null;

    }

    try {

      final SocialUser user =

          await _apiService

              .getCurrentUser();

      _session.updateUser(

        user,

      );

      return user;

    } catch (_) {

      await _session.clear();

      return null;

    }

  }

  Future<List<SocialAcademicPath>>

      getCurrentUserAcademicPaths() async {

    final int? userId =

        _session.currentUserId;

    if (userId == null) {

      throw Exception(

        'Utente non autenticato.',

      );

    }

    return _apiService

        .getUserAcademicPaths(

      userId,

    );

  }

  Future<SocialAcademicPath>

      addAcademicPath({

    required String university,

    required String universityCode,

    required String department,

    required String departmentCode,

    required String course,

    required String courseCode,

    String degreeType = '',

    AcademicPathStatus status =

        AcademicPathStatus.enrolled,

    int? startYear,

    int? graduationYear,

    bool isCurrent = false,

    bool isPrimary = false,

  }) async {

    final SocialAcademicPath path =

        await _apiService

            .createAcademicPath(

      university:

          university,

      universityCode:

          universityCode,

      department:

          department,

      departmentCode:

          departmentCode,

      course:

          course,

      courseCode:

          courseCode,

      degreeType:

          degreeType,

      status:

          status,

      startYear:

          startYear,

      graduationYear:

          graduationYear,

      isCurrent:

          isCurrent,

      isPrimary:

          isPrimary,

    );

    await refreshCurrentUser();

    return path;

  }

  Future<SocialAcademicPath>

      updateAcademicPath({

    required int academicPathId,

    String? university,

    String? universityCode,

    String? department,

    String? departmentCode,

    String? course,

    String? courseCode,

    String? degreeType,

    AcademicPathStatus? status,

    int? startYear,

    bool clearStartYear = false,

    int? graduationYear,

    bool clearGraduationYear = false,

    bool? isCurrent,

    bool? isPrimary,

  }) async {

    final SocialAcademicPath path =

        await _apiService

            .updateAcademicPath(

      academicPathId:

          academicPathId,

      university:

          university,

      universityCode:

          universityCode,

      department:

          department,

      departmentCode:

          departmentCode,

      course:

          course,

      courseCode:

          courseCode,

      degreeType:

          degreeType,

      status:

          status,

      startYear:

          startYear,

      clearStartYear:

          clearStartYear,

      graduationYear:

          graduationYear,

      clearGraduationYear:

          clearGraduationYear,

      isCurrent:

          isCurrent,

      isPrimary:

          isPrimary,

    );

    await refreshCurrentUser();

    return path;

  }

  Future<SocialAcademicPath>

      setCurrentAcademicPath(

    int academicPathId,

  ) async {

    final SocialAcademicPath path =

        await _apiService

            .setCurrentAcademicPath(

      academicPathId,

    );

    await refreshCurrentUser();

    return path;

  }

  Future<SocialAcademicPath>

      setPrimaryAcademicPath(

    int academicPathId,

  ) async {

    final SocialAcademicPath path =

        await _apiService

            .setPrimaryAcademicPath(

      academicPathId,

    );

    await refreshCurrentUser();

    return path;

  }

  Future<void> removeAcademicPath(

    int academicPathId,

  ) async {

    await _apiService

        .removeAcademicPath(

      academicPathId,

    );

    await refreshCurrentUser();

  }

  Future<Map<String, dynamic>> contactUser({
    required int userId,
    required String requestType,
    int? subjectId,
    required String subject,
    required String message,
  }) async {
    if (!_session.isAuthenticated || _session.currentUserId == null) {
      throw Exception('Utente non autenticato.');
    }

    if (userId <= 0) {
      throw ArgumentError('Identificativo utente non valido.');
    }

    if (userId == _session.currentUserId) {
      throw Exception('Non puoi contattare il tuo stesso account.');
    }

    final String normalizedRequestType = requestType.trim().toLowerCase();

    if (!{
      'general',
      'help',
      'private_lesson',
    }.contains(normalizedRequestType)) {
      throw ArgumentError('Tipo di richiesta non valido.');
    }

    if ((normalizedRequestType == 'help' ||
            normalizedRequestType == 'private_lesson') &&
        (subjectId == null || subjectId <= 0)) {
      throw ArgumentError('Seleziona una materia valida.');
    }

    final String normalizedSubject = subject.trim();
    final String normalizedMessage = message.trim();

    if (normalizedSubject.isEmpty) {
      throw ArgumentError('Inserisci l’oggetto.');
    }

    if (normalizedSubject.length > 160 ||
        normalizedSubject.contains('\n') ||
        normalizedSubject.contains('\r')) {
      throw ArgumentError('Oggetto non valido.');
    }

    if (normalizedMessage.isEmpty) {
      throw ArgumentError('Inserisci un messaggio.');
    }

    if (normalizedMessage.length > 5000) {
      throw ArgumentError('Il messaggio è troppo lungo.');
    }

    return _apiService.contactUser(
      userId: userId,
      requestType: normalizedRequestType,
      subjectId: subjectId,
      subject: normalizedSubject,
      message: normalizedMessage,
    );
  }

  Future<void> logout() async {

    final int? userId =

        _session.currentUserId;

    if (userId != null) {

      await _localStorage

          .onLogout(

        userId,

      );

    }

    await _session.clear();

  }

}