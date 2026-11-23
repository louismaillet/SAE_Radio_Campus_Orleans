import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../layout/responsive.dart';
import '../models/campus_radio.dart';
import '../models/radio_settings.dart';
import '../services/radio_choisie.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/images.dart';
import '../widgets/theme_toggle.dart';
import 'admin/admin_page.dart';
import 'radio_details_page.dart';

// Onglet « Explorer l'Univers Radio·s Campus » : toutes les radios du réseau.
class ExplorerPage extends StatefulWidget {
  const ExplorerPage({required this.radios, required this.onRafraichir, super.key});

  final Future<List<CampusRadio>> radios;
  // Recharge la liste des radios (chargée une seule fois par HomePage).
  final Future<void> Function() onRafraichir;

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  // Logos ajoutés par les gérants (slug -> image).
  Map<String, Uint8List> _logos = {};
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _chargerLogos();
  }

  // Tirer la liste vers le bas : on recharge les radios et les logos.
  Future<void> _rafraichir() async {
    await Future.wait([widget.onRafraichir(), _chargerLogos()]);
  }

  Future<void> _chargerLogos() async {
    final logos = await RadioSettingsRepository.loadLogos();
    if (mounted) {
      setState(() => _logos = logos);
    }
  }

  // Ouvre l'espace gérant, puis recharge les logos au retour (il a pu en changer).
  Future<void> _ouvrirAdmin() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const AdminPage()));
    _chargerLogos();
  }

  // L'utilisateur choisit une radio : on propose d'en faire sa radio par défaut
  // (sauf si le choix a déjà été fait, ici ou sur la carte). Par défaut : elle
  // s'affiche dans l'onglet Accueil ; sinon on l'ouvre par-dessus Explorer.
  Future<void> _choisirRadio(CampusRadio radio) async {
    FocusScope.of(context).unfocus(); // ferme le clavier de la recherche
    if (RadioChoisie.courante.value != null) {
      _openRadio(radio);
      return;
    }
    final choix = await showModalBottomSheet<_ChoixRadio>(
      context: context,
      showDragHandle: true,
      // La feuille prend la hauteur de son contenu (et défile sur les petits écrans).
      isScrollControlled: true,
      builder: (context) => _FeuilleRadioParDefaut(radio: radio, logo: _logos[radio.id]),
    );
    if (choix == null || !mounted) {
      return; // feuille fermée sans choisir
    }
    if (choix == _ChoixRadio.parDefaut) {
      // L'écran principal bascule sur l'onglet Accueil, qui affiche cette radio.
      await RadioChoisie.enregistrer(radio.id);
      return;
    }
    if (mounted) {
      _openRadio(radio);
    }
  }

  void _openRadio(CampusRadio radio) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => RadioDetailsPage(radio: radio)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<CampusRadio>>(
        future: widget.radios,
        builder: (context, snapshot) {
          final radios = snapshot.data;
          return RefreshIndicator(
            onRefresh: _rafraichir,
            edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight + 64,
            child: CustomScrollView(
              // Faire défiler la liste ferme le clavier.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _barreHaut(context),
                ..._sectionRadios(context, radios, erreur: snapshot.hasError),
                SliverSafeArea(
                  top: false,
                  sliver: SliverContent(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.lg,
                    sliver: SliverToBoxAdapter(child: _PiedDePage(nombreRadios: radios?.length)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _barreHaut(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      titleSpacing: Responsive.sidePadding(context),
      backgroundColor: Colors.transparent,
      // Verre dépoli : le contenu passe flouté sous la barre.
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: ColoredBox(color: scheme.surface.withValues(alpha: 0.7), child: const SizedBox.expand()),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.graphic_eq_rounded, color: scheme.onPrimary, size: 20),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Radio Campus',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      actions: [
        const ThemeToggleButton(),
        IconButton(
          tooltip: 'Espace gérant',
          onPressed: _ouvrirAdmin,
          icon: const Icon(Icons.admin_panel_settings_outlined),
        ),
        SizedBox(width: Responsive.sidePadding(context) - 12),
      ],
      // Recherche toujours visible sous le titre.
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: EdgeInsets.fromLTRB(Responsive.sidePadding(context), 0, Responsive.sidePadding(context), 12),
          child: _champRecherche(),
        ),
      ),
    );
  }

  List<Widget> _sectionRadios(BuildContext context, List<CampusRadio>? radios, {required bool erreur}) {
    final recherche = _recherche.toLowerCase();
    final filtrees = (radios ?? [])
        .where((r) => r.name.toLowerCase().contains(recherche) || (r.city ?? '').toLowerCase().contains(recherche))
        .toList();
    // 2 colonnes sur téléphone, 3 sur tablette.
    final grille = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: Responsive.isTablet(context) ? 3 : 2,
      mainAxisExtent: 168,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
    );

    Widget contenu;
    if (erreur) {
      contenu = SliverToBoxAdapter(
        child: EmptyState(
          message: 'Impossible de charger les radios.',
          icon: Icons.wifi_off_rounded,
          onRetry: widget.onRafraichir,
        ),
      );
    } else if (radios == null) {
      contenu = SliverGrid(
        gridDelegate: grille,
        delegate: SliverChildBuilderDelegate((context, i) => const Skeleton(), childCount: 8),
      );
    } else if (filtrees.isEmpty) {
      contenu = SliverToBoxAdapter(child: EmptyState(message: 'Aucune radio pour « $_recherche ».'));
    } else {
      contenu = SliverGrid(
        gridDelegate: grille,
        delegate: SliverChildBuilderDelegate(
          (context, i) =>
              RadioCard(radio: filtrees[i], logo: _logos[filtrees[i].id], onTap: () => _choisirRadio(filtrees[i])),
          childCount: filtrees.length,
        ),
      );
    }

    return [
      SliverContent(
        top: AppSpacing.md,
        sliver: SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Les radios du réseau',
            subtitle: radios == null ? null : '${radios.length} radios associatives et étudiantes',
          ),
        ),
      ),
      SliverContent(sliver: contenu),
    ];
  }

  Widget _champRecherche() => TextField(
    onChanged: (texte) => setState(() => _recherche = texte.trim()),
    textInputAction: TextInputAction.search,
    decoration: const InputDecoration(
      hintText: 'Rechercher une radio, une ville…',
      prefixIcon: Icon(Icons.search_rounded),
      isDense: true,
    ),
  );
}

enum _ChoixRadio { ouvrir, parDefaut }

// Feuille du bas qui propose de faire de cette radio la radio par défaut.
class _FeuilleRadioParDefaut extends StatelessWidget {
  const _FeuilleRadioParDefaut({required this.radio, this.logo});

  final CampusRadio radio;
  final Uint8List? logo;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: RadioLogo(url: radio.logoUrl, bytes: logo, size: 72),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(radio.name, textAlign: TextAlign.center, style: textes.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'En faire votre radio par défaut ?\nElle s\'ouvrira directement au prochain lancement.',
              textAlign: TextAlign.center,
              style: textes.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_ChoixRadio.parDefaut),
              child: const Text('Radio par défaut'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(_ChoixRadio.ouvrir),
              child: const Text('Juste écouter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PiedDePage extends StatelessWidget {
  const _PiedDePage({this.nombreRadios});

  final int? nombreRadios;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant);
    return Text(
      'Radio Campus France · ${nombreRadios ?? 'Les'} radios du réseau, en direct et en podcast',
      textAlign: TextAlign.center,
      style: style,
    );
  }
}
