import 'package:flutter/material.dart';

import '../models/campus_radio.dart';
import '../services/notification_service.dart';
import '../services/radio_choisie.dart';
import 'accueil_page.dart';
import 'explorer_page.dart';
import 'radio_details_page.dart';

// Écran principal : deux onglets, Accueil (choix de sa ville sur la carte) et Explorer (toutes les radios).
// Une fois la radio choisie (sur la carte, ou par défaut depuis Explorer), la carte
// n'est plus proposée : il ne reste qu'Explorer.
class HomePage extends StatefulWidget {
  const HomePage({this.chargerRadios = RadioRepository.getRadios, super.key});

  // Remplaçable dans les tests pour ne pas appeler l'API.
  final Future<List<CampusRadio>> Function() chargerRadios;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<CampusRadio>> _radios;
  int _onglet = 0;
  bool _redirection = true;

  @override
  void initState() {
    super.initState();
    _radios = widget.chargerRadios();
    RadioChoisie.choixFait.addListener(_majChoix);
    _ouvrirRadioMemorisee();
  }

  @override
  void dispose() {
    RadioChoisie.choixFait.removeListener(_majChoix);
    super.dispose();
  }

  void _majChoix() {
    if (mounted) setState(() {});
  }

  // Recharge la liste des radios (partagée par les deux onglets).
  Future<void> _rafraichir() async {
    setState(() => _radios = widget.chargerRadios());
    await _radios.then((_) {}, onError: (Object _) {});
  }

  // Si une radio a déjà été choisie lors d'une ouverture précédente,
  // on l'ouvre directement (l'accueil reste derrière avec le bouton retour).
  Future<void> _ouvrirRadioMemorisee() async {
    final radioId = await RadioChoisie.lire();
    if (radioId != null) {
      // On (re)vérifie l'abonnement aux notifications de cette radio.
      NotificationService.abonnerRadio(null, radioId);
      try {
        final radios = await _radios;
        for (final radio in radios) {
          if (radio.id == radioId && mounted) {
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                transitionDuration: Duration.zero,
                pageBuilder: (context, animation, secondaryAnimation) => RadioDetailsPage(radio: radio),
              ),
            );
          }
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _redirection = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_redirection) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final choixFait = RadioChoisie.choixFait.value;
    return Scaffold(
      // L'accueil reste dans l'arbre mais n'est plus affiché une fois le choix fait,
      // pour ne pas recréer Explorer au moment où la radio s'ouvre.
      body: IndexedStack(
        index: choixFait ? 1 : _onglet,
        children: [
          AccueilPage(radios: _radios, onReessayer: _rafraichir),
          ExplorerPage(radios: _radios, onRafraichir: _rafraichir),
        ],
      ),
      bottomNavigationBar: choixFait
          ? null
          : NavigationBar(
              selectedIndex: _onglet,
              onDestinationSelected: (i) => setState(() => _onglet = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.location_on_outlined),
                  selectedIcon: Icon(Icons.location_on),
                  label: 'Accueil',
                ),
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Explorer',
                ),
              ],
            ),
    );
  }
}
