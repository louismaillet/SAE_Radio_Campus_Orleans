import 'package:flutter/material.dart';

import '../models/campus_radio.dart';

// Page de connexion du gérant de la radio choisie. Se ferme avec true quand le formulaire est validé.
// Pour l'instant il n'y a pas de serveur : on vérifie seulement que les champs sont remplis.
// shortcut: aucun contrôle que le gérant appartient à cette radio, à faire avec Supabase.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.radio});

  final CampusRadio radio;

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

  void _seConnecter() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Connexion · ${widget.radio.name}')),
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
