import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

// Ce qui est en cours de lecture : un direct ou un podcast.
class PlayerTrack {
  const PlayerTrack({
    required this.url,
    required this.title,
    required this.subtitle,
    required this.isLive,
    this.artworkUrl,
    this.artworkBytes,
    this.accent,
  });

  final String url;
  final String title; // nom de l'émission ou de la radio
  final String subtitle; // nom de la radio, ou "En direct"
  final bool isLive;
  final String? artworkUrl;
  final Uint8List? artworkBytes; // logo envoyé par le gérant
  final Color? accent; // couleur de la radio, reprise par le lecteur
}

// Un seul lecteur audio pour toute l'appli : le lecteur du bas d'écran
// et tous les boutons "lecture" passent par lui.
class PlayerController extends ChangeNotifier {
  PlayerController() {
    _abonnements.addAll([
      _player.onPlayerStateChanged.listen((etat) {
        _playing = etat == PlayerState.playing;
        notifyListeners();
      }),
      _player.onDurationChanged.listen((duree) {
        _duration = duree;
        notifyListeners();
      }),
      // La position change très souvent : elle a son propre notifier
      // pour ne pas reconstruire toute l'appli plusieurs fois par seconde.
      _player.onPositionChanged.listen((p) => position.value = p),
      _player.onPlayerComplete.listen((_) {
        position.value = Duration.zero;
        _playing = false;
        notifyListeners();
      }),
    ]);
  }

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<Object?>> _abonnements = [];
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  PlayerTrack? _track;
  bool _playing = false;
  bool _loading = false;
  Duration? _duration;
  double _volume = 1;
  String? _error;

  PlayerTrack? get track => _track;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  Duration? get duration => _duration;
  double get volume => _volume;
  String? get error => _error;

  // Ce morceau est-il celui du lecteur ? (pour afficher pause sur le bon bouton)
  bool isCurrent(String url) => _track?.url == url;
  bool isPlayingUrl(String url) => isCurrent(url) && (_playing || _loading);

  // Lance un morceau. Si c'est celui en cours, on met en pause / reprend.
  Future<void> play(PlayerTrack track) async {
    if (isCurrent(track.url) && _error == null) {
      return toggle();
    }
    _track = track;
    _duration = null;
    _error = null;
    position.value = Duration.zero;
    await _lancer();
  }

  Future<void> toggle() async {
    final track = _track;
    if (track == null || _loading) {
      return;
    }
    if (_playing) {
      // Un direct ne se met pas en pause : on l'arrête, et on reprendra en direct.
      await (track.isLive ? _player.stop() : _player.pause());
      return;
    }
    if (track.isLive || _error != null) {
      await _lancer();
    } else {
      await _player.resume();
    }
  }

  Future<void> _lancer() async {
    _loading = true;
    notifyListeners();
    try {
      await _player.play(UrlSource(_track!.url), volume: _volume);
    } catch (_) {
      // Flux coupé, adresse http bloquée par le navigateur...
      _error = 'Lecture impossible pour le moment.';
      _playing = false;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> seek(Duration cible) => _player.seek(cible);

  Future<void> setVolume(double volume) async {
    _volume = volume;
    notifyListeners();
    await _player.setVolume(volume);
  }

  // Ferme le lecteur du bas.
  Future<void> close() async {
    await _player.stop();
    _track = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final abonnement in _abonnements) {
      abonnement.cancel();
    }
    position.dispose();
    _player.dispose();
    super.dispose();
  }
}

// Donne accès au lecteur depuis n'importe quel widget :
// PlayerScope.of(context).play(...)
class PlayerScope extends InheritedNotifier<PlayerController> {
  const PlayerScope({required PlayerController controller, required super.child, super.key})
      : super(notifier: controller);

  // Se reconstruit quand l'état du lecteur change.
  static PlayerController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerScope>()!.notifier!;

  // Juste pour appeler une action (dans un onPressed), sans s'abonner.
  static PlayerController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PlayerScope>()!.notifier!;
}
