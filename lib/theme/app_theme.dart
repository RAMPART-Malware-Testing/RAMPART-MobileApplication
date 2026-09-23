// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class AppTheme {
  // กำหนดสีจากธีมเว็บของคุณ
  static const Color primary = Color(0xFF2a3d4f); // #2a3d4f
  static const Color background = Color(0xFFf8f9fa); // #f8f9fa
  static const Color surface = Color(0xFF000000); // #000000
  static const Color cyanAccent = Color(0xFF00BCD4);
  static const Color blueAccent = Color(0xFF2196F3);

  static ThemeData get lightTheme {
    return FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: primary,
        primaryContainer: Color(0xFF1e2c39),
        secondary: cyanAccent,
        secondaryContainer: Color(0xFF80DEEA),
        tertiary: blueAccent,
        tertiaryContainer: Color(0xFF90CAF9),
        appBarColor: primary,
        error: Color(0xFFB00020),
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 20,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        blendOnColors: false,
        useTextTheme: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      fontFamily: 'Kanit',
      // สำหรับ Dark Theme ที่คุณใช้ในเว็บ
      scaffoldBackground: const Color(0xFF0f172a),
      // cardColor: const Color(0x0FFFFFFF),
    );
  }

  static ThemeData get darkTheme {
    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: primary,
        primaryContainer: Color(0xFF1e2c39),
        secondary: cyanAccent,
        secondaryContainer: Color(0xFF006874),
        tertiary: blueAccent,
        tertiaryContainer: Color(0xFF004BA0),
        appBarColor: primary,
        error: Color(0xFFCF6679),
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 15,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 30,
        useTextTheme: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      fontFamily: 'Kanit',
      // ตั้งค่าสำหรับ Dark Theme แบบเว็บของคุณ
      scaffoldBackground: const Color(0xFF0f172a),
      // cardColor: const Color(0x0FFFFFFF),
      // Custom colors for your specific needs
      extensions: <ThemeExtension<dynamic>>{
        CustomColors(
          backgroundColor: const Color(0xFF0f172a),
          cardBackground: const Color(0x0FFFFFFF),
          hintColor: Colors.blueGrey.shade300,
          cyanColor: cyanAccent,
          blueColor: blueAccent,
        ),
      },
    );
  }
}

// Custom Theme Extension สำหรับสีพิเศษ
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    required this.backgroundColor,
    required this.cardBackground,
    required this.hintColor,
    required this.cyanColor,
    required this.blueColor,
  });

  final Color backgroundColor;
  final Color cardBackground;
  final Color hintColor;
  final Color cyanColor;
  final Color blueColor;

  @override
  ThemeExtension<CustomColors> copyWith({
    Color? backgroundColor,
    Color? cardBackground,
    Color? hintColor,
    Color? cyanColor,
    Color? blueColor,
  }) {
    return CustomColors(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cardBackground: cardBackground ?? this.cardBackground,
      hintColor: hintColor ?? this.hintColor,
      cyanColor: cyanColor ?? this.cyanColor,
      blueColor: blueColor ?? this.blueColor,
    );
  }

  @override
  ThemeExtension<CustomColors> lerp(
    ThemeExtension<CustomColors>? other,
    double t,
  ) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      hintColor: Color.lerp(hintColor, other.hintColor, t)!,
      cyanColor: Color.lerp(cyanColor, other.cyanColor, t)!,
      blueColor: Color.lerp(blueColor, other.blueColor, t)!,
    );
  }
}
