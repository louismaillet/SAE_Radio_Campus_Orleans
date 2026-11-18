import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mon_app/models/campus_radio.dart';
import 'package:mon_app/villes/villes.dart';

CampusRadio _radio(String id, String? ville) =>
    CampusRadio(id: id, name: 'Radio $id', logoUrl: null, streamUrl: null, websiteUrl: null, city: ville);

VilleRadio _ville(String nom, [LatLng? position]) => VilleRadio(nom: nom, position: position, radios: [_radio(nom, nom)]);

void main() {
  test('villesDuReseau regroupe et ignore les radios sans ville', () {
    final villes = villesDuReseau([_radio('t', 'Tours'), _radio('o', 'Orléans'), _radio('f', null)]);
    expect(villes.map((v) => v.nom), ['Orléans', 'Tours']);
    expect(villes.first.radios.single.id, 'o');
    expect(villes.first.position, isNotNull);
  });

  test('villesDuReseau regroupe plusieurs radios d\'une même ville', () {
    final villes = villesDuReseau([_radio('a', 'Paris'), _radio('b', 'Paris')]);
    expect(villes.single.radios.map((r) => r.id), ['a', 'b']);
  });

  test('villesDuReseau ignore les coordonnées manquantes', () {
    final villes = villesDuReseau([_radio('x', 'Atlantis')]);
    expect(villes.single.nom, 'Atlantis');
    expect(villes.single.position, isNull);
  });

  group('rechercherVilles', () {
    final villes = [_ville('Besançon'), _ville('Nancy - Metz'), _ville('Orléans'), _ville('Tours')];

    test('insensible aux accents, à la casse et aux espaces', () {
      expect(rechercherVilles(villes, 'orleans').map((v) => v.nom), ['Orléans']);
      expect(rechercherVilles(villes, 'BESANCON').map((v) => v.nom), ['Besançon']);
      expect(rechercherVilles(villes, 'nancy').map((v) => v.nom), ['Nancy - Metz']);
      expect(rechercherVilles(villes, '  tours ').map((v) => v.nom), ['Tours']);
    });

    test('texte vide : aucune suggestion', () {
      expect(rechercherVilles(villes, ''), isEmpty);
      expect(rechercherVilles(villes, '   '), isEmpty);
    });

    test('les villes qui commencent par le texte passent en premier', () {
      final res = rechercherVilles([_ville('Saint-Denis - La Réunion'), _ville('Denain')], 'den');
      expect(res.map((v) => v.nom), ['Denain', 'Saint-Denis - La Réunion']);
    });
  });

  group('plusProche', () {
    test('depuis Blois : Tours', () {
      final villes = [
        _ville('Orléans', const LatLng(47.902, 1.909)),
        _ville('Tours', const LatLng(47.394, 0.684)),
        _ville('Paris', const LatLng(48.857, 2.352)),
      ];
      final res = plusProche(villes, const LatLng(47.586, 1.335))!;
      expect(res.ville.nom, 'Tours');
      expect(res.km, inInclusiveRange(50, 56));
    });

    test('depuis Montréal : Sherbrooke', () {
      final villes = [_ville('Paris', const LatLng(48.857, 2.352)), _ville('Sherbrooke', const LatLng(45.40, -71.89))];
      expect(plusProche(villes, const LatLng(45.50, -73.57))!.ville.nom, 'Sherbrooke');
    });

    test('ignore les villes sans position, null si aucune', () {
      expect(plusProche([_ville('Atlantis')], const LatLng(0, 0)), isNull);
    });
  });

  test('coordonneesVilles couvre les 33 villes du réseau', () {
    const villesApi = [
      'Agen', 'Amiens', 'Angers', 'Avignon', 'Besançon', 'Bordeaux', 'Brest', 'Bruxelles', 'Caen', 'Castres',
      'Clermont-Ferrand', 'Corte', 'Dijon', 'Grenoble', 'Lille', 'Lyon', 'Marseille', 'Montpellier', 'Mulhouse',
      'Nancy - Metz', 'Orléans', 'Paris', 'Pau', 'Perpignan', 'Poitiers', 'Rennes', 'Rosny-sous-bois', 'Rouen',
      'Saint-Denis - La Réunion', 'Sherbrooke', 'Strasbourg', 'Toulouse', 'Tours',
    ];
    expect(villesApi.where((v) => !coordonneesVilles.containsKey(v)), isEmpty);
  });
}
