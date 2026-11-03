import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mon_app/app.dart';
import 'package:mon_app/models/campus_radio.dart';
import 'package:mon_app/models/radio_settings.dart';
import 'package:mon_app/theme/radio_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _radio = CampusRadio(
  id: 'radio-test',
  name: 'Radio Test',
  logoUrl: null,
  streamUrl: 'https://exemple.fr/live',
  websiteUrl: null,
  categoryColor: '#2154ff',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Pas de téléchargement de polices pendant les tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('RadioPaletteResolver', () {
    test('lit les couleurs hexadécimales', () {
      expect(RadioPaletteResolver.parseHex('#ff0000'), const Color(0xFFFF0000));
      expect(RadioPaletteResolver.parseHex('0f0'), const Color(0xFF00FF00));
      expect(RadioPaletteResolver.parseHex('pas une couleur'), isNull);
      expect(RadioPaletteResolver.parseHex(null), isNull);
    });

    test('la couleur du gérant passe avant tout le reste', () async {
      const reglages = RadioSettings(
        radioId: 'radio-test',
        afficherSite: false,
        siteUrl: null,
        logo: null,
        couleur: Color(0xFF00AA55),
      );
      final palette = await RadioPaletteResolver.resolve(_radio, settings: reglages, couleurApi: '#ff0000');
      expect(palette.seed, const Color(0xFF00AA55));
      expect(palette.source, PaletteSource.gerant);
    });

    test("sans logo, on prend la couleur de l'API puis celle de la catégorie", () async {
      final avecApi = await RadioPaletteResolver.resolve(_radio, couleurApi: '#ff0000');
      expect(avecApi.seed, const Color(0xFFFF0000));
      expect(avecApi.source, PaletteSource.api);

      final sansApi = await RadioPaletteResolver.resolve(_radio);
      expect(sansApi.seed, const Color(0xFF2154FF));
    });
  });

  test('le flux du gérant remplace celui de l\'API', () {
    const reglages = RadioSettings(
      radioId: 'radio-test',
      afficherSite: false,
      siteUrl: null,
      logo: null,
      couleur: null,
      streamUrl: 'https://autre.fr/live',
    );
    expect(reglages.fluxDirect(_radio), 'https://autre.fr/live');
    expect(RadioSettings.parDefaut(_radio).fluxDirect(_radio), 'https://exemple.fr/live');
  });

  testWidgets("l'accueil s'affiche, avec l'accès à l'espace gérant", (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RadioCampusApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Espace gérant'), findsOneWidget);
    expect(find.text('Les radios du réseau'), findsOneWidget);
  });
}
