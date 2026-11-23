import 'package:audioplayers/audioplayers.dart' show PlayerState;

import 'lecteur_natif.dart' if (dart.library.js_interop) 'lecteur_web.dart';

// Ce dont PlayerController a besoin d'un lecteur audio.
// Android/Windows : le plugin audioplayers. Web : une balise <audio> (voir lecteur_web.dart).
abstract class Lecteur {
  factory Lecteur() => creerLecteur();

  Stream<PlayerState> get onPlayerStateChanged;
  Stream<Duration> get onDurationChanged;
  Stream<Duration> get onPositionChanged;
  Stream<void> get onPlayerComplete;

  Future<void> play(String url);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}
