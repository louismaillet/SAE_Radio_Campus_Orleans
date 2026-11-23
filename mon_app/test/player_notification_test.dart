import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_app/player/player_controller.dart';
import 'package:mon_app/player/player_notification.dart';

PlayerTrack _piste({required bool isLive}) =>
    PlayerTrack(url: 'https://x/son.mp3', title: 'Émission', subtitle: 'Radio', isLive: isLive);

void main() {
  test('rien en lecture : la notification disparaît', () {
    final etat = etatNotification(track: null, playing: false, loading: false, position: Duration.zero);
    expect(etat.processingState, AudioProcessingState.idle);
  });

  test('direct : lecture/pause et stop, sans ±10 s', () {
    final etat = etatNotification(track: _piste(isLive: true), playing: true, loading: false, position: Duration.zero);
    expect(etat.playing, isTrue);
    expect(etat.processingState, AudioProcessingState.ready);
    expect(etat.controls, [MediaControl.pause, MediaControl.stop]);
  });

  test('podcast en pause : reculer, lecture, avancer, stop', () {
    final etat = etatNotification(
      track: _piste(isLive: false),
      playing: false,
      loading: false,
      position: const Duration(seconds: 42),
    );
    expect(etat.controls, [MediaControl.rewind, MediaControl.play, MediaControl.fastForward, MediaControl.stop]);
    expect(etat.updatePosition, const Duration(seconds: 42));
  });

  test('chargement : état "loading"', () {
    final etat = etatNotification(track: _piste(isLive: true), playing: false, loading: true, position: Duration.zero);
    expect(etat.processingState, AudioProcessingState.loading);
  });
}
