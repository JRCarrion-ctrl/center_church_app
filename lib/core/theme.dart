import 'package:flutter/material.dart';
import 'constants.dart'; // if you moved the constants

final ccfLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kBrandPrimary,
    brightness: Brightness.light,
    surfaceContainerHighest: kSurfaceLight,
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: kBrandPrimary,
    foregroundColor: Colors.white,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: kBrandAccent,
  ),
);

final ccfDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kBrandPrimary,
    brightness: Brightness.dark,
    surfaceContainerHighest: kSurfaceDark,
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1F1F1F),
    foregroundColor: Colors.white,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: kBrandAccent,
  ),
);
