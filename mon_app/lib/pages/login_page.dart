import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Page de connexion du gérant. Le serveur retrouve sa radio : la page se ferme avec le slug de cette radio.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _utilisateurController = TextEditingController();
  final _motDePasseController = TextEditingController();

  @override
  void dispose() {
    _utilisateurController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  String? _obligatoire(String? valeur) {
    return (valeur == null || valeur.trim().isEmpty) ? 'Champ obligatoire' : null;
  }

  Future<void> _seConnecter() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    String? slug;
    try {
      // Le serveur vérifie utilisateur + mot de passe et renvoie la radio du gérant (null si faux).
      final reponse = await Supabase.instance.client.rpc('radio_du_gerant', params: {
        'p_utilisateur': _utilisateurController.text.trim(),
        'p_mot_de_passe': _motDePasseController.text,
      });
      slug = reponse as String?;
    } catch (_) {
      _message('Connexion impossible, vérifie ta connexion internet.');
      return;
    }
    if (slug == null) {
      _message('Identifiants incorrects.');
      return;
    }
    if (mounted) {
      Navigator.of(context).pop(slug);
    }
  }

  void _message(String texte) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _utilisateurController,
                decoration: const InputDecoration(labelText: "Nom d'utilisateur"),
                textInputAction: TextInputAction.next,
                validator: _obligatoire,
              ),
              TextFormField(
                controller: _motDePasseController,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                onFieldSubmitted: (_) => _seConnecter(),
                validator: _obligatoire,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _seConnecter,
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
