import 'package:flutter/material.dart';

// Donne à son contenu l'état "survolé" (souris) pour animer cartes et boutons.
// Sur écran tactile, hovered reste à false.
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({required this.builder, this.onTap, super.key});

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(context, _hovered),
      ),
    );
  }
}

// Carte qui se soulève légèrement au survol.
class HoverLift extends StatelessWidget {
  const HoverLift({required this.child, this.onTap, this.glow, super.key});

  final Widget child;
  final VoidCallback? onTap;
  final Color? glow; // couleur de l'ombre au survol

  @override
  Widget build(BuildContext context) {
    final ombre = glow ?? Theme.of(context).colorScheme.primary;
    return HoverBuilder(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, hovered ? -6 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: ombre.withValues(alpha: hovered ? 0.28 : 0),
              blurRadius: hovered ? 32 : 0,
              offset: const Offset(0, 12),
              spreadRadius: -10,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
