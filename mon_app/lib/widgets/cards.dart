import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/campus_radio.dart';
import '../player/player_controller.dart';
import '../theme/app_theme.dart';
import 'hover.dart';
import 'images.dart';
import 'live.dart';

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
                Text(title, style: textes.headlineSmall),
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

    Widget icone = Icon(
      courant && player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: size * 0.55,
      color: scheme.onPrimary,
    );
    if (courant && player.isLoading) {
      icone = SizedBox.square(
        dimension: size * 0.4,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
      );
    }

    return Material(
      color: scheme.primary,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: scheme.primary.withValues(alpha: 0.5),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => PlayerScope.read(context).play(track),
        child: SizedBox.square(dimension: size, child: Center(child: icone)),
      ),
    );
  }
}

// Carte d'un podcast : pochette, émission, date et lecture rapide.
// Faite pour une grille à hauteur fixe (mainAxisExtent ~ 300).
class PodcastCard extends StatelessWidget {
  const PodcastCard({required this.podcast, this.radioName, this.accent, super.key});

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

    PlayerTrack? track;
    if (audio != null) {
      track = PlayerTrack(
        url: audio,
        title: podcast.title,
        subtitle: podcast.showTitle ?? radioName ?? 'Podcast',
        isLive: false,
        artworkUrl: podcast.imageUrl,
        accent: accent,
      );
    }

    return HoverBuilder(
      onTap: track == null ? null : () => PlayerScope.read(context).play(track!),
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, hovered ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: enLecture ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: hovered ? 0.25 : 0),
              blurRadius: 32,
              offset: const Offset(0, 14),
              spreadRadius: -12,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedScale(
                    scale: hovered ? 1.06 : 1,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    child: CoverImage(url: podcast.imageUrl),
                  ),
                  // Assombrit le bas de l'image pour faire ressortir le bouton.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                  if (enLecture)
                    const Positioned(left: 14, bottom: 14, child: EqualizerBars(color: Colors.white)),
                  if (track != null)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: AnimatedScale(
                        scale: hovered || enLecture ? 1 : 0.85,
                        duration: const Duration(milliseconds: 200),
                        child: PlayFab(track: track),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (podcast.showTitle ?? radioName ?? 'Podcast').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textes.labelSmall!.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 44, // 2 lignes, pour aligner toutes les cartes
                    child: Text(
                      podcast.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textes.titleSmall!.copyWith(fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(podcast.date, style: textes.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Carte d'une radio du réseau, avec écoute rapide du direct au survol.
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

    return HoverBuilder(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, hovered ? -6 : 0, 0),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: hovered ? scheme.surfaceContainerHigh : scheme.surfaceContainer.withValues(alpha: 0.7),
          border: Border.all(
            color: enLecture ? scheme.primary : scheme.outlineVariant.withValues(alpha: hovered ? 0.5 : 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: hovered ? 0.22 : 0),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: -12,
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(tag: 'logo-${radio.id}', child: RadioLogo(url: radio.logoUrl, bytes: logo, size: 64)),
                const Spacer(),
                Text(
                  radio.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textes.titleSmall!.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (enLecture) ...[const EqualizerBars(size: 12), const SizedBox(width: 6)],
                    Expanded(
                      child: Text(
                        enLecture ? 'En écoute' : (radio.city ?? 'Réseau Radio Campus'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textes.bodySmall!.copyWith(
                          color: enLecture ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (flux != null)
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: hovered || enLecture ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: PlayFab(
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
                ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox.square(
              dimension: 88,
              child: CoverImage(url: news.imageUrl, icon: Icons.article_rounded),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(news.date, style: textes.labelSmall!.copyWith(color: scheme.primary)),
                const SizedBox(height: 4),
                Text(
                  news.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textes.titleSmall!.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
          ],
        ],
      ),
    );
  }
}
