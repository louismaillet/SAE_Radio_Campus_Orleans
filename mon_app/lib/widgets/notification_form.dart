import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/campus_radio.dart';
import '../pages/login_page.dart';

// Radio du gérant national (Radio Campus France) : il peut écrire à tout le monde.
const String _radioNationale = 'radio-campus-france';

// Formulaire de la page admin pour envoyer une notification push :
// - aux utilisateurs qui ont cette radio par défaut ;
// - ou à tout le monde, si le gérant est celui de Radio Campus France.
// Le gérant s'est déjà connecté (LoginPage). La fonction Supabase envoyer-notification
// revérifie son nom et son mot de passe : le serveur ne fait pas confiance à l'app.
class NotificationForm extends StatefulWidget {
  const NotificationForm({required this.radio, required this.gerant, super.key});
  final CampusRadio radio;
  final GerantConnecte gerant;

  @override
  State<NotificationForm> createState() => _NotificationFormState();
}

class _NotificationFormState extends State<NotificationForm> {
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _texteController = TextEditingController();

  bool _pourTous = false;
  bool _envoiEnCours = false;

  bool get _estNational => widget.gerant.slug == _radioNationale;

  @override
  void dispose() {
    _titreController.dispose();
    _texteController.dispose();
    super.dispose();
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
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
      await Supabase.instance.client.functions.invoke(
        'envoyer-notification',
        body: {
          'radioId': radioId,
          'titre': titre,
          'texte': texte,
          'utilisateur': widget.gerant.utilisateur,
          'motDePasse': widget.gerant.motDePasse,
        },
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
  }
}
