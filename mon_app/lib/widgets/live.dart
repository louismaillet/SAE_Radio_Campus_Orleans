import 'package:flutter/material.dart';

import '../player/player_controller.dart';
import '../theme/app_theme.dart';

// Pastille rouge "EN DIRECT" qui clignote doucement.
class LiveBadge extends StatefulWidget {
  const LiveBadge({this.label = 'EN DIRECT', super.key});

  final String label;

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.live.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.live.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.3, end: 1.0).animate(_anim),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall!.copyWith(color: AppColors.live, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

// Ondes qui partent de son contenu, comme un signal radio.
class PulseHalo extends StatefulWidget {
  const PulseHalo({required this.child, required this.color, this.active = true, super.key});

  final Widget child;
  final Color color;
  final bool active;

  @override
  State<PulseHalo> createState() => _PulseHaloState();
}

class _PulseHaloState extends State<PulseHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _anim.repeat();
    }
  }

  @override
  void didUpdateWidget(PulseHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_anim.isAnimating) {
      _anim.repeat();
    } else if (!widget.active) {
      _anim.stop();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OndesPainter(_anim, widget.color, widget.active), child: widget.child);
  }
}

class _OndesPainter extends CustomPainter {
  _OndesPainter(this.anim, this.color, this.active) : super(repaint: anim);

  final Animation<double> anim;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) {
      return;
    }
    final rect = Offset.zero & size;
    // Deux ondes décalées d'une demi-période.
    for (final decalage in [0.0, 0.5]) {
      final t = (anim.value + decalage) % 1;
      final agrandi = rect.inflate(18 * t);
      final peinture = Paint()
        ..color = color.withValues(alpha: 0.45 * (1 - t))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(RRect.fromRectAndRadius(agrandi, Radius.circular(agrandi.height / 2)), peinture);
    }
  }

  @override
  bool shouldRepaint(_OndesPainter oldDelegate) => oldDelegate.color != color || oldDelegate.active != active;
}

// Grand bouton "Écouter en direct" : pulse tant que la radio est à l'antenne,
// et devient "En écoute" quand c'est elle qui joue.
class LiveButton extends StatelessWidget {
  const LiveButton({required this.track, this.large = true, super.key});

  final PlayerTrack track;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final courant = player.isCurrent(track.url);
    final enEcoute = courant && player.isPlaying;
    final chargement = courant && player.isLoading;

    Widget icone = Icon(enEcoute ? Icons.stop_rounded : Icons.play_arrow_rounded, size: large ? 28 : 22);
    if (chargement) {
      icone = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
      );
    }

    return PulseHalo(
      color: scheme.primary,
      active: !enEcoute,
      child: FilledButton.icon(
        onPressed: () => PlayerScope.read(context).play(track),
        style: FilledButton.styleFrom(
          padding: large
              ? const EdgeInsets.symmetric(horizontal: 32, vertical: 22)
              : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 8,
          shadowColor: scheme.primary.withValues(alpha: 0.6),
        ),
        icon: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: icone),
        label: Text(enEcoute ? 'En écoute' : 'Écouter en direct'),
      ),
    );
  }
}

// Petites barres d'égaliseur animées (élément en cours de lecture).
class EqualizerBars extends StatefulWidget {
  const EqualizerBars({this.color, this.size = 16, super.key});

  final Color? color;
  final double size;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couleur = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final phase in [0.0, 0.35, 0.7])
              Container(
                width: widget.size / 5,
                height: widget.size * (0.3 + 0.7 * _rebond((_anim.value + phase) % 1)),
                decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      ),
    );
  }

  // Monte puis redescend : 0 -> 1 -> 0.
  double _rebond(double t) => t < 0.5 ? t * 2 : (1 - t) * 2;
}
