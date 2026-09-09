import 'package:flutter/material.dart';

import 'upp_tokens.dart';

/// `ThemeData` del sistema UPONPENGUIN. El sistema es inherentemente
/// oscuro (base Negro KGB): no existe una variante clara, así que la app
/// fuerza `ThemeMode.dark` en `main.dart` y este es el único tema.
class UppTheme {
  UppTheme._();

  static ThemeData build() {
    const noRadius = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: UppTokens.bgBase,
      fontFamily: UppTokens.fontDisplay,
      colorScheme: const ColorScheme.dark(
        surface: UppTokens.bgBase,
        primary: UppTokens.accent,
        onPrimary: UppTokens.fgOnAccent,
        secondary: UppTokens.accent,
        error: UppTokens.danger,
        onError: UppTokens.fg1,
      ),
      dividerColor: UppTokens.border2,
      dividerTheme: const DividerThemeData(color: UppTokens.border2, thickness: UppTokens.rule),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: UppTokens.bgBase,
        foregroundColor: UppTokens.fg1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: UppTokens.fontDisplay,
          fontWeight: FontWeight.w500,
          fontSize: 18,
          letterSpacing: 0.5,
          color: UppTokens.fg1,
        ),
      ),
      cardTheme: const CardThemeData(
        color: UppTokens.bgCard,
        shape: noRadius,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: UppTokens.border1),
        ),
        backgroundColor: UppTokens.bgPanel,
        labelStyle: const TextStyle(
          fontFamily: UppTokens.fontDisplay,
          fontFeatures: [],
          color: UppTokens.fg1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: UppTokens.bgPanel,
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: UppTokens.border1)),
        enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: UppTokens.border1)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: UppTokens.borderActive)),
        labelStyle: const TextStyle(color: UppTokens.fg3, fontFamily: UppTokens.fontDisplay),
        hintStyle: TextStyle(color: UppTokens.fg3.withValues(alpha: 0.6)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: UppTokens.accent,
          shape: noRadius,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: UppTokens.fg1,
          side: const BorderSide(color: UppTokens.border1),
          shape: noRadius,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: UppTokens.accent,
          foregroundColor: UppTokens.fgOnAccent,
          shape: noRadius,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? UppTokens.accent : UppTokens.fgMuted,
        ),
        thumbColor: const WidgetStatePropertyAll(UppTokens.fg1),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: UppTokens.fg1,
        iconColor: UppTokens.fg3,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: UppTokens.fg1,
        displayColor: UppTokens.fg1,
        fontFamily: UppTokens.fontDisplay,
      ),
      iconTheme: const IconThemeData(color: UppTokens.fg1),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: UppTokens.bgPanel,
        contentTextStyle: TextStyle(color: UppTokens.fg1, fontFamily: UppTokens.fontDisplay),
        shape: noRadius,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: UppTokens.accent),
    );
  }
}
