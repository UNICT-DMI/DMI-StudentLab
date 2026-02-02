import 'package:flutter/material.dart';

class AppColors {
  static const Color midnightNavy = Color(0xFF0A2472);
  static const Color deepOcean = Color(0xFF0F1C3F);
  static const Color darkElegance = Color(0xFF0C0F1A);
  
  static const Color slateMidnight = Color(0xFF1A237E);
  static const Color royalIndigo = Color(0xFF283593);
  static const Color electricBlue = Color(0xFF303F9F);
  static const Color vividSapphire = Color(0xFF3949AB);
  static const Color lavenderBlue = Color(0xFF5C6BC0);
  
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
  
  static List<Color> get cardGradient => [
    vividSapphire.withOpacity(0.9),
    vividSapphire.withOpacity(0.7),
    slateGrey.withOpacity(0.8),
  ];
  
  static List<Color> get backgroundGradient => [
    midnightNavy,
    deepOcean,
    darkElegance,
  ];
  
  static Color get elegantBorder => pureWhite.withOpacity(0.3);
  static Color get elegantShadow => midnightNavy.withOpacity(0.3);
  
  static Map<String, Color> get colorMap => {
    'midnightNavy': midnightNavy,
    'deepOcean': deepOcean,
    'darkElegance': darkElegance,
    'slateMidnight': slateMidnight,
    'royalIndigo': royalIndigo,
    'electricBlue': electricBlue,
    'vividSapphire': vividSapphire,
    'lavenderBlue': lavenderBlue,
    'charcoalGrey': charcoalGrey,
    'slateGrey': slateGrey,
    'graphite': graphite,
    'darkSlate': darkSlate,
    'mediumSlate': mediumSlate,
    'lightSlate': lightSlate,
    'skyBlue': skyBlue,
    'diamondDust': diamondDust,
    'iceBlue': iceBlue,
    'steelBlue': steelBlue,
    'pureWhite': pureWhite,
    'pearlWhite': pearlWhite,
    'mistWhite': mistWhite,
  };
  
  static CardTheme get elegantCardTheme => const CardTheme(
    elevation: 12,
    color: vividSapphire,
  );
  
  static ButtonStyle get elegantButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: translucentWhite,
    foregroundColor: pureWhite,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: elegantBorder, width: 1.5),
    ),
    elevation: 10,
  );
  
  static AppBarTheme get nightAppBarTheme => const AppBarTheme(
    backgroundColor: midnightNavy,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w200,
      color: pearlWhite,
    ),
  );
  
  static BottomNavigationBarThemeData get nightBottomNavTheme => 
    BottomNavigationBarThemeData(
      backgroundColor: midnightNavy.withOpacity(0.9),
      selectedItemColor: diamondDust,
      unselectedItemColor: steelBlue,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w100),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w100),
    );
  
  static Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
  
  static Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
  
  static List<Color> generateShades(Color baseColor, int count) {
    return List.generate(count, (index) {
      final factor = index / (count - 1);
      return Color.lerp(baseColor, darken(baseColor, 0.5), factor)!;
    });
  }
}