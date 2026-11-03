import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  // Permet au mini-lecteur (hors du Navigator) d'ouvrir le lecteur plein écran.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
            navigatorKey: _navigatorKey,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            builder: (context, child) => _Cadre(navigatorKey: _navigatorKey, child: child!),
            home: const HomePage(),
          ),
        ),
      ),
    );
  }
}

// Autour de toutes les pages : le mini-lecteur en bas, la barre de statut
// transparente, et une taille de texte limitée pour ne pas casser les cartes.
class _Cadre extends StatelessWidget {
  const _Cadre({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    // Clavier ouvert : on cache le lecteur pour laisser la place aux champs.
    final clavierOuvert = media.viewInsets.bottom > 0;
    final lecteurVisible = PlayerScope.of(context).track != null && !clavierOuvert;

    Widget pages = child;
    // Le lecteur s'occupe déjà du bas de l'écran (barre gestuelle) :
    // les pages n'ont plus à laisser cette marge.
    if (lecteurVisible) {
      pages = MediaQuery.removePadding(context: context, removeBottom: true, child: pages);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (sombre ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              Expanded(child: pages),
              if (!clavierOuvert) BottomPlayer(navigatorKey: navigatorKey),
            ],
          ),
        ),
      ),
    );
  }
}
