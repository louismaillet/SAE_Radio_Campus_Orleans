import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../layout/responsive.dart';
import '../../models/campus_radio.dart';
import '../../models/radio_settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/radio_palette.dart';
import '../../widgets/glass.dart';
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

  @override
  void initState() {
    super.initState();
    _radiosFuture = RadioRepository.getRadios();
  }

  // Radio choisie : connexion d'abord, puis on ouvre le tableau de bord.
  Future<void> _choisirRadio(CampusRadio radio) async {
    final connecte = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => LoginPage(radio: radio)),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Espace gérant')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Glass(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 48, color: scheme.primary),
                  const SizedBox(height: AppSpacing.md),
                  Text('Gérer ma radio', textAlign: TextAlign.center, style: textes.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Choisis la radio que tu gères pour personnaliser sa page.',
                    textAlign: TextAlign.center,
                    style: textes.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FutureBuilder<List<CampusRadio>>(
                    future: _radiosFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return LayoutBuilder(
                        builder: (context, contraintes) => DropdownMenu<CampusRadio>(
                          width: contraintes.maxWidth,
                          hintText: 'Rechercher ma radio…',
                          enableFilter: true,
                          requestFocusOnTap: true,
                          leadingIcon: const Icon(Icons.search_rounded),
                          menuHeight: 320,
                          onSelected: (radio) {
                            if (radio != null) {
                              _choisirRadio(radio);
                            }
                          },
                          dropdownMenuEntries: [
                            for (final radio in snapshot.data!)
                              DropdownMenuEntry(value: radio, label: radio.name),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum AdminSection {
  dashboard('Tableau de bord', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  apparence('Apparence', Icons.palette_outlined, Icons.palette_rounded),
  flux('Flux audio', Icons.sensors_outlined, Icons.sensors_rounded);

  const AdminSection(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

// Tableau de bord du gérant connecté : barre latérale rétractable + contenu.
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
  bool _replie = false; // barre latérale réduite aux icônes

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
    // Pour afficher "Modifications non enregistrées" pendant la saisie de l'adresse.
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
          .then((couleurApi) => RadioPaletteResolver.resolve(
                widget.radio,
                settings: _reglagesEnCours(),
                couleurApi: couleurApi,
              ));
    });
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _enregistrer() async {
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => RadioDetailsPage(radio: widget.radio)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_enregistres == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final compact = Responsive.isCompact(context);
    final contenu = _contenu();

    if (compact) {
      return Scaffold(
        appBar: AppBar(title: Text(_section.label), actions: [_boutonEnregistrer(), const SizedBox(width: 8)]),
        drawer: Drawer(child: _sidebar(replie: false, dansDrawer: true)),
        body: contenu,
      );
    }
    return Scaffold(
      body: Row(
        children: [
          _sidebar(replie: _replie),
          Expanded(
            child: Column(
              children: [
                _barreHaut(),
                Expanded(child: contenu),
              ],
            ),
          ),
        ],
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
      AdminSection.flux => StreamSection(
          radio: widget.radio,
          brouillon: _brouillon,
          onChanged: _modifier,
        ),
    };
    // Changement de section en fondu.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(_section), child: section),
    );
  }

  Widget _barreHaut() {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35))),
      ),
      child: Row(
        children: [
          Text(_section.label, style: textes.headlineSmall),
          const Spacer(),
          AnimatedOpacity(
            opacity: _modifie ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: scheme.tertiary),
                const SizedBox(width: 8),
                Text('Modifications non enregistrées', style: textes.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(width: AppSpacing.md),
              ],
            ),
          ),
          _boutonEnregistrer(),
        ],
      ),
    );
  }

  Widget _boutonEnregistrer() {
    // Sur téléphone, juste l'icône pour laisser la place au titre.
    if (Responsive.isCompact(context)) {
      return IconButton.filled(
        tooltip: 'Enregistrer',
        onPressed: _modifie ? _enregistrer : null,
        icon: const Icon(Icons.save_rounded),
      );
    }
    return FilledButton.icon(
      onPressed: _modifie ? _enregistrer : null,
      icon: const Icon(Icons.save_rounded, size: 18),
      label: const Text('Enregistrer'),
    );
  }

  Widget _sidebar({required bool replie, bool dansDrawer = false}) {
    final scheme = Theme.of(context).colorScheme;
    final textes = Theme.of(context).textTheme;

    Widget item(IconData icone, String label, VoidCallback onTap, {bool actif = false}) {
      final contenu = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: replie ? 0 : 14),
        decoration: BoxDecoration(
          color: actif ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: replie ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icone, color: actif ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            if (!replie) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: textes.labelLarge!.copyWith(
                    color: actif ? scheme.onPrimaryContainer : scheme.onSurface,
                    fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: replie ? label : '',
          child: InkWell(borderRadius: BorderRadius.circular(AppRadius.md), onTap: onTap, child: contenu),
        ),
      );
    }

    void aller(AdminSection section) {
      setState(() => _section = section);
      if (dansDrawer) {
        Navigator.of(context).pop(); // ferme le menu
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: dansDrawer ? null : (replie ? 84 : 264),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête : la radio gérée.
            SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: replie ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  _LogoGere(radio: widget.radio, logo: _brouillon.logo),
                  if (!replie) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.radio.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textes.titleSmall!.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text('Espace gérant', style: textes.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final section in AdminSection.values)
              item(
                _section == section ? section.selectedIcon : section.icon,
                section.label,
                () => aller(section),
                actif: _section == section,
              ),
            const Spacer(),
            item(Icons.open_in_new_rounded, 'Voir ma page', _voirMaPage),
            item(Icons.logout_rounded, 'Déconnexion', widget.onLogout),
            if (!dansDrawer) ...[
              const Divider(height: AppSpacing.lg),
              item(
                replie ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded,
                'Réduire le menu',
                () => setState(() => _replie = !_replie),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LogoGere extends StatelessWidget {
  const _LogoGere({required this.radio, this.logo});

  final CampusRadio radio;
  final Uint8List? logo;

  @override
  Widget build(BuildContext context) => RadioLogo(url: radio.logoUrl, bytes: logo, size: 44, radius: AppRadius.sm);
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
  }) =>
      AdminDraft(
        afficherSite: afficherSite ?? this.afficherSite,
        logo: logo != null ? logo() : this.logo,
        couleur: couleur != null ? couleur() : this.couleur,
        streamUrl: streamUrl != null ? streamUrl() : this.streamUrl,
      );
}
