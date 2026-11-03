import 'dart:ui';

import 'package:flutter/material.dart';

// Fenêtre modale qui apparaît en fondu + zoom, avec le fond flouté.
Future<T?> showSmoothDialog<T>({required BuildContext context, required WidgetBuilder builder}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final courbe = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6 * animation.value, sigmaY: 6 * animation.value),
        child: FadeTransition(
          opacity: courbe,
          child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(courbe), child: child),
        ),
      );
    },
  );
}
