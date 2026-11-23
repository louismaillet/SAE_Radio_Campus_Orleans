import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;

import '../../models/campus_radio.dart';
import '../../player/player_controller.dart';
import '../../theme/app_theme.dart';
import '../cards.dart';
import '../images.dart';
import 'modules.dart';

// Un élément choisi par le gérant (émission, épisode ou article), en grande carte.
// Masqué si l'élément n'existe plus dans l'API.
class ModuleALaUne extends StatelessWidget {
  const ModuleALaUne({required this.contexte, required this.rafraichissement, super.key});

  final ContexteModule contexte;
  final int rafraichissement;

  @override
  Widget build(BuildContext context) {
    final genre = contexte.module.reglages['genre'] as String;
    final slug = contexte.module.reglages['slug'] as String;
    final showSlugs = contexte.details.showSlugs;

    return ChargementModule<Widget?>(
      titre: null,
      rafraichissement: rafraichissement,
      hauteurSquelette: 260,
      charger: () async {
        switch (genre) {
          case 'emission':
            final show = await RadioRepository.getShow(slug);
            final podcasts = await RadioRepository.getPodcastsRadio(showSlugs);
            final dernier = podcasts.where((p) => p.showSlug == slug).firstOrNull;
            return GrandeCarte(
              etiquette: 'À la Une · Émission',
              titre: show.titre,
              imageUrl: show.imageUrl,
              texte: texteSansHtml(show.description),
              track: dernier == null ? null : _track(dernier),
            );
          case 'episode':
            final podcasts = await RadioRepository.getPodcastsRadio(showSlugs);
            final episode = podcasts.where((p) => p.slug == slug).firstOrNull;
            if (episode == null) {
              return null;
            }
            return GrandeCarte(
              etiquette: 'À la Une · ${episode.showTitle ?? 'Épisode'}',
              titre: episode.title,
              imageUrl: episode.imageUrl,
              texte: episode.description,
              date: episode.date,
              track: _track(episode),
            );
          default:
            final articles = await RadioRepository.getArticlesDetailles();
            final article = articles.where((a) => a.slug == slug).firstOrNull;
            if (article == null) {
              return null;
            }
            return GrandeCarte(
              etiquette: 'À la Une · Article',
              titre: article.title,
              imageUrl: article.imageUrl,
              texte: article.description,
              date: article.date,
            );
        }
      },
      builder: (context, carte) => carte,
    );
  }

  PlayerTrack? _track(RadioContent podcast) {
    final audio = podcast.audioUrl;
    if (audio == null) {
      return null;
    }
    return PlayerTrack(
      url: audio,
      title: podcast.title,
      subtitle: podcast.showTitle ?? contexte.radio.name,
      isLive: false,
      artworkUrl: podcast.imageUrl,
      accent: contexte.palette.seed,
    );
  }
}

// Texte brut d'un contenu HTML de l'API (null s'il est vide).
String? texteSansHtml(String? contenu) {
  if (contenu == null) {
    return null;
  }
  final texte = html.parse(contenu).body?.text.trim() ?? '';
  return texte.isEmpty ? null : texte;
}

// Grande carte : image large, étiquette, titre, texte court et bouton lecture.
class GrandeCarte extends StatelessWidget {
  const GrandeCarte({
    required this.etiquette,
    required this.titre,
    this.imageUrl,
    this.texte,
    this.date,
    this.track,
    super.key,
  });

  final String etiquette;
  final String titre;
  final String? imageUrl;
  final String? texte;
  final String? date;
  final PlayerTrack? track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textes = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ClipRRect + hauteur fixe, comme les autres cartes : sur le web, l'image
          // (balise <img>) déborde sur le texte avec un simple ClipRect.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            child: SizedBox(
              height: 200,
              child: CoverImage(url: imageUrl, icon: Icons.star_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etiquette.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textes.labelSmall!.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(titre, style: textes.titleLarge!.copyWith(height: 1.2)),
                      if (date != null) ...[
                        const SizedBox(height: 2),
                        Text(date!, style: textes.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                      if (texte != null && texte!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          texte!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textes.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (track != null) ...[const SizedBox(width: AppSpacing.sm), PlayFab(track: track!)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
