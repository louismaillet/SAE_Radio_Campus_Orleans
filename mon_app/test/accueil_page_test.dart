import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:mon_app/models/campus_radio.dart';
import 'package:mon_app/pages/accueil_page.dart';
import 'package:mon_app/player/player_controller.dart';
import 'package:mon_app/services/localisateur.dart';
import 'package:mon_app/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

CampusRadio _radio(String id, String ville) =>
    CampusRadio(id: id, name: 'Radio Campus $ville', logoUrl: null, streamUrl: null, websiteUrl: null, city: ville);

final _radios = [_radio('o', 'Orléans'), _radio('t', 'Tours'), _radio('p', 'Paris')];

class _LocalisateurFactice implements Localisateur {
  _LocalisateurFactice(this.resultat);
  final ResultatPosition resultat;

  @override
  Future<ResultatPosition> position() async => resultat;
}

Future<void> _afficher(WidgetTester tester, {Future<List<CampusRadio>>? radios, Localisateur? localisateur}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ThemeScope(
      controller: ThemeController(),
      child: PlayerScope(
        controller: PlayerController(),
        child: MaterialApp(
          // Comme dans HomePage : la page est dans un Scaffold.
          home: Scaffold(
            body: AccueilPage(
              radios: radios ?? Future.value(_radios),
              onReessayer: () {},
              localisateur: localisateur ?? _LocalisateurFactice(PositionRefusee()),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('recherche "orl" propose Orléans', (tester) async {
    await _afficher(tester);
    await tester.enterText(find.byType(TextField), 'orl');
    await tester.pump();
    expect(find.widgetWithText(ListTile, 'Orléans'), findsOneWidget);
  });

  testWidgets('recherche sans résultat affiche le message', (tester) async {
    await _afficher(tester);
    await tester.enterText(find.byType(TextField), 'blois');
    await tester.pump();
    expect(find.textContaining('Pas de radio à'), findsOneWidget);
  });

  testWidgets('choisir une suggestion affiche la confirmation', (tester) async {
    await _afficher(tester);
    await tester.enterText(find.byType(TextField), 'tou');
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'Tours'));
    await tester.pump();
    expect(find.text('Radio Campus Tours'), findsOneWidget);
    expect(find.text('Radio par défaut'), findsOneWidget);
  });

  testWidgets('position trouvée affiche la ville la plus proche', (tester) async {
    await _afficher(tester, localisateur: _LocalisateurFactice(PositionTrouvee(const LatLng(47.9, 1.9))));
    await tester.tap(find.text('Utiliser ma position'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Radio Campus Orléans'), findsOneWidget);
    expect(find.textContaining('km'), findsOneWidget);
    expect(find.text('Radio par défaut'), findsOneWidget);
  });

  testWidgets('position refusée affiche le message et garde le bouton', (tester) async {
    await _afficher(tester, localisateur: _LocalisateurFactice(PositionRefusee()));
    await tester.tap(find.text('Utiliser ma position'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Position refusée'), findsOneWidget);
    final bouton = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('Utiliser ma position'), matching: find.bySubtype<ButtonStyleButton>()),
    );
    expect(bouton.enabled, isTrue);
  });

  testWidgets('position indisponible affiche le message', (tester) async {
    await _afficher(tester, localisateur: _LocalisateurFactice(PositionIndisponible('délai dépassé')));
    await tester.tap(find.text('Utiliser ma position'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining("Impossible d'obtenir ta position"), findsOneWidget);
  });

  testWidgets('pas de débordement avec le clavier ouvert sur un petit téléphone', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    final villes = ['Agen', 'Amiens', 'Angers', 'Avignon', 'Bordeaux', 'Caen', 'Castres', 'Paris'];
    await _afficher(tester, radios: Future.value([for (final v in villes) _radio(v, v)]));
    tester.view.physicalSize = const Size(1080, 2340); // 360 × 780 dp
    tester.view.viewInsets = const FakeViewPadding(bottom: 900); // clavier de 300 dp
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('raccourci Outre-mer et étranger : La Réunion', (tester) async {
    await _afficher(tester, radios: Future.value([..._radios, _radio('r', 'Saint-Denis - La Réunion')]));
    await tester.tap(find.widgetWithText(ActionChip, 'La Réunion'));
    await tester.pump();
    expect(find.text('Radio Campus Saint-Denis - La Réunion'), findsOneWidget);
    expect(find.text('Radio par défaut'), findsOneWidget);
  });

  testWidgets('radios en erreur affiche Réessayer', (tester) async {
    // L'erreur arrive après l'affichage, comme une vraie requête qui échoue.
    await _afficher(tester, radios: Future.delayed(const Duration(milliseconds: 10), () => throw Exception('hors ligne')));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
