import 'package:flutter/material.dart';

import '../../models/campus_radio.dart';
import '../../models/page_module.dart';
import '../../theme/app_theme.dart';
import '../cards.dart';
import 'module_a_la_une.dart';
import 'modules.dart';

// Une émission mise en avant, puis ses derniers épisodes.
class ModuleEmissionVedette extends StatelessWidget {
  const ModuleEmissionVedette({required this.contexte, required this.rafraichissement, super.key});

  final ContexteModule contexte;
  final int rafraichissement;

  @override
  Widget build(BuildContext context) {
    final slug = contexte.module.reglages['emission'] as String;
    final nombre = nombreDe(contexte.module, 5);
    return ChargementModule<(ShowDetails, List<RadioContent>)>(
      titre: 'Émission à la une',
      rafraichissement: rafraichissement,
      hauteurSquelette: 220,
      charger: () async {
        final show = RadioRepository.getShow(slug);
        final podcasts = RadioRepository.getPodcastsRadio(contexte.details.showSlugs);
        return (await show, await podcasts);
      },
      builder: (context, donnees) {
        final (show, podcasts) = donnees;
        final episodes = filtrerReplays(
          podcasts,
          emissionsRadio: contexte.details.showSlugs,
          selection: [slug],
          nombre: nombre,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GrandeCarte(
              etiquette: 'Émission',
              titre: show.titre,
              imageUrl: show.imageUrl,
              texte: texteSansHtml(show.description),
            ),
            const SizedBox(height: AppSpacing.md),
            if (episodes.isEmpty)
              const EmptyState(message: 'Pas encore d\'épisode en ligne.')
            else
              ListeCartes(
                children: [
                  for (final episode in episodes)
                    PodcastTile(podcast: episode, radioName: contexte.radio.name, accent: contexte.palette.seed),
                ],
              ),
          ],
        );
      },
    );
  }
}
