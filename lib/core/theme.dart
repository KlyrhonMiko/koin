import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'typography.dart';

export 'typography.dart';

/// Marks the quieter dark appearance used only by editors and Settings.
class EditorAppearance extends ThemeExtension<EditorAppearance> {
  const EditorAppearance();

  @override
  EditorAppearance copyWith() => this;

  @override
  EditorAppearance lerp(covariant EditorAppearance? other, double t) => this;
}

class AppTheme {
  static const _darkBackground = Color(0xFF171A1C);
  static const _darkSurface = Color(0xFF202427);
  static const _darkSurfaceLight = Color(0xFF292E32);

  static SystemUiOverlayStyle getSystemOverlayStyle(bool isDarkMode) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDarkMode ? _darkBackground : Colors.white,
      systemNavigationBarIconBrightness: isDarkMode
          ? Brightness.light
          : Brightness.dark,
    );
  }

  // Helper getters using context
  static Color primaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color errorColor(BuildContext context) =>
      Theme.of(context).colorScheme.error;
  static Color textColor(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  static Color textLightColor(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  static Color dividerColor(BuildContext context) =>
      Theme.of(context).dividerColor;
  static Color secondaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  static Color incomeColor(BuildContext context) => const Color(0xFF00D09E);

  /// Income and success foregrounds that remain readable on light surfaces.
  static Color incomeContentColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? incomeColor(context)
      : const Color(0xFF007A5D);
  static Color expenseColor(BuildContext context) => const Color(0xFFFF6B6B);
  static Color transferColor(BuildContext context) => const Color(0xFF3B82F6);

  static Color surfaceLightColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (hasEditorAppearance(context)) return const Color(0xFF252B2F);
    return isDark ? _darkSurfaceLight : const Color(0xFFF1F3F5);
  }

  static bool hasEditorAppearance(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark &&
      Theme.of(context).extension<EditorAppearance>() != null;

  static Color fieldHintColor(
    BuildContext context, {
    double lightOpacity = 0.45,
  }) => hasEditorAppearance(context)
      ? textLightColor(context)
      : textLightColor(context).withValues(alpha: lightOpacity);

  static Color fieldBorderColor(
    BuildContext context, {
    double lightOpacity = 0.7,
  }) => dividerColor(
    context,
  ).withValues(alpha: hasEditorAppearance(context) ? 0.65 : lightOpacity);

  /// Colored halos become subtle neutral depth in dark mode.
  static BoxShadow boxShadow(
    BuildContext context, {
    required Color color,
    Offset offset = Offset.zero,
    double blurRadius = 0,
    double spreadRadius = 0,
  }) => BoxShadow(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: color.a.clamp(0.0, 0.12))
        : color,
    offset: offset,
    blurRadius: blurRadius,
    spreadRadius: spreadRadius,
  );

  static LinearGradient primaryGradient(BuildContext context) {
    final primary = primaryColor(context);
    return LinearGradient(
      colors: [primary, primary.withValues(alpha: 0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00D09E), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData getTheme(Color primaryColor, bool isDarkMode) {
    final onPrimary = isDarkMode && primaryColor.computeLuminance() > 0.179
        ? Colors.black
        : Colors.white;
    final Color backgroundColor = isDarkMode
        ? _darkBackground
        : const Color(0xFFF8F9FA);
    final Color surfaceColor = isDarkMode ? _darkSurface : Colors.white;
    final Color surfaceLightColor = isDarkMode
        ? _darkSurfaceLight
        : const Color(0xFFF1F3F5);
    final Color textColor = isDarkMode
        ? const Color(0xFFE8EAEB)
        : const Color(0xFF1A1A1A);
    final Color textLightColor = isDarkMode
        ? const Color(0xFFA4ABB0)
        : const Color(0xFF6B7280);
    final Color dividerColor = isDarkMode
        ? const Color(0xFF363C40)
        : const Color(0xFFE5E7EB);

    const Color errorColor = Color(0xFFFF6B6B);
    const Color secondaryColor = Color(0xFF34D399);

    final brightness = isDarkMode ? Brightness.dark : Brightness.light;
    final baseTheme = isDarkMode ? ThemeData.dark() : ThemeData.light();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      dividerColor: dividerColor,
      colorScheme: isDarkMode
          ? ColorScheme.dark(
              primary: primaryColor,
              secondary: secondaryColor,
              surface: surfaceColor,
              error: errorColor,
              onPrimary: onPrimary,
              onSecondary: const Color(0xFF0A0A0A),
              onSurface: textColor,
              onError: _darkBackground,
              onSurfaceVariant: textLightColor,
              surfaceContainerLowest: backgroundColor,
              surfaceContainerLow: surfaceColor,
              surfaceContainer: surfaceColor,
              surfaceContainerHigh: surfaceLightColor,
              surfaceContainerHighest: const Color(0xFF32383C),
              outline: textLightColor,
              outlineVariant: dividerColor,
              primaryContainer: Color.lerp(surfaceColor, primaryColor, 0.16),
              onPrimaryContainer: textColor,
              secondaryContainer: Color.lerp(
                surfaceColor,
                secondaryColor,
                0.16,
              ),
              onSecondaryContainer: textColor,
              errorContainer: Color.lerp(surfaceColor, errorColor, 0.16),
              onErrorContainer: textColor,
            )
          : ColorScheme.light(
              primary: primaryColor,
              secondary: secondaryColor,
              surface: surfaceColor,
              error: errorColor,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: textColor,
              onError: Colors.white,
            ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.inputAmount,
          fontWeight: KoinTypography.headingWeight,
          letterSpacing: -2,
          height: KoinTypography.amountHeight,
        ),
        displayMedium: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.summaryAmount,
          fontWeight: KoinTypography.headingWeight,
          letterSpacing: KoinTypography.amountTracking,
          height: KoinTypography.amountHeight,
        ),
        displaySmall: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.formTitle,
          fontWeight: KoinTypography.headingWeight,
          letterSpacing: KoinTypography.headingTracking,
        ),
        headlineLarge: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.formTitle,
          fontWeight: KoinTypography.headingWeight,
          letterSpacing: KoinTypography.headingTracking,
        ),
        headlineMedium: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.screenTitle,
          fontWeight: KoinTypography.headingWeight,
          letterSpacing: KoinTypography.headingTracking,
        ),
        headlineSmall: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.sectionTitle,
          fontWeight: KoinTypography.headingWeight,
          letterSpacing: KoinTypography.headingTracking,
        ),
        titleLarge: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.sectionTitle,
          fontWeight: KoinTypography.headingWeight,
          letterSpacing: KoinTypography.headingTracking,
        ),
        titleMedium: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.itemTitle,
          fontWeight: KoinTypography.titleWeight,
          letterSpacing: KoinTypography.itemTracking,
        ),
        titleSmall: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.compact,
          fontWeight: KoinTypography.titleWeight,
          letterSpacing: KoinTypography.itemTracking,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.body,
          fontWeight: KoinTypography.labelWeight,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: textLightColor,
          fontSize: KoinTypography.caption,
          fontWeight: KoinTypography.supportingWeight,
        ),
        bodySmall: GoogleFonts.outfit(
          color: textLightColor,
          fontSize: KoinTypography.small,
          fontWeight: KoinTypography.supportingWeight,
        ),
        labelLarge: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.itemTitle,
          fontWeight: KoinTypography.titleWeight,
        ),
        labelMedium: GoogleFonts.outfit(
          color: textLightColor,
          fontSize: KoinTypography.small,
          fontWeight: KoinTypography.labelWeight,
        ),
        labelSmall: GoogleFonts.outfit(
          color: textLightColor,
          fontSize: KoinTypography.overline,
          fontWeight: KoinTypography.titleWeight,
          letterSpacing: KoinTypography.overlineTracking,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.screenTitle,
          fontWeight: KoinTypography.headingWeight,
          letterSpacing: KoinTypography.headingTracking,
        ),
        systemOverlayStyle: getSystemOverlayStyle(isDarkMode),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: dividerColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLightColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dividerColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: errorColor, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: GoogleFonts.outfit(color: textLightColor, fontSize: 15),
        labelStyle: GoogleFonts.outfit(color: textLightColor, fontSize: 15),
        prefixIconColor: textLightColor,
        suffixIconColor: textLightColor,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textLightColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: onPrimary,
        elevation: isDarkMode ? 0 : 8,
        highlightElevation: isDarkMode ? 2 : 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.outfit(
          color: textColor,
          fontSize: KoinTypography.screenTitle,
          fontWeight: KoinTypography.headingWeight,
          letterSpacing: KoinTypography.headingTracking,
        ),
        contentTextStyle: GoogleFonts.outfit(
          color: textLightColor,
          fontSize: 15,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: GoogleFonts.outfit(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dividerColor, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: dividerColor,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceLightColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: dividerColor),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceLightColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // Predefined colors for variety
  static const List<Color> accentColors = [
    Color(0xFF00D09E), // Original Teal
    Color(0xFF3B82F6), // Blue
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFF43F5E), // Rose
    Color(0xFFEF4444), // Red
    Color(0xFFF59E0B), // Amber
    Color(0xFFEAB308), // Yellow
    Color(0xFF84CC16), // Lime
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFF0EA5E9), // Sky
    Color(0xFFD946EF), // Fuchsia
    Color(0xFF64748B), // Slate
    Color(0xFF171717), // Black
  ];

  // Premium, rich background colors for beautiful card designs
  static const List<Color> cardColors = [
    Color(0xFF1A1D1E), // Obsidian Black
    Color(0xFF0F172A), // Deep Navy
    Color(0xFF1E293B), // Navy Slate
    Color(0xFF1E3A8A), // Royal Blue
    Color(0xFF312E81), // Deep Indigo
    Color(0xFF4C1D95), // Rich Purple
    Color(0xFF701A75), // Dark Plum
    Color(0xFF831843), // Deep Rose
    Color(0xFF7F1D1D), // Crimson
    Color(0xFF451A03), // Mahogany
    Color(0xFF78350F), // Bronze
    Color(0xFF14532D), // Forest Green
    Color(0xFF064E3B), // Deep Emerald
    Color(0xFF134E4A), // Dark Teal
    Color(0xFF164E63), // Ocean Cyan
    Color(0xFF334155), // Slate Gray
  ];
}
