import 'package:flutter/material.dart';

import '../models/campus_radio.dart';
import '../services/notification_service.dart';
import '../services/radio_choisie.dart';
import 'accueil_page.dart';
import 'explorer_page.dart';
import 'radio_details_page.dart';

// Écran principal : deux onglets.
// - Accueil : la carte pour choisir sa ville, puis, une fois une radio par défaut
//   choisie (sur la carte ou dans Explorer), la page de cette radio avec son player.
// - Explorer : la mosaïque de toutes les radios.
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
  bool _lectureEnCours = true; // évite d'afficher la carte un instant avant la radio mémorisée

  @override
  void initState() {
    super.initState();
    _radios = widget.chargerRadios();
    RadioChoisie.courante.addListener(_majRadioParDefaut);
    _lireRadioMemorisee();
  }

  @override
  void dispose() {
    RadioChoisie.courante.removeListener(_majRadioParDefaut);
    super.dispose();
  }

  Future<void> _lireRadioMemorisee() async {
    final radioId = await RadioChoisie.lire();
    // On (re)vérifie l'abonnement aux notifications de cette radio.
    if (radioId != null) NotificationService.abonnerRadio(null, radioId);
    if (mounted) setState(() => _lectureEnCours = false);
  }

  // Nouvelle radio par défaut (carte ou Explorer) : on l'affiche dans l'onglet Accueil.
  void _majRadioParDefaut() {
    if (!mounted) return;
    setState(() {
      if (RadioChoisie.courante.value != null) _onglet = 0;
    });
  }

  // Recharge la liste des radios (partagée par les deux onglets).
  Future<void> _rafraichir() async {
    setState(() => _radios = widget.chargerRadios());
    await _radios.then((_) {}, onError: (Object _) {});
  }

  // Onglet Accueil : la page de la radio par défaut, ou la carte tant qu'il n'y en a pas.
  Widget _accueil() {
    final carte = AccueilPage(radios: _radios, onReessayer: _rafraichir);
    final radioId = RadioChoisie.courante.value;
    if (radioId == null) return carte;
    return FutureBuilder<List<CampusRadio>>(
      future: _radios,
      builder: (context, snapshot) {
        if (snapshot.hasError) return carte; // la carte affiche l'erreur et « Réessayer »
        final radios = snapshot.data;
        if (radios == null) return const Center(child: CircularProgressIndicator());
        for (final radio in radios) {
          if (radio.id == radioId) return RadioDetailsPage(key: ValueKey(radio.id), radio: radio);
        }
        return carte; // radio disparue du réseau : on en choisit une autre
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lectureEnCours) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final aUneRadio = RadioChoisie.courante.value != null;
    return Scaffold(
      body: IndexedStack(
        index: _onglet,
        children: [
          _accueil(),
          ExplorerPage(radios: _radios, onRafraichir: _rafraichir),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _onglet,
        onDestinationSelected: (i) => setState(() => _onglet = i),
        destinations: [
          NavigationDestination(
            icon: Icon(aUneRadio ? Icons.radio_outlined : Icons.location_on_outlined),
            selectedIcon: Icon(aUneRadio ? Icons.radio : Icons.location_on),
            label: 'Accueil',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explorer',
          ),
        ],
      ),
    );
  }
}
