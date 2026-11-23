import 'package:latlong2/latlong.dart';

import '../models/campus_radio.dart';

// Une ville du réseau et ses radios (le plus souvent une seule).
class VilleRadio {
  const VilleRadio({required this.nom, required this.position, required this.radios});

  final String nom; // valeur "city" de l'API
  final LatLng? position; // null si la ville n'est pas dans coordonneesVilles
  final List<CampusRadio> radios;

  // Une ville est identifiée par son nom : la sélection reste valable
  // quand la liste est recalculée (nouvel affichage, rechargement).
  @override
  bool operator ==(Object other) => other is VilleRadio && other.nom == nom;

  @override
  int get hashCode => nom.hashCode;
}

// L'API ne donne pas de coordonnées : centre de chaque ville, clé = "city" exact de l'API.
const Map<String, LatLng> coordonneesVilles = {
  'Agen': LatLng(44.2033, 0.6163),
  'Amiens': LatLng(49.8941, 2.2958),
  'Angers': LatLng(47.4784, -0.5632),
  'Avignon': LatLng(43.9493, 4.8055),
  'Besançon': LatLng(47.2378, 6.0241),
  'Bordeaux': LatLng(44.8378, -0.5792),
  'Brest': LatLng(48.3904, -4.4861),
  'Bruxelles': LatLng(50.8503, 4.3517),
  'Caen': LatLng(49.1829, -0.3707),
  'Castres': LatLng(43.6060, 2.2400),
  'Clermont-Ferrand': LatLng(45.7772, 3.0870),
  'Corte': LatLng(42.3061, 9.1497),
  'Dijon': LatLng(47.3220, 5.0415),
  'Grenoble': LatLng(45.1885, 5.7245),
  'Lille': LatLng(50.6292, 3.0573),
  'Lyon': LatLng(45.7640, 4.8357),
  'Marseille': LatLng(43.2965, 5.3698),
  'Montpellier': LatLng(43.6108, 3.8767),
  'Mulhouse': LatLng(47.7508, 7.3359),
  'Nancy - Metz': LatLng(48.90, 6.18), // entre les deux villes
  'Orléans': LatLng(47.9029, 1.9093),
  'Paris': LatLng(48.8566, 2.3522),
  'Pau': LatLng(43.2951, -0.3708),
  'Perpignan': LatLng(42.6887, 2.8948),
  'Poitiers': LatLng(46.5802, 0.3404),
  'Rennes': LatLng(48.1173, -1.6778),
  'Rosny-sous-bois': LatLng(48.8748, 2.4860),
  'Rouen': LatLng(49.4432, 1.0999),
  'Saint-Denis - La Réunion': LatLng(-20.8823, 55.4504),
  'Sherbrooke': LatLng(45.4042, -71.8929),
  'Strasbourg': LatLng(48.5734, 7.7521),
  'Toulouse': LatLng(43.6047, 1.4442),
  'Tours': LatLng(47.3941, 0.6848),
};

// Regroupe les radios par ville (les radios sans ville sont ignorées), triées par nom.
List<VilleRadio> villesDuReseau(List<CampusRadio> radios) {
  final parVille = <String, List<CampusRadio>>{};
  for (final radio in radios) {
    final ville = radio.city?.trim();
    if (ville == null || ville.isEmpty) continue;
    parVille.putIfAbsent(ville, () => []).add(radio);
  }
  final villes = [
    for (final e in parVille.entries) VilleRadio(nom: e.key, position: coordonneesVilles[e.key], radios: e.value),
  ];
  villes.sort((a, b) => normaliser(a.nom).compareTo(normaliser(b.nom)));
  return villes;
}

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};

// Minuscules, sans accents ; traits d'union, apostrophes et espaces multiples
// deviennent un seul espace (« clermont ferrand » = « Clermont-Ferrand »).
String normaliser(String s) {
  final buffer = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    buffer.write(_accents[c] ?? c);
  }
  return buffer.toString().replaceAll(RegExp(r"[-'’\s]+"), ' ').trim();
}

// Villes dont le nom contient le texte ; celles qui commencent par le texte d'abord.
List<VilleRadio> rechercherVilles(List<VilleRadio> villes, String texte) {
  final t = normaliser(texte);
  if (t.isEmpty) return [];
  final debut = <VilleRadio>[];
  final milieu = <VilleRadio>[];
  for (final ville in villes) {
    final nom = normaliser(ville.nom);
    if (nom.startsWith(t)) {
      debut.add(ville);
    } else if (nom.contains(t)) {
      milieu.add(ville);
    }
  }
  return [...debut, ...milieu];
}

// Ville (avec position) la plus proche à vol d'oiseau, ou null s'il n'y en a pas.
({VilleRadio ville, double km})? plusProche(List<VilleRadio> villes, LatLng position) {
  const distance = Distance();
  ({VilleRadio ville, double km})? meilleure;
  for (final ville in villes) {
    final p = ville.position;
    if (p == null) continue;
    final km = distance.as(LengthUnit.Kilometer, position, p);
    if (meilleure == null || km < meilleure.km) {
      meilleure = (ville: ville, km: km);
    }
  }
  return meilleure;
}

// Villes hors de la vue de départ (France métropolitaine) : proposées en raccourci.
const Set<String> villesLointaines = {'Bruxelles', 'Sherbrooke', 'Saint-Denis - La Réunion'};
