import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;

// Client de notre API FastAPI (dossier backend/ du dépôt).
//
// Adresse du serveur :
//   - par défaut : http://10.0.2.2:8000 sur l'émulateur Android (= le PC),
//     http://localhost:8000 ailleurs (web, Linux...) ;
//   - pour un vrai téléphone ou la production :
//     flutter run --dart-define=API_URL=http://192.168.1.20:8000
class Api {
  static const String _urlForcee = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_urlForcee.isNotEmpty) {
      return _urlForcee;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  // Sans réponse au bout de ce délai, on considère le serveur injoignable.
  static const Duration _delai = Duration(seconds: 8);

  static Uri uri(String chemin, [Map<String, String>? params]) =>
      Uri.parse('$baseUrl$chemin').replace(queryParameters: params);

  // Les images de l'API sont données en chemin relatif ("/media/logos/x.webp").
  static String media(String chemin) => chemin.startsWith('http') ? chemin : '$baseUrl$chemin';

  static Map<String, String> _entetes(String? jeton, {bool json = false}) => {
    if (json) 'Content-Type': 'application/json',
    if (jeton != null) 'Authorization': 'Bearer $jeton',
  };

  static Future<dynamic> get(String chemin, {String? jeton, Map<String, String>? params}) async {
    return _envoyer(() => http.get(uri(chemin, params), headers: _entetes(jeton)));
  }

  static Future<dynamic> patch(String chemin, Map<String, dynamic> corps, {String? jeton}) async {
    return _envoyer(
      () => http.patch(uri(chemin), headers: _entetes(jeton, json: true), body: jsonEncode(corps)),
    );
  }

  static Future<dynamic> delete(String chemin, {String? jeton}) async {
    return _envoyer(() => http.delete(uri(chemin), headers: _entetes(jeton)));
  }

  // Formulaire application/x-www-form-urlencoded (utilisé par /auth/login).
  static Future<dynamic> postFormulaire(String chemin, Map<String, String> champs) async {
    return _envoyer(() => http.post(uri(chemin), body: champs));
  }

  // Envoi d'un fichier (multipart/form-data), ex. le logo d'une radio.
  static Future<dynamic> putFichier(
    String chemin, {
    required String champ,
    required Uint8List octets,
    required String nomFichier,
    String? jeton,
  }) async {
    final requete = http.MultipartRequest('PUT', uri(chemin))
      ..headers.addAll(_entetes(jeton))
      ..files.add(http.MultipartFile.fromBytes(champ, octets, filename: nomFichier));
    return _envoyer(() async => http.Response.fromStream(await requete.send()));
  }

  // Télécharge un fichier (ex. un logo) et renvoie ses octets.
  static Future<Uint8List> telecharger(String chemin) async {
    final reponse = await http.get(Uri.parse(media(chemin))).timeout(_delai);
    if (reponse.statusCode != 200) {
      throw ApiException(reponse.statusCode, 'Fichier introuvable');
    }
    return reponse.bodyBytes;
  }

  static Future<dynamic> _envoyer(Future<http.Response> Function() requete) async {
    final http.Response reponse;
    try {
      reponse = await requete().timeout(_delai);
    } catch (_) {
      throw const ApiException(0, 'Serveur injoignable. Vérifie ta connexion internet.');
    }
    // utf8.decode sur les octets pour bien garder les accents.
    final texte = utf8.decode(reponse.bodyBytes);
    final contenu = texte.isEmpty ? null : jsonDecode(texte);
    if (reponse.statusCode >= 200 && reponse.statusCode < 300) {
      return contenu;
    }
    throw ApiException(reponse.statusCode, _messageErreur(contenu));
  }

  // FastAPI renvoie {"detail": "texte"} ou, pour une erreur de validation (422),
  // {"detail": [{"msg": "...", "loc": [...]}, ...]}.
  static String _messageErreur(dynamic contenu) {
    final detail = contenu is Map ? contenu['detail'] : null;
    if (detail is String) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty && detail.first is Map) {
      return 'Valeur refusée : ${(detail.first as Map)['msg']}';
    }
    return 'Erreur du serveur.';
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode; // 0 = serveur injoignable
  final String message;

  bool get sessionExpiree => statusCode == 401;

  @override
  String toString() => message;
}
