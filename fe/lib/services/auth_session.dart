import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../social/social_models.dart';


class AuthSession extends ChangeNotifier {
  AuthSession._();


  static final AuthSession instance =
      AuthSession._();


  static const String _accessTokenKey =
      'studentlab_access_token';


  final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();


  SocialUser? _currentUser;

  String? _accessToken;

  bool _initialized =
      false;


  SocialUser? get currentUser {
    return _currentUser;
  }


  String? get accessToken {
    return _accessToken;
  }


  bool get isAuthenticated {
    return _currentUser != null &&
        _accessToken != null &&
        _accessToken!.isNotEmpty;
  }


  bool get isGuest {
    return !isAuthenticated;
  }


  bool get initialized {
    return _initialized;
  }


  int? get currentUserId {
    return _currentUser?.id;
  }


  bool get isStudent {
    return _currentUser?.type ==
        SocialUserType.student;
  }


  bool get isTeacher {
    return _currentUser?.type ==
        SocialUserType.teacher;
  }


  bool get isTeacherPending {
    final SocialUser? user =
        _currentUser;

    if (user == null) {
      return false;
    }

    return user.isTeacherPending;
  }


  bool get isVerifiedTeacher {
    final SocialUser? user =
        _currentUser;

    if (user == null) {
      return false;
    }

    return user.isVerifiedTeacher;
  }


  bool get isTeacherRejected {
    final SocialUser? user =
        _currentUser;

    if (user == null) {
      return false;
    }

    return user.isTeacherRejected;
  }


  bool get canAccessTeacherArea {
    return isAuthenticated &&
        isVerifiedTeacher;
  }


  bool get availableForHelp {
    return _currentUser
            ?.availableForHelp ??
        false;
  }


  bool get availableForPrivateLessons {
    return _currentUser
            ?.availableForPrivateLessons ??
        false;
  }


  Future<String?> loadStoredToken() async {
    final String? token =
        await _secureStorage.read(
      key:
          _accessTokenKey,
    );

    _accessToken =
        token;

    return token;
  }


  Future<void> setSession({
    required String accessToken,
    required SocialUser user,
  }) async {
    _accessToken =
        accessToken;

    _currentUser =
        user;

    await _secureStorage.write(
      key:
          _accessTokenKey,

      value:
          accessToken,
    );

    _initialized =
        true;

    notifyListeners();
  }


  void setRestoredSession({
    required String accessToken,
    required SocialUser user,
  }) {
    _accessToken =
        accessToken;

    _currentUser =
        user;

    _initialized =
        true;

    notifyListeners();
  }


  void updateUser(
    SocialUser user,
  ) {
    _currentUser =
        user;

    notifyListeners();
  }


  void markInitialized() {
    _initialized =
        true;

    notifyListeners();
  }


  Future<void> clear() async {
    _currentUser =
        null;

    _accessToken =
        null;

    await _secureStorage.delete(
      key:
          _accessTokenKey,
    );

    _initialized =
        true;

    notifyListeners();
  }
}