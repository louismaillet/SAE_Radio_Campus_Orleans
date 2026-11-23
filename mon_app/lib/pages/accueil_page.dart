import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/campus_radio.dart';
import '../services/localisateur.dart';
import '../services/radio_choisie.dart';
import '../theme/app_theme.dart';
import '../villes/villes.dart';
import '../widgets/cards.dart';
import '../widgets/carte_villes.dart';
import '../widgets/theme_toggle.dart';
import 'admin/admin_page.dart';
import 'radio_details_page.dart';

// Onglet Accueil : l'utilisateur choisit sa ville (recherche, position, carte ou
// raccourci) pour arriver sur sa radio locale. La carte occupe tout l'écran ;
// la recherche flotte en haut, le reste est dans un panneau qu'on tire vers le haut.
class AccueilPage extends StatefulWidget {
  const AccueilPage({
    required this.radios,
    required this.onReessayer,
    this.localisateur = const LocalisateurGeolocator(),
    super.key,
  });

  final Future<List<CampusRadio>> radios;
  final VoidCallback onReessayer;
  final Localisateur localisateur;

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  // Tailles du panneau du bas (fraction de la hauteur).
  static const _panneauMin = 0.16;
  static const _panneauInitial = 0.32;
  static const _panneauChoix = 0.42;
  static const _hauteurBarre = 56.0;

  final TextEditingController _champ = TextEditingController();
  final DraggableScrollableController _panneau = DraggableScrollableController();
  String _recherche = '';
  VilleRadio? _selection;
  double? _distanceKm; // renseignée quand la ville vient de la géolocalisation
  bool _localisationEnCours = false;
  String? _messagePosition;

  @override
  void dispose() {
    _champ.dispose();
    _panneau.dispose();
    super.dispose();
  }

  void _choisirVille(VilleRadio ville, {double? km}) {
    FocusScope.of(context).unfocus();
    _champ.clear();
    setState(() {
      _recherche = '';
      _selection = ville;
      _distanceKm = km;
      _messagePosition = null;
    });
    // On ouvre un peu le panneau pour montrer la confirmation.
    if (_panneau.isAttached && _panneau.size < _panneauChoix) {
      _panneau.animateTo(_panneauChoix, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _utiliserPosition(List<VilleRadio> villes) async {
    setState(() {
      _localisationEnCours = true;
      _messagePosition = null;
    });
    final resultat = await widget.localisateur.position();
    if (!mounted) return;
    setState(() => _localisationEnCours = false);
    switch (resultat) {
      case PositionTrouvee(:final position):
        final proche = plusProche(villes, position);
        if (proche != null) {
          _choisirVille(proche.ville, km: proche.km);
        }
      case PositionRefusee():
        setState(() => _messagePosition = 'Position refusée. Choisis ta ville sur la carte ou avec la recherche.');
      case PositionIndisponible():
        setState(
          () => _messagePosition = "Impossible d'obtenir ta position. Choisis ta ville sur la carte ou avec la recherche.",
        );
    }
  }

  // Une fois le choix fait (radio par défaut ou non), la carte ne sert plus :
  // la page de la radio s'ouvre, et le retour mène à la mosaïque Explorer.
  Future<void> _ouvrir(CampusRadio radio, {required bool parDefaut}) async {
    // Le navigateur est pris avant : l'onglet Accueil disparaît dès que le choix est fait.
    final navigateur = Navigator.of(context);
    if (parDefaut) {
      await RadioChoisie.enregistrer(radio.id);
    } else {
      await RadioChoisie.terminerChoix();
    }
    navigateur.push(MaterialPageRoute<void>(builder: (context) => RadioDetailsPage(radio: radio)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusRadio>>(
      future: widget.radios,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SafeArea(
            child: Column(
              children: [
                _barreRecherche(context, actif: false),
                Expanded(
                  child: Center(
                    child: EmptyState(
                      message: 'Impossible de charger les radios.',
                      icon: Icons.wifi_off_rounded,
                      onRetry: widget.onReessayer,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final radios = snapshot.data;
        if (radios == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final villes = villesDuReseau(radios);
        return LayoutBuilder(
          builder: (context, contraintes) {
            final hauteur = contraintes.maxHeight;
            final haut = MediaQuery.paddingOf(context).top + 12 + _hauteurBarre;
            return Stack(
              children: [
                Positioned.fill(
                  child: CarteVilles(
                    villes: villes,
                    selection: _selection,
                    onChoisir: _choisirVille,
                    margeHaut: haut,
                    margeBas: hauteur * _panneauChoix,
                    margeAttribution: hauteur * _panneauInitial,
                  ),
                ),
                _panneauBas(context, villes),
                // Recherche et suggestions, au-dessus de tout le reste.
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _barreRecherche(context, actif: true),
                        _suggestions(context, villes, hauteurMax: math.max(0, hauteur - haut - 24)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Barre flottante : recherche, thème et espace gérant.
  Widget _barreRecherche(BuildContext context, {required bool actif}) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 4,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: _hauteurBarre,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _champ,
                enabled: actif,
                onChanged: (texte) => setState(() => _recherche = texte),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Rechercher une ville…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
              ),
            ),
            if (_recherche.isNotEmpty)
              IconButton(
                tooltip: 'Effacer',
                onPressed: () {
                  _champ.clear();
                  setState(() => _recherche = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
            const ThemeToggleButton(),
            IconButton(
              tooltip: 'Espace gérant',
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const AdminPage())),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _suggestions(BuildContext context, List<VilleRadio> villes, {required double hauteurMax}) {
    if (_recherche.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final trouvees = rechercherVilles(villes, _recherche).take(6).toList();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 4,
        shadowColor: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          // La liste défile si le clavier laisse peu de place.
          constraints: BoxConstraints(maxHeight: hauteurMax),
          child: trouvees.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('Pas de radio à « ${_recherche.trim()} ». Essaie la carte ou ta position.'),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  children: [
                    for (final ville in trouvees)
                      ListTile(
                        minTileHeight: 56,
                        leading: Icon(Icons.location_on_rounded, color: scheme.primary),
                        title: Text(ville.nom),
                        subtitle: Text(ville.radios.map((r) => r.name).join(', ')),
                        onTap: () => _choisirVille(ville),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _panneauBas(BuildContext context, List<VilleRadio> villes) {
    final scheme = Theme.of(context).colorScheme;
    final textes = Theme.of(context).textTheme;
    final lointaines = villes.where((v) => villesLointaines.contains(v.nom)).toList();
    return DraggableScrollableSheet(
      controller: _panneau,
      initialChildSize: _panneauInitial,
      minChildSize: _panneauMin,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [_panneauInitial, _panneauChoix],
      builder: (context, defilement) => Material(
        color: scheme.surface,
        elevation: 8,
        shadowColor: Colors.black54,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          controller: defilement,
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poignée.
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Quelle est ta ville ?', style: textes.titleLarge!.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _localisationEnCours ? null : () => _utiliserPosition(villes),
                icon: _localisationEnCours
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded),
                label: const Text('Utiliser ma position'),
              ),
              if (_messagePosition != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(_messagePosition!, style: textes.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
                ),
              if (_selection != null) _confirmation(context, _selection!),
              if (lointaines.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Outre-mer et étranger', style: textes.titleSmall!.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final ville in lointaines)
                      ActionChip(
                        avatar: const Icon(Icons.public_rounded, size: 18),
                        label: Text(ville.nom.split(' - ').last),
                        onPressed: () => _choisirVille(ville),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirmation(BuildContext context, VilleRadio ville) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final km = _distanceKm;
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded, color: scheme.onSecondaryContainer),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    km == null ? ville.nom : '${ville.nom} · à ${km.round()} km',
                    style: textes.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            for (final radio in ville.radios) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                radio.name,
                style: textes.bodyLarge!.copyWith(fontWeight: FontWeight.w600, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'En faire ta radio par défaut ? Elle s\'ouvrira directement au prochain lancement.',
                style: textes.bodyMedium!.copyWith(color: scheme.onSecondaryContainer),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => _ouvrir(radio, parDefaut: false),
                      child: const Text('Non'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => _ouvrir(radio, parDefaut: true),
                      child: const Text('Radio par défaut'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
