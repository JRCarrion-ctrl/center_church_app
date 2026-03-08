import 'package:flutter/material.dart';

// --- Organic & Modern Palette ---
const Color kWhite = Color(0xFFFFFFFF);
const Color kParchment = Color(0xFFFAF9F6); // Soft, warm off-white
const Color kSlate = Color(0xFF1A1A1A);     // Soft black for better readability
const Color kGlassBorder = Color(0x33FFFFFF); // 20% White for glass edges

// Updated Brand Colors based on your landing page's warm tones
const Color kBrandPrimary = Color(0xFF2D2D2D); // Deep Charcoal (Modern & Sleek)
const Color kBrandAccent = Color(0xFFD4AF37);  // Muted Gold (High-end Church feel)

final ccfLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kBrandPrimary,
    brightness: Brightness.light,
    primary: kBrandPrimary,
    onPrimary: kWhite,
    secondary: kBrandAccent,
    surface: kParchment, // Warmer base than pure white
    onSurface: kSlate,
    outlineVariant: kGlassBorder,
  ),
  scaffoldBackgroundColor: kParchment,
  
  // Apply the "Sleek" card style globally
  cardTheme: CardThemeData(
    color: kWhite.withValues(alpha: 0.9),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28), // Matches Landing Page pill buttons
      side: BorderSide(color: kSlate.withValues(alpha: 0.05)),
    ),
  ),

  appBarTheme: AppBarTheme(
    backgroundColor: kParchment,
    foregroundColor: kSlate,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w300, // Sleek, light weight
      letterSpacing: 2.0,
      color: kSlate,
    ),
  ),

  // Global Button Theme for pill-shaped consistency
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: StadiumBorder(), // Forces the "Pill" shape everywhere
    ),
  ),
);

// --- Dark Theme (Deep Atmospheric) ---
final ccfDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kBrandPrimary,
    brightness: Brightness.dark,
    primary: kWhite, // White text/icons on dark surfaces
    onPrimary: kSlate,
    surface: kSlate,
  ),
  scaffoldBackgroundColor: const Color(0xFF0F0F0F), // Deep Onyx
  cardTheme: CardThemeData(
    color: const Color(0xFF1E1E1E),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: kWhite.withValues(alpha: 0.1)),
    ),
  ),
);