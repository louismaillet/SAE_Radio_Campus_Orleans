import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/campus_radio.dart';
import '../player/player_controller.dart';
import '../theme/app_theme.dart';
import 'images.dart';
import 'live.dart';
import 'pressable.dart';

// Titre de section, avec un texte d'accompagnement et une action à droite.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.subtitle, this.trailing, super.key});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textes.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: textes.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// Bouton lecture rond, qui devient pause / chargement quand c'est ce morceau qui joue.
class PlayFab extends StatelessWidget {
  const PlayFab({required this.track, this.size = 48, super.key});

  final PlayerTrack track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final courant = player.isCurrent(track.url);
    final enLecture = courant && player.isPlaying;

    Widget icone = Icon(
      enLecture ? (track.isLive ? Icons.stop_rounded : Icons.pause_rounded) : Icons.play_arrow_rounded,
      size: size * 0.55,
      color: scheme.onPrimary,
    );
    if (courant && player.isLoading) {
      icone = SizedBox.square(
        dimension: size * 0.4,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
      );
    }

    return Semantics(
      button: true,
      label: enLecture ? 'Pause' : 'Écouter',
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: scheme.primary.withValues(alpha: 0.5),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => PlayerScope.read(context).play(track),
          child: SizedBox.square(
            dimension: size,
            child: Center(child: icone),
          ),
        ),
      ),
    );
  }
}

// Ligne d'un podcast : vignette, émission, titre, date et bouton lecture.
// Toute la ligne est appuyable pour lancer l'écoute.
class PodcastTile extends StatelessWidget {
  const PodcastTile({required this.podcast, this.radioName, this.accent, super.key});

  final RadioContent podcast;
  final String? radioName;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final audio = podcast.audioUrl;
    final player = PlayerScope.of(context);
    final enLecture = audio != null && player.isCurrent(audio) && player.isPlaying;
    final emission = podcast.showTitle ?? radioName ?? 'Podcast';

    PlayerTrack? track;
    if (audio != null) {
      track = PlayerTrack(
        url: audio,
        title: podcast.title,
        subtitle: emission,
        isLive: false,
        artworkUrl: podcast.imageUrl,
        accent: accent,
      );
    }

    return Pressable(
      onTap: track == null ? null : () => PlayerScope.read(context).play(track!),
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: pressed ? scheme.surfaceContainerHigh : scheme.surfaceContainer.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: enLecture ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox.square(
                dimension: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(url: podcast.imageUrl),
                    if (enLecture)
                      const ColoredBox(
                        color: Colors.black45,
                        child: Center(child: EqualizerBars(color: Colors.white, size: 20)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emission.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textes.labelSmall!.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    podcast.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textes.titleSmall!.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(podcast.date, style: textes.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (track != null) ...[const SizedBox(width: 8), PlayFab(track: track, size: 44)],
          ],
        ),
      ),
    );
  }
}

// Carte d'une radio du réseau, avec un bouton pour écouter le direct sans l'ouvrir.
// Faite pour une grille à hauteur fixe (mainAxisExtent ~ 168).
class RadioCard extends StatelessWidget {
  const RadioCard({required this.radio, required this.onTap, this.logo, super.key});

  final CampusRadio radio;
  final Uint8List? logo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final flux = radio.streamUrl;
    final player = PlayerScope.of(context);
    final enLecture = flux != null && player.isCurrent(flux) && player.isPlaying;

    return Pressable(
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: pressed ? scheme.surfaceContainerHigh : scheme.surfaceContainer.withValues(alpha: 0.8),
          border: Border.all(color: enLecture ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'logo-${radio.id}',
                  child: RadioLogo(url: radio.logoUrl, bytes: logo, size: 56),
                ),
                const Spacer(),
                if (flux != null)
                  PlayFab(
                    size: 40,
                    track: PlayerTrack(
                      url: flux,
                      title: radio.name,
                      subtitle: 'En direct',
                      isLive: true,
                      artworkUrl: radio.logoUrl,
                      artworkBytes: logo,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              radio.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textes.titleSmall!.copyWith(fontWeight: FontWeight.w600, height: 1.25),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (enLecture) ...[const EqualizerBars(size: 12), const SizedBox(width: 6)],
                Expanded(
                  child: Text(
                    enLecture ? 'En écoute' : (radio.city ?? 'Réseau Radio Campus'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textes.bodySmall!.copyWith(color: enLecture ? scheme.primary : scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Actualité du réseau : vignette + titre + extrait.
class NewsCard extends StatelessWidget {
  const NewsCard({required this.news, super.key});

  final RadioContent news;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox.square(
              dimension: 80,
              child: CoverImage(url: news.imageUrl, icon: Icons.article_rounded),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(news.date, style: textes.labelSmall!.copyWith(color: scheme.primary)),
                const SizedBox(height: 2),
                Text(
                  news.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textes.titleSmall!.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  news.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textes.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Message dans une section vide ou en erreur, avec bouton "Réessayer".
class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, this.icon = Icons.inbox_rounded, this.onRetry, super.key});

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    );
  }
}
