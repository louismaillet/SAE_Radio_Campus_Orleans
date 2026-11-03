import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

// Bouton soleil / lune pour passer du thème sombre au clair.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    final sombre = controller.value == ThemeMode.dark;
    return IconButton(
      tooltip: sombre ? 'Thème clair' : 'Thème sombre',
      onPressed: controller.toggle,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween(begin: 0.75, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(sombre ? Icons.light_mode_rounded : Icons.dark_mode_rounded, key: ValueKey(sombre)),
      ),
    );
  }
}
