import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api.dart';
import 'campus_radio.dart';

// Réglages choisis par le gérant d'une radio dans la page admin.
class RadioSettings {
  const RadioSettings({
    required this.radioId,
    required this.afficherSite,
    required this.siteUrl,
    required this.logo,
    required this.couleur,
    this.streamUrl,
  });

  final String radioId; // le slug de la radio
  final bool afficherSite; // true = site web, false = version appli
  final String? siteUrl;
  final Uint8List? logo; // l'image choisie par le gérant (null = logo de l'API)
  final Color? couleur; // couleur secondaire (null = couleur par défaut)
  final String? streamUrl; // flux du direct choisi par le gérant (null = celui de l'API)

  // Réglages d'une radio que le gérant n'a jamais modifiée :
  // site web si la radio est dans la table des sites officiels, sinon version appli.
  factory RadioSettings.parDefaut(CampusRadio radio) {
    return RadioSettings(
      radioId: radio.id,
      afficherSite: radio.websiteUrl != null,
      siteUrl: radio.websiteUrl,
      logo: null,
      couleur: null,
    );
  }

  Map<String, dynamic> toJson() {
    String? logoTexte;
    if (logo != null) {
      logoTexte = base64Encode(logo!); // l'image est enregistrée sous forme de texte
    }
    int? couleurNombre;
    if (couleur != null) {
      couleurNombre = couleur!.toARGB32();
    }
    return {
      'radioId': radioId,
      'afficherSite': afficherSite,
      'siteUrl': siteUrl,
      'logo': logoTexte,
      'couleur': couleurNombre,
      'streamUrl': streamUrl,
    };
  }

  factory RadioSettings.fromJson(Map<String, dynamic> json) {
    Uint8List? logo;
    final logoTexte = json['logo'] as String?;
    if (logoTexte != null) {
      logo = base64Decode(logoTexte);
    }
    Color? couleur;
    final couleurNombre = json['couleur'] as int?;
    if (couleurNombre != null) {
      couleur = Color(couleurNombre);
    }
    return RadioSettings(
      radioId: json['radioId'] as String,
      afficherSite: json['afficherSite'] as bool,
      siteUrl: json['siteUrl'] as String?,
      logo: logo,
      couleur: couleur,
      streamUrl: json['streamUrl'] as String?,
    );
  }

  // Flux du direct à lire : celui du gérant, sinon celui de l'API.
  String? fluxDirect(CampusRadio radio) => streamUrl ?? radio.streamUrl;
}

// Couleur <-> texte "#RRGGBB" (format de l'API).
String couleurVersHex(Color couleur) =>
    '#${(couleur.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color? couleurDepuisHex(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
    return null;
  }
  return Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
}

// Lecture et enregistrement des réglages, dans notre API (table "radios").
// Une radio absente de la base, ou un serveur injoignable, donne les réglages par défaut :
// l'app reste utilisable sans le serveur.
class RadioSettingsRepository {
  static Future<RadioSettings> load(CampusRadio radio) async {
    final Map<String, dynamic> data;
    try {
      data = await Api.get('/radios/${radio.id}') as Map<String, dynamic>;
    } on ApiException {
      return RadioSettings.parDefaut(radio);
    }
    return RadioSettings(
      radioId: radio.id,
      afficherSite: data['site'] as bool,
      siteUrl: (data['url'] as String?) ?? radio.websiteUrl,
      logo: await _logo(data['logo_url'] as String?),
      couleur: couleurDepuisHex(data['color'] as String?),
      streamUrl: data['stream_url'] as String?,
    );
  }

  // Enregistre les réglages (réservé au gérant de la radio, d'où le jeton).
  // Le logo n'est renvoyé que s'il a changé depuis [ancien].
  // Lève une ApiException en cas de refus du serveur.
  static Future<void> save(
    RadioSettings reglages, {
    required RadioSettings ancien,
    required String jeton,
  }) async {
    final chemin = '/radios/${reglages.radioId}';
    final couleur = reglages.couleur;
    await Api.patch(chemin, {
      'site': reglages.afficherSite,
      'url': reglages.siteUrl,
      'color': couleur == null ? null : couleurVersHex(couleur),
      'stream_url': reglages.streamUrl,
    }, jeton: jeton);

    final logo = reglages.logo;
    if (identical(logo, ancien.logo)) {
      return;
    }
    if (logo == null) {
      await Api.delete('$chemin/logo', jeton: jeton);
    } else {
      // Le serveur vérifie l'image lui-même et la convertit en WebP.
      await Api.putFichier('$chemin/logo', champ: 'image', octets: logo, nomFichier: 'logo', jeton: jeton);
    }
  }

  // Logos choisis par les gérants (slug -> image), pour la liste des radios.
  static Future<Map<String, Uint8List>> loadLogos() async {
    final List<dynamic> radios;
    try {
      radios = await Api.get('/radios') as List<dynamic>;
    } on ApiException {
      return {};
    }
    final logos = <String, Uint8List>{};
    await Future.wait([
      for (final radio in radios.cast<Map<String, dynamic>>())
        if (radio['logo_url'] != null)
          _logo(radio['logo_url'] as String).then((octets) {
            if (octets != null) {
              logos[radio['slug'] as String] = octets;
            }
          }),
    ]);
    return logos;
  }

  // Télécharge le logo, ou null s'il n'y en a pas ou s'il est inaccessible.
  static Future<Uint8List?> _logo(String? chemin) async {
    if (chemin == null) {
      return null;
    }
    try {
      return await Api.telecharger(chemin);
    } catch (_) {
      return null;
    }
  }
}
