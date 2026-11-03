import 'package:flutter/material.dart';

import '../models/campus_radio.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/images.dart';

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

  void _seConnecter() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                      Center(child: RadioLogo(url: widget.radio.logoUrl, size: 72)),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Connexion', textAlign: TextAlign.center, style: textes.headlineSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.radio.name,
                        textAlign: TextAlign.center,
                        style: textes.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                      ),
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
                      FilledButton(
                        onPressed: _seConnecter,
                        child: const Text('Se connecter'),
                      ),
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
