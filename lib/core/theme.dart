import 'package:material_ui/material_ui.dart';

// --- Organic & Modern Palette ---
const Color kWhite = Color(0xFFFFFFFF);
const Color kParchment = Color(0xFFFAF9F6); // Soft, warm off-white
const Color kSlate = Color(0xFF1A1A1A);     // Soft black for better readability
const Color kGlassBorder = Color(0x33FFFFFF); // 20% White for glass edges

// Updated Brand Colors based on your landing page's warm tones
const Color kBrandPrimary = Color(0xFF2D2D2D); // Deep Charcoal (Modern & Sleek)
const Color kBrandAccent = Color(0xFFD4AF37);  // Muted Gold (High-end Church feel)

// The whole app follows the group chat's look: charcoal for anything selected
// or primary, clean white cards with a hairline edge on a softly tinted page,
// pill-shaped buttons, and bold, tight titles.
//
// The chat itself only reads primary / surface / surfaceContainer* / onSurface*
// from the scheme, and those stay exactly as they were. Only the *Container
// accents change: the charcoal seed used to turn them cyan.

final ColorScheme _lightScheme = ColorScheme.fromSeed(
  seedColor: kBrandPrimary,
  brightness: Brightness.light,
  primary: kBrandPrimary,
  onPrimary: kWhite,
  secondary: kBrandAccent,
  surface: kParchment, // Warmer base than pure white
  onSurface: kSlate,
  outlineVariant: kGlassBorder,
  // Warm neutral accents instead of the generated cyan.
  primaryContainer: const Color(0xFFEAE7E1),
  onPrimaryContainer: kSlate,
  secondaryContainer: const Color(0xFFF1EAD3), // soft gold tint
  onSecondaryContainer: const Color(0xFF4A3D10),
  tertiaryContainer: const Color(0xFFEDEBE6),
  onTertiaryContainer: kSlate,
);

final ColorScheme _darkScheme = ColorScheme.fromSeed(
  seedColor: kBrandPrimary,
  brightness: Brightness.dark,
  primary: kWhite, // White text/icons on dark surfaces
  onPrimary: kSlate,
  surface: kSlate,
  primaryContainer: const Color(0xFF33322F),
  onPrimaryContainer: kWhite,
  secondaryContainer: const Color(0xFF3B3524),
  onSecondaryContainer: const Color(0xFFF1E3B0),
  tertiaryContainer: const Color(0xFF2E2D2A),
  onTertiaryContainer: kWhite,
);

ThemeData _buildTheme(ColorScheme scheme, {required Color scaffold, required Color appBar}) {
  final dark = scheme.brightness == Brightness.dark;
  // Same "card" and "hairline" the chat uses for other people's messages.
  final card = dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;
  final hairline = scheme.onSurface.withValues(alpha: dark ? 0.08 : 0.09);
  final fieldBorder = scheme.onSurface.withValues(alpha: dark ? 0.14 : 0.16);
  const pill = StadiumBorder();
  const buttonText = TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.1);

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: AppBarTheme(
      backgroundColor: appBar,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: appBar.withValues(alpha: 0),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      // Bold and tight, like the group name in a chat.
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: scheme.onSurface,
      ),
    ),

    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: card.withValues(alpha: 0),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: hairline),
      ),
    ),

    // --- Buttons: pills everywhere ---
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: buttonText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: pill,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: fieldBorder),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: pill,
        foregroundColor: scheme.onSurface,
        textStyle: buttonText.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 3,
      shape: pill,
      extendedTextStyle: buttonText,
    ),

    // --- Inputs: rounded, with the chat field's hairline edge ---
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: fieldBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
    ),

    // --- Overlays ---
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: card.withValues(alpha: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
      surfaceTintColor: card.withValues(alpha: 0),
      modalBackgroundColor: dark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      dragHandleColor: scheme.onSurface.withValues(alpha: 0.2),
      clipBehavior: Clip.antiAlias,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: card.withValues(alpha: 0),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: hairline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w500),
    ),

    // --- Lists & small parts ---
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
      subtitleTextStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      shape: pill,
      side: BorderSide(color: hairline),
      backgroundColor: card,
      selectedColor: scheme.primary,
      secondarySelectedColor: scheme.primary,
      checkmarkColor: scheme.onPrimary,
      labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        side: BorderSide(color: fieldBorder),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    badgeTheme: BadgeThemeData(backgroundColor: scheme.primary, textColor: scheme.onPrimary),
  );
}

final ccfLightTheme = _buildTheme(_lightScheme, scaffold: kParchment, appBar: kParchment);

// --- Dark Theme (Deep Atmospheric) ---
final ccfDarkTheme = _buildTheme(
  _darkScheme,
  scaffold: const Color(0xFF0F0F0F), // Deep Onyx
  appBar: kSlate, // unchanged from before (the chat header sits on it)
);
