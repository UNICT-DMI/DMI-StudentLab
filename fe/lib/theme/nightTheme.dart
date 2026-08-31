import 'package:flutter/material.dart';

class AppColors {
  static const Color brandNightBlue = Color(0xFF1C2841);
  static const Color secondaryNightBlue = Color(0xFF1B263B);
  static const Color deepOcean = Color(0xFF0F1C3F);

  static const Color darkElegance = Color(0xFF0C0F1A);
  static const Color eleganceSoftNight = Color(0xFF0E1220);
  static const Color eleganceMidnight = Color(0xFF111526);
  static const Color eleganceDeepNavy = Color(0xFF14192D);
  static const Color eleganceShadow = Color(0xFF070911);
  static const Color eleganceObsidian = Color(0xFF0B0D14);

  static const Color slateMidnight = Color(0xFF1A237E);
  static const Color royalIndigo = Color(0xFF283593);
  static const Color electricBlue = Color(0xFF303F9F);
  static const Color vividSapphire = Color(0xFF3949AB);
  static const Color lavenderBlue = Color(0xFF5C6BC0);

  static const Color materialBlue = Color(0xFF263A5F);
  static const Color materialNavy = Color(0xFF1E3152);
  static const Color materialSteel = Color(0xFF344B6B);
  static const Color materialSky = Color(0xFF4F7CAC);

  static const Color socialBlue = Color(0xFF304A70);
  static const Color socialIndigo = Color(0xFF3F4F88);
  static const Color socialCobalt = Color(0xFF405D8C);
  static const Color socialSky = Color(0xFF5B8CC0);

  static const Color studentBlue = Color(0xFF42658F);
  static const Color studentSteel = Color(0xFF52769F);

  static const Color teacherIndigo = Color(0xFF454B7A);
  static const Color teacherNavy = Color(0xFF30385F);

  static const Color availableBlue = Color(0xFF4E7FAF);
  static const Color availableGreen = Color(0xFF3F7650);
  static const Color pendingAmber = Color(0xFF9A7838);

  static const Color charcoalGrey = Color(0xFF1A1F3A);
  static const Color slateGrey = Color(0xFF263238);
  static const Color graphite = Color(0xFF212121);
  static const Color darkSlate = Color(0xFF424242);
  static const Color mediumSlate = Color(0xFF757575);
  static const Color lightSlate = Color(0xFFBDBDBD);

  static const Color skyBlue = Color(0xFF64B5F6);
  static const Color diamondDust = Color(0xFFBBDEFB);
  static const Color iceBlue = Color(0xFFE3F2FD);
  static const Color steelBlue = Color(0xFF90A4AE);

  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color pearlWhite = Color(0xFFFAFAFA);
  static const Color mistWhite = Color(0xFFF5F5F5);

  static const Color opaqueWhite = Color.fromRGBO(255, 255, 255, 0.9);
  static const Color translucentWhite = Color.fromRGBO(255, 255, 255, 0.15);

  static const Color correct = Color.fromARGB(255, 4, 89, 8);
  static const Color wrong = Color.fromARGB(255, 68, 1, 1);

  static const Color adminCyan = Color(0xFF35D0E6);
  static const Color adminBlue = Color(0xFF5B8CFF);
  static const Color adminIndigo = Color(0xFF7A78FF);
  static const Color adminGreen = Color(0xFF54D99B);
  static const Color adminAmber = Color(0xFFF4B860);
  static const Color adminMagenta = Color(0xFFE86FCB);
  static const Color adminCoral = Color(0xFFFF7D7D);

  static const Color surface = eleganceDeepNavy;
  static const Color surfaceStrong = eleganceMidnight;
  static const Color surfaceSoft = eleganceSoftNight;
  static const Color textPrimary = pureWhite;
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x73FFFFFF);
  static const Color divider = Color(0x14FFFFFF);
  static const Color surfaceBorder = Color(0x1FFFFFFF);

  static const double radiusSmall = 10;
  static const double radiusMedium = 14;
  static const double radiusLarge = 18;
  static const double radiusXLarge = 22;

  static LinearGradient get adminIconGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          adminCyan.withValues(alpha: 0.70),
          adminBlue.withValues(alpha: 0.55),
          adminIndigo.withValues(alpha: 0.45),
        ],
      );

  static LinearGradient get adminDarkSurfaceGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          eleganceDeepNavy,
          eleganceMidnight,
          eleganceObsidian,
        ],
      );

  static LinearGradient get appBackgroundGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          eleganceSoftNight,
          darkElegance,
          eleganceObsidian,
        ],
      );

  static List<Color> get cardGradient => <Color>[
        eleganceDeepNavy,
        eleganceMidnight,
        eleganceObsidian,
      ];

  static List<Color> get backgroundGradient => <Color>[
        eleganceSoftNight,
        darkElegance,
        eleganceObsidian,
      ];

  static CardThemeData get elegantCardTheme => CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: surfaceBorder),
        ),
      );

  static AppBarTheme get nightAppBarTheme => const AppBarTheme(
        backgroundColor: eleganceMidnight,
        foregroundColor: pureWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: pearlWhite,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: pureWhite, size: 22),
      );

  static BottomNavigationBarThemeData get nightBottomNavTheme =>
      const BottomNavigationBarThemeData(
        backgroundColor: eleganceMidnight,
        selectedItemColor: diamondDust,
        unselectedItemColor: steelBlue,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      );

  static ThemeData get nightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkElegance,
        colorScheme: const ColorScheme.dark(
          primary: socialSky,
          secondary: materialSky,
          surface: eleganceDeepNavy,
          error: adminCoral,
          onPrimary: pureWhite,
          onSecondary: pureWhite,
          onSurface: pureWhite,
          onError: pureWhite,
        ),
        appBarTheme: nightAppBarTheme,
        cardTheme: elegantCardTheme,
        bottomNavigationBarTheme: nightBottomNavTheme,
        dividerColor: divider,
        splashColor: pureWhite.withValues(alpha: 0.05),
        highlightColor: pureWhite.withValues(alpha: 0.03),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: eleganceDeepNavy,
          contentTextStyle: TextStyle(color: pureWhite),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: eleganceDeepNavy,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: eleganceDeepNavy,
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: eleganceDeepNavy,
          modalBarrierColor: Color(0x99000000),
          showDragHandle: true,
          dragHandleColor: textMuted,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceStrong,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: const BorderSide(color: surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: const BorderSide(color: surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: const BorderSide(color: socialSky, width: 1.2),
          ),
        ),
      );

  static Color get elegantBorder => surfaceBorder;
  static Color get elegantShadow => eleganceShadow.withValues(alpha: 0.35);

  static ButtonStyle get elegantButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: surfaceStrong,
        foregroundColor: pureWhite,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: surfaceBorder),
        ),
        elevation: 0,
      );

  static Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final HSLColor hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final HSLColor hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  static List<Color> generateShades(Color baseColor, int count) {
    if (count <= 1) return <Color>[baseColor];
    return List<Color>.generate(
      count,
      (int index) {
        final double factor = index / (count - 1);
        return Color.lerp(baseColor, darken(baseColor, 0.5), factor)!;
      },
    );
  }
}