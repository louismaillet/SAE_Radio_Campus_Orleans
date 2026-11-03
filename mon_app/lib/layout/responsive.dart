import 'dart:math' as math;

import 'package:flutter/material.dart';

// Trois tailles d'écran : téléphone, tablette / petite fenêtre, ordinateur.
enum ScreenSize { compact, medium, expanded }

class Responsive {
  static const double maxContentWidth = 1280;

  static ScreenSize sizeOf(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;
    if (largeur < 600) {
      return ScreenSize.compact;
    }
    if (largeur < 1024) {
      return ScreenSize.medium;
    }
    return ScreenSize.expanded;
  }

  static bool isCompact(BuildContext context) => sizeOf(context) == ScreenSize.compact;
  static bool isExpanded(BuildContext context) => sizeOf(context) == ScreenSize.expanded;

  // Marge sur les côtés : elle grandit pour garder le contenu centré
  // et jamais plus large que maxContentWidth.
  static double sidePadding(BuildContext context, [double? largeurDispo]) {
    final largeur = largeurDispo ?? MediaQuery.sizeOf(context).width;
    final gouttiere = switch (sizeOf(context)) {
      ScreenSize.compact => 16.0,
      ScreenSize.medium => 32.0,
      ScreenSize.expanded => 48.0,
    };
    return math.max(gouttiere, (largeur - maxContentWidth) / 2);
  }
}

// Sliver qui centre son contenu avec les marges responsives.
class SliverContent extends StatelessWidget {
  const SliverContent({required this.sliver, this.top = 0, this.bottom = 0, super.key});

  final Widget sliver;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final cote = Responsive.sidePadding(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(cote, top, cote, bottom),
      sliver: sliver,
    );
  }
}
