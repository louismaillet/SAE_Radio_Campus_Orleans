import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'campus_radio.dart';

// Réglages choisis par le gérant d'une radio dans la page admin.
class RadioSettings {
  const RadioSettings({
    required this.radioId,
    required this.afficherSite,
    required this.siteUrl,
    required this.logo,
    required this.couleur,
  });

  final String radioId; // le slug de la radio
  final bool afficherSite; // true = site web, false = version appli
  final String? siteUrl;
  final Uint8List? logo; // l'image choisie par le gérant (null = logo de l'API)
  final Color? couleur; // couleur secondaire (null = couleur par défaut)

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
    );
  }
}

// Lecture et enregistrement des réglages.
// Pour l'instant ils sont gardés sur l'appareil (shared_preferences) :
// quand la base de données sera prête, il suffira de changer cette classe.
class RadioSettingsRepository {
  // Chaque radio a sa clé : "reglages_<slug>".
  static String _cle(String radioId) => 'reglages_$radioId';

  static Future<RadioSettings> load(CampusRadio radio) async {
    final prefs = await SharedPreferences.getInstance();
    final texte = prefs.getString(_cle(radio.id));
    if (texte == null) {
      return RadioSettings.parDefaut(radio);
    }
    return RadioSettings.fromJson(jsonDecode(texte) as Map<String, dynamic>);
  }

  static Future<void> save(RadioSettings reglages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle(reglages.radioId), jsonEncode(reglages.toJson()));
  }

  // Logos choisis par les gérants (slug -> image), pour la liste des radios.
  static Future<Map<String, Uint8List>> loadLogos() async {
    final prefs = await SharedPreferences.getInstance();
    final logos = <String, Uint8List>{};
    for (final cle in prefs.getKeys()) {
      if (cle.startsWith('reglages_')) {
        final json = jsonDecode(prefs.getString(cle)!) as Map<String, dynamic>;
        final reglages = RadioSettings.fromJson(json);
        if (reglages.logo != null) {
          logos[reglages.radioId] = reglages.logo!;
        }
      }
    }
    return logos;
  }
}
