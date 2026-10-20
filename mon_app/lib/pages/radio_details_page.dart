import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_all/webview_all.dart';

import '../models/campus_radio.dart';
import '../widgets/live_player_tile.dart';

// Lecteur du direct, ou rien si la radio n'a pas de flux.
Widget _livePlayer(CampusRadio radio) {
  final streamUrl = radio.streamUrl;
  if (streamUrl == null) {
    return const SizedBox.shrink(); // obliger d'y mettre un widget donc la on le met vide
  }
  return LivePlayerTile(streamUrl: streamUrl);
}

// Radio avec site officiel : on affiche le site.
// Sinon on charge sa description depuis l'API, avec ses podcasts et les actualités.
class RadioDetailsPage extends StatefulWidget {
  const RadioDetailsPage({required this.radio, super.key});
  final CampusRadio radio;

  @override
  State<RadioDetailsPage> createState() => _RadioDetailsPageState();
}

class _RadioDetailsPageState extends State<RadioDetailsPage> {
  Future<RadioDetails>? _detailsFuture;

  @override
  void initState() {
    super.initState();
    // Pas besoin de l'API si la radio a un site.
    if (widget.radio.websiteUrl == null) {
      _detailsFuture = RadioRepository.getDetails(widget.radio.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final websiteUrl = widget.radio.websiteUrl;
    if (websiteUrl != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.radio.name)),
        body: Column(
          children: [
            _livePlayer(widget.radio),
            Expanded(child: _WebsiteView(url: websiteUrl)),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.radio.name)),
      body: FutureBuilder<RadioDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ContentView(radio: widget.radio, details: snapshot.data!);
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
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
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
    return Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover);
  }

  // Une ligne de contenu. Les podcasts ont un bouton lecture/arrêt.
  Widget _contentTile(RadioContent item) {
    final audioUrl = item.audioUrl;
    Widget? bouton;
    if (audioUrl != null) {
      final enLecture = _playingUrl == audioUrl;
      bouton = IconButton(
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
