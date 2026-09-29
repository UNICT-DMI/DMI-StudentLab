import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Colori di StudentLab.
///
/// I nomi restano quelli di sempre (`AppColors.skyBlue`, `AppColors.darkElegance`…),
/// ma ora sono getter che leggono la palette del tema attivo
/// ([AppPalette.current]). Cambiando tema cambiano i colori in tutta l'app,
/// senza rinominare nulla. I valori del tema Notte sono in [AppPalette.night].
class AppColors {

  // ---------------------------------------------------------------------------
  // Equivalenti dei colori fissi di Material (Colors.white70, Colors.redAccent…)
  // Con Notte hanno esattamente i valori di Material, quindi nulla cambia;
  // negli altri temi seguono la palette. Nei temi chiari i "bianchi" diventano
  // il colore del testo, con la stessa trasparenza.
  // ---------------------------------------------------------------------------

  static bool get _night => identical(AppPalette.current, AppPalette.night);
  static bool get _light => AppPalette.currentIsLight;
  static Color _ink(Color material, double alpha) =>
      _light ? AppPalette.current.pureWhite.withValues(alpha: alpha) : material;

  static Color get white => _ink(Colors.white, 1);
  static Color get white70 => _ink(Colors.white70, 0.70);
  static Color get white60 => _ink(Colors.white60, 0.60);
  static Color get white54 => _ink(Colors.white54, 0.54);
  static Color get white38 => _ink(Colors.white38, 0.38);
  static Color get white30 => _ink(Colors.white30, 0.30);
  static Color get white24 => _ink(Colors.white24, 0.24);
  static Color get white12 => _ink(Colors.white12, 0.12);
  static Color get white10 => _ink(Colors.white10, 0.10);

  static Color get redAccent => _night ? Colors.redAccent : AppPalette.current.adminCoral;
  static Color get red => _night ? Colors.red : AppPalette.current.adminCoral;
  static Color get greenAccent => _night ? Colors.greenAccent : AppPalette.current.adminGreen;
  static Color get green => _night ? Colors.green : AppPalette.current.adminGreen;
  static Color get amber => _night ? Colors.amber : AppPalette.current.adminAmber;
  static Color get amberAccent => _night ? Colors.amberAccent : AppPalette.current.adminAmber;
  static Color get orange => _night ? Colors.orange : AppPalette.current.adminAmber;
  static Color get orangeAccent => _night ? Colors.orangeAccent : AppPalette.current.adminAmber;
  static Color get blueAccent => _night ? Colors.blueAccent : AppPalette.current.adminBlue;
  static Color get lightBlueAccent => _night ? Colors.lightBlueAccent : AppPalette.current.skyBlue;
  static Color get cyanAccent => _night ? Colors.cyanAccent : AppPalette.current.adminCyan;
  static Color get purpleAccent => _night ? Colors.purpleAccent : AppPalette.current.adminMagenta;

  static Color get brandNightBlue => AppPalette.current.brandNightBlue;
  static Color get secondaryNightBlue => AppPalette.current.secondaryNightBlue;
  static Color get deepOcean => AppPalette.current.deepOcean;

  static Color get darkElegance => AppPalette.current.darkElegance;
  static Color get eleganceSoftNight => AppPalette.current.eleganceSoftNight;
  static Color get eleganceMidnight => AppPalette.current.eleganceMidnight;
  static Color get eleganceDeepNavy => AppPalette.current.eleganceDeepNavy;
  static Color get eleganceShadow => AppPalette.current.eleganceShadow;
  static Color get eleganceObsidian => AppPalette.current.eleganceObsidian;

  static Color get slateMidnight => AppPalette.current.slateMidnight;
  static Color get royalIndigo => AppPalette.current.royalIndigo;
  static Color get electricBlue => AppPalette.current.electricBlue;
  static Color get vividSapphire => AppPalette.current.vividSapphire;
  static Color get lavenderBlue => AppPalette.current.lavenderBlue;

  static Color get materialBlue => AppPalette.current.materialBlue;
  static Color get materialNavy => AppPalette.current.materialNavy;
  static Color get materialSteel => AppPalette.current.materialSteel;
  static Color get materialSky => AppPalette.current.materialSky;

  static Color get socialBlue => AppPalette.current.socialBlue;
  static Color get socialIndigo => AppPalette.current.socialIndigo;
  static Color get socialCobalt => AppPalette.current.socialCobalt;
  static Color get socialSky => AppPalette.current.socialSky;

  static Color get studentBlue => AppPalette.current.studentBlue;
  static Color get studentSteel => AppPalette.current.studentSteel;

  static Color get teacherIndigo => AppPalette.current.teacherIndigo;
  static Color get teacherNavy => AppPalette.current.teacherNavy;

  static Color get availableBlue => AppPalette.current.availableBlue;
  static Color get availableGreen => AppPalette.current.availableGreen;
  static Color get pendingAmber => AppPalette.current.pendingAmber;

  static Color get charcoalGrey => AppPalette.current.charcoalGrey;
  static Color get slateGrey => AppPalette.current.slateGrey;
  static Color get graphite => AppPalette.current.graphite;
  static Color get darkSlate => AppPalette.current.darkSlate;
  static Color get mediumSlate => AppPalette.current.mediumSlate;
  static Color get lightSlate => AppPalette.current.lightSlate;

  static Color get skyBlue => AppPalette.current.skyBlue;
  static Color get diamondDust => AppPalette.current.diamondDust;
  static Color get iceBlue => AppPalette.current.iceBlue;
  static Color get steelBlue => AppPalette.current.steelBlue;

  static Color get pureWhite => AppPalette.current.pureWhite;
  static Color get pearlWhite => AppPalette.current.pearlWhite;
  static Color get mistWhite => AppPalette.current.mistWhite;

  static Color get opaqueWhite => AppPalette.current.opaqueWhite;
  static Color get translucentWhite => AppPalette.current.translucentWhite;

  static Color get correct => AppPalette.current.correct;
  static Color get wrong => AppPalette.current.wrong;

  static Color get adminCyan => AppPalette.current.adminCyan;
  static Color get adminBlue => AppPalette.current.adminBlue;
  static Color get adminIndigo => AppPalette.current.adminIndigo;
  static Color get adminGreen => AppPalette.current.adminGreen;
  static Color get adminAmber => AppPalette.current.adminAmber;
  static Color get adminMagenta => AppPalette.current.adminMagenta;
  static Color get adminCoral => AppPalette.current.adminCoral;

  static Color get surface => AppPalette.current.surface;
  static Color get surfaceStrong => AppPalette.current.surfaceStrong;
  static Color get surfaceSoft => AppPalette.current.surfaceSoft;
  static Color get textPrimary => AppPalette.current.textPrimary;
  static Color get textSecondary => AppPalette.current.textSecondary;
  static Color get textMuted => AppPalette.current.textMuted;
  static Color get divider => AppPalette.current.divider;
  static Color get surfaceBorder => AppPalette.current.surfaceBorder;

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

  static LinearGradient get adminDarkSurfaceGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          eleganceDeepNavy,
          eleganceMidnight,
          eleganceObsidian,
        ],
      );

  static LinearGradient get appBackgroundGradient => LinearGradient(
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
          side: BorderSide(color: surfaceBorder),
        ),
      );

  static AppBarTheme get nightAppBarTheme => AppBarTheme(
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
      BottomNavigationBarThemeData(
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
        extensions: <ThemeExtension<dynamic>>[AppPalette.current],
        scaffoldBackgroundColor: darkElegance,
        colorScheme: ColorScheme.dark(
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
        snackBarTheme: SnackBarThemeData(
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
        bottomSheetTheme: BottomSheetThemeData(
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
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: BorderSide(color: surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: BorderSide(color: surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: BorderSide(color: socialSky, width: 1.2),
          ),
        ),
      );

  static Color get elegantBorder => surfaceBorder;
  static Color get elegantShadow => eleganceShadow.withValues(alpha: 0.35);

  static ButtonStyle get elegantButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: surfaceStrong,
        foregroundColor: pureWhite,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: surfaceBorder),
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