import 'package:flutter/material.dart';

// Dark theme colors (default)
const bgColor = Color(0xFF0F172A);
const surfaceColor = Color(0xFF1E293B);
const surface2Color = Color(0xFF334155);
const borderColor = Color(0xFF475569);
const textColor = Color(0xFFF1F5F9);
const textSecondary = Color(0xFF94A3B8);
const primaryColor = Color(0xFF38BDF8);
const primaryDark = Color(0xFF0284C7);
const greenColor = Color(0xFF4ADE80);
const yellowColor = Color(0xFFFBBF24);
const redColor = Color(0xFFF87171);
const cyanColor = Color(0xFF22D3EE);
const purpleColor = Color(0xFFA78BFA);

// Light theme colors
const lightBgColor = Color(0xFFF8FAFC);
const lightSurfaceColor = Color(0xFFFFFFFF);
const lightSurface2Color = Color(0xFFF1F5F9);
const lightBorderColor = Color(0xFFE2E8F0);
const lightTextColor = Color(0xFF1E293B);
const lightTextSecondary = Color(0xFF64748B);

final appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: bgColor,
  colorScheme: const ColorScheme.dark(
    primary: primaryColor,
    surface: surfaceColor,
    onSurface: textColor,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: surfaceColor,
    foregroundColor: textColor,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: textColor,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardThemeData(
    color: surfaceColor,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: borderColor),
    ),
    margin: const EdgeInsets.symmetric(vertical: 4),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: primaryColor),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    filled: true,
    fillColor: bgColor,
    labelStyle: const TextStyle(fontSize: 13, color: textSecondary),
    hintStyle: const TextStyle(fontSize: 13, color: textSecondary),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
    bodyLarge: TextStyle(fontSize: 15, color: textColor),
    bodyMedium: TextStyle(fontSize: 14, color: textColor),
    bodySmall: TextStyle(fontSize: 13, color: textSecondary),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
  ),
  dividerTheme: const DividerThemeData(color: borderColor, space: 1),
  dialogTheme: DialogThemeData(
    backgroundColor: surfaceColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);

final lightAppTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: lightBgColor,
  colorScheme: const ColorScheme.light(
    primary: primaryColor,
    surface: lightSurfaceColor,
    onSurface: lightTextColor,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: lightSurfaceColor,
    foregroundColor: lightTextColor,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: lightTextColor,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardThemeData(
    color: lightSurfaceColor,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: lightBorderColor),
    ),
    margin: const EdgeInsets.symmetric(vertical: 4),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: lightBorderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: lightBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: primaryColor),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    filled: true,
    fillColor: lightBgColor,
    labelStyle: const TextStyle(fontSize: 13, color: lightTextSecondary),
    hintStyle: const TextStyle(fontSize: 13, color: lightTextSecondary),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: lightTextColor),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: lightTextColor),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: lightTextColor),
    bodyLarge: TextStyle(fontSize: 15, color: lightTextColor),
    bodyMedium: TextStyle(fontSize: 14, color: lightTextColor),
    bodySmall: TextStyle(fontSize: 13, color: lightTextSecondary),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: lightTextColor),
  ),
  dividerTheme: const DividerThemeData(color: lightBorderColor, space: 1),
  dialogTheme: DialogThemeData(
    backgroundColor: lightSurfaceColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);

/// Adaptive color getters that respect the current theme brightness
Color getBgColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? bgColor : lightBgColor;
Color getSurfaceColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? surfaceColor : lightSurfaceColor;
Color getSurface2Color(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? surface2Color : lightSurface2Color;
Color getBorderColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? borderColor : lightBorderColor;
Color getTextColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? textColor : lightTextColor;
Color getTextSecondary(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? textSecondary : lightTextSecondary;

Color jvmStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'HEALTHY':
      return greenColor;
    case 'WARNING':
      return yellowColor;
    case 'CRITICAL':
      return redColor;
    default:
      return textSecondary;
  }
}

Color badgeColor(String status) {
  switch (status.toUpperCase()) {
    case 'HEALTHY':
    case 'COMPLETED':
      return greenColor;
    case 'WARNING':
      return yellowColor;
    case 'CRITICAL':
    case 'FAILED':
      return redColor;
    case 'RECORDING':
    case 'DUMPING':
      return cyanColor;
    case 'PENDING':
    case 'CANCELLED':
      return textSecondary;
    default:
      return textSecondary;
  }
}

Color heapBarColor(double percent) {
  if (percent > 85) return redColor;
  if (percent > 70) return yellowColor;
  return greenColor;
}
