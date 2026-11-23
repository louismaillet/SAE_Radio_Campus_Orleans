import 'package:flutter/material.dart';

// Les modules que le gérant peut placer sur la page de sa radio (version appli).
enum ModuleType {
  aLaUne('À la Une', Icons.star_rounded),
  actualites('Actualités', Icons.newspaper_rounded),
  replays('Derniers replays', Icons.replay_rounded),
  articlesTags('Articles par tags', Icons.sell_rounded),
  emissionVedette('Émission à la une', Icons.mic_rounded),
  direct('Direct', Icons.sensors_rounded);

  const ModuleType(this.nom, this.icone);

  final String nom; // libellé affiché
  final IconData icone;
}

// Un module de la page : son type et ses réglages.
// Réglages selon le type :
//   aLaUne          {genre: 'emission' | 'episode' | 'article', slug}
//   actualites      {nombre}
//   replays         {emissions: [slug] (vide = toutes), nombre}
//   articlesTags    {tags: [slug], nombre, titre?}
//   emissionVedette {emission: slug, nombre}
//   direct          {}
class PageModule {
  const PageModule({required this.type, this.reglages = const {}});

  final ModuleType type;
  final Map<String, dynamic> reglages;

  // Un module tout juste ajouté, avec les réglages par défaut de son type.
  static PageModule nouveau(ModuleType type) {
    final reglages = switch (type) {
      ModuleType.aLaUne => <String, dynamic>{},
      ModuleType.actualites => <String, dynamic>{'nombre': 5},
      ModuleType.replays => <String, dynamic>{'emissions': <String>[], 'nombre': 10},
      ModuleType.articlesTags => <String, dynamic>{'tags': <String>[], 'nombre': 5},
      ModuleType.emissionVedette => <String, dynamic>{'nombre': 5},
      ModuleType.direct => <String, dynamic>{},
    };
    return PageModule(type: type, reglages: reglages);
  }

  PageModule copyWith({Map<String, dynamic>? reglages}) =>
      PageModule(type: type, reglages: reglages ?? this.reglages);

  Map<String, dynamic> toJson() => {'type': type.name, 'reglages': reglages};

  // null si le type est inconnu (enregistré par une version plus récente de l'appli).
  static PageModule? fromJson(Map<String, dynamic> json) {
    for (final type in ModuleType.values) {
      if (type.name == json['type']) {
        final reglages = json['reglages'];
        return PageModule(
          type: type,
          reglages: reglages is Map ? Map<String, dynamic>.from(reglages) : {},
        );
      }
    }
    return null;
  }
}

// Page d'une radio jamais configurée : à peu près l'ancienne page fixe.
List<PageModule> modulesParDefaut() => [
  PageModule.nouveau(ModuleType.direct),
  PageModule.nouveau(ModuleType.replays),
  PageModule.nouveau(ModuleType.actualites),
];

// Nombre d'éléments à afficher, toujours entre 1 et 20.
int nombreDe(PageModule module, int defaut) {
  final nombre = module.reglages['nombre'];
  if (nombre is! int) {
    return defaut;
  }
  return nombre.clamp(1, 20);
}

// Liste de textes d'un réglage (ex. 'tags', 'emissions'), vide si absent.
List<String> listeDe(PageModule module, String cle) {
  final valeur = module.reglages[cle];
  if (valeur is! List) {
    return const [];
  }
  return valeur.whereType<String>().toList();
}
