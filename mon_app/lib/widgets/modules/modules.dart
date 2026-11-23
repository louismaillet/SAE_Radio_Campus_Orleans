import 'package:flutter/material.dart';

import '../../layout/responsive.dart';
import '../../models/campus_radio.dart';
import '../../models/page_module.dart';
import '../../models/radio_settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/radio_palette.dart';
import '../cards.dart';
import '../images.dart';
import 'module_a_la_une.dart';
import 'module_actualites.dart';
import 'module_articles_tags.dart';
import 'module_direct.dart';
import 'module_emission_vedette.dart';
import 'module_replays.dart';

// Le module a-t-il tous ses réglages ? (sans vérifier que l'API connaît encore l'élément)
bool moduleBienRegle(PageModule module) {
  final r = module.reglages;
  return switch (module.type) {
    ModuleType.aLaUne =>
      ['emission', 'episode', 'article'].contains(r['genre']) && r['slug'] is String && (r['slug'] as String).isNotEmpty,
    ModuleType.articlesTags => listeDe(module, 'tags').isNotEmpty,
    ModuleType.emissionVedette => r['emission'] is String && (r['emission'] as String).isNotEmpty,
    ModuleType.actualites || ModuleType.replays || ModuleType.direct => true,
  };
}

// Modules à afficher aux auditeurs, dans l'ordre du gérant :
// on retire ceux qui sont mal réglés ou qui visent une émission qui n'est plus celle de la radio.
List<PageModule> modulesAffichables(List<PageModule> modules, RadioDetails details) {
  bool emissionConnue(Object? slug) => details.showSlugs.contains(slug);

  return modules.where((module) {
    if (!moduleBienRegle(module)) {
      return false;
    }
    final r = module.reglages;
    return switch (module.type) {
      ModuleType.emissionVedette => emissionConnue(r['emission']),
      ModuleType.aLaUne => r['genre'] != 'emission' || emissionConnue(r['slug']),
      ModuleType.replays => listeDe(module, 'emissions').isEmpty || listeDe(module, 'emissions').any(emissionConnue),
      _ => true,
    };
  }).toList();
}

// Ce dont tous les modules ont besoin.
class ContexteModule {
  const ContexteModule({
    required this.module,
    required this.radio,
    required this.details,
    required this.reglages,
    required this.palette,
  });

  final PageModule module;
  final CampusRadio radio;
  final RadioDetails details;
  final RadioSettings reglages;
  final RadioPalette palette;
}

// Un module de la page radio, sous forme de sliver.
// [rafraichissement] augmente à chaque "tirer pour rafraîchir" : le module recharge alors ses données.
class ModuleSliver extends StatelessWidget {
  const ModuleSliver({
    required this.module,
    required this.radio,
    required this.details,
    required this.reglages,
    required this.palette,
    required this.rafraichissement,
    super.key,
  });

  final PageModule module;
  final CampusRadio radio;
  final RadioDetails details;
  final RadioSettings reglages;
  final RadioPalette palette;
  final int rafraichissement;

  @override
  Widget build(BuildContext context) {
    final contexte = ContexteModule(
      module: module,
      radio: radio,
      details: details,
      reglages: reglages,
      palette: palette,
    );
    final Widget contenu = switch (module.type) {
      ModuleType.aLaUne => ModuleALaUne(contexte: contexte, rafraichissement: rafraichissement),
      ModuleType.actualites => ModuleActualites(contexte: contexte, rafraichissement: rafraichissement),
      ModuleType.replays => ModuleReplays(contexte: contexte, rafraichissement: rafraichissement),
      ModuleType.articlesTags => ModuleArticlesTags(contexte: contexte, rafraichissement: rafraichissement),
      ModuleType.emissionVedette => ModuleEmissionVedette(contexte: contexte, rafraichissement: rafraichissement),
      ModuleType.direct => ModuleDirect(contexte: contexte),
    };
    return SliverContent(sliver: SliverToBoxAdapter(child: contenu));
  }
}

// Charge les données d'un module et affiche chargement / erreur / contenu.
// Une erreur ne touche que ce module.
class ChargementModule<T> extends StatefulWidget {
  const ChargementModule({
    required this.titre,
    required this.charger,
    required this.builder,
    required this.rafraichissement,
    this.sousTitre,
    this.hauteurSquelette = 86,
    super.key,
  });

  // null = pas de titre de section (ex. À la Une).
  final String? titre;
  final String? sousTitre;
  final Future<T> Function() charger;
  // Renvoie null pour masquer le module (élément introuvable).
  final Widget? Function(BuildContext context, T donnees) builder;
  final int rafraichissement;
  final double hauteurSquelette;

  @override
  State<ChargementModule<T>> createState() => _ChargementModuleState<T>();
}

class _ChargementModuleState<T> extends State<ChargementModule<T>> {
  late Future<T> _future = widget.charger();

  @override
  void didUpdateWidget(ChargementModule<T> ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.rafraichissement != widget.rafraichissement) {
      _future = widget.charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        final Widget corps;
        if (snapshot.hasError) {
          corps = EmptyState(
            message: 'Contenu indisponible.',
            onRetry: () => setState(() => _future = widget.charger()),
          );
        } else if (snapshot.connectionState != ConnectionState.done) {
          // (pas hasData : un module peut charger null pour se masquer)
          corps = Skeleton(height: widget.hauteurSquelette, radius: AppRadius.md);
        } else {
          final contenu = widget.builder(context, snapshot.data as T);
          if (contenu == null) {
            return const SizedBox.shrink();
          }
          corps = contenu;
        }
        return SectionModule(titre: widget.titre, sousTitre: widget.sousTitre, child: corps);
      },
    );
  }
}

// Espacement au-dessus du module et titre de section.
class SectionModule extends StatelessWidget {
  const SectionModule({required this.titre, required this.child, this.sousTitre, super.key});

  final String? titre;
  final String? sousTitre;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titre != null) SectionHeader(title: titre!, subtitle: sousTitre),
          child,
        ],
      ),
    );
  }
}

// Liste verticale de cartes espacées.
class ListeCartes extends StatelessWidget {
  const ListeCartes({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
      ],
    );
  }
}
