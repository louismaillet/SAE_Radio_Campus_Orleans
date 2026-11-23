import 'dart:math' as math;

import 'package:flutter/material.dart';

// L'appli est faite pour le téléphone. Sur une tablette, on garde la même
// mise en page : elle est juste centrée et un peu plus aérée.
class Responsive {
  static const double maxContentWidth = 720;

  static bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= 600;

  // Marge sur les côtés : 16 sur téléphone, et le contenu ne dépasse jamais maxContentWidth.
  static double sidePadding(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;
    final gouttiere = isTablet(context) ? 32.0 : 16.0;
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
    return SliverPadding(padding: EdgeInsets.fromLTRB(cote, top, cote, bottom), sliver: sliver);
  }
}
