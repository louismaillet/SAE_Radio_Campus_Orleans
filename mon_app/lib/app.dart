import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'player/player_controller.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/bottom_player.dart';

class RadioCampusApp extends StatefulWidget {
  const RadioCampusApp({super.key});

  @override
  State<RadioCampusApp> createState() => _RadioCampusAppState();
}

class _RadioCampusAppState extends State<RadioCampusApp> {
  // Créés une seule fois pour toute l'appli.
  final PlayerController _player = PlayerController();
  final ThemeController _theme = ThemeController()..load();

  @override
  void dispose() {
    _player.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _theme,
      child: PlayerScope(
        controller: _player,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: _theme,
          builder: (context, mode, _) => MaterialApp(
            title: 'Radio Campus France',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            // Le lecteur est sous le Navigator : il reste affiché quand on change de page.
            builder: (context, child) => ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  Expanded(child: child!),
                  const BottomPlayer(),
                ],
              ),
            ),
            home: const HomePage(),
          ),
        ),
      ),
    );
  }
}
