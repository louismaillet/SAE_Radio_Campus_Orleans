import 'dart:convert';

import 'package:flutter/services.dart';

class CampusRadio {
  const CampusRadio({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.streamUrl,
    required this.websiteUrl,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? streamUrl;
  final String? websiteUrl;

  factory CampusRadio.fromJson(Map<String, dynamic> json) {
    return CampusRadio(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo'] as String?,
      streamUrl: json['streamUrl'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
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
  });

  final RadioContentType type;
  final String title;
  final String description;
  final String date;

  factory RadioContent.fromPodcastJson(Map<String, dynamic> json) {
    return RadioContent(
      type: RadioContentType.podcast,
      title: json['title'] as String,
      description: json['description'] as String,
      date: '${_formatDate(json['publishedAt'] as String)} · ${json['duration']}',
    );
  }

  factory RadioContent.fromNewsJson(Map<String, dynamic> json) {
    return RadioContent(
      type: RadioContentType.news,
      title: json['title'] as String,
      description: json['content'] as String,
      date: _formatDate(json['date'] as String),
    );
  }
}

// Transforme "2024-03-05T10:00:00" en "05/03/2024".
String _formatDate(String iso) {
  final date = DateTime.parse(iso);
  final jour = date.day.toString().padLeft(2, '0');
  final mois = date.month.toString().padLeft(2, '0');
  return '$jour/$mois/${date.year}';
}

class RadioRepository {
  // on save le contenu du json
  static Map<String, dynamic>? _db;

  static Future<Map<String, dynamic>> _load() async {
    if (_db == null) {
      final texte = await rootBundle.loadString('assets/db.json'); // rootBundle permet de charger des ressources depuis le dossier assets
      _db = jsonDecode(texte) as Map<String, dynamic>;
    }
    return _db!;
  }

  static Future<List<CampusRadio>> getRadios() async {
    final db = await _load();
    final radios = <CampusRadio>[];
    for (final item in db['radios'] as List<dynamic>) {
      radios.add(CampusRadio.fromJson(item as Map<String, dynamic>));
    }
    return radios;
  }

  // Podcasts puis news de la radio demandée.
  static Future<List<RadioContent>> getContent(String radioId) async {
    final db = await _load();
    final contenus = <RadioContent>[];

    for (final item in db['podcasts'] as List<dynamic>) {
      final podcast = item as Map<String, dynamic>;
      if (podcast['radioId'] == radioId) {
        contenus.add(RadioContent.fromPodcastJson(podcast));
      }
    }
    for (final item in db['news'] as List<dynamic>) {
      final news = item as Map<String, dynamic>;
      if (news['radioId'] == radioId) {
        contenus.add(RadioContent.fromNewsJson(news));
      }
    }
    return contenus;
  }
}
