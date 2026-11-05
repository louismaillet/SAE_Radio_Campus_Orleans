import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/campus_radio.dart';

// Formulaire de la page admin pour envoyer une notification push :
// - aux utilisateurs qui ont cette radio par défaut ;
// - ou à tout le monde, si le compte est gérant national (Radio Campus France).
// Le compte doit être connecté (Supabase) et déclaré dans la table "gerants".
// La vérification des droits est refaite par le serveur (fonction envoyer-notification).
class NotificationForm extends StatefulWidget {
  const NotificationForm({required this.radio, super.key});
  final CampusRadio radio;

  @override
  State<NotificationForm> createState() => _NotificationFormState();
}

class _NotificationFormState extends State<NotificationForm> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _texteController = TextEditingController();
  // Champs de la connexion provisoire.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _motDePasseController = TextEditingController();

  bool _chargement = true;
  // Radios gérées par le compte connecté (slugs, ou "national").
  List<String> _radiosGerees = [];
  bool _pourTous = false;
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerDroits();
  }

  @override
  void dispose() {
    _titreController.dispose();
    _texteController.dispose();
    _emailController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  bool get _connecte => _supabase.auth.currentUser != null;
  bool get _estNational => _radiosGerees.contains('national');

  // On lit dans la table "gerants" les radios du compte connecté.
  Future<void> _chargerDroits() async {
    final radios = <String>[];
    if (_connecte) {
      final lignes = await _supabase.from('gerants').select('radio_id');
      for (final ligne in lignes) {
        radios.add(ligne['radio_id'] as String);
      }
    }
    if (mounted) {
      setState(() {
        _radiosGerees = radios;
        _chargement = false;
      });
    }
  }

  // PROVISOIRE : à supprimer quand la page de connexion sera branchée.
  // (Les champs ne sont pas libérés ici : la fenêtre les utilise encore
  // pendant son animation de fermeture. Ils le sont dans dispose().)
  Future<void> _connexionTest() async {
    final valide = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Connexion gérant (test)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              TextField(
                controller: _motDePasseController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Se connecter'),
            ),
          ],
        );
      },
    );
    final email = _emailController.text.trim();
    final motDePasse = _motDePasseController.text;
    _motDePasseController.clear();
    if (valide != true) {
      return;
    }
    try {
      await _supabase.auth.signInWithPassword(email: email, password: motDePasse);
    } on AuthException catch (erreur) {
      _message('Connexion impossible : ${erreur.message}');
      return;
    }
    await _chargerDroits();
  }

  Future<void> _deconnecter() async {
    await _supabase.auth.signOut();
    await _chargerDroits();
  }

  Future<void> _envoyer() async {
    final titre = _titreController.text.trim();
    final texte = _texteController.text.trim();
    if (titre.isEmpty || texte.isEmpty) {
      _message('Écris un titre et un texte.');
      return;
    }
    // "national" = tout le monde, sinon les auditeurs de cette radio.
    String radioId = widget.radio.id;
    if (_pourTous) {
      radioId = 'national';
    }
    setState(() {
      _envoiEnCours = true;
    });
    try {
      await _supabase.functions.invoke(
        'envoyer-notification',
        body: {'radioId': radioId, 'titre': titre, 'texte': texte},
      );
      _titreController.clear();
      _texteController.clear();
      _message('Notification envoyée.');
    } on FunctionException catch (erreur) {
      // Le serveur renvoie { "erreur": "..." } quand il refuse.
      String raison = 'erreur ${erreur.status}';
      final details = erreur.details;
      if (details is Map && details['erreur'] != null) {
        raison = details['erreur'] as String;
      }
      _message('Envoi refusé : $raison');
    }
    if (mounted) {
      setState(() {
        _envoiEnCours = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[
      Text('Envoyer une notification', style: Theme.of(context).textTheme.titleMedium),
    ];

    if (_chargement) {
      widgets.add(const Center(child: CircularProgressIndicator()));
    } else if (!_connecte) {
      widgets.add(const Text('Connecte-toi avec ton compte gérant pour envoyer des notifications.'));
      widgets.add(
        OutlinedButton.icon(
          onPressed: _connexionTest,
          icon: const Icon(Icons.login),
          label: const Text('Connexion (provisoire)'),
        ),
      );
    } else {
      widgets.add(
        Row(
          children: [
            Expanded(child: Text('Connecté : ${_supabase.auth.currentUser!.email}')),
            TextButton(onPressed: _deconnecter, child: const Text('Se déconnecter')),
          ],
        ),
      );
      if (_estNational || _radiosGerees.contains(widget.radio.id)) {
        widgets.addAll(_formulaire());
      } else {
        widgets.add(Text('Ce compte ne gère pas ${widget.radio.name}.'));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  List<Widget> _formulaire() {
    final widgets = <Widget>[];
    // Seul le gérant national peut écrire à tous les utilisateurs.
    if (_estNational) {
      widgets.add(
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Envoyer à tous les utilisateurs'),
          subtitle: Text(
            _pourTous
                ? 'Toutes les radios (Radio Campus France).'
                : 'Seulement les auditeurs de ${widget.radio.name}.',
          ),
          value: _pourTous,
          onChanged: (valeur) {
            setState(() {
              _pourTous = valeur;
            });
          },
        ),
      );
    }
    widgets.add(
      TextField(
        controller: _titreController,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Titre'),
      ),
    );
    widgets.add(
      TextField(
        controller: _texteController,
        maxLength: 500,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Message'),
      ),
    );
    widgets.add(
      FilledButton.icon(
        onPressed: _envoiEnCours ? null : _envoyer,
        icon: const Icon(Icons.send),
        label: const Text('Envoyer'),
      ),
    );
    return widgets;
  }
}
