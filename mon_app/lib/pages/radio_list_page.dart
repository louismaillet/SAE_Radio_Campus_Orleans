import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/campus_radio.dart';
import '../models/radio_settings.dart';
import 'admin_page.dart';
import 'radio_details_page.dart';

class RadioListPage extends StatefulWidget {
  const RadioListPage({super.key});

  @override
  State<RadioListPage> createState() => _RadioListPageState();
}

class _RadioListPageState extends State<RadioListPage> {
  late Future<List<CampusRadio>> _radiosFuture;
  // Logos ajoutés par les gérants (slug -> image).
  Map<String, Uint8List> _logos = {};

  @override
  void initState() {
    super.initState();
    _radiosFuture = RadioRepository.getRadios();
    _chargerLogos();
  }

  Future<void> _chargerLogos() async {
    final logos = await RadioSettingsRepository.loadLogos();
    if (mounted) {
      setState(() {
        _logos = logos;
      });
    }
  }

  // Bouton temporaire : plus tard on passera par la page de connexion.
  Future<void> _ouvrirAdmin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const AdminPage()),
    );
    // Le gérant a peut-être changé son logo.
    _chargerLogos();
  }

  void _openRadio(CampusRadio radio) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => RadioDetailsPage(radio: radio)),
    );
  }

  Widget _logo(CampusRadio radio) {
    final logoGerant = _logos[radio.id];
    if (logoGerant != null) {
      return Image.memory(logoGerant, width: 40, height: 40);
    }
    final logoUrl = radio.logoUrl;
    if (logoUrl == null) {
      return const Icon(Icons.radio);
    }
    return Image.network(
      logoUrl,
      width: 40,
      height: 40,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.radio),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radios Campus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Espace gérant',
            onPressed: _ouvrirAdmin,
          ),
        ],
      ),
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
                onTap: () => _openRadio(radio),
              );
            },
          );
        },
      ),
    );
  }
}
