import 'dart:convert';

import 'package:http/http.dart' as http;

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
  });

  final String id; // le "slug" de l'API
  final String name;
  final String? logoUrl;
  final String? streamUrl;
  final String? websiteUrl; // null = pas de site officiel

  factory CampusRadio.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String;
    return CampusRadio(
      id: slug,
      name: json['title'] as String,
      logoUrl: _imageUrl(json['imageUrl']),
      streamUrl: json['mediaUrl'] as String?,
      websiteUrl: _sitesOfficiels[slug],
    );
  }
}

// Détail d'une radio sans site (/radios/{slug}) : description et ses émissions.
class RadioDetails {
  const RadioDetails({
    required this.description,
    required this.showSlugs,
  });

  final String? description; // en HTML
  final List<String> showSlugs;

  factory RadioDetails.fromJson(Map<String, dynamic> json) {
    final showSlugs = <String>[];
    for (final show in json['radioshows']['member'] as List<dynamic>) {
      showSlugs.add(show['slug'] as String);
    }
    return RadioDetails(
      description: json['content'] as String?,
      showSlugs: showSlugs,
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
  });

  final RadioContentType type;
  final String title;
  final String description;
  final String date;
  final String? audioUrl; // seulement pour les podcasts
  final String? imageUrl;

  factory RadioContent.fromPodcastJson(Map<String, dynamic> json) {
    return RadioContent(
      type: RadioContentType.podcast,
      title: json['title'] as String,
      description: (json['contentExcerpt'] as String?) ?? '',
      date: _formatDate(DateTime.parse(json['createdAt'] as String)),
      audioUrl: json['mediaUrl'] as String?,
      imageUrl: _imageUrl(json['imageUrl']),
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
    final url = Uri.https(_host, '/api$path', params);
    final reponse = await http.get(url, headers: {'Accept': 'application/ld+json'});
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
  static Future<List<RadioContent>> getContent(List<String> showSlugs) async {
    final contenus = <RadioContent>[];

    // Le filtre par radio de l'API ne marche pas : on prend tous les podcasts
    // (235 au total) et on garde ceux publiés qui viennent des émissions de la radio.
    final podcasts = await _get('/podcasts', {'itemsPerPage': '300'});
    for (final item in podcasts['member'] as List<dynamic>) {
      final podcast = item as Map<String, dynamic>;
      final emission = podcast['radioshow'];
      if (podcast['published'] == true &&
          emission is Map &&
          showSlugs.contains(emission['slug'])) {
        contenus.add(RadioContent.fromPodcastJson(podcast));
      }
    }

    // Les articles ne sont pas liés à une radio : ce sont les actualités du réseau.
    final articles = await _get('/articles', {'itemsPerPage': '5', 'order[publishedAt]': 'desc'});
    for (final item in articles['member'] as List<dynamic>) {
      contenus.add(RadioContent.fromNewsJson(item as Map<String, dynamic>));
    }
    return contenus;
  }
}
