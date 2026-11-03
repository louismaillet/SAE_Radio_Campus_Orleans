import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mode clair / sombre choisi par l'utilisateur, gardé sur l'appareil.
// Sombre par défaut.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark);

  static const String _cle = 'mode_theme';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_cle) == 'light') {
      value = ThemeMode.light;
    }
  }

  Future<void> toggle() async {
    value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, value == ThemeMode.dark ? 'dark' : 'light');
  }
}

// Donne accès au ThemeController depuis n'importe quel widget.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({required ThemeController controller, required super.child, super.key})
      : super(notifier: controller);

  static ThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.notifier!;
}
