import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

import '../models/campus_radio.dart';
import '../widgets/error_retry.dart';
import '../widgets/live_player_tile.dart';

class RadioDetailsPage extends StatefulWidget {
  const RadioDetailsPage({required this.radio, super.key});
  final CampusRadio radio;

  @override
  State<RadioDetailsPage> createState() => _RadioDetailsPageState();
}

class _RadioDetailsPageState extends State<RadioDetailsPage> {
  // Radio avec site web : on affiche le site dans une webview.
  WebViewController? _webController;
  // Radio sans site web : on affiche ses podcasts et news.
  Future<List<RadioContent>>? _contentFuture;

  @override
  void initState() {
    super.initState();
    final websiteUrl = widget.radio.websiteUrl;
    if (websiteUrl != null) {
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted) // javascriptMode pour que le site web fonctionne correctement
        ..loadRequest(Uri.parse(websiteUrl));
    } else {
      _contentFuture = RadioRepository.getContent(widget.radio.id);
    }
  }

  void _reloadContent() {
    setState(() {
      _contentFuture = RadioRepository.getContent(widget.radio.id);
    });
  }

  // Lecteur du direct, ou rien si la radio n'a pas de flux.
  Widget _livePlayer() {
    final streamUrl = widget.radio.streamUrl;
    if (streamUrl == null) {
      return const SizedBox.shrink(); // obliger d'y mettre un widget donc la on le met vide
    }
    return LivePlayerTile(streamUrl: streamUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (_webController != null) {
      return _buildWebsitePage(_webController!);
    }
    return _buildContentPage();
  }

  Widget _buildWebsitePage(WebViewController controller) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.radio.name)),
      body: Column(
        children: [
          _livePlayer(),
          Expanded(child: WebViewWidget(controller: controller)),
        ],
      ),
    );
  }

  Widget _buildContentPage() {
    return Scaffold(
      appBar: AppBar(title: Text(widget.radio.name)),
      body: FutureBuilder<List<RadioContent>>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorRetry(onRetry: _reloadContent);
          }
          final content = snapshot.data ?? [];
          final podcasts = content.where((item) => item.type == RadioContentType.podcast).toList();
          final news = content.where((item) => item.type == RadioContentType.news).toList();

          return ListView(
            children: [
              _livePlayer(),
              ..._section('Podcasts', podcasts),
              ..._section('News et agenda', news),
            ],
          );
        },
      ),
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
      widgets.add(
        ListTile(
          title: Text(item.title),
          subtitle: Text('${item.description}\n${item.date}'),
        ),
      );
    }
    return widgets;
  }
}
