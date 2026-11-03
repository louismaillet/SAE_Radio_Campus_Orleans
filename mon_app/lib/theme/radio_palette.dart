import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/campus_radio.dart';
import '../models/radio_settings.dart';
import 'app_theme.dart';

// D'où vient la couleur d'une radio (affiché dans l'espace gérant).
enum PaletteSource { gerant, logo, api, defaut }

// Identité visuelle d'une radio : une couleur "graine" d'où on tire
// tout le thème (boutons, textes) et le dégradé de fond de sa page.
class RadioPalette {
  const RadioPalette(this.seed, this.source);

  static const RadioPalette defaut = RadioPalette(AppColors.brand, PaletteSource.defaut);

  final Color seed;
  final PaletteSource source;

  ThemeData theme(Brightness brightness) => AppTheme.fromSeed(seed, brightness);

  // Dégradé subtil : la couleur de la radio en haut, qui se fond dans le fond de page.
  Gradient fond(Brightness brightness) {
    final scheme = AppTheme.schemeFromSeed(seed, brightness);
    final sombre = brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(scheme.surface, seed, sombre ? 0.55 : 0.35)!,
        Color.lerp(scheme.surface, scheme.tertiary, sombre ? 0.18 : 0.10)!,
        scheme.surface,
      ],
      stops: const [0, 0.45, 0.9],
    );
  }

  // Halo lumineux derrière le logo ou les boutons.
  List<BoxShadow> halo([double force = 1]) => [
    BoxShadow(
      color: seed.withValues(alpha: 0.45 * force),
      blurRadius: 60 * force,
      spreadRadius: -8,
    ),
  ];
}

// Calcule la palette d'une radio. Ordre de priorité :
// 1. la couleur choisie par le gérant,
// 2. la couleur dominante du logo (du gérant, sinon celui de l'API),
// 3. la couleur donnée par l'API (backgroundColor ou couleur de catégorie),
// 4. le bleu du réseau.
//
// Attention : sur le web, le serveur d'images de l'API n'autorise pas le CORS,
// on ne peut donc pas lire les pixels de ses logos. L'étape 2 échoue alors
// en silence et on passe à l'étape 3 (les logos envoyés par les gérants marchent).
class RadioPaletteResolver {
  // Couleurs déjà extraites, pour ne pas analyser deux fois la même image.
  static final Map<String, Future<Color?>> _cache = {};

  static Future<RadioPalette> resolve(CampusRadio radio, {RadioSettings? settings, String? couleurApi}) async {
    final couleurGerant = settings?.couleur;
    if (couleurGerant != null) {
      return RadioPalette(couleurGerant, PaletteSource.gerant);
    }
    final duLogo = await couleurDuLogo(logoBytes: settings?.logo, logoUrl: radio.logoUrl);
    if (duLogo != null) {
      return RadioPalette(duLogo, PaletteSource.logo);
    }
    final api = _couleurApi(radio, couleurApi);
    if (api != null) {
      return RadioPalette(api, PaletteSource.api);
    }
    return RadioPalette.defaut;
  }

  // Couleur de l'API, en ignorant le noir, le blanc et les gris
  // (ex. Radio Campus France a "#000000") : ils donneraient une page terne.
  static Color? _couleurApi(CampusRadio radio, String? couleurApi) {
    for (final hex in [couleurApi, radio.categoryColor]) {
      final couleur = parseHex(hex);
      if (couleur == null) {
        continue;
      }
      final hsl = HSLColor.fromColor(couleur);
      if (hsl.saturation >= 0.25 && hsl.lightness > 0.1 && hsl.lightness < 0.92) {
        return couleur;
      }
    }
    return null;
  }

  // Palette immédiate (sans analyser d'image), pour afficher la page tout de suite.
  static RadioPalette immediate(CampusRadio radio, {RadioSettings? settings, String? couleurApi}) {
    final couleur = settings?.couleur;
    if (couleur != null) {
      return RadioPalette(couleur, PaletteSource.gerant);
    }
    final api = _couleurApi(radio, couleurApi);
    return api != null ? RadioPalette(api, PaletteSource.api) : RadioPalette.defaut;
  }

  static Future<Color?> couleurDuLogo({Uint8List? logoBytes, String? logoUrl}) {
    if (logoBytes != null) {
      // Clé courte : taille + quelques octets suffisent à distinguer deux images.
      final cle = 'bytes:${logoBytes.length}:${logoBytes.take(16).join(',')}';
      return _cache[cle] ??= _extraire(MemoryImage(logoBytes));
    }
    if (logoUrl != null) {
      return _cache['url:$logoUrl'] ??= _extraire(NetworkImage(logoUrl));
    }
    return Future.value(null);
  }

  static Future<Color?> _extraire(ImageProvider image) async {
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: image,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ).timeout(const Duration(seconds: 6));
      return scheme.primary;
    } catch (_) {
      return null; // image illisible (CORS, 404...) : on passe à la couleur suivante
    }
  }

  // "#ff0000" ou "ff0000" -> Color. null si le texte n'est pas une couleur.
  static Color? parseHex(String? hex) {
    if (hex == null) {
      return null;
    }
    var texte = hex.trim().replaceFirst('#', '');
    if (texte.length == 3) {
      texte = texte.split('').map((c) => '$c$c').join();
    }
    final valeur = int.tryParse(texte, radix: 16);
    if (texte.length != 6 || valeur == null) {
      return null;
    }
    return Color(0xFF000000 | valeur);
  }
}
