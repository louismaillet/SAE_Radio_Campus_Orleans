import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_app/models/campus_radio.dart';
import 'package:mon_app/models/radio_settings.dart';
import 'package:mon_app/services/api.dart';

void main() {
  test("couleur -> texte #RRGGBB de l'API, et retour", () {
    expect(couleurVersHex(const Color(0xFFE30613)), '#E30613');
    expect(couleurVersHex(const Color(0xFF000A0B)), '#000A0B'); // zéros gardés
    expect(couleurDepuisHex('#e30613'), const Color(0xFFE30613));
    expect(couleurDepuisHex(null), isNull);
    expect(couleurDepuisHex('rouge'), isNull);
  });

  test("les images de l'API sont complétées avec l'adresse du serveur", () {
    expect(Api.media('/media/logos/a.webp'), '${Api.baseUrl}/media/logos/a.webp');
    expect(Api.media('https://ailleurs.fr/a.png'), 'https://ailleurs.fr/a.png');
  });

  test("une radio de l'API (GET /radios) devient une CampusRadio", () {
    final radio = CampusRadio.fromApiJson({
      'slug': 'radio-campus-orleans',
      'name': 'Radio Campus Orléans',
      'city': 'Orléans',
      'excerpt': 'La radio des étudiants',
      'slogan': 'RADIO CAMPUS ORLÉANS - 88.3 FM',
      'category_color': '#2154ff',
      'image_url': 'https://api.radio-campus.org/orleans.png',
      'live_url': 'https://api.radiocampus.org/audio/live/radio-campus-orleans',
      'website_url': 'https://orleans.radiocampus.org/',
      'site': true,
    });
    expect(radio.id, 'radio-campus-orleans');
    expect(radio.name, 'Radio Campus Orléans');
    expect(radio.city, 'Orléans');
    expect(radio.logoUrl, 'https://api.radio-campus.org/orleans.png');
    expect(radio.streamUrl, endsWith('/radio-campus-orleans'));
    expect(radio.websiteUrl, 'https://orleans.radiocampus.org/');
    expect(radio.categoryColor, '#2154ff');

    // Radio ajoutée à la main en base, sans nom : on affiche son slug
    final minimale = CampusRadio.fromApiJson({'slug': 'ma-radio', 'name': ''});
    expect(minimale.name, 'ma-radio');
    expect(minimale.streamUrl, isNull);
  });
}
