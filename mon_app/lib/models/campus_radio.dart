import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../services/api.dart';

// Radio de la liste, lue dans notre API (GET /radios, table "radios").
class CampusRadio {
  const CampusRadio({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.streamUrl,
    required this.websiteUrl,
    this.city,
    this.excerpt,
    this.categoryColor,
    this.slogan,
  });

  final String id; // le "slug" (le même que dans l'API Radio Campus)
  final String name;
  final String? logoUrl;
  final String? streamUrl;
  final String? websiteUrl; // null = pas de site officiel
  final String? city;
  final String? excerpt; // courte présentation
  final String? categoryColor; // couleur de la catégorie, ex. "#2154ff"
  // Texte du lecteur officiel (playerMetadata.title). L'API ne donne pas le morceau en cours :
  // ni endpoint, ni métadonnées ICY dans les flux (testé sur les 35 radios en novembre 2026).
  final String? slogan;

  factory CampusRadio.fromApiJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String;
    final nom = json['name'] as String?;
    return CampusRadio(
      id: slug,
      name: (nom == null || nom.isEmpty) ? slug : nom,
      logoUrl: json['image_url'] as String?,
      streamUrl: json['live_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      city: json['city'] as String?,
      excerpt: json['excerpt'] as String?,
      categoryColor: json['category_color'] as String?,
      slogan: json['slogan'] as String?,
    );
  }
}

// Émission d'une radio (dans /radios/{slug}).
class RadioShow {
  const RadioShow({required this.slug, required this.title, required this.imageUrl});

  final String slug;
  final String title;
  final String? imageUrl;
}

// Détail d'une radio sans site (/radios/{slug}) : description et ses émissions.
class RadioDetails {
  const RadioDetails({
    required this.description,
    required this.showSlugs,
    this.shows = const [],
    this.catchPhrase,
    this.backgroundColor,
    this.address,
    this.email,
  });

  final String? description; // en HTML
  final List<String> showSlugs;
  final List<RadioShow> shows;
  final String? catchPhrase; // slogan, ex. "RADIO CAMPUS ORLÉANS - 88.3 FM"
  final String? backgroundColor; // couleur choisie par la radio, ex. "#ff0000"
  final String? address;
  final String? email;

  factory RadioDetails.fromJson(Map<String, dynamic> json) {
    final showSlugs = <String>[];
    final shows = <RadioShow>[];
    for (final show in json['radioshows']['member'] as List<dynamic>) {
      showSlugs.add(show['slug'] as String);
      shows.add(
        RadioShow(slug: show['slug'] as String, title: show['title'] as String, imageUrl: _imageUrl(show['imageUrl'])),
      );
    }
    return RadioDetails(
      description: json['content'] as String?,
      showSlugs: showSlugs,
      shows: shows,
      catchPhrase: json['catchPhrase'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      address: json['address'] as String?,
      email: json['email'] as String?,
    );
  }
}

enum RadioContentType { podcast, news }

class RadioContent {
  const RadioContent({
    required this.type,
    required this.title,
    required this.description,
    required this.date,
    required this.audioUrl,
    required this.imageUrl,
    this.showSlug,
    this.showTitle,
  });

  final RadioContentType type;
  final String title;
  final String description;
  final String date;
  final String? audioUrl; // seulement pour les podcasts
  final String? imageUrl;
  final String? showSlug; // émission du podcast
  final String? showTitle;

  factory RadioContent.fromPodcastJson(Map<String, dynamic> json) {
    final emission = json['radioshow'];
    return RadioContent(
      type: RadioContentType.podcast,
      title: json['title'] as String,
      description: (json['contentExcerpt'] as String?) ?? '',
      date: _formatDate(DateTime.parse(json['createdAt'] as String)),
      audioUrl: json['mediaUrl'] as String?,
      imageUrl: _imageUrl(json['imageUrl']),
      showSlug: emission is Map ? emission['slug'] as String? : null,
      showTitle: emission is Map ? emission['title'] as String? : null,
    );
  }

  factory RadioContent.fromNewsJson(Map<String, dynamic> json) {
    // publishedAt est un timestamp Unix en secondes.
    final secondes = json['publishedAt'] as int;
    return RadioContent(
      type: RadioContentType.news,
      title: json['title'] as String,
      description: (json['contentExcerpt'] as String?) ?? '',
      date: _formatDate(DateTime.fromMillisecondsSinceEpoch(secondes * 1000)),
      audioUrl: null,
      imageUrl: _imageUrl(json['imageUrl']),
    );
  }
}

// Transforme une date en "05/03/2024".
String _formatDate(DateTime date) {
  final jour = date.day.toString().padLeft(2, '0');
  final mois = date.month.toString().padLeft(2, '0');
  return '$jour/$mois/${date.year}';
}

// L'API donne les images sous la forme { "card": { "1x": "https://..." } }.
// On prend "card" en 1x, ou null s'il n'y en a pas.
// (On évite "card-sm" en 1x : son lien renvoie une erreur 404 côté API.)
String? _imageUrl(dynamic images) {
  if (images is Map) {
    final card = images['card'];
    if (card is Map) {
      return card['1x'] as String?;
    }
  }
  return null;
}

class RadioRepository {
  static const String _host = 'api.radiocampus.org';

  // Appelle l'API et renvoie le JSON décodé.
  static Future<Map<String, dynamic>> _get(String path, [Map<String, String>? params]) async {
    // Sur le web, l'API bloque les navigateurs (CORS) : on passe par le relais de notre API
    // (GET /proxy/radiocampus). Pas d'en-tête personnalisé ici, pour éviter la requête préliminaire.
    final http.Response reponse;
    if (kIsWeb) {
      final url = Api.uri('/proxy/radiocampus', {'chemin': '/api$path', ...?params});
      reponse = await http.get(url);
    } else {
      final url = Uri.https(_host, '/api$path', params);
      reponse = await http.get(url, headers: {'Accept': 'application/ld+json'});
    }
    // utf8.decode sur les octets pour bien garder les accents.
    return jsonDecode(utf8.decode(reponse.bodyBytes)) as Map<String, dynamic>;
  }

  // La liste des radios vient de notre base (remplie par `python -m app.catalogue`).
  // Le détail, les podcasts et les actualités viennent toujours de l'API Radio Campus.
  static Future<List<CampusRadio>> getRadios() async {
    final data = await Api.get('/radios') as List<dynamic>;
    return [for (final item in data) CampusRadio.fromApiJson(item as Map<String, dynamic>)];
  }

  static Future<RadioDetails> getDetails(String radioId) async {
    final data = await _get('/radios/$radioId');
    return RadioDetails.fromJson(data);
  }

  // Podcasts des émissions de la radio, puis les dernières actualités.
  // Tous les podcasts publiés, du plus récent au plus ancien.
  // L'appel est gardé en mémoire : les pages radio s'en servent.
  static Future<List<Map<String, dynamic>>>? _podcastsCache;

  static Future<List<Map<String, dynamic>>> _podcastsPublies() {
    final cache = _podcastsCache;
    if (cache != null) {
      return cache;
    }
    final future = _chargerPodcasts();
    _podcastsCache = future;
    // En cas d'erreur, on réessaiera au prochain appel.
    future.catchError((Object _) {
      _podcastsCache = null;
      return <Map<String, dynamic>>[];
    });
    return future;
  }

  static Future<List<Map<String, dynamic>>> _chargerPodcasts() async {
    final data = await _get('/podcasts', {'itemsPerPage': '300'});
    final podcasts = <Map<String, dynamic>>[];
    for (final item in data['member'] as List<dynamic>) {
      final podcast = item as Map<String, dynamic>;
      if (podcast['published'] == true) {
        podcasts.add(podcast);
      }
    }
    // Les dates ISO 8601 se trient comme du texte.
    podcasts.sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
    return podcasts;
  }

  static Future<List<RadioContent>> getContent(List<String> showSlugs) async {
    final contenus = <RadioContent>[];

    // Le filtre par radio de l'API ne marche pas : on prend tous les podcasts
    // (235 au total) et on garde ceux qui viennent des émissions de la radio.
    for (final podcast in await _podcastsPublies()) {
      final emission = podcast['radioshow'];
      if (emission is Map && showSlugs.contains(emission['slug'])) {
        contenus.add(RadioContent.fromPodcastJson(podcast));
      }
    }

    contenus.addAll(await getNews());
    return contenus;
  }

  // Les articles ne sont pas liés à une radio : ce sont les actualités du réseau.
  static Future<List<RadioContent>> getNews() async {
    final articles = await _get('/articles', {'itemsPerPage': '5', 'order[publishedAt]': 'desc'});
    final news = <RadioContent>[];
    for (final item in articles['member'] as List<dynamic>) {
      news.add(RadioContent.fromNewsJson(item as Map<String, dynamic>));
    }
    return news;
  }
}
