import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class AppTheme {
  static const Color primary = Color(0xFF2a3d4f);
  static const Color background = Color(0xFFf8f9fa);
  static const Color surface = Color(0xFF000000);
  static const Color cyanAccent = Color(0xFF00BCD4);
  static const Color blueAccent = Color(0xFF2196F3);

  static const Color splashBackground = Color(0xFF0f172a);

  static ButtonStyle _flatButtonStyle() => ButtonStyle(
        elevation: const WidgetStatePropertyAll<double>(0),
        shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      );

  static ThemeData _withoutShadows(ThemeData theme) => theme.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(style: _flatButtonStyle()),
        filledButtonTheme: FilledButtonThemeData(style: _flatButtonStyle()),
        outlinedButtonTheme:
            OutlinedButtonThemeData(style: _flatButtonStyle()),
        textButtonTheme: TextButtonThemeData(style: _flatButtonStyle()),
        cardTheme: const CardThemeData(
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: const DialogThemeData(elevation: 0),
        bottomSheetTheme: const BottomSheetThemeData(elevation: 0),
      );

  static ThemeData get lightTheme {
    final theme = FlexThemeData.light(
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
        useMaterial3Typography: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      fontFamily: 'Kanit',
      scaffoldBackground: const Color(0xFF0f172a),
      extensions: <ThemeExtension<dynamic>>{
        CustomColors(
          backgroundColor: background,
          cardBackground: const Color(0x0A000000),
          hintColor: Colors.blueGrey.shade700,
          cyanColor: cyanAccent,
          blueColor: blueAccent,
        ),
      },
    );
    return _withoutShadows(theme);
  }

  static ThemeData get darkTheme {
    final theme = FlexThemeData.dark(
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
        useMaterial3Typography: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      fontFamily: 'Kanit',
      scaffoldBackground: const Color(0xFF0f172a),
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
    return _withoutShadows(theme);
  }
}

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
