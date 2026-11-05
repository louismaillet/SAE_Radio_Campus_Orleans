import 'package:flutter/material.dart';

// Élément "appuyable" : il s'enfonce légèrement sous le doigt.
// builder reçoit pressed pour animer d'autres détails (bordure, ombre...).
class Pressable extends StatefulWidget {
  const Pressable({required this.builder, this.onTap, this.onLongPress, super.key});

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _appui(bool valeur) {
    if (_pressed != valeur) {
      setState(() => _pressed = valeur);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _appui(true),
      onTapUp: (_) => _appui(false),
      onTapCancel: () => _appui(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.builder(context, _pressed),
      ),
    );
  }
}
