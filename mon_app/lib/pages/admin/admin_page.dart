import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../layout/responsive.dart';
import '../../models/campus_radio.dart';
import '../../models/radio_settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/radio_palette.dart';
import '../../widgets/cards.dart';
import '../../widgets/images.dart';
import '../login_page.dart';
import '../radio_details_page.dart';
import 'admin_sections.dart';

// Espace gérant : le gérant choisit sa radio, se connecte, puis règle
// l'affichage de sa page. Chaque gérant ne règle que sa propre radio.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<List<CampusRadio>> _radiosFuture;
  // Radio gérée (null tant qu'il n'est pas connecté à une radio).
  CampusRadio? _radio;
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _radiosFuture = RadioRepository.getRadios();
  }

  // Radio choisie : connexion d'abord, puis on ouvre le tableau de bord.
  Future<void> _choisirRadio(CampusRadio radio) async {
    FocusScope.of(context).unfocus();
    final connecte = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (context) => LoginPage(radio: radio)));
    if (connecte == true && mounted) {
      setState(() => _radio = radio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radio = _radio;
    if (radio != null) {
      return AdminShell(radio: radio, onLogout: () => setState(() => _radio = null));
    }
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cote = Responsive.sidePadding(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Espace gérant')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(cote, AppSpacing.sm, cote, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quelle radio gères-tu ?', style: textes.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choisis-la pour te connecter et personnaliser sa page.',
                  style: textes.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  onChanged: (texte) => setState(() => _recherche = texte.trim().toLowerCase()),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher ma radio…',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CampusRadio>>(
              future: _radiosFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: cote),
                    child: EmptyState(
                      message: 'Impossible de charger les radios.',
                      icon: Icons.wifi_off_rounded,
                      onRetry: () => setState(() => _radiosFuture = RadioRepository.getRadios()),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final radios = snapshot.data!.where((r) => r.name.toLowerCase().contains(_recherche)).toList();
                return ListView.builder(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(cote - 8, 0, cote - 8, MediaQuery.paddingOf(context).bottom + 16),
                  itemCount: radios.length,
                  itemBuilder: (context, i) => ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: RadioLogo(url: radios[i].logoUrl, size: 44, radius: AppRadius.sm),
                    title: Text(radios[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: radios[i].city == null ? null : Text(radios[i].city!),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _choisirRadio(radios[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum AdminSection {
  dashboard('Tableau de bord', 'Accueil', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  apparence('Apparence', 'Apparence', Icons.palette_outlined, Icons.palette_rounded),
  flux('Flux audio', 'Flux', Icons.sensors_outlined, Icons.sensors_rounded);

  const AdminSection(this.label, this.shortLabel, this.icon, this.selectedIcon);

  final String label;
  final String shortLabel; // dans la barre du bas
  final IconData icon;
  final IconData selectedIcon;
}

// Tableau de bord du gérant connecté : barre de navigation en bas + contenu.
// Les réglages modifiés ne sont enregistrés qu'avec le bouton "Enregistrer".
class AdminShell extends StatefulWidget {
  const AdminShell({required this.radio, required this.onLogout, super.key});

  final CampusRadio radio;
  final VoidCallback onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminSection _section = AdminSection.dashboard;

  // Réglages tels qu'enregistrés, et ceux en cours de modification.
  RadioSettings? _enregistres;
  late AdminDraft _brouillon;
  final TextEditingController _siteController = TextEditingController();

  late Future<RadioDetails> _detailsFuture;
  late Future<List<RadioContent>> _contenuFuture;
  Future<RadioPalette>? _apercuFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = RadioRepository.getDetails(widget.radio.id);
    _contenuFuture = _detailsFuture.then((d) => RadioRepository.getContent(d.showSlugs));
    // Pour activer "Enregistrer" pendant la saisie de l'adresse.
    _siteController.addListener(() => setState(() {}));
    _chargerReglages();
  }

  @override
  void dispose() {
    _siteController.dispose();
    super.dispose();
  }

  Future<void> _chargerReglages() async {
    final reglages = await RadioSettingsRepository.load(widget.radio);
    if (!mounted) {
      return;
    }
    setState(() {
      _enregistres = reglages;
      _brouillon = AdminDraft.depuis(reglages);
      _siteController.text = reglages.siteUrl ?? '';
    });
    _majApercu();
  }

  RadioSettings _reglagesEnCours() {
    final site = _siteController.text.trim();
    return RadioSettings(
      radioId: widget.radio.id,
      afficherSite: _brouillon.afficherSite,
      siteUrl: site.isEmpty ? null : site,
      logo: _brouillon.logo,
      couleur: _brouillon.couleur,
      streamUrl: _brouillon.streamUrl,
    );
  }

  bool get _modifie {
    final avant = _enregistres;
    if (avant == null) {
      return false;
    }
    final site = _siteController.text.trim();
    return avant.afficherSite != _brouillon.afficherSite ||
        (avant.siteUrl ?? '') != site ||
        !identical(avant.logo, _brouillon.logo) ||
        avant.couleur != _brouillon.couleur ||
        avant.streamUrl != _brouillon.streamUrl;
  }

  // Une section a changé un réglage : on met à jour le brouillon et l'aperçu.
  void _modifier(AdminDraft brouillon) {
    setState(() => _brouillon = brouillon);
    _majApercu();
  }

  void _majApercu() {
    setState(() {
      _apercuFuture = _detailsFuture
          .then((d) => d.backgroundColor, onError: (Object _) => null)
          .then(
            (couleurApi) =>
                RadioPaletteResolver.resolve(widget.radio, settings: _reglagesEnCours(), couleurApi: couleurApi),
          );
    });
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    final reglages = _reglagesEnCours();
    if (reglages.afficherSite && reglages.siteUrl == null) {
      setState(() => _section = AdminSection.apparence);
      _message("Indique l'adresse de ton site web.");
      return;
    }
    await RadioSettingsRepository.save(reglages);
    if (mounted) {
      setState(() => _enregistres = reglages);
      _message('Réglages enregistrés.');
    }
  }

  void _voirMaPage() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => RadioDetailsPage(radio: widget.radio)));
  }

  // Quitter avec des modifications non enregistrées : on demande d'abord.
  Future<bool> _peutQuitter() async {
    if (!_modifie) {
      return true;
    }
    final quitter = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifications non enregistrées'),
        content: const Text('Si tu quittes maintenant, tes modifications seront perdues.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Quitter')),
          FilledButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Rester')),
        ],
      ),
    );
    return quitter == true;
  }

  Future<void> _deconnexion() async {
    if (await _peutQuitter()) {
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enregistres == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_modifie,
      onPopInvokedWithResult: (aQuitte, _) async {
        if (!aQuitte && await _peutQuitter() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              RadioLogo(url: widget.radio.logoUrl, bytes: _brouillon.logo, size: 36, radius: AppRadius.sm),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_section.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textes.titleMedium),
                    Text(
                      widget.radio.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textes.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<VoidCallback>(
              tooltip: 'Plus',
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _voirMaPage,
                  child: const ListTile(leading: Icon(Icons.visibility_outlined), title: Text('Voir ma page')),
                ),
                PopupMenuItem(
                  value: _deconnexion,
                  child: const ListTile(leading: Icon(Icons.logout_rounded), title: Text('Déconnexion')),
                ),
              ],
            ),
          ],
        ),
        body: _contenu(),
        // Bouton "Enregistrer" flottant, visible seulement s'il y a quelque chose à enregistrer.
        floatingActionButton: AnimatedScale(
          scale: _modifie ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: FloatingActionButton.extended(
            onPressed: _modifie ? _enregistrer : null,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Enregistrer'),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _section.index,
          onDestinationSelected: (i) {
            FocusScope.of(context).unfocus();
            setState(() => _section = AdminSection.values[i]);
          },
          destinations: [
            for (final section in AdminSection.values)
              NavigationDestination(
                icon: Icon(section.icon),
                selectedIcon: Icon(section.selectedIcon),
                label: section.shortLabel,
              ),
          ],
        ),
      ),
    );
  }

  Widget _contenu() {
    final section = switch (_section) {
      AdminSection.dashboard => DashboardSection(
        radio: widget.radio,
        reglages: _reglagesEnCours(),
        detailsFuture: _detailsFuture,
        contenuFuture: _contenuFuture,
        apercuFuture: _apercuFuture,
        onVoirMaPage: _voirMaPage,
      ),
      AdminSection.apparence => AppearanceSection(
        radio: widget.radio,
        brouillon: _brouillon,
        siteController: _siteController,
        apercuFuture: _apercuFuture,
        onChanged: _modifier,
        onMessage: _message,
      ),
      AdminSection.flux => StreamSection(radio: widget.radio, brouillon: _brouillon, onChanged: _modifier),
    };
    // Changement de section en fondu.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(_section), child: section),
    );
  }
}

// Réglages en cours de modification (le texte du site est dans un TextEditingController).
class AdminDraft {
  const AdminDraft({required this.afficherSite, this.logo, this.couleur, this.streamUrl});

  factory AdminDraft.depuis(RadioSettings reglages) => AdminDraft(
    afficherSite: reglages.afficherSite,
    logo: reglages.logo,
    couleur: reglages.couleur,
    streamUrl: reglages.streamUrl,
  );

  final bool afficherSite;
  final Uint8List? logo;
  final Color? couleur;
  final String? streamUrl;

  // copyWith qui permet aussi de remettre une valeur à null.
  AdminDraft copyWith({
    bool? afficherSite,
    Uint8List? Function()? logo,
    Color? Function()? couleur,
    String? Function()? streamUrl,
  }) => AdminDraft(
    afficherSite: afficherSite ?? this.afficherSite,
    logo: logo != null ? logo() : this.logo,
    couleur: couleur != null ? couleur() : this.couleur,
    streamUrl: streamUrl != null ? streamUrl() : this.streamUrl,
  );
}
