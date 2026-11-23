import 'package:flutter/material.dart';

import '../player/player_controller.dart';
import '../theme/app_theme.dart';
import 'glass.dart';
import 'images.dart';
import 'live.dart';

// Mini-lecteur en bas de l'écran, au-dessus de toutes les pages
// (il est placé dans MaterialApp.builder, voir app.dart).
// - un appui ouvre le lecteur plein écran,
// - un glissement sur le côté ferme le lecteur.
// Comme il est en dehors du Navigator, il passe par navigatorKey pour ouvrir
// le plein écran, et n'utilise pas de Tooltip.
class BottomPlayer extends StatelessWidget {
  const BottomPlayer({required this.navigatorKey, super.key});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final track = player.track;

    // Apparition / disparition en glissant depuis le bas.
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: track == null
          ? const SizedBox(width: double.infinity)
          : _MiniLecteur(player: player, track: track, onOpen: _ouvrirPleinEcran),
    );
  }

  void _ouvrirPleinEcran() {
    final contexte = navigatorKey.currentContext;
    if (contexte == null) {
      return;
    }
    showModalBottomSheet<void>(
      context: contexte,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FullPlayer(),
    );
  }
}

// Thème du lecteur : les couleurs de la radio en cours d'écoute.
ThemeData _themeLecteur(BuildContext context, PlayerTrack track) {
  final accent = track.accent;
  return accent == null ? Theme.of(context) : AppTheme.fromSeed(accent, Theme.of(context).brightness);
}

class _MiniLecteur extends StatelessWidget {
  const _MiniLecteur({required this.player, required this.track, required this.onOpen});

  final PlayerController player;
  final PlayerTrack track;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = _themeLecteur(context, track);
    return AnimatedTheme(
      data: theme,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + MediaQuery.paddingOf(context).bottom),
          child: Dismissible(
            key: ValueKey(track.url),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => player.close(),
            child: GestureDetector(
              onTap: onOpen,
              // Glisser vers le haut ouvre aussi le plein écran.
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -200) {
                  onOpen();
                }
              },
              child: Glass(
                radius: AppRadius.md,
                opacity: 0.9,
                tint: theme.colorScheme.surfaceContainerHigh,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                      child: Row(
                        children: [
                          _Pochette(track: track, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Titres(track: track, error: player.error),
                          ),
                          _BoutonLecture(player: player, size: 44),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    // Fine barre de progression pour les podcasts.
                    if (!track.isLive) _ProgressionFine(player: player),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Lecteur plein écran (feuille qui monte du bas).
class FullPlayer extends StatelessWidget {
  const FullPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final track = player.track;
    if (track == null) {
      return const SizedBox.shrink();
    }
    final theme = _themeLecteur(context, track);
    final scheme = theme.colorScheme;
    final textes = theme.textTheme;
    // Pochette la plus grande possible, sans faire déborder les petits écrans.
    final ecran = MediaQuery.sizeOf(context);
    final pochette = [ecran.width - 96, ecran.height * 0.32, 360.0].reduce((a, b) => a < b ? a : b).clamp(120.0, 360.0);

    return AnimatedTheme(
      data: theme,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(scheme.surface, scheme.primary, 0.35)!, scheme.surface],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée : on peut faire glisser la feuille vers le bas pour la fermer.
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(color: scheme.primary.withValues(alpha: 0.45), blurRadius: 60, spreadRadius: -6),
                  ],
                ),
                child: _Pochette(track: track, size: pochette),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textes.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                player.error ?? track.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textes.bodyLarge!.copyWith(color: player.error != null ? scheme.error : scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (track.isLive) const LiveBadge() else _Timeline(player: player),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!track.isLive)
                    _IconeAction(
                      icon: Icons.replay_10_rounded,
                      label: 'Reculer de 10 secondes',
                      onTap: () => player.skip(const Duration(seconds: -10)),
                    ),
                  const SizedBox(width: AppSpacing.lg),
                  _BoutonLecture(player: player, size: 76),
                  const SizedBox(width: AppSpacing.lg),
                  if (!track.isLive)
                    _IconeAction(
                      icon: Icons.forward_30_rounded,
                      label: 'Avancer de 30 secondes',
                      onTap: () => player.skip(const Duration(seconds: 30)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  player.close();
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('Fermer le lecteur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pochette extends StatelessWidget {
  const _Pochette({required this.track, required this.size});

  final PlayerTrack track;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (track.isLive) {
      return RadioLogo(url: track.artworkUrl, bytes: track.artworkBytes, size: size, radius: size * 0.2);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: SizedBox.square(
        dimension: size,
        child: CoverImage(url: track.artworkUrl),
      ),
    );
  }
}

class _Titres extends StatelessWidget {
  const _Titres({required this.track, this.error});

  final PlayerTrack track;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textes.titleSmall!.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (track.isLive && error == null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                error ?? track.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textes.bodySmall!.copyWith(color: error != null ? scheme.error : scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BoutonLecture extends StatelessWidget {
  const _BoutonLecture({required this.player, required this.size});

  final PlayerController player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enLecture = player.isPlaying;
    Widget icone = Icon(
      enLecture ? (player.track!.isLive ? Icons.stop_rounded : Icons.pause_rounded) : Icons.play_arrow_rounded,
      key: ValueKey(enLecture),
      color: scheme.onPrimary,
      size: size * 0.6,
    );
    if (player.isLoading) {
      icone = SizedBox.square(
        dimension: size * 0.45,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
      );
    }
    return Semantics(
      button: true,
      label: enLecture ? 'Pause' : 'Lecture',
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: player.toggle,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: icone),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconeAction extends StatelessWidget {
  const _IconeAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(iconSize: 32, onPressed: onTap, icon: Icon(icon)),
    );
  }
}

// Fine barre sous le mini-lecteur. N'écoute que la position,
// donc elle est la seule à se reconstruire pendant la lecture.
class _ProgressionFine extends StatelessWidget {
  const _ProgressionFine({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: player.position,
      builder: (context, position, _) {
        final duree = player.duration?.inMilliseconds ?? 0;
        return LinearProgressIndicator(
          value: duree == 0 ? 0 : (position.inMilliseconds / duree).clamp(0.0, 1.0),
          minHeight: 2,
          backgroundColor: Colors.transparent,
        );
      },
    );
  }
}

// Barre de progression du plein écran, qu'on peut faire glisser.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ValueListenableBuilder<Duration>(
      valueListenable: player.position,
      builder: (context, position, _) {
        final duree = player.duration ?? Duration.zero;
        final max = duree.inMilliseconds.toDouble();
        final valeur = position.inMilliseconds.clamp(0, duree.inMilliseconds).toDouble();
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(
                context,
              ).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
              child: Slider(
                value: max == 0 ? 0 : valeur,
                max: max == 0 ? 1 : max,
                onChanged: max == 0 ? null : (v) => player.seek(Duration(milliseconds: v.round())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_format(position), style: style),
                  Text(_format(duree), style: style),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secondes = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$minutes:$secondes' : '$minutes:$secondes';
  }
}
