import 'package:flutter/material.dart';

import '../layout/responsive.dart';
import '../player/player_controller.dart';
import '../theme/app_theme.dart';
import 'glass.dart';
import 'images.dart';
import 'live.dart';

// Lecteur persistant en bas de l'écran, au-dessus de toutes les pages
// (il est placé dans MaterialApp.builder, voir app.dart).
// Comme il est en dehors du Navigator, il n'utilise pas de Tooltip.
class BottomPlayer extends StatelessWidget {
  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final track = player.track;

    // Apparition / disparition en glissant depuis le bas.
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: track == null ? const SizedBox(width: double.infinity) : _Barre(player: player, track: track),
    );
  }
}

class _Barre extends StatelessWidget {
  const _Barre({required this.player, required this.track});

  final PlayerController player;
  final PlayerTrack track;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = track.accent;
    final theme = accent == null ? Theme.of(context) : AppTheme.fromSeed(accent, brightness);
    final compact = Responsive.isCompact(context);

    return AnimatedTheme(
      data: theme,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 16,
            0,
            compact ? 8 : 16,
            (compact ? 8 : 16) + MediaQuery.paddingOf(context).bottom,
          ),
          child: Glass(
            radius: AppRadius.lg,
            opacity: 0.85,
            tint: theme.colorScheme.surfaceContainerHigh,
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18, vertical: 10),
            child: compact ? _compact(context) : _large(context),
          ),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _Pochette(track: track, size: 44),
            const SizedBox(width: 12),
            Expanded(child: _Titres(track: track, error: player.error)),
            _BoutonLecture(player: player, size: 44),
            _IconeAction(icon: Icons.close_rounded, label: 'Fermer le lecteur', onTap: player.close),
          ],
        ),
        if (!track.isLive) _Timeline(player: player, dense: true),
      ],
    );
  }

  Widget _large(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          // Gauche : pochette et titres.
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _Pochette(track: track, size: 56),
                const SizedBox(width: 14),
                Expanded(child: _Titres(track: track, error: player.error)),
              ],
            ),
          ),
          // Centre : contrôles et barre de progression (ou badge direct).
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!track.isLive)
                      _IconeAction(
                        icon: Icons.replay_10_rounded,
                        label: 'Reculer de 10 secondes',
                        onTap: () => _decaler(const Duration(seconds: -10)),
                      ),
                    const SizedBox(width: 8),
                    _BoutonLecture(player: player, size: 40),
                    const SizedBox(width: 8),
                    if (!track.isLive)
                      _IconeAction(
                        icon: Icons.forward_30_rounded,
                        label: 'Avancer de 30 secondes',
                        onTap: () => _decaler(const Duration(seconds: 30)),
                      ),
                  ],
                ),
                if (track.isLive)
                  const Padding(padding: EdgeInsets.only(top: 4), child: LiveBadge())
                else
                  _Timeline(player: player, dense: true),
              ],
            ),
          ),
          // Droite : volume et fermeture.
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _IconeAction(
                  icon: player.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  label: 'Couper le son',
                  onTap: () => player.setVolume(player.volume == 0 ? 1 : 0),
                ),
                SizedBox(
                  width: 120,
                  child: Slider(value: player.volume, onChanged: player.setVolume),
                ),
                _IconeAction(icon: Icons.close_rounded, label: 'Fermer le lecteur', onTap: player.close),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _decaler(Duration decalage) {
    final cible = player.position.value + decalage;
    final duree = player.duration;
    if (cible < Duration.zero) {
      player.seek(Duration.zero);
    } else if (duree == null || cible < duree) {
      player.seek(cible);
    }
  }
}

class _Pochette extends StatelessWidget {
  const _Pochette({required this.track, required this.size});

  final PlayerTrack track;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (track.isLive) {
      return RadioLogo(url: track.artworkUrl, bytes: track.artworkBytes, size: size, radius: AppRadius.sm);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox.square(dimension: size, child: CoverImage(url: track.artworkUrl)),
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
        Text(
          error ?? track.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textes.bodySmall!.copyWith(color: error != null ? scheme.error : scheme.onSurfaceVariant),
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
      child: IconButton(onPressed: onTap, icon: Icon(icon)),
    );
  }
}

// Barre de progression d'un podcast. N'écoute que la position,
// donc elle est la seule à se reconstruire pendant la lecture.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.player, this.dense = false});

  final PlayerController player;
  final bool dense;

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
        return SizedBox(
          height: dense ? 22 : 32,
          child: Row(
            children: [
              Text(_format(position), style: style),
              Expanded(
                child: Slider(
                  value: max == 0 ? 0 : valeur,
                  max: max == 0 ? 1 : max,
                  onChanged: max == 0 ? null : (v) => player.seek(Duration(milliseconds: v.round())),
                ),
              ),
              Text(_format(duree), style: style),
            ],
          ),
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
