import 'package:flutter/material.dart';

import '../../models/campus_radio.dart';
import '../../models/page_module.dart';
import '../cards.dart';
import 'modules.dart';

// Articles récents du réseau qui portent au moins un des tags choisis.
class ModuleArticlesTags extends StatelessWidget {
  const ModuleArticlesTags({required this.contexte, required this.rafraichissement, super.key});

  final ContexteModule contexte;
  final int rafraichissement;

  @override
  Widget build(BuildContext context) {
    final module = contexte.module;
    final tags = listeDe(module, 'tags');
    final nombre = nombreDe(module, 5);
    final titre = module.reglages['titre'];
    return ChargementModule<(List<RadioContent>, List<Tag>)>(
      // Titre affiché une fois les noms des tags connus (voir builder).
      titre: null,
      rafraichissement: rafraichissement,
      hauteurSquelette: 100,
      charger: () async {
        // Les deux requêtes partent en même temps.
        final articles = RadioRepository.getArticlesDetailles();
        final tousLesTags = RadioRepository.getTags();
        return (await articles, await tousLesTags);
      },
      builder: (context, donnees) {
        final (articles, tousLesTags) = donnees;
        final noms = [for (final tag in tousLesTags) if (tags.contains(tag.slug)) tag.nom];
        final texteTitre = titre is String && titre.trim().isNotEmpty ? titre.trim() : noms.join(' · ');
        final trouves = filtrerParTags(articles, tags, nombre);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: texteTitre.isEmpty ? 'Articles' : texteTitre),
            if (trouves.isEmpty)
              const EmptyState(message: 'Aucun article récent pour ces thèmes.')
            else
              ListeCartes(children: [for (final article in trouves) NewsCard(news: article)]),
          ],
        );
      },
    );
  }
}
