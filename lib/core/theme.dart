import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static SystemUiOverlayStyle getSystemOverlayStyle(bool isDarkMode) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDarkMode ? const Color(0xFF0F0F14) : Colors.white,
      systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
    );
  }

  // Helper getters using context
  static Color primaryColor(BuildContext context) => Theme.of(context).colorScheme.primary;
  static Color surfaceColor(BuildContext context) => Theme.of(context).colorScheme.surface;
  static Color backgroundColor(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
  static Color errorColor(BuildContext context) => Theme.of(context).colorScheme.error;
  static Color textColor(BuildContext context) => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  static Color textLightColor(BuildContext context) => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  static Color dividerColor(BuildContext context) => Theme.of(context).dividerColor;
  static Color secondaryColor(BuildContext context) => Theme.of(context).colorScheme.secondary;
  
  static Color incomeColor(BuildContext context) => const Color(0xFF00D09E);
  static Color expenseColor(BuildContext context) => const Color(0xFFFF6B6B);
  static Color transferColor(BuildContext context) => const Color(0xFF3B82F6);
  
  static Color surfaceLightColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF232339) : const Color(0xFFF1F3F5);
  }

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
    final Color backgroundColor = isDarkMode ? const Color(0xFF0F0F14) : const Color(0xFFF8F9FA);
    final Color surfaceColor = isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;
    final Color surfaceLightColor = isDarkMode ? const Color(0xFF232339) : const Color(0xFFF1F3F5);
    final Color textColor = isDarkMode ? const Color(0xFFF1F1F6) : const Color(0xFF1A1A1A);
    final Color textLightColor = isDarkMode ? const Color(0xFF8E8EA0) : const Color(0xFF6B7280);
    final Color dividerColor = isDarkMode ? const Color(0xFF2A2A3D) : const Color(0xFFE5E7EB);
    
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
            onPrimary: isDarkMode ? const Color(0xFF0F0F14) : Colors.white,
            onSecondary: const Color(0xFF0F0F14),
            onSurface: textColor,
            onError: Colors.white,
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
        displayLarge: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.outfit(color: textColor),
        bodyMedium: GoogleFonts.outfit(color: textLightColor),
        bodySmall: GoogleFonts.outfit(color: textLightColor),
        labelLarge: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w600),
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
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
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
          foregroundColor: isDarkMode ? const Color(0xFF0F0F14) : Colors.white,
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
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
        selectedLabelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: isDarkMode ? const Color(0xFF0F0F14) : Colors.white,
        elevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.outfit(
          color: textLightColor,
          fontSize: 15,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLightColor,
        contentTextStyle: GoogleFonts.outfit(color: textColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Predefined colors for variety
  static const List<Color> accentColors = [
    Color(0xFF00D09E), // Original Teal
    Color(0xFF6366F1), // Indigo
    Color(0xFF3B82F6), // Blue
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEF4444), // Red
    Color(0xFF06B6D4), // Cyan
  ];
}
