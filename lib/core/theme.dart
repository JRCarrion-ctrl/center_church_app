import 'package:flutter/material.dart';
// import 'constants.dart'; // Assuming kBrandPrimary and kBrandAccent are defined here

// --- Red, White, and Blue Palette ---
const Color kWhite = Color.fromARGB(255, 255, 255, 255);
const Color kBlack = Color.fromARGB(255, 0, 0, 0);

const Color kBrandPrimary = Color.fromARGB(255, 0, 122, 255); // Vibrant Blue
const Color kBrandAccent = Color.fromARGB(255, 230, 0, 38); // Muted Red

// --- Enhanced Contrast Neutral Shades ---
// LIGHT THEME NEUTRALS:
const Color kSurfaceLightBase = Color.fromARGB(255, 255, 255, 255); // Pure White (Scaffold)
const Color kSurfaceLightHigh = Color.fromARGB(255, 245, 245, 245); // Off-White (Containers)
const Color kSurfaceLightContrast = Color.fromARGB(255, 150, 150, 150); // Medium Gray (Borders/Outline)

// DARK THEME NEUTRALS:
const Color kSurfaceDarkBase = Color.fromARGB(255, 18, 18, 18); // Deep Blackish-Gray (Scaffold)
const Color kSurfaceDarkContainer = Color.fromARGB(255, 36, 36, 36); // Lighter Gray (Containers)
const Color kSurfaceDarkHigh = Color.fromARGB(255, 50, 50, 50); // AppBar/Highest Surface

final ccfLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kBrandPrimary,
    brightness: Brightness.light,
    
    // Explicitly set main colors
    primary: kBrandPrimary,     // Blue: Buttons, indicators
    onPrimary: kWhite,
    secondary: kBrandAccent,    // Red: Secondary accent/buttons
    onSecondary: kWhite,
    tertiary: kBrandPrimary,    // Blue: Subtle accents

    // --- High Contrast Light Surfaces ---
    surface: kSurfaceLightBase,
    onSurface: kBlack,
    // Used for cards, elevated surfaces to add contrast
    surfaceContainerHighest: kSurfaceLightHigh, 
    outline: kSurfaceLightContrast, // Used for subtle borders/dividers
  ),
  scaffoldBackgroundColor: kSurfaceLightBase,
  appBarTheme: AppBarTheme(
    backgroundColor: kSurfaceLightBase, 
    foregroundColor: kBlack,
    elevation: 0.5, 
    shadowColor: kBlack.withOpacity(0.1),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: kBrandPrimary, 
    foregroundColor: kWhite,
    elevation: 4, 
  ),
);

final ccfDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kBrandPrimary,
    brightness: Brightness.dark,
    
    // Explicitly set main colors
    primary: kBrandPrimary,     // Blue: Buttons, indicators
    onPrimary: kWhite,
    secondary: kBrandAccent,    // Red: Secondary accent/buttons
    onSecondary: kWhite,
    tertiary: kBrandPrimary,    // Blue: Subtle accents

    // --- High Contrast Dark Surfaces ---
    surface: kSurfaceDarkBase,
    onSurface: kWhite,
    surfaceContainerHighest: kSurfaceDarkHigh, 
    surfaceContainer: kSurfaceDarkContainer, // Used for containers/cards
    outline: kSurfaceLightContrast.withOpacity(0.5), // Muted light gray outline
  ),
  scaffoldBackgroundColor: kSurfaceDarkBase,
  appBarTheme: AppBarTheme(
    backgroundColor: kSurfaceDarkHigh.withOpacity(0.9), 
    foregroundColor: kWhite,
    elevation: 0.5,
    shadowColor: kBlack.withOpacity(0.5),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: kBrandPrimary, 
    foregroundColor: kWhite,
    elevation: 4,
  ),
);