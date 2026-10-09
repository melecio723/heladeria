import 'package:flutter/material.dart';

/// Paleta Gestor de Créditos — estilo BodegApp (índigo/azul moderno) con
/// identidad Bear Helados. Índigo primario, fondos claros con tinte azul y
/// acentos verde/ámbar/rojo para acciones.
class BearColors {
  // --- Marca / primarios (índigo estilo BodegApp) ---
  static const indigo = Color(0xFF4F46E5);
  static const indigoDark = Color(0xFF4338CA);
  static const indigoDeep = Color(0xFF312E81);
  static const blue = Color(0xFF3B82F6);

  /// Alias primario histórico. Antes era rojo Bear; ahora apunta al índigo
  /// para que toda la app migre al look BodegApp sin romper referencias.
  static const primary = indigo;

  // --- Sidebar degradado oscuro índigo ---
  static const sidebarTop = Color(0xFF232A63);
  static const sidebarBottom = Color(0xFF141A45);
  static const sidebar = Color(0xFF1B2050);

  static const white = Color(0xFFFFFFFF);

  // --- Rojo Bear conservado como acento de marca / peligro ---
  static const red = Color(0xFFE53935);
  static const redDark = Color(0xFFC62828);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0xFFFEE2E2);

  // --- Acentos de acción (referencia BodegApp) ---
  static const success = Color(0xFF16A34A);
  static const successLight = Color(0xFFDCFCE7);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const gold = Color(0xFFF59E0B);
  static const pink = Color(0xFFF8BBD0);

  // --- Neutros / superficies con tinte azul ---
  static const bg = Color(0xFFEEF2FB);
  static const bgAlt = Color(0xFFF7F9FE);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const textPrimary = Color(0xFF1E293B);
  static const textMuted = Color(0xFF64748B);
  static const grayLight = Color(0xFF94A3B8);

  /// Sombra suave índigo para tarjetas.
  static const shadow = Color(0x1A312E81);
}

class BearTheme {
  static const double radius = 16;
  static const double radiusSm = 12;

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: BearColors.indigo,
      primary: BearColors.indigo,
      onPrimary: BearColors.white,
      secondary: BearColors.blue,
      onSecondary: BearColors.white,
      surface: BearColors.surface,
      onSurface: BearColors.textPrimary,
      tertiary: BearColors.warning,
      error: BearColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BearColors.bg,
      fontFamily: 'SF Pro Text',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: BearColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: BearColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: BearColors.shadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BearColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: BearColors.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius + 4)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BearColors.indigo,
        foregroundColor: BearColors.white,
      ),
      dividerTheme: const DividerThemeData(color: BearColors.border, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: BearColors.bg,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(color: BearColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BearColors.bgAlt,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: BearColors.grayLight),
        labelStyle: const TextStyle(color: BearColors.textMuted),
        prefixIconColor: BearColors.grayLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: BearColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: BearColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: BearColors.indigo, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BearColors.indigo,
          foregroundColor: BearColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BearColors.textPrimary,
          backgroundColor: BearColors.surface,
          side: const BorderSide(color: BearColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BearColors.indigo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BearColors.indigo,
          foregroundColor: BearColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: const TextStyle(
          color: BearColors.textMuted,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: 0.3,
        ),
        dataTextStyle: const TextStyle(color: BearColors.textPrimary, fontSize: 13.5),
        headingRowColor: WidgetStatePropertyAll(BearColors.bg),
        dividerThickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BearColors.sidebar,
        contentTextStyle: const TextStyle(color: BearColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: BearColors.indigo,
        unselectedLabelColor: BearColors.textMuted,
        indicatorColor: BearColors.indigo,
        dividerColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: BearColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 26),
        titleLarge: TextStyle(color: BearColors.textPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: BearColors.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: BearColors.textPrimary, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: BearColors.textPrimary),
        bodySmall: TextStyle(color: BearColors.textMuted),
      ),
    );
  }
}
