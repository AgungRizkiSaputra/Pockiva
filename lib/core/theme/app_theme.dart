import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';

/// Semantic theme extension so components access brand surfaces & semantic colors cleanly.
@immutable
class AppColorPalette extends ThemeExtension<AppColorPalette> {
  const AppColorPalette({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.sageFill,
    required this.sageText,
    required this.sageSurface,
    required this.fabAccent,
    required this.linkAccent,
    required this.success,
    required this.successBg,
    required this.danger,
    required this.dangerBg,
    required this.warning,
    required this.warningBg,
  });

  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color sageFill;
  final Color sageText;
  final Color sageSurface;
  final Color fabAccent;
  final Color linkAccent;
  final Color success;
  final Color successBg;
  final Color danger;
  final Color dangerBg;
  final Color warning;
  final Color warningBg;

  Color get sageBorder => sageFill.withValues(alpha: 0.35);
  Color get borderSubtle => border.withValues(alpha: 0.65);

  static const AppColorPalette light = AppColorPalette(
    background: AppTokens.sand,
    surface: AppTokens.surfaceWhite,
    surfaceSubtle: AppTokens.sandSubtle,
    border: AppTokens.sandBorder,
    inkPrimary: AppTokens.inkPrimary,
    inkSecondary: AppTokens.inkSecondary,
    sageFill: AppTokens.sage,
    sageText: AppTokens.sageDeep,
    sageSurface: AppTokens.sageLight,
    fabAccent: AppTokens.electricBlue,
    linkAccent: AppTokens.electricBlueAccessible,
    success: AppTokens.successLight,
    successBg: AppTokens.successBgLight,
    danger: AppTokens.dangerLight,
    dangerBg: AppTokens.dangerBgLight,
    warning: AppTokens.warningLight,
    warningBg: AppTokens.warningBgLight,
  );

  static const AppColorPalette dark = AppColorPalette(
    background: AppTokens.darkBackground,
    surface: AppTokens.darkSurface,
    surfaceSubtle: AppTokens.darkSurfaceElevated,
    border: AppTokens.darkBorder,
    inkPrimary: AppTokens.darkInkPrimary,
    inkSecondary: AppTokens.darkInkSecondary,
    sageFill: AppTokens.sageDarkAccent,
    sageText: AppTokens.sageDarkAccent,
    sageSurface: Color(0xFF0F2D22),
    fabAccent: AppTokens.electricBlue,
    linkAccent: Color(0xFF60A5FA),
    success: AppTokens.successDark,
    successBg: AppTokens.successBgDark,
    danger: AppTokens.dangerDark,
    dangerBg: AppTokens.dangerBgDark,
    warning: AppTokens.warningDark,
    warningBg: AppTokens.warningBgDark,
  );

  @override
  AppColorPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSubtle,
    Color? border,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? sageFill,
    Color? sageText,
    Color? sageSurface,
    Color? fabAccent,
    Color? linkAccent,
    Color? success,
    Color? successBg,
    Color? danger,
    Color? dangerBg,
    Color? warning,
    Color? warningBg,
  }) {
    return AppColorPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      border: border ?? this.border,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      sageFill: sageFill ?? this.sageFill,
      sageText: sageText ?? this.sageText,
      sageSurface: sageSurface ?? this.sageSurface,
      fabAccent: fabAccent ?? this.fabAccent,
      linkAccent: linkAccent ?? this.linkAccent,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
    );
  }

  @override
  AppColorPalette lerp(ThemeExtension<AppColorPalette>? other, double t) {
    if (other is! AppColorPalette) return this;
    return AppColorPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      sageFill: Color.lerp(sageFill, other.sageFill, t)!,
      sageText: Color.lerp(sageText, other.sageText, t)!,
      sageSurface: Color.lerp(sageSurface, other.sageSurface, t)!,
      fabAccent: Color.lerp(fabAccent, other.fabAccent, t)!,
      linkAccent: Color.lerp(linkAccent, other.linkAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
    );
  }
}

extension AppThemeX on BuildContext {
  AppColorPalette get palette =>
      Theme.of(this).extension<AppColorPalette>() ?? AppColorPalette.light;
}

class AppTheme {
  const AppTheme._();

  /// Toggleable for unit/widget tests to avoid HTTP font loading in offline test runs.
  static bool useGoogleFonts = true;

  static ThemeData light() => _build(
        brightness: Brightness.light,
        palette: AppColorPalette.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        palette: AppColorPalette.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppColorPalette palette,
  }) {
    final baseTextTheme = _createTextTheme(brightness, palette);
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.sageText,
      onPrimary: brightness == Brightness.light ? Colors.white : AppTokens.darkBackground,
      secondary: palette.fabAccent,
      onSecondary: Colors.white,
      error: palette.danger,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.inkPrimary,
      outline: palette.border,
      surfaceContainerHighest: palette.surfaceSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: baseTextTheme,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.inkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: palette.inkPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.sageText,
          foregroundColor:
              brightness == Brightness.light ? Colors.white : AppTokens.darkBackground,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space24,
            vertical: AppTokens.space12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.inkPrimary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space24,
            vertical: AppTokens.space12,
          ),
          side: BorderSide(color: palette.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.linkAccent,
          minimumSize: const Size(44, 44),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.fabAccent,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: palette.sageText, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: palette.danger, width: 1.5),
        ),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(color: palette.inkSecondary),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(
          color: palette.inkSecondary.withValues(alpha: 0.7),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusSheet),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.sageSurface,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return baseTextTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.sageText : palette.inkSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? palette.sageText : palette.inkSecondary,
            size: 24,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.inkPrimary,
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
          color: palette.background,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
    );
  }

  static TextTheme _createTextTheme(
    Brightness brightness,
    AppColorPalette palette,
  ) {
    final fallbackBase = brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white;

    final base = useGoogleFonts
        ? GoogleFonts.plusJakartaSansTextTheme(fallbackBase)
        : fallbackBase;

    const tabular = [FontFeature.tabularFigures()];

    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: palette.inkPrimary,
        fontFeatures: tabular,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: palette.inkPrimary,
        fontFeatures: tabular,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: palette.inkPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: palette.inkPrimary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.45,
        color: palette.inkPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.45,
        color: palette.inkPrimary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.4,
        color: palette.inkSecondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: palette.inkPrimary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: palette.inkSecondary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: palette.inkSecondary,
      ),
    );
  }
}
