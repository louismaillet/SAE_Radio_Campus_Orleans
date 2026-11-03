import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Logo d'une radio : celui du gérant, sinon celui de l'API, sinon une icône.
// Posé sur un fond clair car beaucoup de logos sont prévus pour du blanc.
class RadioLogo extends StatelessWidget {
  const RadioLogo({this.url, this.bytes, this.size = 56, this.radius, super.key});

  final String? url;
  final Uint8List? bytes;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final icone = Icon(Icons.radio_rounded, size: size * 0.5, color: Colors.black38);
    Widget image = icone;
    if (bytes != null) {
      image = Image.memory(bytes!, fit: BoxFit.contain);
    } else if (url != null) {
      image = Image.network(
        url!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => icone,
      );
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius ?? size * 0.28),
        // Liseré discret pour que le blanc ne se perde pas sur un fond clair.
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: image),
    );
  }
}

// Image d'un podcast / d'une actualité, avec un dégradé de remplacement
// si elle est absente ou en erreur (certaines renvoient 404).
class CoverImage extends StatelessWidget {
  const CoverImage({required this.url, this.icon = Icons.graphic_eq_rounded, super.key});

  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remplacement = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
      ),
      child: Center(child: Icon(icon, size: 40, color: scheme.onPrimaryContainer.withValues(alpha: 0.6))),
    );
    if (url == null) {
      return remplacement;
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => remplacement,
      frameBuilder: (context, child, frame, synchrone) {
        if (synchrone) {
          return child;
        }
        // Apparition en fondu une fois l'image chargée.
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surfaceContainerHighest),
            AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

// Bloc gris qui "respire" pendant le chargement.
class Skeleton extends StatefulWidget {
  const Skeleton({this.height, this.radius = AppRadius.lg, super.key});

  final double? height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couleur = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 0.8).animate(_anim),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}
