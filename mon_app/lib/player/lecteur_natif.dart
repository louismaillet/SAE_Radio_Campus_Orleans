import 'package:audioplayers/audioplayers.dart';

import 'lecteur.dart';

Lecteur creerLecteur() => LecteurNatif();

// Android / Windows : simple passe-plat vers audioplayers.
class LecteurNatif implements Lecteur {
  final AudioPlayer _p = AudioPlayer();

  @override
  Stream<PlayerState> get onPlayerStateChanged => _p.onPlayerStateChanged;
  @override
  Stream<Duration> get onDurationChanged => _p.onDurationChanged;
  @override
  Stream<Duration> get onPositionChanged => _p.onPositionChanged;
  @override
  Stream<void> get onPlayerComplete => _p.onPlayerComplete;

  @override
  Future<void> play(String url) => _p.play(UrlSource(url));
  @override
  Future<void> pause() => _p.pause();
  @override
  Future<void> resume() => _p.resume();
  @override
  Future<void> stop() => _p.stop();
  @override
  Future<void> seek(Duration position) => _p.seek(position);
  @override
  Future<void> dispose() => _p.dispose();
}
