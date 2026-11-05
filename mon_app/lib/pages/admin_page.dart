import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../models/campus_radio.dart';
import '../models/radio_settings.dart';
import '../widgets/notification_form.dart';
import 'login_page.dart';

// Page admin : le gérant d'une radio règle l'affichage de sa page.
// Le gérant choisit sa radio, se connecte, puis règle l'affichage de sa page :
// chaque gérant ne règle que sa propre radio.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<List<CampusRadio>> _radiosFuture;
  final TextEditingController _siteController = TextEditingController();

  // Radio gérée (null tant qu'il n'est pas connecté à une radio).
  CampusRadio? _radio;
  // Le gérant connecté (null tant qu'il n'est pas connecté).
  GerantConnecte? _gerant;
  // Réglages en cours de modification (enregistrés seulement avec le bouton).
  bool _afficherSite = false;
  Uint8List? _logo;
  Color? _couleur;

  @override
  void initState() {
    super.initState();
    _radiosFuture = RadioRepository.getRadios();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connexion());
  }

  @override
  void dispose() {
    _siteController.dispose();
    super.dispose();
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  
  Future<void> _connexion() async {
    final gerant = await Navigator.of(context).push<GerantConnecte>(
      MaterialPageRoute<GerantConnecte>(builder: (context) => const LoginPage()),
    );
    if (!mounted) {
      return;
    }
    if (gerant == null) {
      Navigator.of(context).pop(); 
      return;
    }
    final radios = await _radiosFuture;
    CampusRadio? radio;
    for (final candidate in radios) {
      if (candidate.id == gerant.slug) {
        radio = candidate;
      }
    }
    if (radio == null) {
      if (mounted) {
        _message('Radio introuvable : ${gerant.slug}');
        Navigator.of(context).pop();
      }
      return;
    }
    final reglages = await RadioSettingsRepository.load(radio);
    if (!mounted) {
      return;
    }
    setState(() {
      _gerant = gerant;
      _radio = radio;
      _afficherSite = reglages.afficherSite;
      _siteController.text = reglages.siteUrl ?? '';
      _logo = reglages.logo;
      _couleur = reglages.couleur;
    });
  }

  Future<void> _choisirLogo() async {
    final fichier = await FilePicker.pickFile(type: FileType.image);
    if (fichier == null) {
      return; // le gérant a annulé
    }
    final octets = await fichier.readAsBytes();
    // L'image est enregistrée en texte : on évite les fichiers trop lourds.
    if (octets.length > 1000000) {
      _message('Image trop lourde (1 Mo maximum).');
      return;
    }
    setState(() {
      _logo = octets;
    });
  }

  Future<void> _choisirCouleur() async {
    Color choix = _couleur ?? Theme.of(context).colorScheme.secondary;
    final valide = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Couleur secondaire'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: choix,
            enableAlpha: false, // pas de transparence
            onColorChanged: (couleur) {
              choix = couleur;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (valide == true) {
      setState(() {
        _couleur = choix;
      });
    }
  }

  Future<void> _enregistrer() async {
    final radio = _radio!;
    String? siteUrl = _siteController.text.trim();
    if (siteUrl.isEmpty) {
      siteUrl = null;
    }
    if (_afficherSite && siteUrl == null) {
      _message("Indique l'adresse de ton site web.");
      return;
    }
    await RadioSettingsRepository.save(
      RadioSettings(
        radioId: radio.id,
        afficherSite: _afficherSite,
        siteUrl: siteUrl,
        logo: _logo,
        couleur: _couleur,
      ),
    );
    if (mounted) {
      _message('Réglages enregistrés.');
    }
  }

  // Aperçu du logo : celui du gérant, sinon celui de l'API.
  Widget _apercuLogo() {
    if (_logo != null) {
      return Image.memory(_logo!, width: 80, height: 80, fit: BoxFit.contain);
    }
    final logoUrl = _radio!.logoUrl;
    if (logoUrl != null) {
      return Image.network(logoUrl, width: 80, height: 80, fit: BoxFit.contain);
    }
    return const Icon(Icons.radio, size: 80);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Espace gérant')),
      body: _radio == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_radio!.name, style: Theme.of(context).textTheme.headlineSmall),
                ..._formulaire(),
              ],
            ),
    );
  }

  List<Widget> _formulaire() {
    final titre = Theme.of(context).textTheme.titleMedium;
    final widgets = <Widget>[];

    // 1. Site web ou version appli.
    widgets.add(const SizedBox(height: 24));
    widgets.add(Text('Quand on touche ma radio', style: titre));
    widgets.add(
      SwitchListTile(
        title: const Text('Afficher mon site web'),
        subtitle: Text(
          _afficherSite
              ? 'Ton site web s\'ouvre dans l\'appli.'
              : 'Version appli : description, podcasts et actualités.',
        ),
        value: _afficherSite,
        onChanged: (valeur) {
          setState(() {
            _afficherSite = valeur;
          });
        },
      ),
    );
    if (_afficherSite) {
      widgets.add(
        TextField(
          controller: _siteController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Adresse du site',
            hintText: 'https://...',
          ),
        ),
      );
    }

    // 2. Logo.
    widgets.add(const SizedBox(height: 24));
    widgets.add(Text('Logo', style: titre));
    final boutonsLogo = <Widget>[
      OutlinedButton.icon(
        onPressed: _choisirLogo,
        icon: const Icon(Icons.image),
        label: const Text('Choisir une image'),
      ),
    ];
    if (_logo != null) {
      boutonsLogo.add(
        TextButton(
          onPressed: () {
            setState(() {
              _logo = null;
            });
          },
          child: const Text('Retirer'),
        ),
      );
    }
    widgets.add(
      Row(
        children: [
          _apercuLogo(),
          const SizedBox(width: 16),
          Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: boutonsLogo)),
        ],
      ),
    );

    // 3. Couleur secondaire.
    widgets.add(const SizedBox(height: 24));
    widgets.add(Text('Couleur de ma page', style: titre));
    Widget? boutonDefaut;
    if (_couleur != null) {
      boutonDefaut = TextButton(
        onPressed: () {
          setState(() {
            _couleur = null;
          });
        },
        child: const Text('Par défaut'),
      );
    }
    widgets.add(
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: _couleur ?? Theme.of(context).colorScheme.secondary,
        ),
        title: const Text('Couleur secondaire'),
        subtitle: const Text('Bandeau du logo, lecteur et boutons de ta page.'),
        onTap: _choisirCouleur,
        trailing: boutonDefaut,
      ),
    );

    // Enregistrer.
    widgets.add(const SizedBox(height: 32));
    widgets.add(
      FilledButton.icon(
        onPressed: _enregistrer,
        icon: const Icon(Icons.save),
        label: const Text('Enregistrer'),
      ),
    );

    // Notifications push aux auditeurs.
    widgets.add(const Divider(height: 48));
    // La "key" recrée le formulaire quand le gérant change de radio.
    widgets.add(NotificationForm(key: ValueKey(_radio!.id), radio: _radio!, gerant: _gerant!));
    return widgets;
  }
}
