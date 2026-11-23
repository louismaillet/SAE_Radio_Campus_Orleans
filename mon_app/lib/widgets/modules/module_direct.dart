import 'package:flutter/material.dart';

import '../../player/player_controller.dart';
import '../live.dart';
import 'modules.dart';

// Le direct de la radio, là où le gérant l'a placé (masqué s'il n'y a pas de flux).
class ModuleDirect extends StatelessWidget {
  const ModuleDirect({required this.contexte, super.key});

  final ContexteModule contexte;

  @override
  Widget build(BuildContext context) {
    final radio = contexte.radio;
    final flux = contexte.reglages.fluxDirect(radio);
    if (flux == null) {
      return const SizedBox.shrink();
    }
    final track = PlayerTrack(
      url: flux,
      title: radio.name,
      subtitle: contexte.details.catchPhrase ?? radio.slogan ?? 'En direct',
      isLive: true,
      artworkUrl: radio.logoUrl,
      artworkBytes: contexte.reglages.logo,
      accent: contexte.palette.seed,
    );
    return SectionModule(titre: 'En direct', child: LiveButton(track: track));
  }
}
