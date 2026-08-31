import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../social_models.dart';

class StudentLabUserAvatar extends StatelessWidget {
  static const String studentAsset = 'assets/mascot/student_profile.png';
  static const String teacherAsset = 'assets/mascot/teacher_profile.png';
  static const String guestAsset = 'assets/mascot/guest_profile.png';

  final SocialUserType? type;
  final double radius;
  final bool showBorder;

  const StudentLabUserAvatar({
    super.key,
    this.type,
    this.radius = 25,
    this.showBorder = true,
  });

  bool get _isTeacher => type == SocialUserType.teacher;
  bool get _isGuest => type == null;

  String get _assetPath {
    if (_isGuest) return guestAsset;
    if (_isTeacher) return teacherAsset;
    return studentAsset;
  }

  Color get _accent {
    if (_isGuest) return AppColors.materialSky;
    if (_isTeacher) return AppColors.teacherIndigo;
    return AppColors.studentBlue;
  }

  String get _semanticLabel {
    if (_isGuest) return 'Avatar ospite StudentLab';
    if (_isTeacher) return 'Avatar docente StudentLab';
    return 'Avatar studente StudentLab';
  }

  IconData get _fallbackIcon {
    if (_isGuest) return Icons.person_outline_rounded;
    if (_isTeacher) return Icons.cast_for_education_rounded;
    return Icons.school_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final double diameter = radius * 2;
    final double outerPadding = showBorder ? 1.6 : 0;
    final double innerPadding = showBorder ? 1.2 : 0;
    return Semantics(
      image: true,
      label: _semanticLabel,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: showBorder ? AppColors.adminIconGradient : null,
            color: showBorder ? null : _accent.withValues(alpha: 0.18),
            boxShadow: showBorder
                ? <BoxShadow>[
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.16),
                      blurRadius: radius * 0.34,
                      spreadRadius: 0.2,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(outerPadding),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.eleganceMidnight,
                border: Border.all(
                  color: _accent.withValues(alpha: 0.18),
                  width: showBorder ? 0.8 : 0,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(innerPadding),
                child: ClipOval(
                  child: ColoredBox(
                    color: AppColors.eleganceDeepNavy,
                    child: Image.asset(
                      _assetPath,
                      width: diameter,
                      height: diameter,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            _fallbackIcon,
                            color: _accent,
                            size: radius * 0.95,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
