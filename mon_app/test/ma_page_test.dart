import 'package:flutter_test/flutter_test.dart';
import 'package:mon_app/models/campus_radio.dart';
import 'package:mon_app/models/page_module.dart';
import 'package:mon_app/models/radio_settings.dart';
import 'package:mon_app/pages/admin/admin_page.dart';
import 'package:mon_app/pages/admin/ma_page_section.dart';

const _details = RadioDetails(
  description: null,
  showSlugs: ['e1'],
  shows: [RadioShow(slug: 'e1', title: 'Émission 1', imageUrl: null)],
);

void main() {
  final a = PageModule.nouveau(ModuleType.actualites);
  final b = PageModule.nouveau(ModuleType.replays);
  final c = PageModule.nouveau(ModuleType.direct);

  test('peutAjouter refuse un second direct', () {
    expect(peutAjouter(ModuleType.direct, [c]), isFalse);
    expect(peutAjouter(ModuleType.articlesTags, [c]), isTrue);
    expect(peutAjouter(ModuleType.direct, []), isTrue);
  });

  test('deplacer vers le bas', () {
    expect(deplacer([a, b, c], 0, 2), [b, a, c]);
  });

  test('deplacer vers le haut', () {
    final liste = [a, b, c];
    expect(deplacer(liste, 2, 0), [c, a, b]);
    expect(liste, [a, b, c]);
  });

  test('resumeModule signale un module non réglé', () {
    expect(resumeModule(PageModule.nouveau(ModuleType.aLaUne), _details), 'Non réglé');
  });

  test('resumeModule décrit les replays', () {
    expect(resumeModule(b, _details), '10 derniers · toutes les émissions');
    final choisie = PageModule(type: ModuleType.replays, reglages: {'emissions': ['e1'], 'nombre': 3});
    expect(resumeModule(choisie, _details), '3 derniers · Émission 1');
  });

  test('AdminDraft garde les modules', () {
    final reglages = RadioSettings(
      radioId: 'x',
      afficherSite: false,
      siteUrl: null,
      logo: null,
      couleur: null,
      modules: [a],
    );
    final brouillon = AdminDraft.depuis(reglages);
    expect(brouillon.modules!.single.type, ModuleType.actualites);
    expect(brouillon.copyWith(modules: () => null).modules, isNull);
  });
}
