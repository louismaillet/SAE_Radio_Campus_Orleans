import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_all/webview_all.dart';

import '../models/campus_radio.dart';
import '../models/radio_settings.dart';
import '../widgets/live_player_tile.dart';

// Lecteur du direct, ou rien si la radio n'a pas de flux.
Widget _livePlayer(CampusRadio radio) {
  final streamUrl = radio.streamUrl;
  if (streamUrl == null) {
    return const SizedBox.shrink(); // obliger d'y mettre un widget donc la on le met vide
  }
  return LivePlayerTile(streamUrl: streamUrl);
}

// Thème de la page d'une radio : la couleur secondaire choisie par le gérant.
ThemeData _themeRadio(BuildContext context, Color? couleur) {
  final theme = Theme.of(context);
  if (couleur == null) {
    return theme;
  }
  // Texte blanc sur une couleur foncée, noir sur une couleur claire.
  Color texte = Colors.black;
  if (ThemeData.estimateBrightnessForColor(couleur) == Brightness.dark) {
    texte = Colors.white;
  }
  return theme.copyWith(
    colorScheme: theme.colorScheme.copyWith(secondary: couleur, onSecondary: texte),
  );
}

// Bandeau sous la barre du haut : le logo sur la couleur secondaire.
Widget _bandeau(ThemeData theme, CampusRadio radio, RadioSettings reglages) {
  Widget logo = const Icon(Icons.radio, size: 56);
  final logoUrl = radio.logoUrl;
  if (reglages.logo != null) {
    logo = Image.memory(reglages.logo!, height: 56);
  } else if (logoUrl != null) {
    logo = Image.network(logoUrl, height: 56);
  }
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    color: theme.colorScheme.secondary,
    child: Center(child: logo),
  );
}

// Selon le choix du gérant : on affiche le site web de la radio,
// ou sa description depuis l'API, avec ses podcasts et les actualités.
class RadioDetailsPage extends StatefulWidget {
  const RadioDetailsPage({required this.radio, super.key});
  final CampusRadio radio;

  @override
  State<RadioDetailsPage> createState() => _RadioDetailsPageState();
}

class _RadioDetailsPageState extends State<RadioDetailsPage> {
  late Future<RadioSettings> _reglagesFuture;
  // Détail de l'API, chargé seulement pour la version appli.
  RadioDetails? _details;

  @override
  void initState() {
    super.initState();
    _reglagesFuture = _charger();
  }

  // Le site s'affiche si le gérant l'a choisi et a donné son adresse.
  bool _ouvreLeSite(RadioSettings reglages) {
    return reglages.afficherSite && reglages.siteUrl != null;
  }

  // On lit les réglages du gérant, puis le détail de l'API si besoin.
  Future<RadioSettings> _charger() async {
    final reglages = await RadioSettingsRepository.load(widget.radio);
    if (!_ouvreLeSite(reglages)) {
      _details = await RadioRepository.getDetails(widget.radio.id);
    }
    return reglages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.radio.name)),
      body: FutureBuilder<RadioSettings>(
        future: _reglagesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reglages = snapshot.data!;
          Widget contenu;
          if (_ouvreLeSite(reglages)) {
            contenu = _WebsiteView(url: reglages.siteUrl!);
          } else {
            contenu = _ContentView(radio: widget.radio, details: _details!);
          }
          // Le widget Theme applique la couleur du gérant à tout ce qu'il contient.
          final theme = _themeRadio(context, reglages.couleur);
          return Theme(
            data: theme,
            child: Column(
              children: [
                _bandeau(theme, widget.radio, reglages),
                Expanded(child: contenu),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Radio avec site web : on affiche le site dans une webview.
class _WebsiteView extends StatefulWidget {
  const _WebsiteView({required this.url});
  final String url;

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
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}

// Radio sans site web : description, podcasts (avec lecture) et actualités.
class _ContentView extends StatefulWidget {
  const _ContentView({required this.radio, required this.details});
  final CampusRadio radio;
  final RadioDetails details;

  @override
  State<_ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<_ContentView> {
  late Future<List<RadioContent>> _contentFuture;
  // Un seul lecteur pour tous les podcasts.
  final AudioPlayer _player = AudioPlayer();
  // Podcast en cours de lecture (null si aucun).
  String? _playingUrl;

  @override
  void initState() {
    super.initState();
    _contentFuture = RadioRepository.getContent(widget.details.showSlugs);
    // Quand le podcast est fini, on remet le bouton lecture.
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _playingUrl = null);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // Lance le podcast, ou l'arrête si c'est celui qui joue déjà.
  Future<void> _togglePodcast(String url) async {
    // "mounted" = la page est encore affichée (sinon setState planterait).
    if (_playingUrl == url) {
      await _player.stop();
      if (mounted) {
        setState(() {
          _playingUrl = null;
        });
      }
      return;
    }
    await _player.play(UrlSource(url));
    if (mounted) {
      setState(() {
        _playingUrl = url;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RadioContent>>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final content = snapshot.data!;
        // On sépare les podcasts et les actualités.
        final podcasts = <RadioContent>[];
        final news = <RadioContent>[];
        for (final item in content) {
          if (item.type == RadioContentType.podcast) {
            podcasts.add(item);
          } else {
            news.add(item);
          }
        }

        // On construit la liste des éléments à afficher, du haut vers le bas.
        final widgets = <Widget>[_livePlayer(widget.radio)];

        // Description de la radio : du HTML, affiché avec le package flutter_html.
        final description = widget.details.description;
        if (description != null && description.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Html(data: description),
            ),
          );
        }

        // On n'affiche que les 10 premiers podcasts.
        widgets.addAll(_section('Podcasts', podcasts.take(10).toList()));
        widgets.addAll(_section('Actualités du réseau', news));

        return ListView(children: widgets);
      },
    );
  }

  // Un titre suivi de la liste des contenus (ou d'un message si la liste est vide).
  List<Widget> _section(String title, List<RadioContent> items) {
    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
        ),
      ),
    ];
    if (items.isEmpty) {
      widgets.add(const ListTile(title: Text('Aucun contenu pour le moment.')));
    }
    for (final item in items) {
      widgets.add(_contentTile(item));
    }
    return widgets;
  }

  // Petite image d'un podcast ou d'une actualité (pour l'enlever : supprimer cette
  // méthode et la ligne "leading" dans _contentTile).
  Widget _vignette(String? imageUrl) {
    if (imageUrl == null) {
      return const Icon(Icons.image_not_supported, size: 56);
    }
    return Image.network(
      imageUrl,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      // Certaines images renvoient une erreur 404 : on affiche l'icône à la place.
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.image_not_supported, size: 56),
    );
  }

  // Une ligne de contenu. Les podcasts ont un bouton lecture/arrêt.
  Widget _contentTile(RadioContent item) {
    final audioUrl = item.audioUrl;
    Widget? bouton;
    if (audioUrl != null) {
      final enLecture = _playingUrl == audioUrl;
      bouton = IconButton(
        color: Theme.of(context).colorScheme.secondary,
        icon: Icon(enLecture ? Icons.stop : Icons.play_arrow),
        onPressed: () => _togglePodcast(audioUrl),
      );
    }
    return ListTile(
      leading: _vignette(item.imageUrl),
      title: Text(item.title),
      subtitle: Text(
        '${item.description}\n${item.date}',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: bouton,
    );
  }
}
