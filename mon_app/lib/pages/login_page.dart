import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

// Page de connexion du gérant, via notre API (POST /auth/login puis GET /auth/me).
// La page se ferme avec un GerantConnecte : sa radio et son jeton de connexion.
class GerantConnecte {
  const GerantConnecte({
    required this.slug,
    required this.jeton,
    required this.utilisateur,
    required this.motDePasse,
  });

  final String slug; // la radio qu'il gère
  final String jeton; // à envoyer dans "Authorization: Bearer ..." (valable 7 jours)
  // Encore utilisés par l'envoi de notifications (fonction Supabase), qui revérifie
  // le compte. À retirer quand les notifications passeront par notre API.
  final String utilisateur;
  final String motDePasse;
}

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
    final utilisateur = _utilisateurController.text.trim();
    final motDePasse = _motDePasseController.text;
    final String jeton;
    final Map<String, dynamic> compte;
    try {
      // Standard OAuth2 : formulaire avec "username" et "password".
      final connexion = await Api.postFormulaire('/auth/login', {
        'username': utilisateur,
        'password': motDePasse,
      });
      jeton = connexion['access_token'] as String;
      compte = await Api.get('/auth/me', jeton: jeton) as Map<String, dynamic>;
    } on ApiException catch (erreur) {
      _message(erreur.statusCode == 401 ? 'Identifiants incorrects.' : erreur.message);
      return;
    }
    final slug = compte['radio_slug'] as String?;
    if (compte['is_admin'] != true || slug == null) {
      _message("Ce compte ne gère aucune radio.");
      return;
    }
    if (mounted) {
      Navigator.of(context).pop(
        GerantConnecte(slug: slug, jeton: jeton, utilisateur: utilisateur, motDePasse: motDePasse),
      );
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
