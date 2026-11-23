import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Couleurs de base de l'appli (identité du réseau Radio Campus).
class AppColors {
  static const Color brand = Color(0xFF2154FF); // bleu de la catégorie "radio-campus" de l'API
  static const Color live = Color(0xFFFF3D57); // pastille "en direct"
}

// Arrondis et espacements utilisés partout, pour garder un rythme régulier.
class AppRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;
  static const double xxl = 64;
}

class AppTheme {
  static ThemeData dark([Color seed = AppColors.brand]) => fromSeed(seed, Brightness.dark);
  static ThemeData light([Color seed = AppColors.brand]) => fromSeed(seed, Brightness.light);

  // "fidelity" garde la couleur d'origine (celle du logo) au lieu de la ternir.
  static ColorScheme schemeFromSeed(Color seed, Brightness brightness) => ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );

  static ThemeData fromSeed(Color seed, Brightness brightness) => fromScheme(schemeFromSeed(seed, brightness));

  // Tout le thème est construit à partir d'un ColorScheme : c'est ce qui permet
  // à chaque page radio d'avoir ses propres couleurs avec les mêmes composants.
  static ThemeData fromScheme(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final texte = _textTheme(base.textTheme).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final champ = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: texte,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: texte.titleLarge,
        // Icônes de la barre de statut lisibles sur le fond (barres transparentes).
        systemOverlayStyle:
            (scheme.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
              statusBarColor: Colors.transparent,
            ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: texte.labelLarge!.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
          textStyle: texte.labelLarge!.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: const StadiumBorder())),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: champ,
        enabledBorder: champ,
        focusedBorder: champ.copyWith(borderSide: BorderSide(color: scheme.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        selectedColor: scheme.primaryContainer,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      // Pas de bulle de valeur au-dessus du curseur (gênante sous le doigt).
      sliderTheme: const SliderThemeData(
        showValueIndicator: ShowValueIndicator.never,
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final plateforme in TargetPlatform.values) plateforme: const FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  // Poppins pour les titres, Inter pour le texte courant.
  // (google_fonts 9 attend le TextTheme du package material_ui : on applique
  // donc les polices style par style, avec des TextStyle communs aux deux.)
  static TextTheme _textTheme(TextTheme base) {
    TextStyle corps(TextStyle? style) => GoogleFonts.inter(textStyle: style);
    TextStyle titre(TextStyle? style, FontWeight poids, [double espacement = -0.5]) =>
        GoogleFonts.poppins(textStyle: style, fontWeight: poids, letterSpacing: espacement);
    return TextTheme(
      displayLarge: titre(base.displayLarge, FontWeight.w700, -1.5),
      displayMedium: titre(base.displayMedium, FontWeight.w700, -1),
      displaySmall: titre(base.displaySmall, FontWeight.w700),
      headlineLarge: titre(base.headlineLarge, FontWeight.w700),
      headlineMedium: titre(base.headlineMedium, FontWeight.w600),
      headlineSmall: titre(base.headlineSmall, FontWeight.w600),
      titleLarge: titre(base.titleLarge, FontWeight.w600, 0),
      titleMedium: titre(base.titleMedium, FontWeight.w600, 0),
      titleSmall: corps(base.titleSmall),
      bodyLarge: corps(base.bodyLarge),
      bodyMedium: corps(base.bodyMedium),
      bodySmall: corps(base.bodySmall),
      labelLarge: corps(base.labelLarge),
      labelMedium: corps(base.labelMedium),
      labelSmall: corps(base.labelSmall),
    );
  }
}
