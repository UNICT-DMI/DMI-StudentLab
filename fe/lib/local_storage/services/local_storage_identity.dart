import '../../services/auth_session.dart';

class LocalStorageIdentity {
  LocalStorageIdentity._();

  static const int guestUserId = 0;

  static int get currentLocalUserId {
    return AuthSession.instance.currentUserId ??
        guestUserId;
  }

  static bool get isAuthenticated {
    return AuthSession.instance.isAuthenticated;
  }

  static bool get isGuest {
    return AuthSession.instance.isGuest;
  }

  static int resolve({
    int? userId,
  }) {
    return userId ??
        currentLocalUserId;
  }

  static bool isGuestId(
    int userId,
  ) {
    return userId ==
        guestUserId;
  }
}