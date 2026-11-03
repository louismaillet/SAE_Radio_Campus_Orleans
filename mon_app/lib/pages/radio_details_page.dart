import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_all/webview_all.dart';

import '../layout/responsive.dart';
import '../models/campus_radio.dart';
import '../models/radio_settings.dart';
import '../player/player_controller.dart';
import '../theme/app_theme.dart';
import '../theme/radio_palette.dart';
import '../widgets/cards.dart';
import '../widgets/glass.dart';
import '../widgets/images.dart';
import '../widgets/live.dart';
import '../widgets/theme_toggle.dart';

// Ce qu'il faut pour afficher la page : réglages du gérant et détail de l'API.
class _Donnees {
  const _Donnees(this.reglages, this.details);

  final RadioSettings reglages;
  final RadioDetails? details; // null si l'API n'a pas répondu (mode site seulement)
}

// Page d'une radio. Toute la page prend les couleurs de la radio :
// on affiche d'abord une couleur immédiate (gérant ou API), puis on passe
// en fondu à la couleur extraite du logo dès qu'elle est calculée.
//
// Selon le choix du gérant : on affiche le site web de la radio,
// ou sa description depuis l'API, avec ses émissions, podcasts et les actualités.
class RadioDetailsPage extends StatefulWidget {
  const RadioDetailsPage({required this.radio, super.key});
  final CampusRadio radio;

  @override
  State<RadioDetailsPage> createState() => _RadioDetailsPageState();
}

class _RadioDetailsPageState extends State<RadioDetailsPage> {
  late Future<_Donnees> _future;
  late RadioPalette _palette = RadioPaletteResolver.immediate(widget.radio);

  @override
  void initState() {
    super.initState();
    _future = _charger();
  }

  // Le site s'affiche si le gérant l'a choisi et a donné son adresse.
  bool _ouvreLeSite(RadioSettings reglages) {
    return reglages.afficherSite && reglages.siteUrl != null;
  }

  Future<_Donnees> _charger() async {
    final reglages = await RadioSettingsRepository.load(widget.radio);
    RadioDetails? details;
    try {
      details = await RadioRepository.getDetails(widget.radio.id);
    } catch (_) {
      // En mode site, le détail ne sert qu'aux couleurs : on peut s'en passer.
      if (!_ouvreLeSite(reglages)) {
        rethrow;
      }
    }
    if (mounted) {
      setState(() {
        _palette = RadioPaletteResolver.immediate(
          widget.radio,
          settings: reglages,
          couleurApi: details?.backgroundColor,
        );
      });
    }
    _resoudrePalette(reglages, details);
    return _Donnees(reglages, details);
  }

  // Couleur extraite du logo (peut prendre un moment, ou échouer sur le web).
  Future<void> _resoudrePalette(RadioSettings reglages, RadioDetails? details) async {
    final palette = await RadioPaletteResolver.resolve(
      widget.radio,
      settings: reglages,
      couleurApi: details?.backgroundColor,
    );
    if (mounted && palette.seed != _palette.seed) {
      setState(() => _palette = palette);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // AnimatedTheme fait passer en douceur toutes les couleurs de la page.
    return AnimatedTheme(
      data: _palette.theme(brightness),
      duration: const Duration(milliseconds: 800),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(gradient: _palette.fond(brightness)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: FutureBuilder<_Donnees>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Erreur(onRetry: () => setState(() => _future = _charger()));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final donnees = snapshot.data!;
              if (_ouvreLeSite(donnees.reglages)) {
                return _WebsiteView(radio: widget.radio, donnees: donnees, palette: _palette);
              }
              return _ContentView(radio: widget.radio, donnees: donnees, palette: _palette);
            },
          ),
        ),
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  const _Erreur({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Align(alignment: Alignment.centerLeft, child: BackButton()),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EmptyState(
                  message: 'Impossible de charger cette radio.',
                  icon: Icons.wifi_off_rounded,
                  onRetry: onRetry,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Morceau "direct" de la radio pour le lecteur, ou null si elle n'a pas de flux.
PlayerTrack? _trackDirect(CampusRadio radio, _Donnees donnees, RadioPalette palette) {
  final flux = donnees.reglages.fluxDirect(radio);
  if (flux == null) {
    return null;
  }
  return PlayerTrack(
    url: flux,
    title: radio.name,
    subtitle: donnees.details?.catchPhrase ?? 'En direct',
    isLive: true,
    artworkUrl: radio.logoUrl,
    artworkBytes: donnees.reglages.logo,
    accent: palette.seed,
  );
}

// Grand en-tête : logo avec halo, nom, slogan et bouton du direct.
class _EnTete extends StatelessWidget {
  const _EnTete({required this.radio, required this.donnees, required this.palette, this.dense = false});

  final CampusRadio radio;
  final _Donnees donnees;
  final RadioPalette palette;
  final bool dense; // version réduite au-dessus du site web

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final compact = Responsive.isCompact(context);
    final centre = compact && !dense;
    final track = _trackDirect(radio, donnees, palette);
    final slogan = donnees.details?.catchPhrase;
    final tailleLogo = dense ? 64.0 : (compact ? 120.0 : 168.0);

    final logo = Hero(
      tag: 'logo-${radio.id}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tailleLogo * 0.28),
          boxShadow: palette.halo(dense ? 0.6 : 1.2),
        ),
        child: RadioLogo(url: radio.logoUrl, bytes: donnees.reglages.logo, size: tailleLogo),
      ),
    );

    final infos = Column(
      crossAxisAlignment: centre ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          [if (radio.city != null) radio.city!, 'Réseau Radio Campus'].join(' · ').toUpperCase(),
          style: textes.labelMedium!.copyWith(color: scheme.primary, letterSpacing: 1.4, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          radio.name,
          textAlign: centre ? TextAlign.center : TextAlign.start,
          style: dense
              ? textes.headlineSmall
              : (compact ? textes.headlineLarge : textes.displayMedium)!.copyWith(height: 1.05),
        ),
        if (slogan != null && slogan.isNotEmpty && !dense) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            slogan,
            textAlign: centre ? TextAlign.center : TextAlign.start,
            style: textes.titleMedium!.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
          ),
        ],
        if (track != null && !dense) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiveButton(track: track, large: !compact),
              const SizedBox(width: AppSpacing.md),
              if (!compact) const LiveBadge(),
            ],
          ),
        ],
      ],
    );

    if (centre) {
      return Column(children: [logo, const SizedBox(height: AppSpacing.lg), infos]);
    }
    return Row(
      children: [
        logo,
        SizedBox(width: dense ? AppSpacing.md : AppSpacing.xl),
        Expanded(child: infos),
        if (dense && track != null) LiveButton(track: track, large: false),
      ],
    );
  }
}

// Barre du haut en verre : retour + bouton thème.
class _BarreHaut extends StatelessWidget {
  const _BarreHaut({required this.titre});

  final String titre;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      title: Text(titre),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      actions: const [ThemeToggleButton(), SizedBox(width: 8)],
    );
  }
}

// Radio avec site web : en-tête réduit puis le site dans une webview.
class _WebsiteView extends StatefulWidget {
  const _WebsiteView({required this.radio, required this.donnees, required this.palette});
  final CampusRadio radio;
  final _Donnees donnees;
  final RadioPalette palette;

  @override
  State<_WebsiteView> createState() => _WebsiteViewState();
}

class _WebsiteViewState extends State<_WebsiteView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // javascriptMode pour que le site web fonctionne correctement
      ..loadRequest(Uri.parse(widget.donnees.reglages.siteUrl!));
  }

  @override
  Widget build(BuildContext context) {
    final cote = Responsive.isCompact(context) ? AppSpacing.sm : AppSpacing.lg;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(cote, AppSpacing.sm, cote, AppSpacing.md),
            child: Glass(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _EnTete(
                      radio: widget.radio,
                      donnees: widget.donnees,
                      palette: widget.palette,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(cote, 0, cote, cote),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: WebViewWidget(controller: _controller),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Radio sans site web : présentation, émissions, podcasts et actualités.
class _ContentView extends StatefulWidget {
  const _ContentView({required this.radio, required this.donnees, required this.palette});
  final CampusRadio radio;
  final _Donnees donnees;
  final RadioPalette palette;

  @override
  State<_ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<_ContentView> {
  late Future<List<RadioContent>> _contentFuture;
  String? _emissionChoisie; // filtre des podcasts (null = toutes)
  int _nombrePodcasts = 12;

  RadioDetails get _details => widget.donnees.details!;

  @override
  void initState() {
    super.initState();
    _contentFuture = RadioRepository.getContent(_details.showSlugs);
  }

  @override
  Widget build(BuildContext context) {
    final expanded = Responsive.isExpanded(context);
    final description = _details.description;
    final aDescription = description != null && description.trim().isNotEmpty;

    final presentation = <Widget>[
      if (aDescription) _Description(html: description),
      _CarteInfos(radio: widget.radio, details: _details),
    ];

    return FutureBuilder<List<RadioContent>>(
      future: _contentFuture,
      builder: (context, snapshot) {
        // On sépare les podcasts et les actualités.
        final podcasts = <RadioContent>[];
        final news = <RadioContent>[];
        for (final item in snapshot.data ?? <RadioContent>[]) {
          if (item.type == RadioContentType.podcast) {
            if (_emissionChoisie == null || item.showSlug == _emissionChoisie) {
              podcasts.add(item);
            }
          } else {
            news.add(item);
          }
        }

        return CustomScrollView(
          slivers: [
            _BarreHaut(titre: widget.radio.name),
            SliverContent(
              top: AppSpacing.lg,
              sliver: SliverToBoxAdapter(
                child: _EnTete(radio: widget.radio, donnees: widget.donnees, palette: widget.palette),
              ),
            ),
            // Présentation + infos : côte à côte sur grand écran, l'une sous l'autre sinon.
            SliverContent(
              top: AppSpacing.xxl,
              sliver: SliverToBoxAdapter(
                child: expanded && aDescription
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: presentation[0]),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(flex: 2, child: presentation[1]),
                        ],
                      )
                    : Column(
                        children: [
                          for (final bloc in presentation) ...[bloc, const SizedBox(height: AppSpacing.lg)],
                        ],
                      ),
              ),
            ),
            if (_details.shows.isNotEmpty) ...[
              const SliverContent(
                top: AppSpacing.xxl,
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(title: 'Émissions', subtitle: 'Touchez une émission pour filtrer ses podcasts'),
                ),
              ),
              SliverToBoxAdapter(child: _ListeEmissions(
                shows: _details.shows,
                choisie: _emissionChoisie,
                onChanged: (slug) => setState(() {
                  _emissionChoisie = slug;
                  _nombrePodcasts = 12;
                }),
              )),
            ],
            const SliverContent(
              top: AppSpacing.xxl,
              sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Podcasts')),
            ),
            ..._grillePodcasts(snapshot, podcasts),
            const SliverContent(
              top: AppSpacing.xxl,
              sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Actualités du réseau')),
            ),
            SliverContent(
              bottom: AppSpacing.xxl,
              sliver: news.isEmpty
                  ? SliverToBoxAdapter(
                      child: snapshot.hasData
                          ? const EmptyState(message: 'Aucune actualité pour le moment.')
                          : const Skeleton(height: 112),
                    )
                  : SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 640,
                        mainAxisExtent: 112,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => NewsCard(news: news[i]),
                        childCount: news.length,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _grillePodcasts(AsyncSnapshot<List<RadioContent>> snapshot, List<RadioContent> podcasts) {
    const grille = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 300,
      mainAxisExtent: 310,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
    );
    if (snapshot.hasError) {
      return [
        SliverContent(
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              message: 'Podcasts indisponibles.',
              onRetry: () => setState(() => _contentFuture = RadioRepository.getContent(_details.showSlugs)),
            ),
          ),
        ),
      ];
    }
    if (!snapshot.hasData) {
      return [
        SliverContent(
          sliver: SliverGrid(
            gridDelegate: grille,
            delegate: SliverChildBuilderDelegate((context, i) => const Skeleton(), childCount: 4),
          ),
        ),
      ];
    }
    if (podcasts.isEmpty) {
      return [
        const SliverContent(
          sliver: SliverToBoxAdapter(child: EmptyState(message: 'Aucun contenu pour le moment.')),
        ),
      ];
    }
    final affiches = podcasts.take(_nombrePodcasts).toList();
    return [
      SliverContent(
        sliver: SliverGrid(
          gridDelegate: grille,
          delegate: SliverChildBuilderDelegate(
            (context, i) => PodcastCard(
              podcast: affiches[i],
              radioName: widget.radio.name,
              accent: widget.palette.seed,
            ),
            childCount: affiches.length,
          ),
        ),
      ),
      if (podcasts.length > affiches.length)
        SliverContent(
          top: AppSpacing.lg,
          sliver: SliverToBoxAdapter(
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _nombrePodcasts += 12),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text('Voir plus (${podcasts.length - affiches.length})'),
              ),
            ),
          ),
        ),
    ];
  }
}

// Description HTML de la radio, repliée au-delà d'une certaine hauteur.
class _Description extends StatefulWidget {
  const _Description({required this.html});

  final String html;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _deplie = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texte = Html(
      data: widget.html,
      style: {
        'body': Style(
          margin: Margins.zero,
          color: scheme.onSurface,
          fontSize: FontSize(15),
          lineHeight: const LineHeight(1.6),
        ),
        'strong': Style(color: scheme.primary),
        'a': Style(color: scheme.primary),
      },
    );
    return Glass(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('À propos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _deplie
                ? texte
                : ShaderMask(
                    // Le bas du texte s'efface pour inviter à "lire la suite".
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.transparent],
                      stops: [0.6, 1],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ClipRect(child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: texte,
                      )),
                    ),
                  ),
          ),
          TextButton(
            onPressed: () => setState(() => _deplie = !_deplie),
            child: Text(_deplie ? 'Réduire' : 'Lire la suite'),
          ),
        ],
      ),
    );
  }
}

// Infos pratiques : ville, adresse, contact, nombre d'émissions.
class _CarteInfos extends StatelessWidget {
  const _CarteInfos({required this.radio, required this.details});

  final CampusRadio radio;
  final RadioDetails details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textes = Theme.of(context).textTheme;
    Widget ligne(IconData icone, String titre, String valeur) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icone, size: 18, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: textes.labelSmall!.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(valeur, style: textes.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        );

    return Glass(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Infos', style: textes.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          if (radio.city != null) ligne(Icons.location_city_rounded, 'Ville', radio.city!),
          if (details.address != null) ligne(Icons.place_outlined, 'Adresse', details.address!),
          if (details.email != null) ligne(Icons.mail_outline_rounded, 'Contact', details.email!),
          ligne(Icons.mic_none_rounded, 'Émissions', '${details.shows.length} à la grille'),
          ligne(
            Icons.sensors_rounded,
            'Direct',
            radio.streamUrl != null ? 'Disponible 24h/24' : 'Pas de flux direct',
          ),
        ],
      ),
    );
  }
}

// Émissions de la radio en bande horizontale : un appui filtre les podcasts.
class _ListeEmissions extends StatelessWidget {
  const _ListeEmissions({required this.shows, required this.choisie, required this.onChanged});

  final List<RadioShow> shows;
  final String? choisie;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cote = Responsive.sidePadding(context);
    final scheme = Theme.of(context).colorScheme;
    final textes = Theme.of(context).textTheme;
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: cote),
        itemCount: shows.length,
        separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final show = shows[i];
          final active = show.slug == choisie;
          return SizedBox(
            width: 200,
            child: GestureDetector(
              onTap: () => onChanged(active ? null : show.slug),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: active ? scheme.primary : Colors.transparent, width: 2.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CoverImage(url: show.imageUrl, icon: Icons.mic_rounded),
                            if (active)
                              ColoredBox(
                                color: scheme.primary.withValues(alpha: 0.35),
                                child: const Center(child: Icon(Icons.filter_alt_rounded, color: Colors.white)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      show.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textes.labelLarge!.copyWith(color: active ? scheme.primary : null),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
