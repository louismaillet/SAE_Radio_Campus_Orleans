import 'package:audio_service/audio_service.dart';

import 'player_controller.dart';

const Duration _saut = Duration(seconds: 10);

// Notification "lecteur" (comme Spotify) quand on quitte l'app : titre, radio, logo
// et boutons. Elle relaie les boutons au PlayerController et suit son état.
class PlayerNotification extends BaseAudioHandler {
  PlayerNotification(this._player) {
    _player.addListener(_maj);
  }

  final PlayerController _player;
  PlayerTrack? _pisteAffichee;

  // À appeler une fois au lancement, avant runApp.
  static Future<void> demarrer(PlayerController player) => AudioService.init(
    builder: () => PlayerNotification(player),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'radio_campus_lecteur',
      androidNotificationChannelName: 'Lecture en cours',
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  void _maj() {
    final track = _player.track;
    if (!identical(track, _pisteAffichee)) {
      _pisteAffichee = track;
      if (track != null) {
        final logo = track.artworkUrl;
        mediaItem.add(
          MediaItem(
            id: track.url,
            title: track.title,
            artist: track.subtitle,
            duration: _player.duration,
            artUri: logo == null ? null : Uri.tryParse(logo),
          ),
        );
      }
    }
    // shortcut: la position n'est envoyée qu'aux changements d'état (Android l'extrapole pendant la lecture),
    // un seek fait depuis l'app décale la barre jusqu'au prochain play/pause ; écouter player.position si gênant.
    playbackState.add(
      etatNotification(
        track: track,
        playing: _player.isPlaying,
        loading: _player.isLoading,
        position: _player.position.value,
      ),
    );
  }

  @override
  Future<void> play() => _player.toggle();

  @override
  Future<void> pause() => _player.toggle();

  @override
  Future<void> stop() => _player.close();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> rewind() => _player.skip(-_saut);

  @override
  Future<void> fastForward() => _player.skip(_saut);
}

// Ce que la notification affiche pour un état du lecteur. Sans piste : "idle", la notification disparaît.
PlaybackState etatNotification({
  required PlayerTrack? track,
  required bool playing,
  required bool loading,
  required Duration position,
}) {
  if (track == null) {
    return PlaybackState();
  }
  final lecture = playing ? MediaControl.pause : MediaControl.play;
  // Un direct n'a ni début ni fin : pas de ±10 s ni de barre de progression.
  final controles = track.isLive
      ? [lecture, MediaControl.stop]
      : [MediaControl.rewind, lecture, MediaControl.fastForward, MediaControl.stop];
  return PlaybackState(
    controls: controles,
    systemActions: track.isLive ? const {} : const {MediaAction.seek},
    androidCompactActionIndices: track.isLive ? const [0, 1] : const [0, 1, 2],
    processingState: loading ? AudioProcessingState.loading : AudioProcessingState.ready,
    playing: playing,
    updatePosition: position,
  );
}
