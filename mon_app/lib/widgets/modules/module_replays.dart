import 'package:flutter/material.dart';

import '../../models/campus_radio.dart';
import '../../models/page_module.dart';
import '../../theme/app_theme.dart';
import '../cards.dart';
import '../images.dart';
import '../pressable.dart';
import 'modules.dart';

// Derniers podcasts des émissions de la radio (toutes, ou celles choisies par le gérant).
// Avec "toutes", l'auditeur peut filtrer par émission avec la bande d'émissions.
class ModuleReplays extends StatefulWidget {
  const ModuleReplays({required this.contexte, required this.rafraichissement, super.key});

  final ContexteModule contexte;
  final int rafraichissement;

  @override
  State<ModuleReplays> createState() => _ModuleReplaysState();
}

class _ModuleReplaysState extends State<ModuleReplays> {
  String? _emissionChoisie; // filtre de l'auditeur (null = aucune)
  late int _affiches = _pas;

  int get _pas => nombreDe(widget.contexte.module, 10);

  @override
  Widget build(BuildContext context) {
    final details = widget.contexte.details;
    final selection = listeDe(widget.contexte.module, 'emissions');
    // La bande de filtre n'a de sens que si toutes les émissions sont affichées.
    final shows = selection.isEmpty ? details.shows : const <RadioShow>[];

    return ChargementModule<List<RadioContent>>(
      titre: 'Derniers replays',
      sousTitre: shows.length > 1 ? 'Touchez une émission pour filtrer ses podcasts' : null,
      rafraichissement: widget.rafraichissement,
      charger: () => RadioRepository.getPodcastsRadio(details.showSlugs),
      builder: (context, podcasts) {
        final tous = filtrerReplays(
          podcasts,
          emissionsRadio: details.showSlugs,
          selection: _emissionChoisie != null ? [_emissionChoisie!] : selection,
          nombre: podcasts.length,
        );
        final visibles = tous.take(_affiches).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shows.length > 1) ...[
              _BandeEmissions(
                shows: shows,
                choisie: _emissionChoisie,
                onChanged: (slug) => setState(() {
                  _emissionChoisie = slug;
                  _affiches = _pas;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (visibles.isEmpty)
              const EmptyState(message: 'Aucun replay pour le moment.')
            else
              ListeCartes(
                children: [
                  for (final podcast in visibles)
                    PodcastTile(
                      podcast: podcast,
                      radioName: widget.contexte.radio.name,
                      accent: widget.contexte.palette.seed,
                    ),
                ],
              ),
            if (tous.length > visibles.length) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => setState(() => _affiches += _pas),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text('Voir plus (${tous.length - visibles.length})'),
              ),
            ],
          ],
        );
      },
    );
  }
}

// Émissions en bande horizontale : un appui filtre les replays.
class _BandeEmissions extends StatelessWidget {
  const _BandeEmissions({required this.shows, required this.choisie, required this.onChanged});

  final List<RadioShow> shows;
  final String? choisie;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textes = Theme.of(context).textTheme;
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shows.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final show = shows[i];
          final active = show.slug == choisie;
          return SizedBox(
            width: 150,
            child: Pressable(
              onTap: () => onChanged(active ? null : show.slug),
              builder: (context, pressed) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: active ? scheme.primary : Colors.transparent, width: 2.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CoverImage(url: show.imageUrl, icon: Icons.mic_rounded),
                          if (active)
                            ColoredBox(
                              color: scheme.primary.withValues(alpha: 0.35),
                              child: const Center(child: Icon(Icons.filter_alt_rounded, color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    show.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textes.labelLarge!.copyWith(color: active ? scheme.primary : null, height: 1.2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
