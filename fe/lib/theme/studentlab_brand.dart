import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'theme_controller.dart';

/// Immagini e colori del marchio legati al tema: mascotte (vestiti, cappello,
/// zaino), logo e titolo "StudentLab" della schermata iniziale.
///
/// Con Notte si usano le immagini originali. Per gli altri temi ci sono
/// versioni ricolorate in `assets/mascot/themes/<tema>_<nome>.webp`: cambiano
/// solo blu, viola e ciano (vestiti, logo, riflessi); pelo, occhi chiari,
/// lingua e scarpe bianche restano uguali.
class StudentLabBrand {
  StudentLabBrand._();

  static StudentLabTheme get _theme => StudentLabThemeController.instance.theme;

  static String _asset(String name, String original) {
    final theme = _theme;
    if (theme == StudentLabTheme.notte) return original;
    return 'assets/mascot/themes/${theme.id}_$name.webp';
  }

  static String get wolf => _asset('studentlab_wolf', 'assets/mascot/studentlab_wolf.png');
  static String get guestAvatar => _asset('guest_profile', 'assets/mascot/guest_profile.png');
  static String get studentAvatar => _asset('student_profile', 'assets/mascot/student_profile.png');
  static String get teacherAvatar => _asset('teacher_profile', 'assets/mascot/teacher_profile.png');
  static String get logo => _asset('favicon', 'assets/icons/favicon.png');

  static const _BrandColors _night = _BrandColors(
    lab: [Color(0xFF00E5FF), Color(0xFF168CFF), Color(0xFF654DFF), Color(0xFFE13CFF)],
    student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFBFDDF7)],
    glow: [Color(0xFF00D9FF), Color(0xFF654DFF)],
  );

  static const Map<String, _BrandColors> _byTheme = {
    // Focus: blu acciaio poco saturo, come il tema.
    'focus': _BrandColors(
      lab: [Color(0xFFBFD8F5), Color(0xFF9BB4D6), Color(0xFF7F9CC8), Color(0xFFA8B5E0)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F7FC), Color(0xFFE2EAF4), Color(0xFFCBD8E8)],
      glow: [Color(0xFF9BB4D6), Color(0xFF7F9CC8)],
    ),
    // Argilla: argilla e avorio caldi.
    'argilla': _BrandColors(
      lab: [Color(0xFFF0A07E), Color(0xFFD97757), Color(0xFFC4623F), Color(0xFFE8B48A)],
      student: [Color(0xFFFAF9F5), Color(0xFFF5F4EE), Color(0xFFEFE9DF), Color(0xFFE6D9CB)],
      glow: [Color(0xFFD97757), Color(0xFFE8B48A)],
    ),
    'ardesia': _BrandColors(
      lab: [Color(0xFF26FF63), Color(0xFF39FF9B), Color(0xFF68FFE8), Color(0xFF59D7FF)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFC1E3F1)],
      glow: [Color(0xFF26FF69), Color(0xFF68FFE8)],
    ),
    'terra': _BrandColors(
      lab: [Color(0xFFF26D93), Color(0xFFF27981), Color(0xFFF2B095), Color(0xFFF2D18C)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFC9D9EE)],
      glow: [Color(0xFFF26D90), Color(0xFFF2B095)],
    ),
    'bosco': _BrandColors(
      lab: [Color(0xFFB6F255), Color(0xFF9CF262), Color(0xFF8AF284), Color(0xFF7AF2A3)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFC5E0EC)],
      glow: [Color(0xFFB2F255), Color(0xFF8AF284)],
    ),
    'pietra': _BrandColors(
      lab: [Color(0xFFF2ADAA), Color(0xFFF2C1B0), Color(0xFFF2DFC0), Color(0xFFF2F2BB)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFC9DDF0)],
      glow: [Color(0xFFF2AFAA), Color(0xFFF2DFC0)],
    ),
    'fico': _BrandColors(
      lab: [Color(0xFFC533FF), Color(0xFFF245FF), Color(0xFFFF71D7), Color(0xFFFF6396)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFCBD9F7)],
      glow: [Color(0xFFCA33FF), Color(0xFFFF71D7)],
    ),
    'torbiera': _BrandColors(
      lab: [Color(0xFFEBCA6A), Color(0xFFEBE675), Color(0xFFCEEB91), Color(0xFFA5EB88)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFC7DEEC)],
      glow: [Color(0xFFEBCD6A), Color(0xFFCEEB91)],
    ),
    'kiwi': _BrandColors(
      lab: [Color(0xFFC6C600), Color(0xFFA4D000), Color(0xFF64EA00), Color(0xFF09E200)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFCAE3ED)],
      glow: [Color(0xFFFAFF40), Color(0xFFB3FF7A)],
    ),
    'pesca': _BrandColors(
      lab: [Color(0xFFDA0030), Color(0xFFE30000), Color(0xFFF85600), Color(0xFFF1B300)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFCCDBEF)],
      glow: [Color(0xFFFF617F), Color(0xFFFFB791)],
    ),
    'antartide': _BrandColors(
      lab: [Color(0xFF00B697), Color(0xFF00B9C1), Color(0xFF0086DF), Color(0xFF002DD5)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFC2E5F9)],
      glow: [Color(0xFF26FFE0), Color(0xFF68C3FF)],
    ),
    'cocco': _BrandColors(
      lab: [Color(0xFF9A2330), Color(0xFF9D3126), Color(0xFFA46530), Color(0xFFA2902D)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFC3D4E8)],
      glow: [Color(0xFFD95763), Color(0xFFD9A77E)],
    ),
    'laguna': _BrandColors(
      lab: [Color(0xFF00B64B), Color(0xFF00C17A), Color(0xFF00DFDA), Color(0xFF0086D5)],
      student: [Color(0xFFFFFFFF), Color(0xFFF3F9FF), Color(0xFFDCEEFF), Color(0xFFC1E3F3)],
      glow: [Color(0xFF26FF86), Color(0xFF68FFFC)],
    ),
  };

  static _BrandColors get _colors => _byTheme[_theme.id] ?? _night;

  /// Sfumatura di "Lab" nel titolo della schermata iniziale.
  static List<Color> get labGradient => _colors.lab;

  /// Sfumatura di "Student": nei temi chiari usa il colore del testo.
  static List<Color> get studentGradient {
    if (!_theme.isLight) return _colors.student;
    final p = _theme.palette;
    return [p.pureWhite, p.pureWhite, Color.lerp(p.pureWhite, p.skyBlue, 0.25)!, Color.lerp(p.pureWhite, p.skyBlue, 0.45)!];
  }

  /// Bagliore dietro al titolo.
  static List<Color> get glow => _colors.glow;
}

class _BrandColors {
  final List<Color> lab;
  final List<Color> student;
  final List<Color> glow;

  const _BrandColors({required this.lab, required this.student, required this.glow});
}
