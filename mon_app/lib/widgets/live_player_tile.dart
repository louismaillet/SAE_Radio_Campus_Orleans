import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class LivePlayerTile extends StatefulWidget {
  const LivePlayerTile({required this.streamUrl, super.key});

  final String streamUrl;

  @override
  State<LivePlayerTile> createState() => _LivePlayerTileState();
}

class _LivePlayerTileState extends State<LivePlayerTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playing = state == PlayerState.playing);
      }
    });
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      return;
    }
    setState(() => _loading = true);
    await _player.play(UrlSource(widget.streamUrl));
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListTile(
        leading: _loading
            ? const CircularProgressIndicator()
            : Icon(_playing ? Icons.stop : Icons.play_arrow),
        title: const Text('Direct'),
        subtitle: Text(_playing ? 'Lecture en cours' : 'Écouter la radio en direct'),
        onTap: _loading ? null : _toggle,
      );
}
