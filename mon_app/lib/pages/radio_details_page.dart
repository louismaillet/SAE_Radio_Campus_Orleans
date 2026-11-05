import 'dart:ui';

import 'package:flutter/foundation.dart';
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
import '../widgets/pressable.dart';
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

// En-tête centré : logo avec halo, nom, slogan et grand bouton du direct.
class _EnTete extends StatelessWidget {
  const _EnTete({required this.radio, required this.donnees, required this.palette});

  final CampusRadio radio;
  final _Donnees donnees;
  final RadioPalette palette;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final track = _trackDirect(radio, donnees, palette);
    final slogan = donnees.details?.catchPhrase;

    return Column(
      children: [
        Hero(
          tag: 'logo-${radio.id}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), boxShadow: palette.halo(1.2)),
            child: RadioLogo(url: radio.logoUrl, bytes: donnees.reglages.logo, size: 112),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          [if (radio.city != null) radio.city!, 'Réseau Radio Campus'].join(' · ').toUpperCase(),
          textAlign: TextAlign.center,
          style: textes.labelMedium!.copyWith(color: scheme.primary, letterSpacing: 1.4, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(radio.name, textAlign: TextAlign.center, style: textes.headlineMedium!.copyWith(height: 1.1)),
        if (slogan != null && slogan.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            slogan,
            textAlign: TextAlign.center,
            style: textes.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (track != null) ...[
          const SizedBox(height: AppSpacing.lg),
          // Bouton pleine largeur, facile à atteindre avec le pouce.
          SizedBox(
            width: double.infinity,
            child: LiveButton(track: track),
          ),
        ],
      ],
    );
  }
}

// Radio avec site web : petite barre (retour, logo, nom, direct) puis le site en plein écran.
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
    final textes = Theme.of(context).textTheme;
    final track = _trackDirect(widget.radio, widget.donnees, widget.palette);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
            child: Row(
              children: [
                const BackButton(),
                Hero(
                  tag: 'logo-${widget.radio.id}',
                  child: RadioLogo(url: widget.radio.logoUrl, bytes: widget.donnees.reglages.logo, size: 40),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.radio.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textes.titleMedium,
                  ),
                ),
                if (track != null) PlayFab(track: track, size: 44),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              child: WebViewWidget(controller: _controller),
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
  int _nombrePodcasts = 10;
  // Le nom de la radio n'apparaît dans la barre du haut qu'une fois l'en-tête passé.
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _titreVisible = ValueNotifier(false);

  RadioDetails get _details => widget.donnees.details!;

  @override
  void initState() {
    super.initState();
    _contentFuture = RadioRepository.getContent(_details.showSlugs);
    _scroll.addListener(() => _titreVisible.value = _scroll.offset > 220);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _titreVisible.dispose();
    super.dispose();
  }

  Future<void> _rafraichir() async {
    setState(() => _contentFuture = RadioRepository.getContent(_details.showSlugs));
    await _contentFuture.then((_) {}, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final description = _details.description;
    final aDescription = description != null && description.trim().isNotEmpty;

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

        return RefreshIndicator(
          onRefresh: _rafraichir,
          edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _BarreHaut(titre: widget.radio.name, visible: _titreVisible),
              SliverContent(
                top: AppSpacing.sm,
                sliver: SliverToBoxAdapter(
                  child: _EnTete(radio: widget.radio, donnees: widget.donnees, palette: widget.palette),
                ),
              ),
              SliverContent(
                top: AppSpacing.xl,
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (aDescription) ...[_Description(html: description), const SizedBox(height: AppSpacing.md)],
                      _CarteInfos(radio: widget.radio, details: _details),
                    ],
                  ),
                ),
              ),
              if (_details.shows.isNotEmpty) ...[
                const SliverContent(
                  top: AppSpacing.xl,
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Émissions',
                      subtitle: 'Touchez une émission pour filtrer ses podcasts',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ListeEmissions(
                    shows: _details.shows,
                    choisie: _emissionChoisie,
                    onChanged: (slug) => setState(() {
                      _emissionChoisie = slug;
                      _nombrePodcasts = 10;
                    }),
                  ),
                ),
              ],
              const SliverContent(
                top: AppSpacing.xl,
                sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Podcasts')),
              ),
              ..._listePodcasts(snapshot, podcasts),
              const SliverContent(
                top: AppSpacing.xl,
                sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Actualités du réseau')),
              ),
              SliverSafeArea(
                top: false,
                sliver: SliverContent(
                  bottom: AppSpacing.xl,
                  sliver: news.isEmpty
                      ? SliverToBoxAdapter(
                          child: snapshot.hasData
                              ? const EmptyState(message: 'Aucune actualité pour le moment.')
                              : const Skeleton(height: 100),
                        )
                      : SliverList.separated(
                          itemCount: news.length,
                          separatorBuilder: (context, i) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => NewsCard(news: news[i]),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _listePodcasts(AsyncSnapshot<List<RadioContent>> snapshot, List<RadioContent> podcasts) {
    if (snapshot.hasError) {
      return [
        SliverContent(
          sliver: SliverToBoxAdapter(
            child: EmptyState(message: 'Podcasts indisponibles.', onRetry: _rafraichir),
          ),
        ),
      ];
    }
    if (!snapshot.hasData) {
      return [
        SliverContent(
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (context, i) => const SizedBox(height: 10),
            itemBuilder: (context, i) => const Skeleton(height: 86, radius: AppRadius.md),
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
        sliver: SliverList.separated(
          itemCount: affiches.length,
          separatorBuilder: (context, i) => const SizedBox(height: 10),
          itemBuilder: (context, i) =>
              PodcastTile(podcast: affiches[i], radioName: widget.radio.name, accent: widget.palette.seed),
        ),
      ),
      if (podcasts.length > affiches.length)
        SliverContent(
          top: AppSpacing.md,
          sliver: SliverToBoxAdapter(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _nombrePodcasts += 10),
              icon: const Icon(Icons.expand_more_rounded),
              label: Text('Voir plus (${podcasts.length - affiches.length})'),
            ),
          ),
        ),
    ];
  }
}

// Barre du haut en verre : retour, nom de la radio (après défilement) et bouton thème.
class _BarreHaut extends StatelessWidget {
  const _BarreHaut({required this.titre, required this.visible});

  final String titre;
  final ValueListenable<bool> visible;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      title: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, montre, _) => AnimatedOpacity(
          opacity: montre ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
      flexibleSpace: ValueListenableBuilder<bool>(
        valueListenable: visible,
        // Le fond n'apparaît qu'une fois l'en-tête passé, pour laisser voir le dégradé.
        builder: (context, montre, _) => AnimatedOpacity(
          opacity: montre ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
      actions: const [ThemeToggleButton(), SizedBox(width: 4)],
    );
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
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('À propos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
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
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ClipRect(
                        child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: texte),
                      ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icone, size: 18, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: textes.labelSmall!.copyWith(color: scheme.onSurfaceVariant)),
                Text(valeur, style: textes.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Infos', style: textes.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          if (radio.city != null) ligne(Icons.location_city_rounded, 'Ville', radio.city!),
          if (details.address != null) ligne(Icons.place_outlined, 'Adresse', details.address!),
          if (details.email != null) ligne(Icons.mail_outline_rounded, 'Contact', details.email!),
          ligne(Icons.mic_none_rounded, 'Émissions', '${details.shows.length} à la grille'),
          ligne(Icons.sensors_rounded, 'Direct', radio.streamUrl != null ? 'Disponible 24h/24' : 'Pas de flux direct'),
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
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: cote),
        itemCount: shows.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final show = shows[i];
          final active = show.slug == choisie;
          return SizedBox(
            width: 150,
            child: Pressable(
              onTap: () => onChanged(active ? null : show.slug),
              builder: (context, pressed) => Column(
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
                  const SizedBox(height: 6),
                  Text(
                    show.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textes.labelLarge!.copyWith(color: active ? scheme.primary : null, height: 1.2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
