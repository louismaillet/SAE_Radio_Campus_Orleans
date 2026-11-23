import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_app/models/campus_radio.dart';
import 'package:mon_app/models/page_module.dart';
import 'package:mon_app/models/radio_settings.dart';
import 'package:mon_app/player/player_controller.dart';
import 'package:mon_app/theme/radio_palette.dart';
import 'package:mon_app/widgets/live.dart';
import 'package:mon_app/widgets/modules/modules.dart';

const _details = RadioDetails(description: null, showSlugs: ['e1', 'e2']);

PageModule _m(ModuleType type, [Map<String, dynamic> reglages = const {}]) =>
    PageModule(type: type, reglages: reglages);

void main() {
  test('modulesAffichables garde l\'ordre', () {
    final modules = [
      PageModule.nouveau(ModuleType.actualites),
      PageModule.nouveau(ModuleType.direct),
      PageModule.nouveau(ModuleType.replays),
    ];
    expect(modulesAffichables(modules, _details).map((m) => m.type), [
      ModuleType.actualites,
      ModuleType.direct,
      ModuleType.replays,
    ]);
  });

  test('modulesAffichables retire les modules mal réglés', () {
    final modules = [
      _m(ModuleType.aLaUne),
      _m(ModuleType.articlesTags, {'tags': <String>[]}),
      _m(ModuleType.emissionVedette),
    ];
    expect(modulesAffichables(modules, _details), isEmpty);
  });

  test('modulesAffichables retire une émission inconnue', () {
    final modules = [
      _m(ModuleType.emissionVedette, {'emission': 'zzz'}),
      _m(ModuleType.aLaUne, {'genre': 'emission', 'slug': 'zzz'}),
      _m(ModuleType.emissionVedette, {'emission': 'e1'}),
    ];
    final gardes = modulesAffichables(modules, _details);
    expect(gardes.single.reglages['emission'], 'e1');
  });

  test('replays avec sélection hors radio retiré', () {
    expect(modulesAffichables([_m(ModuleType.replays, {'emissions': ['zzz']})], _details), isEmpty);
    expect(modulesAffichables([_m(ModuleType.replays, {'emissions': ['zzz', 'e1']})], _details).length, 1);
  });

  testWidgets('le module Direct affiche le bouton d\'écoute', (tester) async {
    const radio = CampusRadio(
      id: 'r',
      name: 'Radio test',
      logoUrl: null,
      streamUrl: 'https://exemple/live',
      websiteUrl: null,
    );
    await tester.pumpWidget(
      PlayerScope(
        controller: PlayerController(),
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ModuleSliver(
                  module: PageModule.nouveau(ModuleType.direct),
                  radio: radio,
                  details: _details,
                  reglages: RadioSettings.parDefaut(radio),
                  palette: RadioPaletteResolver.immediate(radio),
                  rafraichissement: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(LiveButton), findsOneWidget);
  });
}
