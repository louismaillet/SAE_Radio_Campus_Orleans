import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/campus_radio.dart';
import 'radio_details_page.dart';

// Clé sous laquelle on mémorise la radio choisie (son slug) sur l'appareil.
const String _cleRadioChoisie = 'radio_choisie';

class RadioListPage extends StatefulWidget {
  const RadioListPage({super.key});

  @override
  State<RadioListPage> createState() => _RadioListPageState();
}

class _RadioListPageState extends State<RadioListPage> {
  late Future<List<CampusRadio>> _radiosFuture;

  @override
  void initState() {
    super.initState();
    _radiosFuture = RadioRepository.getRadios();
    _ouvrirRadioMemorisee();
  }

  // Si une radio a déjà été choisie lors d'une ouverture précédente,
  // on l'ouvre directement (la liste reste derrière avec le bouton retour).
  Future<void> _ouvrirRadioMemorisee() async {
    final prefs = await SharedPreferences.getInstance();
    final radioId = prefs.getString(_cleRadioChoisie);
    if (radioId == null) {
      return; // première ouverture : on laisse l'utilisateur choisir
    }
    final radios = await _radiosFuture;
    if (!mounted) {
      return;
    }
    for (final radio in radios) {
      if (radio.id == radioId) {
        _openRadio(radio);
        return;
      }
    }
  }

  // Fenêtre qui demande de confirmer la radio par défaut.
  // Renvoie true si l'utilisateur a appuyé sur « Confirmer ».
  Future<bool> _confirmerRadio(CampusRadio radio) async {
    final reponse = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Radio par défaut'),
          content: Text(
            'Voulez-vous choisir ${radio.name} comme radio par défaut ?\n'
            'Elle s\'ouvrira directement au prochain lancement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
    // reponse vaut null si l'utilisateur ferme la fenêtre sans choisir
    return reponse == true;
  }

  // L'utilisateur choisit une radio : on demande confirmation,
  // puis on la mémorise et on l'ouvre.
  Future<void> _choisirRadio(CampusRadio radio) async {
    final confirme = await _confirmerRadio(radio);
    if (!confirme || !mounted) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleRadioChoisie, radio.id);
    if (!mounted) {
      return;
    }
    _openRadio(radio);
  }

  void _openRadio(CampusRadio radio) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => RadioDetailsPage(radio: radio)),
    );
  }

  Widget _logo(CampusRadio radio) {
    final logoUrl = radio.logoUrl;
    if (logoUrl == null) {
      return const Icon(Icons.radio);
    }
    return Image.network(logoUrl, width: 40, height: 40);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radios Campus')),
      body: FutureBuilder<List<CampusRadio>>(
        future: _radiosFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final radios = snapshot.data!;
          return ListView.builder(
            itemCount: radios.length,
            itemBuilder: (context, index) {
              final radio = radios[index];
              return ListTile(
                leading: _logo(radio),
                title: Text(radio.name),
                onTap: () => _choisirRadio(radio),
              );
            },
          );
        },
      ),
    );
  }
}
