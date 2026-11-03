import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Carte pleine (sans flou) pour le contenu qui défile : le flou coûte cher
// sur les téléphones, on le garde pour les barres fixes et le lecteur.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({required this.child, this.padding = const EdgeInsets.all(AppSpacing.md), super.key});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }
}

// Panneau "verre dépoli" : floute ce qu'il y a derrière, avec un léger reflet.
class Glass extends StatelessWidget {
  const Glass({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = AppRadius.lg,
    this.blur = 20,
    this.opacity = 0.55,
    this.tint,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double opacity; // opacité de la teinte (0 = transparent)
  final Color? tint; // par défaut : la couleur de surface du thème

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sombre = scheme.brightness == Brightness.dark;
    final teinte = tint ?? scheme.surfaceContainer;
    final arrondi = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: arrondi,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: arrondi,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                teinte.withValues(alpha: opacity),
                teinte.withValues(alpha: opacity * 0.7),
              ],
            ),
            border: Border.all(color: (sombre ? Colors.white : Colors.black).withValues(alpha: sombre ? 0.08 : 0.06)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
