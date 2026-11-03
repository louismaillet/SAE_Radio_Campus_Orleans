import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layout/responsive.dart';
import '../models/campus_radio.dart';
import '../models/radio_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/images.dart';
import '../widgets/theme_toggle.dart';
import 'admin/admin_page.dart';
import 'radio_details_page.dart';

// Clé sous laquelle on mémorise la radio choisie (son slug) sur l'appareil.
const String _cleRadioChoisie = 'radio_choisie';

// Accueil : le choix d'une radio du réseau.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<CampusRadio>> _radiosFuture;
  // Logos ajoutés par les gérants (slug -> image).
  Map<String, Uint8List> _logos = {};
  String? _radioParDefaut;
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _charger();
    _chargerLogos();
    _ouvrirRadioMemorisee();
  }

  void _charger() {
    _radiosFuture = RadioRepository.getRadios();
  }

  Future<void> _chargerLogos() async {
    final logos = await RadioSettingsRepository.loadLogos();
    if (mounted) {
      setState(() => _logos = logos);
    }
  }

  // Ouvre l'espace gérant, puis recharge les logos au retour (il a pu en changer).
  Future<void> _ouvrirAdmin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const AdminPage()),
    );
    _chargerLogos();
  }

  // Si une radio a déjà été choisie lors d'une ouverture précédente,
  // on l'ouvre directement (l'accueil reste derrière avec le bouton retour).
  Future<void> _ouvrirRadioMemorisee() async {
    final prefs = await SharedPreferences.getInstance();
    final radioId = prefs.getString(_cleRadioChoisie);
    if (radioId == null) {
      return; // première ouverture : on laisse l'utilisateur choisir
    }
    setState(() => _radioParDefaut = radioId);
    final radios = await _radiosFuture;
    if (!mounted) {
      return;
    }
    for (final radio in radios) {
      if (radio.id == radioId) {
        _openRadio(radio);
        return;
      }
    }
  }

  // L'utilisateur choisit une radio : on propose d'en faire sa radio par défaut
  // (sauf si c'est déjà le cas), puis on l'ouvre.
  Future<void> _choisirRadio(CampusRadio radio) async {
    if (radio.id == _radioParDefaut) {
      _openRadio(radio);
      return;
    }
    final choix = await showDialog<_ChoixRadio>(
      context: context,
      builder: (context) => _DialogueRadioParDefaut(radio: radio, logo: _logos[radio.id]),
    );
    if (choix == null || !mounted) {
      return; // fenêtre fermée sans choisir
    }
    if (choix == _ChoixRadio.parDefaut) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cleRadioChoisie, radio.id);
      setState(() => _radioParDefaut = radio.id);
    }
    if (mounted) {
      _openRadio(radio);
    }
  }

  void _openRadio(CampusRadio radio) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => RadioDetailsPage(radio: radio)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<CampusRadio>>(
        future: _radiosFuture,
        builder: (context, snapshot) {
          final radios = snapshot.data;
          return CustomScrollView(
            slivers: [
              _barreHaut(context),
              ..._sectionRadios(context, radios, erreur: snapshot.hasError),
              SliverContent(
                top: AppSpacing.xxl,
                bottom: AppSpacing.xl,
                sliver: SliverToBoxAdapter(child: _PiedDePage(nombreRadios: radios?.length)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _barreHaut(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final scheme = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 72,
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.graphic_eq_rounded, color: scheme.onPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Radio Campus'),
                  if (!compact) TextSpan(text: ' France', style: TextStyle(color: scheme.primary)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      actions: [
        const ThemeToggleButton(),
        const SizedBox(width: 8),
        if (compact)
          IconButton(
            tooltip: 'Espace gérant',
            onPressed: _ouvrirAdmin,
            icon: const Icon(Icons.admin_panel_settings_outlined),
          )
        else
          OutlinedButton.icon(
            onPressed: _ouvrirAdmin,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('Espace gérant'),
          ),
        SizedBox(width: Responsive.sidePadding(context) - 8),
      ],
    );
  }

  List<Widget> _sectionRadios(BuildContext context, List<CampusRadio>? radios, {required bool erreur}) {
    final recherche = _recherche.toLowerCase();
    final filtrees = (radios ?? [])
        .where((r) =>
            r.name.toLowerCase().contains(recherche) || (r.city ?? '').toLowerCase().contains(recherche))
        .toList();
    const grille = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 220,
      mainAxisExtent: 180,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
    );

    Widget contenu;
    if (erreur) {
      contenu = SliverToBoxAdapter(
        child: EmptyState(
          message: 'Impossible de charger les radios.',
          icon: Icons.wifi_off_rounded,
          onRetry: () => setState(_charger),
        ),
      );
    } else if (radios == null) {
      contenu = SliverGrid(
        gridDelegate: grille,
        delegate: SliverChildBuilderDelegate((context, i) => const Skeleton(), childCount: 10),
      );
    } else if (filtrees.isEmpty) {
      contenu = SliverToBoxAdapter(child: EmptyState(message: 'Aucune radio pour « $_recherche ».'));
    } else {
      contenu = SliverGrid(
        gridDelegate: grille,
        delegate: SliverChildBuilderDelegate(
          (context, i) => RadioCard(
            radio: filtrees[i],
            logo: _logos[filtrees[i].id],
            onTap: () => _choisirRadio(filtrees[i]),
          ),
          childCount: filtrees.length,
        ),
      );
    }

    return [
      SliverContent(
        top: AppSpacing.lg,
        sliver: SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Les radios du réseau',
            subtitle: radios == null ? null : '${radios.length} radios associatives et étudiantes',
            trailing: Responsive.isCompact(context) ? null : SizedBox(width: 280, child: _champRecherche()),
          ),
        ),
      ),
      if (Responsive.isCompact(context))
        SliverContent(
          bottom: AppSpacing.md,
          sliver: SliverToBoxAdapter(child: _champRecherche()),
        ),
      SliverContent(sliver: contenu),
    ];
  }

  Widget _champRecherche() => TextField(
        onChanged: (texte) => setState(() => _recherche = texte.trim()),
        decoration: const InputDecoration(
          hintText: 'Rechercher une radio, une ville…',
          prefixIcon: Icon(Icons.search_rounded),
          isDense: true,
        ),
      );
}

enum _ChoixRadio { ouvrir, parDefaut }

// Fenêtre qui propose de faire de cette radio la radio par défaut.
class _DialogueRadioParDefaut extends StatelessWidget {
  const _DialogueRadioParDefaut({required this.radio, this.logo});

  final CampusRadio radio;
  final Uint8List? logo;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: RadioLogo(url: radio.logoUrl, bytes: logo, size: 72),
      title: Text(radio.name, textAlign: TextAlign.center),
      content: const Text(
        'Voulez-vous en faire votre radio par défaut ?\n'
        'Elle s\'ouvrira directement au prochain lancement.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ChoixRadio.ouvrir),
          child: const Text('Juste écouter'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ChoixRadio.parDefaut),
          child: const Text('Radio par défaut'),
        ),
      ],
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
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Radio Campus France · ${nombreRadios ?? 'Les'} radios du réseau, en direct et en podcast',
          textAlign: TextAlign.center,
          style: style,
        ),
      ],
    );
  }
}
