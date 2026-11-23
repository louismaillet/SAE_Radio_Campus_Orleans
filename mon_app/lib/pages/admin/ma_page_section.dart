import 'package:flutter/material.dart';

import '../../layout/responsive.dart';
import '../../models/campus_radio.dart';
import '../../models/page_module.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/modules/modules.dart';
import '../../widgets/smooth_dialog.dart';
import 'admin_page.dart';

// Le module Direct ne peut être placé qu'une fois ; les autres autant de fois qu'on veut.
bool peutAjouter(ModuleType type, List<PageModule> modules) {
  return type != ModuleType.direct || !modules.any((m) => m.type == ModuleType.direct);
}

// Déplace un module, avec les indices donnés par ReorderableListView.onReorder.
List<PageModule> deplacer(List<PageModule> modules, int ancien, int nouveau) {
  final liste = [...modules];
  final module = liste.removeAt(ancien);
  liste.insert(nouveau > ancien ? nouveau - 1 : nouveau, module);
  return liste;
}

// Résumé des réglages d'un module, affiché sous son nom.
String resumeModule(PageModule module, RadioDetails details) {
  if (!moduleBienRegle(module)) {
    return 'Non réglé';
  }
  String titreEmission(String slug) {
    for (final show in details.shows) {
      if (show.slug == slug) {
        return show.title;
      }
    }
    return 'émission introuvable';
  }

  final r = module.reglages;
  return switch (module.type) {
    ModuleType.aLaUne => switch (r['genre']) {
      'emission' => 'Émission : ${titreEmission(r['slug'] as String)}',
      'episode' => 'Un épisode choisi',
      _ => 'Un article choisi',
    },
    ModuleType.actualites => '${nombreDe(module, 5)} derniers articles du réseau',
    ModuleType.replays => () {
      final emissions = listeDe(module, 'emissions');
      final quoi = emissions.isEmpty ? 'toutes les émissions' : emissions.map(titreEmission).join(', ');
      return '${nombreDe(module, 10)} derniers · $quoi';
    }(),
    ModuleType.articlesTags => 'Tags : ${listeDe(module, 'tags').join(', ')}',
    ModuleType.emissionVedette =>
      '${titreEmission(r['emission'] as String)} · ${nombreDe(module, 5)} épisodes',
    ModuleType.direct => 'Bouton « Écouter en direct »',
  };
}

// Section « Ma page » : modules de la page version appli, dans l'ordre d'affichage.
class MaPageSection extends StatelessWidget {
  const MaPageSection({
    required this.radio,
    required this.details,
    required this.brouillon,
    required this.onChanged,
    super.key,
  });

  final CampusRadio radio;
  final Future<RadioDetails> details;
  final AdminDraft brouillon;
  final ValueChanged<AdminDraft> onChanged;

  List<PageModule> get _modules => brouillon.modules ?? modulesParDefaut();

  void _changer(List<PageModule> modules) => onChanged(brouillon.copyWith(modules: () => modules));

  Future<void> _regler(BuildContext context, RadioDetails details, int index) async {
    final module = _modules[index];
    if (module.type == ModuleType.direct) {
      return;
    }
    final reglages = await showSmoothDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DialogueReglages(module: module, radio: radio, details: details),
    );
    if (reglages != null) {
      final modules = [..._modules];
      modules[index] = module.copyWith(reglages: reglages);
      _changer(modules);
    }
  }

  Future<void> _ajouter(BuildContext context, RadioDetails details) async {
    final type = await showModalBottomSheet<ModuleType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final type in ModuleType.values)
              ListTile(
                leading: Icon(type.icone),
                title: Text(type.nom),
                subtitle: peutAjouter(type, _modules) ? null : const Text('Déjà sur ta page'),
                enabled: peutAjouter(type, _modules),
                onTap: () => Navigator.of(context).pop(type),
              ),
          ],
        ),
      ),
    );
    if (type == null || !context.mounted) {
      return;
    }
    var module = PageModule.nouveau(type);
    // Les modules à régler ouvrent leurs réglages avant d'être ajoutés.
    // Annuler ajoute quand même le module, signalé « Non réglé » dans la liste.
    if (!moduleBienRegle(module)) {
      final reglages = await showSmoothDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _DialogueReglages(module: module, radio: radio, details: details),
      );
      if (reglages != null) {
        module = module.copyWith(reglages: reglages);
      }
    }
    _changer([..._modules, module]);
  }

  @override
  Widget build(BuildContext context) {
    final cote = Responsive.sidePadding(context);
    final scheme = Theme.of(context).colorScheme;
    final textes = Theme.of(context).textTheme;

    return FutureBuilder<RadioDetails>(
      future: details,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: EmptyState(message: 'Impossible de charger les émissions de ta radio.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final details = snapshot.data!;
        final modules = _modules;

        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          // En bas : la place du bouton flottant "Enregistrer".
          padding: EdgeInsets.fromLTRB(cote, AppSpacing.md, cote, 96),
          header: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (brouillon.afficherSite)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      'Ta page affiche actuellement ton site web. Ces modules ne sont utilisés '
                      'qu\'en « Version appli » (réglage dans Apparence).',
                      style: textes.bodyMedium!.copyWith(color: scheme.onTertiaryContainer),
                    ),
                  ),
                Text(
                  'Sous ta présentation, ta page affiche ces modules dans cet ordre. '
                  'Fais-les glisser pour les réordonner, touche-en un pour le régler.',
                  style: textes.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          footer: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: () => _ajouter(context, details),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter un module'),
                ),
                if (brouillon.modules != null)
                  TextButton(
                    onPressed: () => onChanged(brouillon.copyWith(modules: () => null)),
                    child: const Text('Rétablir la page par défaut'),
                  ),
              ],
            ),
          ),
          itemCount: modules.length,
          onReorder: (ancien, nouveau) => _changer(deplacer(modules, ancien, nouveau)),
          itemBuilder: (context, i) {
            final module = modules[i];
            // Mal réglé ou visant une émission qui n'est plus celle de la radio : masqué sur la page.
            final masque = modulesAffichables([module], details).isEmpty;
            return Padding(
              key: ObjectKey(module),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(
                    color: masque ? scheme.error : scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => _regler(context, details, i),
                  leading: Icon(module.type.icone, color: scheme.primary),
                  title: Text(module.type.nom),
                  subtitle: Text(
                    masque ? '${resumeModule(module, details)} · non affiché' : resumeModule(module, details),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: masque ? TextStyle(color: scheme.error) : null,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Retirer',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _changer([...modules]..removeAt(i)),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_indicator_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Réglages d'un module. Renvoie les nouveaux réglages, ou null si annulé.
class _DialogueReglages extends StatefulWidget {
  const _DialogueReglages({required this.module, required this.radio, required this.details});

  final PageModule module;
  final CampusRadio radio;
  final RadioDetails details;

  @override
  State<_DialogueReglages> createState() => _DialogueReglagesState();
}

class _DialogueReglagesState extends State<_DialogueReglages> {
  late final Map<String, dynamic> _r = Map<String, dynamic>.from(widget.module.reglages);
  late final TextEditingController _titre = TextEditingController(text: _r['titre'] as String? ?? '');
  Future<List<Tag>>? _tags;
  Future<List<RadioContent>>? _elements; // éléments proposés pour À la Une

  ModuleType get _type => widget.module.type;

  @override
  void initState() {
    super.initState();
    if (_type == ModuleType.articlesTags) {
      _tags = RadioRepository.getTags();
    }
    _chargerElements();
  }

  @override
  void dispose() {
    _titre.dispose();
    super.dispose();
  }

  void _chargerElements() {
    if (_type != ModuleType.aLaUne) {
      return;
    }
    _elements = switch (_r['genre']) {
      'episode' => RadioRepository.getPodcastsRadio(widget.details.showSlugs).then((p) => p.take(30).toList()),
      'article' => RadioRepository.getArticlesDetailles(),
      _ => null,
    };
  }

  List<String> _liste(String cle) => listeDe(PageModule(type: _type, reglages: _r), cle);

  int _defaut() => _type == ModuleType.replays ? 10 : 5;

  void _valider() {
    final reglages = Map<String, dynamic>.from(_r);
    if (_type == ModuleType.articlesTags) {
      final titre = _titre.text.trim();
      if (titre.isEmpty) {
        reglages.remove('titre');
      } else {
        reglages['titre'] = titre;
      }
    }
    Navigator.of(context).pop(reglages);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_type.nom),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...switch (_type) {
                ModuleType.aLaUne => _champsALaUne(),
                ModuleType.replays => _champsReplays(),
                ModuleType.articlesTags => _champsTags(),
                ModuleType.emissionVedette => _champsEmission(),
                ModuleType.actualites || ModuleType.direct => <Widget>[],
              },
              if (_type != ModuleType.aLaUne && _type != ModuleType.direct) _champNombre(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _valider, child: const Text('Valider')),
      ],
    );
  }

  Widget _titreChamp(String texte) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
    child: Text(texte, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _champNombre() {
    final nombre = nombreDe(PageModule(type: _type, reglages: _r), _defaut());
    final unite = _type == ModuleType.emissionVedette ? 'épisodes' : 'éléments';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titreChamp('Nombre affiché : $nombre $unite'),
        Slider(
          value: nombre.toDouble(),
          min: 1,
          max: 20,
          divisions: 19,
          label: '$nombre',
          onChanged: (v) => setState(() => _r['nombre'] = v.round()),
        ),
      ],
    );
  }

  // Une ligne choisie / pas choisie (liste à choix unique).
  Widget _choix({required String titre, String? sousTitre, required bool choisi, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(titre, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: sousTitre == null ? null : Text(sousTitre),
      trailing: Icon(choisi ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
      selected: choisi,
      onTap: onTap,
    );
  }

  List<Widget> _champsEmission() {
    if (widget.details.shows.isEmpty) {
      return [const Text('Ta radio n\'a pas encore d\'émission sur Radio Campus.')];
    }
    return [
      _titreChamp('Émission mise en avant'),
      for (final show in widget.details.shows)
        _choix(
          titre: show.title,
          choisi: _r['emission'] == show.slug,
          onTap: () => setState(() => _r['emission'] = show.slug),
        ),
    ];
  }

  List<Widget> _champsReplays() {
    final choisies = _liste('emissions');
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Toutes mes émissions'),
        value: choisies.isEmpty,
        onChanged: (toutes) => setState(() {
          _r['emissions'] = toutes ? <String>[] : [for (final s in widget.details.shows.take(1)) s.slug];
        }),
      ),
      if (choisies.isNotEmpty)
        for (final show in widget.details.shows)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(show.title),
            value: choisies.contains(show.slug),
            onChanged: (coche) => setState(() {
              final liste = [...choisies];
              coche == true ? liste.add(show.slug) : liste.remove(show.slug);
              // Décocher la dernière émission revient à "toutes".
              _r['emissions'] = liste;
            }),
          ),
    ];
  }

  List<Widget> _champsTags() {
    final choisis = _liste('tags');
    return [
      TextField(
        controller: _titre,
        decoration: const InputDecoration(labelText: 'Titre de la section (facultatif)'),
      ),
      _titreChamp('Thèmes'),
      FutureBuilder<List<Tag>>(
        future: _tags,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Impossible de charger les thèmes.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in snapshot.data!)
                FilterChip(
                  label: Text(tag.nom),
                  selected: choisis.contains(tag.slug),
                  onSelected: (oui) => setState(() {
                    final liste = [...choisis];
                    oui ? liste.add(tag.slug) : liste.remove(tag.slug);
                    _r['tags'] = liste;
                  }),
                ),
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _champsALaUne() {
    final genre = _r['genre'] as String?;
    return [
      _titreChamp('Que veux-tu mettre à la Une ?'),
      SegmentedButton<String>(
        emptySelectionAllowed: true,
        segments: const [
          ButtonSegment(value: 'emission', label: Text('Émission')),
          ButtonSegment(value: 'episode', label: Text('Épisode')),
          ButtonSegment(value: 'article', label: Text('Article')),
        ],
        selected: {?genre},
        onSelectionChanged: (choix) => setState(() {
          if (choix.isEmpty) {
            return;
          }
          _r['genre'] = choix.first;
          _r.remove('slug');
          _chargerElements();
        }),
      ),
      if (genre == 'emission')
        for (final show in widget.details.shows)
          _choix(
            titre: show.title,
            choisi: _r['slug'] == show.slug,
            onTap: () => setState(() => _r['slug'] = show.slug),
          ),
      if (genre == 'episode' || genre == 'article')
        FutureBuilder<List<RadioContent>>(
          future: _elements,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(padding: EdgeInsets.only(top: AppSpacing.md), child: Text('Chargement impossible.'));
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final elements = snapshot.data!.where((e) => e.slug != null).toList();
            if (elements.isEmpty) {
              return const Padding(padding: EdgeInsets.only(top: AppSpacing.md), child: Text('Rien à proposer.'));
            }
            return Column(
              children: [
                for (final e in elements)
                  _choix(
                    titre: e.title,
                    sousTitre: [?e.showTitle, e.date].join(' · '),
                    choisi: _r['slug'] == e.slug,
                    onTap: () => setState(() => _r['slug'] = e.slug),
                  ),
              ],
            );
          },
        ),
    ];
  }
}
