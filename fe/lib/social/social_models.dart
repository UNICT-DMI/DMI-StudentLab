enum SocialUserType {
  student,
  teacher,
}

enum TeacherVerificationStatus {
  notRequired,
  pending,
  verified,
  rejected,
}

enum GradeVerificationStatus {
  none,
  pending,
  verified,
  rejected,
}

enum AcademicPathStatus {
  enrolled,
  graduated,
  suspended,
  withdrawn,
  transferred,
}

enum AcademicPathVerificationStatus {
  notRequired,
  pending,
  verified,
  rejected,
}

enum AcademicTitleVerificationStatus {
  notRequired,
  pending,
  verified,
  rejected,
}

enum TeacherAssignmentVerificationStatus {
  pending,
  verified,
  rejected,
}

enum ReviewModerationStatus {
  pending,
  approved,
  rejected,
  hidden,
}

class AcademicUniversity {
  final String code;

  final String name;

  const AcademicUniversity({
    required this.code,
    required this.name,
  });

  factory AcademicUniversity.fromJson(
    Map<String, dynamic> json,
  ) {
    return AcademicUniversity(
      code:
          json['code']
                  ?.toString() ??
              '',

      name:
          json['name']
                  ?.toString() ??
              '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code':
          code,

      'name':
          name,
    };
  }

  @override
  bool operator ==(
    Object other,
  ) {
    return identical(
          this,
          other,
        ) ||
        other is AcademicUniversity &&
            other.code ==
                code;
  }

  @override
  int get hashCode {
    return code.hashCode;
  }
}

class AcademicDepartment {
  final String code;

  final String name;

  const AcademicDepartment({
    required this.code,
    required this.name,
  });

  factory AcademicDepartment.fromJson(
    Map<String, dynamic> json,
  ) {
    return AcademicDepartment(
      code:
          json['code']
                  ?.toString() ??
              '',

      name:
          json['name']
                  ?.toString() ??
              '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code':
          code,

      'name':
          name,
    };
  }

  @override
  bool operator ==(
    Object other,
  ) {
    return identical(
          this,
          other,
        ) ||
        other is AcademicDepartment &&
            other.code ==
                code;
  }

  @override
  int get hashCode {
    return code.hashCode;
  }
}

class AcademicCourse {
  final String code;

  final String name;

  final String degreeType;

  const AcademicCourse({
    required this.code,
    required this.name,
    this.degreeType = '',
  });

  factory AcademicCourse.fromJson(
    Map<String, dynamic> json,
  ) {
    return AcademicCourse(
      code:
          json['code']
                  ?.toString() ??
              '',

      name:
          json['name']
                  ?.toString() ??
              '',

      degreeType:
          json['degree_type']
                  ?.toString() ??
              '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code':
          code,

      'name':
          name,

      'degree_type':
          degreeType,
    };
  }

  @override
  bool operator ==(
    Object other,
  ) {
    return identical(
          this,
          other,
        ) ||
        other is AcademicCourse &&
            other.code ==
                code;
  }

  @override
  int get hashCode {
    return code.hashCode;
  }
}

class SocialAcademicPathDraft {
  final String university;
  final String universityCode;
  final String department;
  final String departmentCode;
  final String course;
  final String courseCode;
  final String degreeType;
  final AcademicPathStatus status;
  final int? startYear;
  final int? graduationYear;
  final bool isCurrent;
  final bool isPrimary;

  const SocialAcademicPathDraft({
    required this.university,
    required this.universityCode,
    required this.department,
    required this.departmentCode,
    required this.course,
    required this.courseCode,
    this.degreeType = '',
    this.status = AcademicPathStatus.enrolled,
    this.startYear,
    this.graduationYear,
    this.isCurrent = false,
    this.isPrimary = false,
  });

  bool get isGraduated =>
      status ==
      AcademicPathStatus.graduated;

  bool get isEnrolled =>
      status ==
      AcademicPathStatus.enrolled;

  String get pathTypeLabel {
    return academicPathTypeLabel(
      degreeType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'university': university,
      'university_code': universityCode,
      'department': department,
      'department_code': departmentCode,
      'course': course,
      'course_code': courseCode,
      'degree_type': degreeType,
      'status': _academicPathStatusToApi(status),
      'start_year': startYear,
      'graduation_year': graduationYear,
      'is_current': isCurrent,
      'is_primary': isPrimary,
    };
  }

  factory SocialAcademicPathDraft.fromJson(
    Map<String, dynamic> json,
  ) {
    return SocialAcademicPathDraft(
      university: json['university']?.toString() ?? '',
      universityCode: json['university_code']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      departmentCode: json['department_code']?.toString() ?? '',
      course: json['course']?.toString() ?? '',
      courseCode: json['course_code']?.toString() ?? '',
      degreeType: json['degree_type']?.toString() ?? '',
      status: _academicPathStatusFromValue(json['status']),
      startYear: _toInt(json['start_year']),
      graduationYear: _toInt(json['graduation_year']),
      isCurrent: _toBool(json['is_current']) ?? false,
      isPrimary: _toBool(json['is_primary']) ?? false,
    );
  }
}

String academicPathTypeLabel(
  String degreeType,
) {
  final String value =
      degreeType.trim();

  if (value.isEmpty) {
    return 'Percorso universitario';
  }

  final String upper =
      value.toUpperCase();

  if (
    upper.startsWith('LMG') ||
    upper.contains('CICLO UNICO')
  ) {
    return 'Laurea magistrale a ciclo unico · $value';
  }

  if (
    upper.startsWith('LM-') ||
    RegExp(r'^LM\d').hasMatch(
      upper,
    )
  ) {
    return 'Laurea magistrale · Classe $value';
  }

  if (
    upper.startsWith('L-') ||
    RegExp(r'^L\d').hasMatch(
      upper,
    )
  ) {
    return 'Laurea triennale · Classe $value';
  }

  if (upper.contains('DOTT')) {
    return 'Dottorato di ricerca';
  }

  if (
    upper.contains('MASTER') &&
    (
      upper.contains('II') ||
      upper.contains('2')
    )
  ) {
    return 'Master di II livello';
  }

  if (upper.contains('MASTER')) {
    return 'Master di I livello';
  }

  if (
    upper.contains('SPECIAL') ||
    upper.contains('SCUOLA')
  ) {
    return 'Scuola di specializzazione · $value';
  }

  return 'Tipo di percorso · $value';
}

class SocialAcademicPath {
  final int id;

  final int userId;

  final String university;

  final String universityCode;

  final String department;

  final String departmentCode;

  final String course;

  final String courseCode;

  final String degreeType;

  final AcademicPathStatus status;

  final AcademicPathVerificationStatus
      verificationStatus;

  final int? verifiedBy;

  final DateTime? verifiedAt;

  final int? startYear;

  final int? graduationYear;

  final bool isCurrent;

  final bool isPrimary;

  const SocialAcademicPath({
    required this.id,
    required this.userId,
    required this.university,
    required this.universityCode,
    required this.department,
    required this.departmentCode,
    required this.course,
    required this.courseCode,
    this.degreeType = '',
    this.status =
        AcademicPathStatus.enrolled,
    this.verificationStatus =
        AcademicPathVerificationStatus
            .pending,
    this.verifiedBy,
    this.verifiedAt,
    this.startYear,
    this.graduationYear,
    this.isCurrent = false,
    this.isPrimary = false,
  });

  bool get isEnrolled {
    return status ==
        AcademicPathStatus.enrolled;
  }

  bool get isGraduated {
    return status ==
        AcademicPathStatus.graduated;
  }

  bool get isSuspended {
    return status ==
        AcademicPathStatus.suspended;
  }

  bool get isWithdrawn {
    return status ==
        AcademicPathStatus.withdrawn;
  }

  bool get isTransferred {
    return status ==
        AcademicPathStatus.transferred;
  }

  bool get isVerificationPending {
    return verificationStatus ==
        AcademicPathVerificationStatus
            .pending;
  }

  bool get isVerified {
    return verificationStatus ==
        AcademicPathVerificationStatus
            .verified;
  }

  bool get isVerificationRejected {
    return verificationStatus ==
        AcademicPathVerificationStatus
            .rejected;
  }

  String get statusApiValue {
    return _academicPathStatusToApi(
      status,
    );
  }

  String get verificationStatusApiValue {
    return _academicPathVerificationStatusToApi(
      verificationStatus,
    );
  }

  factory SocialAcademicPath.fromJson(
    Map<String, dynamic> json,
  ) {
    final AcademicPathStatus status =
        _academicPathStatusFromValue(
      json['status'],
    );

    return SocialAcademicPath(
      id:
          _toInt(
            json['id'],
          ) ??
          0,

      userId:
          _toInt(
            json['user_id'],
          ) ??
          0,

      university:
          json['university']
                  ?.toString() ??
              '',

      universityCode:
          json['university_code']
                  ?.toString() ??
              '',

      department:
          json['department']
                  ?.toString() ??
              '',

      departmentCode:
          json['department_code']
                  ?.toString() ??
              '',

      course:
          json['course']
                  ?.toString() ??
              '',

      courseCode:
          json['course_code']
                  ?.toString() ??
              '',

      degreeType:
          json['degree_type']
                  ?.toString() ??
              '',

      status:
          status,

      verificationStatus:
          _academicPathVerificationStatusFromValue(
        json['verification_status'],
        status:
            status,
      ),

      verifiedBy:
          _toInt(
        json['verified_by'],
      ),

      verifiedAt:
          DateTime.tryParse(
        json['verified_at']
                ?.toString() ??
            '',
      ),

      startYear:
          _toInt(
        json['start_year'],
      ),

      graduationYear:
          _toInt(
        json['graduation_year'],
      ),

      isCurrent:
          _toBool(
            json['is_current'],
          ) ??
          false,

      isPrimary:
          _toBool(
            json['is_primary'],
          ) ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':
          id,

      'user_id':
          userId,

      'university':
          university,

      'university_code':
          universityCode,

      'department':
          department,

      'department_code':
          departmentCode,

      'course':
          course,

      'course_code':
          courseCode,

      'degree_type':
          degreeType.isEmpty
              ? null
              : degreeType,

      'status':
          statusApiValue,

      'verification_status':
          verificationStatusApiValue,

      'verified_by':
          verifiedBy,

      'verified_at':
          verifiedAt
              ?.toIso8601String(),

      'start_year':
          startYear,

      'graduation_year':
          graduationYear,

      'is_current':
          isCurrent,

      'is_primary':
          isPrimary,
    };
  }

  Map<String, dynamic>
      toCreateJson() {
    return {
      'university':
          university,

      'university_code':
          universityCode,

      'department':
          department,

      'department_code':
          departmentCode,

      'course':
          course,

      'course_code':
          courseCode,

      'degree_type':
          degreeType.isEmpty
              ? null
              : degreeType,

      'status':
          statusApiValue,

      'start_year':
          startYear,

      'graduation_year':
          graduationYear,

      'is_current':
          isCurrent,

      'is_primary':
          isPrimary,
    };
  }

  SocialAcademicPath copyWith({
    int? id,
    int? userId,
    String? university,
    String? universityCode,
    String? department,
    String? departmentCode,
    String? course,
    String? courseCode,
    String? degreeType,
    AcademicPathStatus? status,
    AcademicPathVerificationStatus?
        verificationStatus,
    int? verifiedBy,
    bool clearVerifiedBy = false,
    DateTime? verifiedAt,
    bool clearVerifiedAt = false,
    int? startYear,
    bool clearStartYear = false,
    int? graduationYear,
    bool clearGraduationYear = false,
    bool? isCurrent,
    bool? isPrimary,
  }) {
    return SocialAcademicPath(
      id:
          id ??
              this.id,

      userId:
          userId ??
              this.userId,

      university:
          university ??
              this.university,

      universityCode:
          universityCode ??
              this.universityCode,

      department:
          department ??
              this.department,

      departmentCode:
          departmentCode ??
              this.departmentCode,

      course:
          course ??
              this.course,

      courseCode:
          courseCode ??
              this.courseCode,

      degreeType:
          degreeType ??
              this.degreeType,

      status:
          status ??
              this.status,

      verificationStatus:
          verificationStatus ??
              this.verificationStatus,

      verifiedBy:
          clearVerifiedBy
              ? null
              : verifiedBy ??
                  this.verifiedBy,

      verifiedAt:
          clearVerifiedAt
              ? null
              : verifiedAt ??
                  this.verifiedAt,

      startYear:
          clearStartYear
              ? null
              : startYear ??
                  this.startYear,

      graduationYear:
          clearGraduationYear
              ? null
              : graduationYear ??
                  this.graduationYear,

      isCurrent:
          isCurrent ??
              this.isCurrent,

      isPrimary:
          isPrimary ??
              this.isPrimary,
    );
  }
}

class SocialAcademicTitleDraft {
  final String university;
  final String universityCode;
  final String department;
  final String departmentCode;
  final String course;
  final String courseCode;
  final String titleType;
  final int? graduationYear;
  final bool isPrimary;

  const SocialAcademicTitleDraft({
    required this.university,
    required this.universityCode,
    required this.department,
    required this.departmentCode,
    required this.course,
    required this.courseCode,
    required this.titleType,
    this.graduationYear,
    this.isPrimary = false,
  });

  String get titleTypeLabel {
    return academicTitleTypeLabel(
      titleType,
    );
  }

  factory SocialAcademicTitleDraft.fromLegacyPath(
    SocialAcademicPathDraft path,
  ) {
    return SocialAcademicTitleDraft(
      university: path.university,
      universityCode: path.universityCode,
      department: path.department,
      departmentCode: path.departmentCode,
      course: path.course,
      courseCode: path.courseCode,
      titleType: path.degreeType,
      graduationYear: path.graduationYear,
      isPrimary: path.isPrimary,
    );
  }

  SocialAcademicPathDraft toLegacyPathDraft() {
    return SocialAcademicPathDraft(
      university: university,
      universityCode: universityCode,
      department: department,
      departmentCode: departmentCode,
      course: course,
      courseCode: courseCode,
      degreeType: titleType,
      status: AcademicPathStatus.graduated,
      graduationYear: graduationYear,
      isCurrent: false,
      isPrimary: isPrimary,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'university': university,
      'university_code': universityCode,
      'department': department,
      'department_code': departmentCode,
      'course': course,
      'course_code': courseCode,
      'title_type': titleType,
      'graduation_year': graduationYear,
      'is_primary': isPrimary,
    };
  }

  factory SocialAcademicTitleDraft.fromJson(
    Map<String, dynamic> json,
  ) {
    return SocialAcademicTitleDraft(
      university: json['university']?.toString() ?? '',
      universityCode: json['university_code']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      departmentCode: json['department_code']?.toString() ?? '',
      course: json['course']?.toString() ?? '',
      courseCode: json['course_code']?.toString() ?? '',
      titleType: json['title_type']?.toString() ?? '',
      graduationYear: _toInt(json['graduation_year']),
      isPrimary: _toBool(json['is_primary']) ?? false,
    );
  }
}

String academicTitleTypeLabel(
  String titleType,
) {
  final String value =
      titleType.trim();

  if (value.isEmpty) {
    return 'Titolo accademico';
  }

  final String upper =
      value.toUpperCase();

  if (
    upper.startsWith('LMG') ||
    upper.contains('CICLO UNICO')
  ) {
    return 'Laurea magistrale a ciclo unico';
  }

  if (
    upper.startsWith('LM-') ||
    RegExp(r'^LM\d').hasMatch(
      upper,
    )
  ) {
    return 'Laurea magistrale';
  }

  if (
    upper.startsWith('L-') ||
    RegExp(r'^L\d').hasMatch(
      upper,
    )
  ) {
    return 'Laurea triennale';
  }

  if (upper.contains('DOTT')) {
    return 'Dottorato di ricerca';
  }

  if (
    upper.contains('MASTER') &&
    (
      upper.contains('II') ||
      upper.contains('2')
    )
  ) {
    return 'Master di II livello';
  }

  if (upper.contains('MASTER')) {
    return 'Master di I livello';
  }

  if (
    upper.contains('SPECIAL') ||
    upper.contains('SCUOLA')
  ) {
    return 'Scuola di specializzazione';
  }

  return value;
}

class SocialAcademicTitle {
  final int id;
  final int userId;
  final String university;
  final String universityCode;
  final String department;
  final String departmentCode;
  final String course;
  final String courseCode;
  final String titleType;
  final AcademicTitleVerificationStatus verificationStatus;
  final int? verifiedBy;
  final DateTime? verifiedAt;
  final int? graduationYear;
  final bool isPrimary;

  const SocialAcademicTitle({
    required this.id,
    required this.userId,
    required this.university,
    required this.universityCode,
    required this.department,
    required this.departmentCode,
    required this.course,
    required this.courseCode,
    required this.titleType,
    this.verificationStatus = AcademicTitleVerificationStatus.pending,
    this.verifiedBy,
    this.verifiedAt,
    this.graduationYear,
    this.isPrimary = false,
  });

  bool get isVerificationPending =>
      verificationStatus == AcademicTitleVerificationStatus.pending;

  bool get isVerified =>
      verificationStatus == AcademicTitleVerificationStatus.verified;

  bool get isVerificationRejected =>
      verificationStatus == AcademicTitleVerificationStatus.rejected;

  String get titleTypeLabel =>
      academicTitleTypeLabel(titleType);

  String get verificationStatusApiValue =>
      _academicTitleVerificationStatusToApi(verificationStatus);

  factory SocialAcademicTitle.fromJson(
    Map<String, dynamic> json,
  ) {
    return SocialAcademicTitle(
      id: _toInt(json['id']) ?? 0,
      userId: _toInt(json['user_id']) ?? 0,
      university: json['university']?.toString() ?? '',
      universityCode: json['university_code']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      departmentCode: json['department_code']?.toString() ?? '',
      course: json['course']?.toString() ?? '',
      courseCode: json['course_code']?.toString() ?? '',
      titleType: (json['title_type'] ?? json['degree_type'])?.toString() ?? '',
      verificationStatus: _academicTitleVerificationStatusFromValue(
        json['verification_status'],
      ),
      verifiedBy: _toInt(json['verified_by']),
      verifiedAt: DateTime.tryParse(
        json['verified_at']?.toString() ?? '',
      ),
      graduationYear: _toInt(json['graduation_year']),
      isPrimary: _toBool(json['is_primary']) ?? false,
    );
  }

  factory SocialAcademicTitle.fromLegacyPath(
    SocialAcademicPath path,
  ) {
    return SocialAcademicTitle(
      id: path.id,
      userId: path.userId,
      university: path.university,
      universityCode: path.universityCode,
      department: path.department,
      departmentCode: path.departmentCode,
      course: path.course,
      courseCode: path.courseCode,
      titleType: path.degreeType,
      verificationStatus: _academicTitleVerificationStatusFromPathStatus(
        path.verificationStatus,
      ),
      verifiedBy: path.verifiedBy,
      verifiedAt: path.verifiedAt,
      graduationYear: path.graduationYear,
      isPrimary: path.isPrimary,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'university': university,
      'university_code': universityCode,
      'department': department,
      'department_code': departmentCode,
      'course': course,
      'course_code': courseCode,
      'title_type': titleType,
      'verification_status': verificationStatusApiValue,
      'verified_by': verifiedBy,
      'verified_at': verifiedAt?.toIso8601String(),
      'graduation_year': graduationYear,
      'is_primary': isPrimary,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'university': university,
      'university_code': universityCode,
      'department': department,
      'department_code': departmentCode,
      'course': course,
      'course_code': courseCode,
      'title_type': titleType,
      'graduation_year': graduationYear,
      'is_primary': isPrimary,
    };
  }

  SocialAcademicTitle copyWith({
    int? id,
    int? userId,
    String? university,
    String? universityCode,
    String? department,
    String? departmentCode,
    String? course,
    String? courseCode,
    String? titleType,
    AcademicTitleVerificationStatus? verificationStatus,
    int? verifiedBy,
    bool clearVerifiedBy = false,
    DateTime? verifiedAt,
    bool clearVerifiedAt = false,
    int? graduationYear,
    bool clearGraduationYear = false,
    bool? isPrimary,
  }) {
    return SocialAcademicTitle(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      university: university ?? this.university,
      universityCode: universityCode ?? this.universityCode,
      department: department ?? this.department,
      departmentCode: departmentCode ?? this.departmentCode,
      course: course ?? this.course,
      courseCode: courseCode ?? this.courseCode,
      titleType: titleType ?? this.titleType,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedBy: clearVerifiedBy ? null : verifiedBy ?? this.verifiedBy,
      verifiedAt: clearVerifiedAt ? null : verifiedAt ?? this.verifiedAt,
      graduationYear: clearGraduationYear
          ? null
          : graduationYear ?? this.graduationYear,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

class AcademicTeacher {
  final int id;

  final String name;

  final int? userId;

  final bool isActive;

  const AcademicTeacher({
    required this.id,
    required this.name,
    this.userId,
    this.isActive = true,
  });

  factory AcademicTeacher.fromJson(
    Map<String, dynamic> json,
  ) {
    return AcademicTeacher(
      id:
          _toInt(
            json['id'],
          ) ??
          0,

      name:
          json['name']
                  ?.toString() ??
              '',

      userId:
          _toInt(
        json['user_id'],
      ),

      isActive:
          _toBool(
            json['is_active'],
          ) ??
          true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':
          id,

      'name':
          name,

      'user_id':
          userId,

      'is_active':
          isActive,
    };
  }
}

class SubjectOffering {
  final int id;

  final String module;

  final String channel;

  final String academicYear;

  final String sourceUrl;

  final bool isActive;

  final List<AcademicTeacher> teachers;

  const SubjectOffering({
    required this.id,
    this.module = '',
    this.channel = '',
    this.academicYear = '',
    this.sourceUrl = '',
    this.isActive = true,
    this.teachers = const [],
  });

  bool get hasModule {
    return module
        .trim()
        .isNotEmpty;
  }

  bool get hasChannel {
    return channel
        .trim()
        .isNotEmpty;
  }

  bool get hasTeachers {
    return teachers.isNotEmpty;
  }

  factory SubjectOffering.fromJson(
    Map<String, dynamic> json,
  ) {
    final List<AcademicTeacher>
        parsedTeachers =
        [];

    final dynamic teachersData =
        json['teachers'];

    if (teachersData is List) {
      for (
        final dynamic item
        in teachersData
      ) {
        if (item is Map) {
          parsedTeachers.add(
            AcademicTeacher.fromJson(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          );
        }
      }
    }

    return SubjectOffering(
      id:
          _toInt(
            json['id'],
          ) ??
          0,

      module:
          json['module']
                  ?.toString() ??
              '',

      channel:
          json['channel']
                  ?.toString() ??
              '',

      academicYear:
          json['academic_year']
                  ?.toString() ??
              '',

      sourceUrl:
          json['source_url']
                  ?.toString() ??
              '',

      isActive:
          _toBool(
            json['is_active'],
          ) ??
          true,

      teachers:
          parsedTeachers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':
          id,

      'module':
          module.isEmpty
              ? null
              : module,

      'channel':
          channel.isEmpty
              ? null
              : channel,

      'academic_year':
          academicYear.isEmpty
              ? null
              : academicYear,

      'source_url':
          sourceUrl.isEmpty
              ? null
              : sourceUrl,

      'is_active':
          isActive,

      'teachers':
          teachers
              .map(
                (
                  AcademicTeacher teacher,
                ) =>
                    teacher.toJson(),
              )
              .toList(),
    };
  }
}

class SocialSubject {
  final int id;

  final String code;

  final String name;

  final String university;

  final String universityCode;

  final String department;

  final String departmentCode;

  final String course;

  final String courseCode;

  final String degreeType;

  final int? studyYear;

  final List<SubjectOffering> offerings;

  final int? grade;

  final GradeVerificationStatus
      gradeVerificationStatus;

  final String note;

  final bool canHelp;

  final bool canGivePrivateLessons;

  final bool isActive;

  const SocialSubject({
    required this.id,
    this.code = '',
    required this.name,
    this.university = '',
    this.universityCode = '',
    required this.department,
    this.departmentCode = '',
    required this.course,
    this.courseCode = '',
    this.degreeType = '',
    this.studyYear,
    this.offerings = const [],
    this.grade,
    this.gradeVerificationStatus =
        GradeVerificationStatus.none,
    this.note = '',
    this.canHelp = false,
    this.canGivePrivateLessons = false,
    this.isActive = true,
  });

  bool get hasGrade {
    return grade != null;
  }

  bool get isGradePending {
    return grade != null &&
        gradeVerificationStatus ==
            GradeVerificationStatus.pending;
  }

  bool get isGradeVerified {
    return grade != null &&
        gradeVerificationStatus ==
            GradeVerificationStatus.verified;
  }

  bool get isGradeRejected {
    return grade != null &&
        gradeVerificationStatus ==
            GradeVerificationStatus.rejected;
  }

  bool get hasOfferings {
    return offerings.isNotEmpty;
  }

  factory SocialSubject.fromJson(
    Map<String, dynamic> json,
  ) {
    final Map<String, dynamic>
        subjectData;

    if (json['subject'] is Map) {
      subjectData =
          Map<String, dynamic>.from(
        json['subject'] as Map,
      );
    } else {
      subjectData =
          json;
    }

    final int? grade =
        _toInt(
      json['grade'],
    );

    final List<SubjectOffering>
        parsedOfferings =
        [];

    final dynamic offeringsData =
        subjectData['offerings'];

    if (offeringsData is List) {
      for (
        final dynamic item
        in offeringsData
      ) {
        if (item is Map) {
          parsedOfferings.add(
            SubjectOffering.fromJson(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          );
        }
      }
    }

    return SocialSubject(
      id:
          _toInt(
            subjectData['id'],
          ) ??
          0,

      code:
          subjectData['code']
                  ?.toString() ??
              '',

      name:
          subjectData['name']
                  ?.toString() ??
              '',

      university:
          subjectData['university']
                  ?.toString() ??
              '',

      universityCode:
          subjectData[
                      'university_code']
                  ?.toString() ??
              '',

      department:
          subjectData['department']
                  ?.toString() ??
              '',

      departmentCode:
          subjectData[
                      'department_code']
                  ?.toString() ??
              '',

      course:
          subjectData['course']
                  ?.toString() ??
              '',

      courseCode:
          subjectData['course_code']
                  ?.toString() ??
              '',

      degreeType:
          subjectData['degree_type']
                  ?.toString() ??
              '',

      studyYear:
          _toInt(
        subjectData['study_year'],
      ),

      offerings:
          parsedOfferings,

      grade:
          grade,

      gradeVerificationStatus:
          _gradeVerificationStatusFromValue(
        json['grade_status'] ??
            json[
                'grade_verification_status'],
        hasGrade:
            grade != null,
      ),

      note:
          json['note']
                  ?.toString() ??
              '',

      canHelp:
          _toBool(
            json['can_help'],
          ) ??
          false,

      canGivePrivateLessons:
          _toBool(
            json[
                'can_give_private_lessons'],
          ) ??
          false,

      isActive:
          _toBool(
            subjectData['is_active'],
          ) ??
          true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':
          id,

      'code':
          code,

      'name':
          name,

      'university':
          university,

      'university_code':
          universityCode,

      'department':
          department,

      'department_code':
          departmentCode,

      'course':
          course,

      'course_code':
          courseCode,

      'degree_type':
          degreeType,

      'study_year':
          studyYear,

      'offerings':
          offerings
              .map(
                (
                  SubjectOffering offering,
                ) =>
                    offering.toJson(),
              )
              .toList(),

      'grade':
          grade,

      'grade_status':
          gradeVerificationStatus.name,

      'note':
          note,

      'can_help':
          canHelp,

      'can_give_private_lessons':
          canGivePrivateLessons,

      'is_active':
          isActive,
    };
  }

  Map<String, dynamic>
      toUserSubjectJson() {
    return {
      'subject_id':
          id,

      'grade':
          grade,

      'note':
          note,

      'can_help':
          canHelp,

      'can_give_private_lessons':
          canGivePrivateLessons,
    };
  }

  SocialSubject copyWith({
    int? id,
    String? code,
    String? name,
    String? university,
    String? universityCode,
    String? department,
    String? departmentCode,
    String? course,
    String? courseCode,
    String? degreeType,
    int? studyYear,
    bool clearStudyYear = false,
    List<SubjectOffering>? offerings,
    int? grade,
    bool clearGrade = false,
    GradeVerificationStatus?
        gradeVerificationStatus,
    String? note,
    bool? canHelp,
    bool? canGivePrivateLessons,
    bool? isActive,
  }) {
    return SocialSubject(
      id:
          id ??
              this.id,

      code:
          code ??
              this.code,

      name:
          name ??
              this.name,

      university:
          university ??
              this.university,

      universityCode:
          universityCode ??
              this.universityCode,

      department:
          department ??
              this.department,

      departmentCode:
          departmentCode ??
              this.departmentCode,

      course:
          course ??
              this.course,

      courseCode:
          courseCode ??
              this.courseCode,

      degreeType:
          degreeType ??
              this.degreeType,

      studyYear:
          clearStudyYear
              ? null
              : studyYear ??
                  this.studyYear,

      offerings:
          offerings ??
              this.offerings,

      grade:
          clearGrade
              ? null
              : grade ??
                  this.grade,

      gradeVerificationStatus:
          gradeVerificationStatus ??
              this.gradeVerificationStatus,

      note:
          note ??
              this.note,

      canHelp:
          canHelp ??
              this.canHelp,

      canGivePrivateLessons:
          canGivePrivateLessons ??
              this.canGivePrivateLessons,

      isActive:
          isActive ??
              this.isActive,
    );
  }

  static GradeVerificationStatus
      _gradeVerificationStatusFromValue(
    dynamic value, {
    required bool hasGrade,
  }) {
    final String status =
        value
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    switch (status) {
      case 'pending':
        return GradeVerificationStatus
            .pending;

      case 'verified':
      case 'approved':
        return GradeVerificationStatus
            .verified;

      case 'rejected':
        return GradeVerificationStatus
            .rejected;

      case 'none':
        return GradeVerificationStatus
            .none;

      default:
        return hasGrade
            ? GradeVerificationStatus
                .pending
            : GradeVerificationStatus
                .none;
    }
  }
}

class TeacherAssignment {
  final int id;

  final int userId;

  final int subjectId;

  final int? offeringId;

  final TeacherAssignmentVerificationStatus
      verificationStatus;

  final int? verifiedBy;

  final DateTime? verifiedAt;

  final bool isCurrent;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  final SocialSubject subject;

  final SubjectOffering? offering;

  final String? teacherName;

  final String? teacherEmail;

  const TeacherAssignment({
    required this.id,
    required this.userId,
    required this.subjectId,
    this.offeringId,
    this.verificationStatus =
        TeacherAssignmentVerificationStatus
            .pending,
    this.verifiedBy,
    this.verifiedAt,
    this.isCurrent = true,
    this.createdAt,
    this.updatedAt,
    required this.subject,
    this.offering,
    this.teacherName,
    this.teacherEmail,
  });

  bool get isPending {
    return verificationStatus ==
        TeacherAssignmentVerificationStatus
            .pending;
  }

  bool get isVerified {
    return verificationStatus ==
        TeacherAssignmentVerificationStatus
            .verified;
  }

  bool get isRejected {
    return verificationStatus ==
        TeacherAssignmentVerificationStatus
            .rejected;
  }

  String get verificationStatusApiValue {
    switch (verificationStatus) {
      case TeacherAssignmentVerificationStatus
            .verified:
        return 'verified';

      case TeacherAssignmentVerificationStatus
            .rejected:
        return 'rejected';

      case TeacherAssignmentVerificationStatus
            .pending:
        return 'pending';
    }
  }

  factory TeacherAssignment.fromJson(
    Map<String, dynamic> json,
  ) {
    final Map<String, dynamic>
        subjectData =
        json['subject'] is Map
            ? Map<String, dynamic>.from(
                json['subject'] as Map,
              )
            : <String, dynamic>{};

    final SubjectOffering? offering =
        json['offering'] is Map
            ? SubjectOffering.fromJson(
                Map<String, dynamic>.from(
                  json['offering'] as Map,
                ),
              )
            : null;

    final Map<String, dynamic>? teacherData =
        json['teacher'] is Map
            ? Map<String, dynamic>.from(
                json['teacher'] as Map,
              )
            : null;

    final String? teacherName =
        teacherData == null
            ? null
            : '${teacherData['first_name'] ?? ''} ${teacherData['last_name'] ?? ''}'
                .trim();

    return TeacherAssignment(
      id:
          _toInt(
            json['id'],
          ) ??
          0,

      userId:
          _toInt(
            json['user_id'],
          ) ??
          0,

      subjectId:
          _toInt(
            json['subject_id'],
          ) ??
          0,

      offeringId:
          _toInt(
        json['offering_id'],
      ),

      verificationStatus:
          _teacherAssignmentVerificationStatusFromValue(
        json['verification_status'],
      ),

      verifiedBy:
          _toInt(
        json['verified_by'],
      ),

      verifiedAt:
          DateTime.tryParse(
        json['verified_at']
                ?.toString() ??
            '',
      ),

      isCurrent:
          _toBool(
            json['is_current'],
          ) ??
          true,

      createdAt:
          DateTime.tryParse(
        json['created_at']
                ?.toString() ??
            '',
      ),

      updatedAt:
          DateTime.tryParse(
        json['updated_at']
                ?.toString() ??
            '',
      ),

      subject:
          SocialSubject.fromJson(
        subjectData,
      ),

      offering:
          offering,

      teacherName:
          teacherName != null && teacherName.isNotEmpty
              ? teacherName
              : null,

      teacherEmail:
          teacherData?['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':
          id,

      'user_id':
          userId,

      'subject_id':
          subjectId,

      'offering_id':
          offeringId,

      'verification_status':
          verificationStatusApiValue,

      'verified_by':
          verifiedBy,

      'verified_at':
          verifiedAt
              ?.toIso8601String(),

      'is_current':
          isCurrent,

      'created_at':
          createdAt
              ?.toIso8601String(),

      'updated_at':
          updatedAt
              ?.toIso8601String(),

      'subject':
          subject.toJson(),

      'offering':
          offering?.toJson(),
    };
  }

  TeacherAssignment copyWith({
    int? id,
    int? userId,
    int? subjectId,
    int? offeringId,
    bool clearOfferingId = false,
    TeacherAssignmentVerificationStatus?
        verificationStatus,
    int? verifiedBy,
    bool clearVerifiedBy = false,
    DateTime? verifiedAt,
    bool clearVerifiedAt = false,
    bool? isCurrent,
    DateTime? createdAt,
    DateTime? updatedAt,
    SocialSubject? subject,
    SubjectOffering? offering,
    bool clearOffering = false,
  }) {
    return TeacherAssignment(
      id:
          id ??
              this.id,

      userId:
          userId ??
              this.userId,

      subjectId:
          subjectId ??
              this.subjectId,

      offeringId:
          clearOfferingId
              ? null
              : offeringId ??
                  this.offeringId,

      verificationStatus:
          verificationStatus ??
              this.verificationStatus,

      verifiedBy:
          clearVerifiedBy
              ? null
              : verifiedBy ??
                  this.verifiedBy,

      verifiedAt:
          clearVerifiedAt
              ? null
              : verifiedAt ??
                  this.verifiedAt,

      isCurrent:
          isCurrent ??
              this.isCurrent,

      createdAt:
          createdAt ??
              this.createdAt,

      updatedAt:
          updatedAt ??
              this.updatedAt,

      subject:
          subject ??
              this.subject,

      offering:
          clearOffering
              ? null
              : offering ??
                  this.offering,
    );
  }
}

class TeacherAssignmentDraft {
  final int subjectId;

  final int? offeringId;

  final bool isCurrent;

  const TeacherAssignmentDraft({
    required this.subjectId,
    this.offeringId,
    this.isCurrent = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'subject_id':
          subjectId,

      'offering_id':
          offeringId,

      'is_current':
          isCurrent,
    };
  }

  factory TeacherAssignmentDraft.fromJson(
    Map<String, dynamic> json,
  ) {
    return TeacherAssignmentDraft(
      subjectId:
          _toInt(json['subject_id']) ?? 0,
      offeringId:
          _toInt(json['offering_id']),
      isCurrent:
          _toBool(json['is_current']) ?? true,
    );
  }

  TeacherAssignmentDraft copyWith({
    int? subjectId,
    int? offeringId,
    bool clearOfferingId = false,
    bool? isCurrent,
  }) {
    return TeacherAssignmentDraft(
      subjectId:
          subjectId ??
              this.subjectId,

      offeringId:
          clearOfferingId
              ? null
              : offeringId ??
                  this.offeringId,

      isCurrent:
          isCurrent ??
              this.isCurrent,
    );
  }
}

class ReviewAuthor {
  final int id;

  final String firstName;

  final String lastName;

  final String name;

  final String role;

  final SocialAcademicPath?
      primaryAcademicPath;

  const ReviewAuthor({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.role,
    this.primaryAcademicPath,
  });

  bool get isTeacher {
    return role
            .trim()
            .toLowerCase() ==
        'teacher';
  }

  bool get isStudent {
    return role
            .trim()
            .toLowerCase() ==
        'student';
  }

  factory ReviewAuthor.fromJson(
    Map<String, dynamic> json,
  ) {
    SocialAcademicPath?
        primaryAcademicPath;

    final dynamic pathData =
        json['primary_academic_path'];

    if (pathData is Map) {
      final Map<String, dynamic>
          pathJson =
          Map<String, dynamic>.from(
        pathData,
      );

      pathJson['user_id'] ??=
          _toInt(
            json['id'],
          ) ??
          0;

      primaryAcademicPath =
          SocialAcademicPath.fromJson(
        pathJson,
      );
    }

    final String firstName =
        json['first_name']
                ?.toString() ??
            '';

    final String lastName =
        json['last_name']
                ?.toString() ??
            '';

    final String parsedName =
        json['name']
                ?.toString()
                .trim() ??
            '';

    return ReviewAuthor(
      id:
          _toInt(
            json['id'],
          ) ??
          0,

      firstName:
          firstName,

      lastName:
          lastName,

      name:
          parsedName.isNotEmpty
              ? parsedName
              : '$firstName $lastName'
                  .trim(),

      role:
          json['role']
                  ?.toString() ??
              'student',

      primaryAcademicPath:
          primaryAcademicPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':
          id,

      'first_name':
          firstName,

      'last_name':
          lastName,

      'name':
          name,

      'role':
          role,

      'primary_academic_path':
          primaryAcademicPath
              ?.toJson(),
    };
  }
}

class ReviewSubject {
  final int id;

  final String code;

  final String name;

  const ReviewSubject({
    required this.id,
    this.code = '',
    required this.name,
  });

  factory ReviewSubject.fromJson(
    Map<String, dynamic> json,
  ) {
    return ReviewSubject(
      id:
          _toInt(
            json['id'],
          ) ??
          0,

      code:
          json['code']
                  ?.toString() ??
              '',

      name:
          json['name']
                  ?.toString() ??
              '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':
          id,

      'code':
          code,

      'name':
          name,
    };
  }
}

class SocialReview {
  final int? id;

  final int? authorId;

  final String authorName;

  final double rating;

  final String comment;

  final DateTime? createdAt;

  final int? reviewedUserId;

  final ReviewModerationStatus
      moderationStatus;

  final int? moderatedBy;

  final DateTime? moderatedAt;

  final ReviewSubject? subject;

  final ReviewAuthor? reviewer;

  final DateTime? updatedAt;

  const SocialReview({
    this.id,
    this.authorId,
    required this.authorName,
    required this.rating,
    required this.comment,
    this.createdAt,
    this.reviewedUserId,
    this.moderationStatus =
        ReviewModerationStatus.approved,
    this.moderatedBy,
    this.moderatedAt,
    this.subject,
    this.reviewer,
    this.updatedAt,
  });

  bool get isPending {
    return moderationStatus ==
        ReviewModerationStatus.pending;
  }

  bool get isApproved {
    return moderationStatus ==
        ReviewModerationStatus.approved;
  }

  bool get isRejected {
    return moderationStatus ==
        ReviewModerationStatus.rejected;
  }

  bool get isHidden {
    return moderationStatus ==
        ReviewModerationStatus.hidden;
  }

  String get reviewerRole {
    return reviewer?.role ??
        'student';
  }

  SocialAcademicPath?
      get reviewerAcademicPath {
    return reviewer
        ?.primaryAcademicPath;
  }

  factory SocialReview.fromJson(
    Map<String, dynamic> json,
  ) {
    ReviewAuthor? reviewer;

    final dynamic reviewerData =
        json['reviewer'];

    if (reviewerData is Map) {
      reviewer =
          ReviewAuthor.fromJson(
        Map<String, dynamic>.from(
          reviewerData,
        ),
      );
    }

    ReviewSubject? subject;

    final dynamic subjectData =
        json['subject'];

    if (subjectData is Map) {
      subject =
          ReviewSubject.fromJson(
        Map<String, dynamic>.from(
          subjectData,
        ),
      );
    }

    final int? authorId =
        _toInt(
      json['author_id'] ??
          json['reviewer_id'] ??
          reviewer?.id,
    );

    final String nestedAuthorName =
        reviewer?.name
                .trim() ??
            '';

    final String authorName =
        json['author_name']
                ?.toString()
                .trim() ??
            '';

    final String reviewerName =
        json['reviewer_name']
                ?.toString()
                .trim() ??
            '';

    return SocialReview(
      id:
          _toInt(
        json['id'],
      ),

      authorId:
          authorId,

      authorName:
          nestedAuthorName.isNotEmpty
              ? nestedAuthorName
              : authorName.isNotEmpty
                  ? authorName
                  : reviewerName,

      rating:
          _toDouble(
            json['rating'],
          ) ??
          0,

      comment:
          json['comment']
                  ?.toString() ??
              '',

      createdAt:
          DateTime.tryParse(
        json['created_at']
                ?.toString() ??
            '',
      ),

      reviewedUserId:
          _toInt(
        json['reviewed_user_id'],
      ),

      moderationStatus:
          _reviewModerationStatusFromValue(
        json['moderation_status'],
      ),

      moderatedBy:
          _toInt(
        json['moderated_by'],
      ),

      moderatedAt:
          DateTime.tryParse(
        json['moderated_at']
                ?.toString() ??
            '',
      ),

      subject:
          subject,

      reviewer:
          reviewer,

      updatedAt:
          DateTime.tryParse(
        json['updated_at']
                ?.toString() ??
            '',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null)
        'id':
            id,

      if (authorId != null)
        'author_id':
            authorId,

      if (authorId != null)
        'reviewer_id':
            authorId,

      'author_name':
          authorName,

      'rating':
          rating,

      'comment':
          comment,

      if (reviewedUserId != null)
        'reviewed_user_id':
            reviewedUserId,

      'moderation_status':
          _reviewModerationStatusToApi(
        moderationStatus,
      ),

      'moderated_by':
          moderatedBy,

      'moderated_at':
          moderatedAt
              ?.toIso8601String(),

      'subject':
          subject?.toJson(),

      'reviewer':
          reviewer?.toJson(),

      if (createdAt != null)
        'created_at':
            createdAt!
                .toIso8601String(),

      if (updatedAt != null)
        'updated_at':
            updatedAt!
                .toIso8601String(),
    };
  }

  SocialReview copyWith({
    int? id,
    bool clearId = false,
    int? authorId,
    bool clearAuthorId = false,
    String? authorName,
    double? rating,
    String? comment,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    int? reviewedUserId,
    bool clearReviewedUserId = false,
    ReviewModerationStatus?
        moderationStatus,
    int? moderatedBy,
    bool clearModeratedBy = false,
    DateTime? moderatedAt,
    bool clearModeratedAt = false,
    ReviewSubject? subject,
    bool clearSubject = false,
    ReviewAuthor? reviewer,
    bool clearReviewer = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) {
    return SocialReview(
      id:
          clearId
              ? null
              : id ??
                  this.id,

      authorId:
          clearAuthorId
              ? null
              : authorId ??
                  this.authorId,

      authorName:
          authorName ??
              this.authorName,

      rating:
          rating ??
              this.rating,

      comment:
          comment ??
              this.comment,

      createdAt:
          clearCreatedAt
              ? null
              : createdAt ??
                  this.createdAt,

      reviewedUserId:
          clearReviewedUserId
              ? null
              : reviewedUserId ??
                  this.reviewedUserId,

      moderationStatus:
          moderationStatus ??
              this.moderationStatus,

      moderatedBy:
          clearModeratedBy
              ? null
              : moderatedBy ??
                  this.moderatedBy,

      moderatedAt:
          clearModeratedAt
              ? null
              : moderatedAt ??
                  this.moderatedAt,

      subject:
          clearSubject
              ? null
              : subject ??
                  this.subject,

      reviewer:
          clearReviewer
              ? null
              : reviewer ??
                  this.reviewer,

      updatedAt:
          clearUpdatedAt
              ? null
              : updatedAt ??
                  this.updatedAt,
    );
  }
}

class SocialUser {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String university;
  final String department;
  final String course;
  final List<SocialAcademicPath> academicPaths;
  final List<SocialAcademicTitle> academicTitles;
  final List<SocialSubject> subjects;
  final List<TeacherAssignment> teacherAssignments;
  final String description;
  final SocialUserType type;
  final String accountRole;
  final TeacherVerificationStatus teacherVerificationStatus;
  final int? teacherVerifiedBy;
  final DateTime? teacherVerifiedAt;
  final bool available;
  final bool availableForHelp;
  final bool availableForPrivateLessons;
  final bool isActive;
  final List<SocialReview> reviews;

  const SocialUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.university = '',
    required this.department,
    required this.course,
    this.academicPaths = const [],
    this.academicTitles = const [],
    required this.subjects,
    this.teacherAssignments = const [],
    required this.description,
    required this.type,
    this.accountRole = '',
    this.teacherVerificationStatus = TeacherVerificationStatus.notRequired,
    this.teacherVerifiedBy,
    this.teacherVerifiedAt,
    required this.available,
    required this.availableForHelp,
    required this.availableForPrivateLessons,
    required this.isActive,
    this.reviews = const [],
  });

  String get name =>
      '$firstName $lastName'.trim();

  String get role {
    final String normalized = accountRole.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    switch (type) {
      case SocialUserType.teacher:
        return 'teacher';
      case SocialUserType.student:
        return 'student';
    }
  }

  bool get isCreator => role == 'creator';

  bool get isAdmin => role == 'admin' || role == 'creator';

  bool get isDeveloperSystem => role == 'devsyst' || role == 'creator';

  bool get isTeacher =>
      type == SocialUserType.teacher;

  bool get isStudent =>
      type == SocialUserType.student;

  bool get isTeacherPending =>
      isTeacher &&
      teacherVerificationStatus == TeacherVerificationStatus.pending;

  bool get isVerifiedTeacher =>
      isTeacher &&
      teacherVerificationStatus == TeacherVerificationStatus.verified;

  bool get isTeacherRejected =>
      isTeacher &&
      teacherVerificationStatus == TeacherVerificationStatus.rejected;

  bool get willingToTeach =>
      availableForPrivateLessons;

  bool get privateLessons =>
      availableForPrivateLessons;

  SocialAcademicPath? get currentAcademicPath {
    for (final SocialAcademicPath path in academicPaths) {
      if (path.isCurrent) {
        return path;
      }
    }
    return null;
  }

  SocialAcademicPath? get primaryAcademicPath {
    for (final SocialAcademicPath path in academicPaths) {
      if (path.isPrimary) {
        return path;
      }
    }
    return null;
  }

  SocialAcademicTitle? get primaryAcademicTitle {
    for (final SocialAcademicTitle title in academicTitles) {
      if (title.isPrimary) {
        return title;
      }
    }
    return academicTitles.isEmpty ? null : academicTitles.first;
  }

  List<SocialAcademicTitle> get verifiedAcademicTitles {
    return academicTitles
        .where((SocialAcademicTitle title) => title.isVerified)
        .toList();
  }

  List<SocialAcademicTitle> get pendingAcademicTitles {
    return academicTitles
        .where((SocialAcademicTitle title) => title.isVerificationPending)
        .toList();
  }

  List<SocialAcademicTitle> get rejectedAcademicTitles {
    return academicTitles
        .where((SocialAcademicTitle title) => title.isVerificationRejected)
        .toList();
  }

  List<SocialAcademicPath> get verifiedAcademicPaths {
    return academicPaths
        .where((SocialAcademicPath path) => path.isVerified)
        .toList();
  }

  List<SocialAcademicPath> get pendingAcademicPaths {
    return academicPaths
        .where((SocialAcademicPath path) => path.isVerificationPending)
        .toList();
  }

  List<SocialAcademicPath> get rejectedAcademicPaths {
    return academicPaths
        .where((SocialAcademicPath path) => path.isVerificationRejected)
        .toList();
  }

  List<SocialAcademicPath> get graduatedAcademicPaths =>
      const [];

  List<SocialAcademicPath> get verifiedGraduatedAcademicPaths =>
      const [];

  bool get hasVerifiedDegree =>
      verifiedAcademicTitles.isNotEmpty;

  List<SocialSubject> get helpSubjects {
    return subjects
        .where((SocialSubject subject) => subject.canHelp)
        .toList();
  }

  List<SocialSubject> get privateLessonSubjects {
    return subjects
        .where((SocialSubject subject) => subject.canGivePrivateLessons)
        .toList();
  }

  List<TeacherAssignment> get currentTeacherAssignments {
    return teacherAssignments
        .where((TeacherAssignment assignment) => assignment.isCurrent)
        .toList();
  }

  List<TeacherAssignment> get verifiedTeacherAssignments {
    return teacherAssignments
        .where(
          (TeacherAssignment assignment) =>
              assignment.isVerified && assignment.isCurrent,
        )
        .toList();
  }

  List<TeacherAssignment> get pendingTeacherAssignments {
    return teacherAssignments
        .where((TeacherAssignment assignment) => assignment.isPending)
        .toList();
  }

  double get averageRating {
    if (reviews.isEmpty) {
      return 0;
    }

    final double total = reviews.fold<double>(
      0,
      (double sum, SocialReview review) => sum + review.rating,
    );

    return total / reviews.length;
  }

  int get reviewCount =>
      reviews.length;

  factory SocialUser.fromJson(
    Map<String, dynamic> json,
  ) {
    final List<SocialSubject> parsedSubjects = [];
    final dynamic subjectsData = json['subjects'];

    if (subjectsData is List) {
      for (final dynamic item in subjectsData) {
        if (item is Map) {
          parsedSubjects.add(
            SocialSubject.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final List<SocialAcademicPath> parsedAcademicPaths = [];
    final List<SocialAcademicTitle> legacyAcademicTitles = [];
    final dynamic academicPathsData = json['academic_paths'];

    if (academicPathsData is List) {
      for (final dynamic item in academicPathsData) {
        if (item is Map) {
          final SocialAcademicPath path = SocialAcademicPath.fromJson(
            Map<String, dynamic>.from(item),
          );

          if (path.isGraduated) {
            final Map<String, dynamic> legacyJson =
                Map<String, dynamic>.from(item);
            legacyAcademicTitles.add(
              SocialAcademicTitle(
                id: path.id,
                userId: path.userId,
                university: path.university,
                universityCode: path.universityCode,
                department: path.department,
                departmentCode: path.departmentCode,
                course: path.course,
                courseCode: path.courseCode,
                titleType: path.degreeType,
                verificationStatus:
                    _academicTitleVerificationStatusFromPathStatus(
                  path.verificationStatus,
                ),
                verifiedBy: path.verifiedBy,
                verifiedAt: path.verifiedAt,
                graduationYear: _toInt(legacyJson['graduation_year']),
                isPrimary: path.isPrimary,
              ),
            );
          } else {
            parsedAcademicPaths.add(path);
          }
        }
      }
    }

    final List<SocialAcademicTitle> parsedAcademicTitles = [];
    final dynamic academicTitlesData = json['academic_titles'];

    if (academicTitlesData is List) {
      for (final dynamic item in academicTitlesData) {
        if (item is Map) {
          parsedAcademicTitles.add(
            SocialAcademicTitle.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    if (parsedAcademicTitles.isEmpty) {
      parsedAcademicTitles.addAll(legacyAcademicTitles);
    } else {
      for (final SocialAcademicTitle legacy in legacyAcademicTitles) {
        final bool duplicate = parsedAcademicTitles.any(
          (SocialAcademicTitle title) =>
              _sameAcademicTitleIdentity(title, legacy),
        );
        if (!duplicate) {
          parsedAcademicTitles.add(legacy);
        }
      }
    }

    final List<SocialReview> parsedReviews = [];
    final dynamic reviewsData = json['reviews'];

    if (reviewsData is List) {
      for (final dynamic item in reviewsData) {
        if (item is Map) {
          parsedReviews.add(
            SocialReview.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final List<TeacherAssignment> parsedTeacherAssignments = [];
    final dynamic teacherAssignmentsData = json['teacher_assignments'];

    if (teacherAssignmentsData is List) {
      for (final dynamic item in teacherAssignmentsData) {
        if (item is Map) {
          parsedTeacherAssignments.add(
            TeacherAssignment.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final SocialUserType type =
        _typeFromRole(json['role']?.toString());

    final bool available =
        _toBool(json['available']) ?? false;

    final bool availableForHelp =
        _toBool(json['available_for_help']) ?? available;

    final bool availableForPrivateLessons =
        _toBool(json['available_for_private_lessons']) ??
        _toBool(json['willing_to_teach']) ??
        false;

    return SocialUser(
      id: _toInt(json['id']) ?? 0,
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      university:
          (json['university'] ?? json['university_name'] ?? json['ateneo'])
                  ?.toString() ??
              '',
      department: json['department']?.toString() ?? '',
      course: json['course']?.toString() ?? '',
      academicPaths: parsedAcademicPaths,
      academicTitles: parsedAcademicTitles,
      subjects: parsedSubjects,
      teacherAssignments: parsedTeacherAssignments,
      description: json['description']?.toString() ?? '',
      type: type,
      accountRole: json['role']?.toString().trim().toLowerCase() ?? '',
      teacherVerificationStatus: _teacherVerificationStatusFromValue(
        json['teacher_verification_status'] ?? json['teacher_status'],
        type: type,
      ),
      teacherVerifiedBy: _toInt(json['teacher_verified_by']),
      teacherVerifiedAt: DateTime.tryParse(
        json['teacher_verified_at']?.toString() ?? '',
      ),
      available: available,
      availableForHelp: availableForHelp,
      availableForPrivateLessons: availableForPrivateLessons,
      isActive: _toBool(json['is_active']) ?? true,
      reviews: parsedReviews,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'university': university,
      'department': department,
      'course': course,
      'academic_paths': academicPaths
          .map((SocialAcademicPath path) => path.toJson())
          .toList(),
      'academic_titles': academicTitles
          .map((SocialAcademicTitle title) => title.toJson())
          .toList(),
      'subjects': subjects
          .map((SocialSubject subject) => subject.toJson())
          .toList(),
      'teacher_assignments': teacherAssignments
          .map((TeacherAssignment assignment) => assignment.toJson())
          .toList(),
      'description': description,
      'role': role,
      'teacher_verification_status':
          _teacherVerificationStatusToApi(teacherVerificationStatus),
      'teacher_verified_by': teacherVerifiedBy,
      'teacher_verified_at': teacherVerifiedAt?.toIso8601String(),
      'available': available,
      'available_for_help': availableForHelp,
      'available_for_private_lessons': availableForPrivateLessons,
      'willing_to_teach': availableForPrivateLessons,
      'is_active': isActive,
      'reviews': reviews
          .map((SocialReview review) => review.toJson())
          .toList(),
    };
  }

  SocialUser copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? university,
    String? department,
    String? course,
    List<SocialAcademicPath>? academicPaths,
    List<SocialAcademicTitle>? academicTitles,
    List<SocialSubject>? subjects,
    List<TeacherAssignment>? teacherAssignments,
    String? description,
    SocialUserType? type,
    String? accountRole,
    TeacherVerificationStatus? teacherVerificationStatus,
    int? teacherVerifiedBy,
    bool clearTeacherVerifiedBy = false,
    DateTime? teacherVerifiedAt,
    bool clearTeacherVerifiedAt = false,
    bool? available,
    bool? availableForHelp,
    bool? availableForPrivateLessons,
    bool? isActive,
    List<SocialReview>? reviews,
  }) {
    return SocialUser(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      university: university ?? this.university,
      department: department ?? this.department,
      course: course ?? this.course,
      academicPaths: academicPaths ?? this.academicPaths,
      academicTitles: academicTitles ?? this.academicTitles,
      subjects: subjects ?? this.subjects,
      teacherAssignments: teacherAssignments ?? this.teacherAssignments,
      description: description ?? this.description,
      type: type ?? this.type,
      accountRole: accountRole ?? this.accountRole,
      teacherVerificationStatus:
          teacherVerificationStatus ?? this.teacherVerificationStatus,
      teacherVerifiedBy: clearTeacherVerifiedBy
          ? null
          : teacherVerifiedBy ?? this.teacherVerifiedBy,
      teacherVerifiedAt: clearTeacherVerifiedAt
          ? null
          : teacherVerifiedAt ?? this.teacherVerifiedAt,
      available: available ?? this.available,
      availableForHelp: availableForHelp ?? this.availableForHelp,
      availableForPrivateLessons:
          availableForPrivateLessons ?? this.availableForPrivateLessons,
      isActive: isActive ?? this.isActive,
      reviews: reviews ?? this.reviews,
    );
  }

  static TeacherVerificationStatus _teacherVerificationStatusFromValue(
    dynamic value, {
    required SocialUserType type,
  }) {
    if (type != SocialUserType.teacher) {
      return TeacherVerificationStatus.notRequired;
    }

    final String status =
        value?.toString().trim().toLowerCase() ?? '';

    switch (status) {
      case 'pending':
        return TeacherVerificationStatus.pending;
      case 'verified':
      case 'approved':
        return TeacherVerificationStatus.verified;
      case 'rejected':
        return TeacherVerificationStatus.rejected;
      case 'not_required':
      case 'notrequired':
        return TeacherVerificationStatus.notRequired;
      default:
        return TeacherVerificationStatus.pending;
    }
  }

  static SocialUserType _typeFromRole(
    String? role,
  ) {
    switch (role?.trim().toLowerCase()) {
      case 'teacher':
        return SocialUserType.teacher;
      case 'student':
      default:
        return SocialUserType.student;
    }
  }
}

class SocialProfileDraft {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final DateTime dateOfBirth;
  final String university;
  final String universityCode;
  final String department;
  final String departmentCode;
  final String course;
  final String courseCode;
  final String degreeType;
  final AcademicPathStatus academicStatus;
  final int? startYear;
  final int? graduationYear;
  final List<SocialSubject> subjects;
  final List<TeacherAssignmentDraft> teacherAssignments;
  final List<SocialAcademicPathDraft> additionalAcademicPaths;
  final List<SocialAcademicTitleDraft> academicTitles;
  final String description;
  final SocialUserType type;
  final bool available;
  final bool availableForHelp;
  final bool availableForPrivateLessons;

  const SocialProfileDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.dateOfBirth,
    this.university = '',
    this.universityCode = '',
    required this.department,
    this.departmentCode = '',
    required this.course,
    this.courseCode = '',
    this.degreeType = '',
    this.academicStatus = AcademicPathStatus.enrolled,
    this.startYear,
    this.graduationYear,
    required this.subjects,
    this.teacherAssignments = const [],
    this.additionalAcademicPaths = const [],
    this.academicTitles = const [],
    required this.description,
    required this.type,
    required this.available,
    required this.availableForHelp,
    required this.availableForPrivateLessons,
  });

  String get name =>
      '$firstName $lastName'.trim();

  String get role {
    switch (type) {
      case SocialUserType.student:
        return 'student';
      case SocialUserType.teacher:
        return 'teacher';
    }
  }

  bool get willingToTeach =>
      availableForPrivateLessons;

  bool get privateLessons =>
      availableForPrivateLessons;

  bool get isGraduated =>
      academicStatus == AcademicPathStatus.graduated;

  bool get isEnrolled =>
      academicStatus == AcademicPathStatus.enrolled;

  List<SocialAcademicPathDraft> get resolvedAcademicPaths {
    final List<SocialAcademicPathDraft> values = [];

    if (
      university.trim().isNotEmpty &&
      department.trim().isNotEmpty &&
      course.trim().isNotEmpty &&
      academicStatus != AcademicPathStatus.graduated
    ) {
      values.add(
        SocialAcademicPathDraft(
          university: university,
          universityCode: universityCode,
          department: department,
          departmentCode: departmentCode,
          course: course,
          courseCode: courseCode,
          degreeType: degreeType,
          status: academicStatus,
          startYear: startYear,
          isCurrent: academicStatus == AcademicPathStatus.enrolled,
          isPrimary: true,
        ),
      );
    }

    values.addAll(
      additionalAcademicPaths.where(
        (SocialAcademicPathDraft path) =>
            path.status != AcademicPathStatus.graduated,
      ),
    );

    return values;
  }

  List<SocialAcademicTitleDraft> get resolvedAcademicTitles {
    final List<SocialAcademicTitleDraft> values = [
      ...academicTitles,
    ];

    if (
      academicStatus == AcademicPathStatus.graduated &&
      university.trim().isNotEmpty &&
      department.trim().isNotEmpty &&
      course.trim().isNotEmpty
    ) {
      values.add(
        SocialAcademicTitleDraft(
          university: university,
          universityCode: universityCode,
          department: department,
          departmentCode: departmentCode,
          course: course,
          courseCode: courseCode,
          titleType: degreeType,
          graduationYear: graduationYear,
          isPrimary: true,
        ),
      );
    }

    for (
      final SocialAcademicPathDraft path
      in additionalAcademicPaths
    ) {
      if (path.status != AcademicPathStatus.graduated) {
        continue;
      }

      final SocialAcademicTitleDraft title =
          SocialAcademicTitleDraft.fromLegacyPath(path);

      final bool duplicate = values.any(
        (SocialAcademicTitleDraft current) =>
            _sameAcademicTitleDraftIdentity(current, title),
      );

      if (!duplicate) {
        values.add(title);
      }
    }

    return values;
  }

  Map<String, dynamic> toRegisterJson() {
    return {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim(),
      'password': password,
      'date_of_birth':
          '${dateOfBirth.year.toString().padLeft(4, '0')}-'
          '${dateOfBirth.month.toString().padLeft(2, '0')}-'
          '${dateOfBirth.day.toString().padLeft(2, '0')}',
      'university': university.isEmpty ? null : university,
      'university_code': universityCode.isEmpty ? null : universityCode,
      'department': department.isEmpty ? null : department,
      'department_code': departmentCode.isEmpty ? null : departmentCode,
      'course': course.isEmpty ? null : course,
      'course_code': courseCode.isEmpty ? null : courseCode,
      'degree_type': degreeType.isEmpty ? null : degreeType,
      'academic_status': _academicPathStatusToApi(academicStatus),
      'start_year': startYear,
      'graduation_year': graduationYear,
      'description': description,
      'role': role,
      'available': available,
      'available_for_help': availableForHelp,
      'available_for_private_lessons': availableForPrivateLessons,
      'willing_to_teach': availableForPrivateLessons,
    };
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'university': university,
      'university_code': universityCode,
      'department': department,
      'department_code': departmentCode,
      'course': course,
      'course_code': courseCode,
      'degree_type': degreeType,
      'academic_status': _academicPathStatusToApi(academicStatus),
      'start_year': startYear,
      'graduation_year': graduationYear,
      'subjects':
          subjects.map((SocialSubject s) => s.toJson()).toList(),
      'teacher_assignments': teacherAssignments
          .map((TeacherAssignmentDraft a) => a.toJson())
          .toList(),
      'additional_academic_paths': additionalAcademicPaths
          .map((SocialAcademicPathDraft p) => p.toJson())
          .toList(),
      'academic_titles': academicTitles
          .map((SocialAcademicTitleDraft t) => t.toJson())
          .toList(),
      'description': description,
      'role': role,
      'available': available,
      'available_for_help': availableForHelp,
      'available_for_private_lessons': availableForPrivateLessons,
    };
  }

  factory SocialProfileDraft.fromStorageJson(
    Map<String, dynamic> json,
  ) {
    List<Map<String, dynamic>> mapList(dynamic value) {
      if (value is! List) {
        return const [];
      }
      return value
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return SocialProfileDraft(
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      password: '',
      dateOfBirth:
          DateTime.tryParse(json['date_of_birth']?.toString() ?? '') ??
              DateTime.now(),
      university: json['university']?.toString() ?? '',
      universityCode: json['university_code']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      departmentCode: json['department_code']?.toString() ?? '',
      course: json['course']?.toString() ?? '',
      courseCode: json['course_code']?.toString() ?? '',
      degreeType: json['degree_type']?.toString() ?? '',
      academicStatus:
          _academicPathStatusFromValue(json['academic_status']),
      startYear: _toInt(json['start_year']),
      graduationYear: _toInt(json['graduation_year']),
      subjects: mapList(json['subjects'])
          .map((Map<String, dynamic> item) => SocialSubject.fromJson(item))
          .toList(),
      teacherAssignments: mapList(json['teacher_assignments'])
          .map(
            (Map<String, dynamic> item) =>
                TeacherAssignmentDraft.fromJson(item),
          )
          .toList(),
      additionalAcademicPaths: mapList(json['additional_academic_paths'])
          .map(
            (Map<String, dynamic> item) =>
                SocialAcademicPathDraft.fromJson(item),
          )
          .toList(),
      academicTitles: mapList(json['academic_titles'])
          .map(
            (Map<String, dynamic> item) =>
                SocialAcademicTitleDraft.fromJson(item),
          )
          .toList(),
      description: json['description']?.toString() ?? '',
      type: (json['role']?.toString().trim().toLowerCase() == 'teacher')
          ? SocialUserType.teacher
          : SocialUserType.student,
      available: _toBool(json['available']) ?? false,
      availableForHelp: _toBool(json['available_for_help']) ?? false,
      availableForPrivateLessons:
          _toBool(json['available_for_private_lessons']) ?? false,
    );
  }

  List<Map<String, dynamic>> academicPathsCreateJson() {
    return resolvedAcademicPaths
        .map(
          (SocialAcademicPathDraft path) => {
            'university': path.university,
            'university_code':
                path.universityCode.isEmpty ? null : path.universityCode,
            'department': path.department,
            'department_code':
                path.departmentCode.isEmpty ? null : path.departmentCode,
            'course': path.course,
            'course_code': path.courseCode.isEmpty ? null : path.courseCode,
            'degree_type': path.degreeType.isEmpty ? null : path.degreeType,
            'status': _academicPathStatusToApi(path.status),
            'start_year': path.startYear,
            'is_current': path.isCurrent,
            'is_primary': path.isPrimary,
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> academicTitlesCreateJson() {
    return resolvedAcademicTitles
        .map(
          (SocialAcademicTitleDraft title) => {
            'university': title.university,
            'university_code':
                title.universityCode.isEmpty ? null : title.universityCode,
            'department': title.department,
            'department_code':
                title.departmentCode.isEmpty ? null : title.departmentCode,
            'course': title.course,
            'course_code': title.courseCode.isEmpty ? null : title.courseCode,
            'title_type': title.titleType,
            'graduation_year': title.graduationYear,
            'is_primary': title.isPrimary,
          },
        )
        .toList();
  }

  SocialUser toSocialUser({
    required int id,
  }) {
    final List<SocialAcademicPath> paths =
        resolvedAcademicPaths
            .map(
              (SocialAcademicPathDraft path) => SocialAcademicPath(
                id: 0,
                userId: id,
                university: path.university,
                universityCode: path.universityCode,
                department: path.department,
                departmentCode: path.departmentCode,
                course: path.course,
                courseCode: path.courseCode,
                degreeType: path.degreeType,
                status: path.status,
                verificationStatus: AcademicPathVerificationStatus.pending,
                startYear: path.startYear,
                isCurrent: path.isCurrent,
                isPrimary: path.isPrimary,
              ),
            )
            .toList();

    final List<SocialAcademicTitle> titles =
        resolvedAcademicTitles
            .map(
              (SocialAcademicTitleDraft title) => SocialAcademicTitle(
                id: 0,
                userId: id,
                university: title.university,
                universityCode: title.universityCode,
                department: title.department,
                departmentCode: title.departmentCode,
                course: title.course,
                courseCode: title.courseCode,
                titleType: title.titleType,
                verificationStatus: AcademicTitleVerificationStatus.pending,
                graduationYear: title.graduationYear,
                isPrimary: title.isPrimary,
              ),
            )
            .toList();

    return SocialUser(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      university: university,
      department: department,
      course: course,
      academicPaths: paths,
      academicTitles: titles,
      subjects: subjects,
      teacherAssignments: const [],
      description: description,
      type: type,
      teacherVerificationStatus: type == SocialUserType.teacher
          ? TeacherVerificationStatus.pending
          : TeacherVerificationStatus.notRequired,
      available: available,
      availableForHelp: availableForHelp,
      availableForPrivateLessons: availableForPrivateLessons,
      isActive: true,
    );
  }

  SocialProfileDraft copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? password,
    DateTime? dateOfBirth,
    String? university,
    String? universityCode,
    String? department,
    String? departmentCode,
    String? course,
    String? courseCode,
    String? degreeType,
    AcademicPathStatus? academicStatus,
    int? startYear,
    bool clearStartYear = false,
    int? graduationYear,
    bool clearGraduationYear = false,
    List<SocialSubject>? subjects,
    List<TeacherAssignmentDraft>? teacherAssignments,
    List<SocialAcademicPathDraft>? additionalAcademicPaths,
    List<SocialAcademicTitleDraft>? academicTitles,
    String? description,
    SocialUserType? type,
    bool? available,
    bool? availableForHelp,
    bool? availableForPrivateLessons,
  }) {
    return SocialProfileDraft(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      password: password ?? this.password,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      university: university ?? this.university,
      universityCode: universityCode ?? this.universityCode,
      department: department ?? this.department,
      departmentCode: departmentCode ?? this.departmentCode,
      course: course ?? this.course,
      courseCode: courseCode ?? this.courseCode,
      degreeType: degreeType ?? this.degreeType,
      academicStatus: academicStatus ?? this.academicStatus,
      startYear: clearStartYear ? null : startYear ?? this.startYear,
      graduationYear: clearGraduationYear
          ? null
          : graduationYear ?? this.graduationYear,
      subjects: subjects ?? this.subjects,
      teacherAssignments: teacherAssignments ?? this.teacherAssignments,
      additionalAcademicPaths:
          additionalAcademicPaths ?? this.additionalAcademicPaths,
      academicTitles: academicTitles ?? this.academicTitles,
      description: description ?? this.description,
      type: type ?? this.type,
      available: available ?? this.available,
      availableForHelp: availableForHelp ?? this.availableForHelp,
      availableForPrivateLessons:
          availableForPrivateLessons ?? this.availableForPrivateLessons,
    );
  }
}

class ChatMessage {
  final String id;

  final String conversationId;

  final String senderId;

  final String text;

  final DateTime createdAt;

  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });
}

class ChatConversation {
  final String id;

  final String user1Id;

  final String user2Id;

  final List<ChatMessage> messages;

  const ChatConversation({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.messages,
  });
}

String _teacherVerificationStatusToApi(
  TeacherVerificationStatus status,
) {
  switch (status) {
    case TeacherVerificationStatus
          .notRequired:
      return 'not_required';

    case TeacherVerificationStatus
          .pending:
      return 'pending';

    case TeacherVerificationStatus
          .verified:
      return 'verified';

    case TeacherVerificationStatus
          .rejected:
      return 'rejected';
  }
}

TeacherAssignmentVerificationStatus
    _teacherAssignmentVerificationStatusFromValue(
  dynamic value,
) {
  switch (
      value
          ?.toString()
          .trim()
          .toLowerCase()) {
    case 'verified':
      return TeacherAssignmentVerificationStatus
          .verified;

    case 'rejected':
      return TeacherAssignmentVerificationStatus
          .rejected;

    case 'pending':
    default:
      return TeacherAssignmentVerificationStatus
          .pending;
  }
}

AcademicPathStatus
    _academicPathStatusFromValue(
  dynamic value,
) {
  final String status =
      value
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

  switch (status) {
    case 'graduated':
      return AcademicPathStatus
          .graduated;

    case 'suspended':
      return AcademicPathStatus
          .suspended;

    case 'withdrawn':
      return AcademicPathStatus
          .withdrawn;

    case 'transferred':
      return AcademicPathStatus
          .transferred;

    case 'enrolled':
    default:
      return AcademicPathStatus
          .enrolled;
  }
}

String _academicPathStatusToApi(
  AcademicPathStatus status,
) {
  switch (status) {
    case AcademicPathStatus.enrolled:
      return 'enrolled';

    case AcademicPathStatus.graduated:
      return 'graduated';

    case AcademicPathStatus.suspended:
      return 'suspended';

    case AcademicPathStatus.withdrawn:
      return 'withdrawn';

    case AcademicPathStatus.transferred:
      return 'transferred';
  }
}

AcademicPathVerificationStatus
    _academicPathVerificationStatusFromValue(
  dynamic value, {
  required AcademicPathStatus status,
}) {
  final String verificationStatus =
      value
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

  switch (verificationStatus) {
    case 'pending':
      return AcademicPathVerificationStatus
          .pending;

    case 'verified':
    case 'approved':
      return AcademicPathVerificationStatus
          .verified;

    case 'rejected':
      return AcademicPathVerificationStatus
          .rejected;

    case 'not_required':
    case 'notrequired':
      return AcademicPathVerificationStatus
          .notRequired;

    default:
      return AcademicPathVerificationStatus
          .pending;
  }
}

String
    _academicPathVerificationStatusToApi(
  AcademicPathVerificationStatus
      status,
) {
  switch (status) {
    case AcademicPathVerificationStatus
          .notRequired:
      return 'not_required';

    case AcademicPathVerificationStatus
          .pending:
      return 'pending';

    case AcademicPathVerificationStatus
          .verified:
      return 'verified';

    case AcademicPathVerificationStatus
          .rejected:
      return 'rejected';
  }
}

AcademicTitleVerificationStatus
    _academicTitleVerificationStatusFromValue(
  dynamic value,
) {
  final String status =
      value?.toString().trim().toLowerCase() ?? '';

  switch (status) {
    case 'verified':
    case 'approved':
      return AcademicTitleVerificationStatus.verified;
    case 'rejected':
      return AcademicTitleVerificationStatus.rejected;
    case 'not_required':
    case 'notrequired':
      return AcademicTitleVerificationStatus.notRequired;
    case 'pending':
    default:
      return AcademicTitleVerificationStatus.pending;
  }
}

AcademicTitleVerificationStatus
    _academicTitleVerificationStatusFromPathStatus(
  AcademicPathVerificationStatus status,
) {
  switch (status) {
    case AcademicPathVerificationStatus.verified:
      return AcademicTitleVerificationStatus.verified;
    case AcademicPathVerificationStatus.rejected:
      return AcademicTitleVerificationStatus.rejected;
    case AcademicPathVerificationStatus.notRequired:
      return AcademicTitleVerificationStatus.notRequired;
    case AcademicPathVerificationStatus.pending:
      return AcademicTitleVerificationStatus.pending;
  }
}

String _academicTitleVerificationStatusToApi(
  AcademicTitleVerificationStatus status,
) {
  switch (status) {
    case AcademicTitleVerificationStatus.notRequired:
      return 'not_required';
    case AcademicTitleVerificationStatus.pending:
      return 'pending';
    case AcademicTitleVerificationStatus.verified:
      return 'verified';
    case AcademicTitleVerificationStatus.rejected:
      return 'rejected';
  }
}

bool _sameAcademicTitleIdentity(
  SocialAcademicTitle a,
  SocialAcademicTitle b,
) {
  final bool sameUniversity =
      a.universityCode.trim().isNotEmpty &&
              b.universityCode.trim().isNotEmpty
          ? _sameNormalizedText(a.universityCode, b.universityCode)
          : _sameNormalizedText(a.university, b.university);

  if (!sameUniversity) {
    return false;
  }

  final bool sameCourse =
      a.courseCode.trim().isNotEmpty &&
              b.courseCode.trim().isNotEmpty
          ? _sameNormalizedText(a.courseCode, b.courseCode)
          : _sameNormalizedText(a.course, b.course);

  return sameCourse &&
      _sameNormalizedText(a.titleType, b.titleType) &&
      a.graduationYear == b.graduationYear;
}

bool _sameAcademicTitleDraftIdentity(
  SocialAcademicTitleDraft a,
  SocialAcademicTitleDraft b,
) {
  final bool sameUniversity =
      a.universityCode.trim().isNotEmpty &&
              b.universityCode.trim().isNotEmpty
          ? _sameNormalizedText(a.universityCode, b.universityCode)
          : _sameNormalizedText(a.university, b.university);

  if (!sameUniversity) {
    return false;
  }

  final bool sameCourse =
      a.courseCode.trim().isNotEmpty &&
              b.courseCode.trim().isNotEmpty
          ? _sameNormalizedText(a.courseCode, b.courseCode)
          : _sameNormalizedText(a.course, b.course);

  return sameCourse &&
      _sameNormalizedText(a.titleType, b.titleType) &&
      a.graduationYear == b.graduationYear;
}

bool _sameNormalizedText(
  String a,
  String b,
) {
  return a.trim().toLowerCase() ==
      b.trim().toLowerCase();
}

ReviewModerationStatus
    _reviewModerationStatusFromValue(
  dynamic value,
) {
  final String status =
      value
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

  switch (status) {
    case 'pending':
      return ReviewModerationStatus
          .pending;

    case 'rejected':
      return ReviewModerationStatus
          .rejected;

    case 'hidden':
      return ReviewModerationStatus
          .hidden;

    case 'approved':
    default:
      return ReviewModerationStatus
          .approved;
  }
}

String _reviewModerationStatusToApi(
  ReviewModerationStatus status,
) {
  switch (status) {
    case ReviewModerationStatus.pending:
      return 'pending';

    case ReviewModerationStatus.approved:
      return 'approved';

    case ReviewModerationStatus.rejected:
      return 'rejected';

    case ReviewModerationStatus.hidden:
      return 'hidden';
  }
}

int? _toInt(
  dynamic value,
) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
    value?.toString() ??
        '',
  );
}

double? _toDouble(
  dynamic value,
) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
    value?.toString() ??
        '',
  );
}

bool? _toBool(
  dynamic value,
) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final String normalized =
      value
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

  if (
    normalized ==
        'true' ||
    normalized ==
        '1'
  ) {
    return true;
  }

  if (
    normalized ==
        'false' ||
    normalized ==
        '0'
  ) {
    return false;
  }

  return null;
}