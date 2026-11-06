import 'package:flutter/material.dart';

/// Folio design tokens — warm paper, ink serif, one vermilion accent.
///
/// Colours are read only through `context.f`; text only through [FolioText].
/// No network fonts: we use the platform serif/sans generics with a fallback
/// chain so the editorial look survives on every device.
const List<String> kSerifFallback = ['Georgia', 'Times New Roman', 'serif'];
const List<String> kSansFallback = ['Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'];

/// The full palette for one brightness. Immutable; use [FolioColors.light] /
/// [FolioColors.dark] or `context.f`.
@immutable
class FolioColors {
  const FolioColors({
    required this.paper,
    required this.card,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentSoft,
    required this.rule,
    required this.gold,
    required this.success,
    required this.danger,
    required this.warning,
    required this.brightness,
  });

  final Color paper;
  final Color card;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color accentSoft;
  final Color rule;
  final Color gold;
  final Color success;
  final Color danger;
  final Color warning;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  static const FolioColors light = FolioColors(
    paper: Color(0xFFF6F1E7),
    card: Color(0xFFFBF8F1),
    surface: Color(0xFFFFFDF8),
    ink: Color(0xFF1C1B19),
    muted: Color(0xFF6B655C),
    faint: Color(0xFF9C958A),
    accent: Color(0xFFC73E1D),
    accentSoft: Color(0xFFF3DED5),
    rule: Color(0xFFDED6C6),
    gold: Color(0xFFB5732E),
    success: Color(0xFF3E6B4A),
    danger: Color(0xFFB3261E),
    warning: Color(0xFFB5732E),
    brightness: Brightness.light,
  );

  static const FolioColors dark = FolioColors(
    paper: Color(0xFF15130F),
    card: Color(0xFF1E1B16),
    surface: Color(0xFF26221B),
    ink: Color(0xFFEDE6D8),
    muted: Color(0xFFA79E8E),
    faint: Color(0xFF7C7466),
    accent: Color(0xFFE0653F),
    accentSoft: Color(0xFF3A241C),
    rule: Color(0xFF38332A),
    gold: Color(0xFFD29A5B),
    success: Color(0xFF7FB08C),
    danger: Color(0xFFE07A6F),
    warning: Color(0xFFD29A5B),
    brightness: Brightness.dark,
  );
}

/// Read the active palette: `final f = context.f;`.
extension FolioContext on BuildContext {
  FolioColors get f =>
      Theme.of(this).brightness == Brightness.dark ? FolioColors.dark : FolioColors.light;
}

/// Editorial type scale. Display + body use the platform serif; labels and
/// captions use a clean sans. Everything is a [TextStyle] you can pass to Text.
class FolioText {
  FolioText._();

  static TextStyle _serif(BuildContext context, double size,
      {FontWeight weight = FontWeight.w400, double height = 1.25, FontStyle? style, double? spacing}) {
    return TextStyle(
      fontFamily: 'serif',
      fontFamilyFallback: kSerifFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      fontStyle: style,
      letterSpacing: spacing,
      color: context.f.ink,
    );
  }

  static TextStyle _sans(BuildContext context, double size,
      {FontWeight weight = FontWeight.w400, double height = 1.4, double? spacing, Color? color}) {
    return TextStyle(
      fontFamily: 'sans-serif',
      fontFamilyFallback: kSansFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color ?? context.f.ink,
    );
  }

  static TextStyle display(BuildContext context) => _serif(context, 44, weight: FontWeight.w700, height: 1.1);
  static TextStyle h1(BuildContext context) => _serif(context, 32, weight: FontWeight.w700, height: 1.15);
  static TextStyle h2(BuildContext context) => _serif(context, 24, weight: FontWeight.w700, height: 1.2);
  static TextStyle h3(BuildContext context) => _serif(context, 19, weight: FontWeight.w600, height: 1.25);
  static TextStyle title(BuildContext context) => _serif(context, 17, weight: FontWeight.w600, height: 1.3);
  static TextStyle body(BuildContext context) => _serif(context, 16, height: 1.55);
  static TextStyle bodySmall(BuildContext context) => _serif(context, 14, height: 1.5);
  static TextStyle italic(BuildContext context) => _serif(context, 16, style: FontStyle.italic, height: 1.5);
  static TextStyle quote(BuildContext context) => _serif(context, 20, style: FontStyle.italic, height: 1.45);
  static TextStyle caption(BuildContext context) => _sans(context, 12.5, color: context.f.muted, height: 1.4);
  static TextStyle label(BuildContext context) =>
      _sans(context, 11, weight: FontWeight.w700, spacing: 1.4, color: context.f.muted);
  static TextStyle button(BuildContext context) => _sans(context, 14, weight: FontWeight.w600, spacing: 0.3);
  static TextStyle mono(BuildContext context) => TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier New', 'monospace'],
        fontSize: 13,
        height: 1.4,
        color: context.f.ink,
      );
}

/// Spacing + radii tokens.
class FolioSpace {
  FolioSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double radius = 14;
  static const double radiusSm = 10;
  static const double maxContentWidth = 720;
}

/// Build the themed [ThemeData] for one brightness. We strip Material chrome
/// (no splash, no elevation tint) so the Folio widgets read as paper.
ThemeData buildFolioTheme(Brightness brightness) {
  final f = brightness == Brightness.dark ? FolioColors.dark : FolioColors.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: f.paper,
    colorScheme: base.colorScheme.copyWith(
      brightness: brightness,
      primary: f.accent,
      secondary: f.accent,
      surface: f.card,
      error: f.danger,
      onPrimary: Colors.white,
      onSurface: f.ink,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: f.rule,
    iconTheme: IconThemeData(color: f.ink),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: f.accent,
      selectionColor: f.accent.withValues(alpha: 0.22),
      selectionHandleColor: f.accent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: f.paper,
      foregroundColor: f.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: f.faint),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: f.rule)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: f.accent, width: 1.4)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: f.ink,
      contentTextStyle: TextStyle(color: f.paper),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
