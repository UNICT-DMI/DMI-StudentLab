class DeveloperAccessPolicy {
  static const String developerSystemRole = 'devsyst';
  static const String creatorRole = 'creator';

  const DeveloperAccessPolicy._();

  static bool canAccess(String? role) {
    final String normalizedRole =
        role?.trim().toLowerCase() ?? '';

    return normalizedRole == developerSystemRole ||
        normalizedRole == creatorRole;
  }

  static bool isDeveloperSystem(String? role) {
    return role?.trim().toLowerCase() ==
        developerSystemRole;
  }

  static bool isCreator(String? role) {
    return role?.trim().toLowerCase() ==
        creatorRole;
  }
}
