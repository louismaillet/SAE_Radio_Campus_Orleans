import 'package:flutter/material.dart';

import '../../models/campus_radio.dart';
import '../../models/page_module.dart';
import '../cards.dart';
import 'modules.dart';

// Derniers articles du réseau (l'API n'a pas d'articles propres à une radio).
class ModuleActualites extends StatelessWidget {
  const ModuleActualites({required this.contexte, required this.rafraichissement, super.key});

  final ContexteModule contexte;
  final int rafraichissement;

  @override
  Widget build(BuildContext context) {
    final nombre = nombreDe(contexte.module, 5);
    return ChargementModule<List<RadioContent>>(
      titre: 'Actualités du réseau',
      rafraichissement: rafraichissement,
      hauteurSquelette: 100,
      charger: () => RadioRepository.getNews(nombre: nombre),
      builder: (context, articles) {
        if (articles.isEmpty) {
          return const EmptyState(message: 'Aucune actualité pour le moment.');
        }
        return ListeCartes(children: [for (final article in articles) NewsCard(news: article)]);
      },
    );
  }
}
