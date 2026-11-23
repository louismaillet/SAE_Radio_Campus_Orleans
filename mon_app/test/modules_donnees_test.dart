import 'package:flutter_test/flutter_test.dart';
import 'package:mon_app/models/campus_radio.dart';

RadioContent _article(String titre, List<String> tags) => RadioContent(
  type: RadioContentType.news,
  title: titre,
  description: '',
  date: '01/01/2026',
  audioUrl: null,
  imageUrl: null,
  tags: tags,
);

RadioContent _podcast(String titre, String emission) => RadioContent(
  type: RadioContentType.podcast,
  title: titre,
  description: '',
  date: '01/01/2026',
  audioUrl: 'https://exemple/a.mp3',
  imageUrl: null,
  showSlug: emission,
);

void main() {
  final articles = [
    _article('a', ['a']),
    _article('b', ['b']),
    _article('ac', ['a', 'c']),
    _article('rien', []),
  ];

  test('filtrerParTags garde les articles avec au moins un tag', () {
    expect(filtrerParTags(articles, ['a', 'c'], 10).map((a) => a.title), ['a', 'ac']);
  });

  test('filtrerParTags sans tag ni résultat', () {
    expect(filtrerParTags(articles, [], 10), isEmpty);
    expect(filtrerParTags(articles, ['z'], 10), isEmpty);
  });

  test('filtrerParTags tronque', () {
    final cinq = [for (var i = 0; i < 5; i++) _article('$i', ['a'])];
    expect(filtrerParTags(cinq, ['a'], 2).length, 2);
  });

  final podcasts = [_podcast('1', 'e1'), _podcast('2', 'autre'), _podcast('3', 'e2'), _podcast('4', 'e1')];

  test('filtrerReplays sélection vide = toutes les émissions de la radio', () {
    final resultat = filtrerReplays(podcasts, emissionsRadio: ['e1', 'e2'], selection: [], nombre: 10);
    expect(resultat.map((p) => p.title), ['1', '3', '4']);
  });

  test('filtrerReplays sélection', () {
    expect(
      filtrerReplays(podcasts, emissionsRadio: ['e1', 'e2'], selection: ['e2'], nombre: 10).map((p) => p.title),
      ['3'],
    );
    expect(filtrerReplays(podcasts, emissionsRadio: ['e1', 'e2'], selection: ['autre'], nombre: 10), isEmpty);
  });

  test('filtrerReplays tronque', () {
    expect(filtrerReplays(podcasts, emissionsRadio: ['e1', 'e2'], selection: [], nombre: 2).length, 2);
  });

  test('fromNewsJson lit slug et tags', () {
    final avecTags = RadioContent.fromNewsJson({
      'title': 't',
      'slug': 's',
      'publishedAt': 0,
      'tags': {
        'member': [
          {'slug': 't1'},
        ],
      },
    });
    expect(avecTags.slug, 's');
    expect(avecTags.tags, ['t1']);

    final sansTags = RadioContent.fromNewsJson({'title': 't', 'slug': 's', 'publishedAt': 0});
    expect(sansTags.tags, isEmpty);
  });
}
