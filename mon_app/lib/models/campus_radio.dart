import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../supabase_config.dart';

// Sites officiels (slug de l'API -> site). On ne prend pas le websiteUrl de l'API
// car il contient parfois des Facebook/Instagram.
// Une radio qui n'est pas dans cette liste est considérée comme "sans site" :
// on affiche alors sa description, ses podcasts et les actualités de l'API.
const Map<String, String> _sitesOfficiels = {
  'radio-campus-47': 'https://radiocampus47.fr/',
  'radio-campus-amiens-amiens': 'http://www.radiocampusamiens.fr/',
  'radio-campus-angers': 'https://www.radiocampusangers.com/',
  'radio-campus-avignon': 'https://avignon.radiocampus.fr/',
  'radio-campus-besancon': 'https://campusbesancon.fr/',
  'radio-campus-bordeaux': 'https://www.radiocampusbordeaux.fr/',
  'programmationatradio-u-org': 'https://www.radio-u.org/',
  'radio-phenix': 'https://phenix.fm/',
  'radiom-campus-castres': 'https://www.radiom.fr/',
  'radio-campus-clermont-ferrand': 'https://campus-clermont.net/',
  'radio-dijon-campus': 'https://radiodijoncampus.com/',
  'radio-campus-grenoble': 'https://campusgrenoble.org/',
  'radio-campus-lille': 'https://www.campuslille.com/',
  'radio-campus-tours': 'https://www.radiocampustours.com/',
  'campus-fm-toulouse': 'https://www.campusfm.net/',
  'radio-en-construction': 'https://www.radioenconstruction.com/',
  'c-lab-campus-rennes': 'https://www.c-lab.fr/',
  'radio-pulsar-poitiers': 'https://www.radio-pulsar.org/',
  'radio-campus-pau': 'https://radiocampuspau.fr/',
  'www-radiocampusparis-org': 'https://www.radiocampusparis.org/',
  'radio-campus-orleans': 'https://orleans.radiocampus.org/',
  'radio-mne-mulhouse': 'https://www.radiomne.com/',
  'radio-campus-montpellier': 'https://www.radiocampusmontpellier.fr/',
  'radio-grenouille-marseille': 'https://www.radiogrenouille.com/',
  'radio-brume-lyon': 'https://www.radiobrume.fr/',
  'radio-campus-lorraine-nancy-metz': 'https://www.radiocampuslorraine.com/',
};

// Radio de la liste (/radios).
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

  final String id; // le "slug" de l'API
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

  factory CampusRadio.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String;
    return CampusRadio(
      id: slug,
      name: json['title'] as String,
      logoUrl: _imageUrl(json['imageUrl']),
      streamUrl: json['mediaUrl'] as String?,
      websiteUrl: _sitesOfficiels[slug],
      city: json['city'] as String?,
      excerpt: json['contentExcerpt'] as String?,
      categoryColor: (json['category'] as Map?)?['color'] as String?,
      slogan: (json['playerMetadata'] as Map?)?['title'] as String?,
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
    this.slug,
    this.tags = const [],
  });

  final RadioContentType type;
  final String title;
  final String description;
  final String date;
  final String? audioUrl; // seulement pour les podcasts
  final String? imageUrl;
  final String? showSlug; // émission du podcast
  final String? showTitle;
  final String? slug; // slug de l'épisode ou de l'article
  final List<String> tags; // slugs des tags (articles détaillés seulement)

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
      slug: json['slug'] as String?,
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
      slug: json['slug'] as String?,
      tags: _slugsTags(json['tags']),
    );
  }
}

// Le détail d'un article donne ses tags sous la forme { "member": [ { "slug": ... } ] }.
List<String> _slugsTags(dynamic tags) {
  if (tags is! Map || tags['member'] is! List) {
    return const [];
  }
  final slugs = <String>[];
  for (final tag in tags['member'] as List) {
    if (tag is Map && tag['slug'] is String) {
      slugs.add(tag['slug'] as String);
    }
  }
  return slugs;
}

// Tag de l'API (/tags).
class Tag {
  const Tag({required this.slug, required this.nom});

  final String slug;
  final String nom;
}

// Détail d'une émission (/shows/{slug}).
class ShowDetails {
  const ShowDetails({required this.slug, required this.titre, this.imageUrl, this.description});

  final String slug;
  final String titre;
  final String? imageUrl;
  final String? description; // en HTML
}

// Articles qui ont au moins un des tags, dans l'ordre reçu, au plus [nombre].
List<RadioContent> filtrerParTags(List<RadioContent> articles, List<String> tags, int nombre) {
  return articles.where((a) => a.tags.any(tags.contains)).take(nombre).toList();
}

// Podcasts des émissions choisies (sélection vide = toutes les émissions de la radio).
// Une émission qui n'est pas celle de la radio n'est jamais gardée.
List<RadioContent> filtrerReplays(
  List<RadioContent> podcasts, {
  required List<String> emissionsRadio,
  required List<String> selection,
  required int nombre,
}) {
  final emissions = selection.isEmpty ? emissionsRadio : selection.where(emissionsRadio.contains).toList();
  return podcasts.where((p) => emissions.contains(p.showSlug)).take(nombre).toList();
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
    // Sur le web, l'API bloque les navigateurs (CORS) : on passe par la fonction Supabase
    // "proxy-radiocampus". Pas d'en-tête personnalisé ici, pour éviter la requête préliminaire.
    final http.Response reponse;
    if (kIsWeb) {
      final url = Uri.parse('$supabaseUrl/functions/v1/proxy-radiocampus')
          .replace(queryParameters: {'chemin': '/api$path', ...?params});
      reponse = await http.get(url);
    } else {
      final url = Uri.https(_host, '/api$path', params);
      reponse = await http.get(url, headers: {'Accept': 'application/ld+json'});
    }
    // utf8.decode sur les octets pour bien garder les accents.
    return jsonDecode(utf8.decode(reponse.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<List<CampusRadio>> getRadios() async {
    final data = await _get('/radios');
    final radios = <CampusRadio>[];
    for (final item in data['member'] as List<dynamic>) {
      radios.add(CampusRadio.fromJson(item as Map<String, dynamic>));
    }
    return radios;
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
    return [...await getPodcastsRadio(showSlugs), ...await getNews()];
  }

  // Podcasts publiés des émissions de la radio, du plus récent au plus ancien.
  static Future<List<RadioContent>> getPodcastsRadio(List<String> showSlugs) async {
    final contenus = <RadioContent>[];
    for (final podcast in await _podcastsPublies()) {
      final emission = podcast['radioshow'];
      if (emission is Map && showSlugs.contains(emission['slug'])) {
        contenus.add(RadioContent.fromPodcastJson(podcast));
      }
    }
    return contenus;
  }

  // Les articles ne sont pas liés à une radio : ce sont les actualités du réseau.
  static Future<List<RadioContent>> getNews({int nombre = 5}) async {
    final articles = await _get('/articles', {'itemsPerPage': '$nombre', 'order[publishedAt]': 'desc'});
    final news = <RadioContent>[];
    for (final item in articles['member'] as List<dynamic>) {
      news.add(RadioContent.fromNewsJson(item as Map<String, dynamic>));
    }
    return news;
  }

  // Les 30 derniers articles avec leurs tags. La liste de l'API ne donne pas les tags
  // et ignore le filtre par tag : on charge le détail de chaque article.
  // Gardé en mémoire comme les podcasts.
  static Future<List<RadioContent>>? _articlesCache;

  static Future<List<RadioContent>> getArticlesDetailles() {
    final cache = _articlesCache;
    if (cache != null) {
      return cache;
    }
    final future = _chargerArticlesDetailles();
    _articlesCache = future;
    future.catchError((Object _) {
      _articlesCache = null;
      return <RadioContent>[];
    });
    return future;
  }

  static Future<List<RadioContent>> _chargerArticlesDetailles() async {
    final liste = await _get('/articles', {'itemsPerPage': '30', 'order[publishedAt]': 'desc'});
    final slugs = [for (final item in liste['member'] as List<dynamic>) item['slug'] as String];
    final details = await Future.wait(slugs.map((slug) => _get('/articles/$slug')));
    return [for (final article in details) RadioContent.fromNewsJson(article)];
  }

  static Future<List<Tag>> getTags() async {
    final data = await _get('/tags', {'itemsPerPage': '100'});
    final tags = <Tag>[];
    for (final item in data['member'] as List<dynamic>) {
      tags.add(Tag(slug: item['slug'] as String, nom: item['name'] as String));
    }
    tags.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return tags;
  }

  static Future<ShowDetails> getShow(String slug) async {
    final data = await _get('/shows/$slug');
    return ShowDetails(
      slug: data['slug'] as String,
      titre: data['title'] as String,
      imageUrl: _imageUrl(data['imageUrl']),
      description: data['content'] as String?,
    );
  }
}
