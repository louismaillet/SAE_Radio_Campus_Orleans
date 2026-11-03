import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';

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
  bool _masquerMotDePasse = true;

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
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      extendBodyBehindAppBar: true,
      body: _FondAdmin(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Glass(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Connexion', textAlign: TextAlign.center, style: textes.headlineSmall),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _utilisateurController,
                        decoration: const InputDecoration(
                          labelText: "Nom d'utilisateur",
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _obligatoire,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _motDePasseController,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _masquerMotDePasse ? 'Afficher' : 'Masquer',
                            onPressed: () => setState(() => _masquerMotDePasse = !_masquerMotDePasse),
                            icon: Icon(_masquerMotDePasse ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        obscureText: _masquerMotDePasse,
                        onFieldSubmitted: (_) => _seConnecter(),
                        validator: _obligatoire,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(onPressed: _seConnecter, child: const Text('Se connecter')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Fond de l'espace gérant : deux taches de couleur floues derrière le verre.
class _FondAdmin extends StatelessWidget {
  const _FondAdmin({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tache(Color couleur) => Container(
      width: 420,
      height: 420,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [couleur.withValues(alpha: 0.45), couleur.withValues(alpha: 0)]),
      ),
    );
    return Stack(
      children: [
        Positioned(top: -120, left: -80, child: tache(scheme.primary)),
        Positioned(bottom: -140, right: -60, child: tache(scheme.tertiary)),
        Positioned.fill(child: child),
      ],
    );
  }
}
