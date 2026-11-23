import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mon_app/models/page_module.dart';
import 'package:mon_app/models/radio_settings.dart';

RadioSettings _reglages(List<PageModule>? modules) => RadioSettings(
  radioId: 'x',
  afficherSite: false,
  siteUrl: null,
  logo: null,
  couleur: null,
  modules: modules,
);

void main() {
  test('aller-retour JSON d\'un module', () {
    final module = PageModule.fromJson(PageModule.nouveau(ModuleType.replays).toJson())!;
    expect(module.type, ModuleType.replays);
    expect(module.reglages, {'emissions': [], 'nombre': 10});
  });

  test('type inconnu ignoré', () {
    expect(PageModule.fromJson({'type': 'meteo', 'reglages': {}}), isNull);
  });

  test('modules par défaut', () {
    expect(modulesParDefaut().map((m) => m.type), [ModuleType.direct, ModuleType.replays, ModuleType.actualites]);
  });

  test('nombreDe borne', () {
    PageModule avec(Object? n) => PageModule(type: ModuleType.actualites, reglages: {'nombre': ?n});
    expect(nombreDe(avec(50), 5), 20);
    expect(nombreDe(avec(0), 5), 1);
    expect(nombreDe(avec(null), 5), 5);
  });

  test('ancien JSON sans modules', () {
    final reglages = RadioSettings.fromJson({
      'radioId': 'x',
      'afficherSite': false,
      'siteUrl': null,
      'logo': null,
      'couleur': null,
    });
    expect(reglages.modules, isNull);
    expect(reglages.modulesEffectifs.length, 3);
  });

  test('RadioSettings garde l\'ordre des modules', () {
    final avant = _reglages([PageModule.nouveau(ModuleType.actualites), PageModule.nouveau(ModuleType.direct)]);
    final json = jsonDecode(jsonEncode(avant.toJson())) as Map<String, dynamic>;
    expect(RadioSettings.fromJson(json).modules!.map((m) => m.type), [ModuleType.actualites, ModuleType.direct]);

    (json['modules'] as List).insert(1, {'type': 'meteo', 'reglages': {}});
    expect(RadioSettings.fromJson(json).modules!.map((m) => m.type), [ModuleType.actualites, ModuleType.direct]);
  });
}
