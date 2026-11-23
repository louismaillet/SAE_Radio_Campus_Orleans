import 'dart:async';
import 'dart:js_interop';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:web/web.dart' as web;

import 'lecteur.dart';

Lecteur creerLecteur() => LecteurWeb();

// Web : une simple balise <audio>, sans Web Audio (audioplayers l'utilise et Safari iOS
// reste alors muet : interrupteur silencieux, flux). Pas de crossOrigin : pas besoin de CORS.
class LecteurWeb implements Lecteur {
  LecteurWeb() {
    _ecouter('playing', () => _etat.add(PlayerState.playing));
    _ecouter('pause', () => _etat.add(PlayerState.paused));
    _ecouter('error', () => _etat.add(PlayerState.stopped));
    _ecouter('ended', () {
      _etat.add(PlayerState.completed);
      _fin.add(null);
    });
    _ecouter('durationchange', () {
      if (_audio.duration.isFinite) {
        _duree.add(Duration(milliseconds: (_audio.duration * 1000).round()));
      }
    });
    _ecouter('timeupdate', () => _position.add(Duration(milliseconds: (_audio.currentTime * 1000).round())));
  }

  final web.HTMLAudioElement _audio = web.HTMLAudioElement();
  final _etat = StreamController<PlayerState>.broadcast();
  final _duree = StreamController<Duration>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _fin = StreamController<void>.broadcast();

  void _ecouter(String evenement, void Function() action) {
    _audio.addEventListener(evenement, ((web.Event _) => action()).toJS);
  }

  @override
  Stream<PlayerState> get onPlayerStateChanged => _etat.stream;
  @override
  Stream<Duration> get onDurationChanged => _duree.stream;
  @override
  Stream<Duration> get onPositionChanged => _position.stream;
  @override
  Stream<void> get onPlayerComplete => _fin.stream;

  // Doit être appelé tout de suite après le toucher : iOS refuse de lancer le son sinon.
  @override
  Future<void> play(String url) {
    _audio.src = url;
    return _audio.play().toDart;
  }

  @override
  Future<void> pause() async => _audio.pause();

  @override
  Future<void> resume() => _audio.play().toDart;

  // Vide la source : sinon le navigateur continue à télécharger le direct.
  @override
  Future<void> stop() async {
    _audio.pause();
    _audio.removeAttribute('src');
    _audio.load();
    _etat.add(PlayerState.stopped);
  }

  @override
  Future<void> seek(Duration position) async => _audio.currentTime = position.inMilliseconds / 1000;

  @override
  Future<void> dispose() async => stop();
}
