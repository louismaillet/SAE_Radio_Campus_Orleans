import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../layout/responsive.dart';
import '../../models/campus_radio.dart';
import '../../models/radio_settings.dart';
import '../../player/player_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/radio_palette.dart';
import '../../widgets/cards.dart';
import '../../widgets/images.dart';
import '../../widgets/smooth_dialog.dart';
import 'admin_page.dart';

// Contenu défilant d'une section, centré et limité en largeur.
class _SectionScroll extends StatelessWidget {
  const _SectionScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cote = Responsive.sidePadding(context);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // En bas : la place du bouton flottant "Enregistrer".
      padding: EdgeInsets.fromLTRB(cote, AppSpacing.md, cote, 96),
      children: children,
    );
  }
}

// Bloc de réglages avec titre et description.
class _Panneau extends StatelessWidget {
  const _Panneau({required this.titre, required this.child, this.description, this.action});

  final String titre;
  final String? description;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textes = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(titre, style: textes.titleMedium)),
              ?action,
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(description!, style: textes.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

// Blocs les uns sous les autres, espacés régulièrement.
class _Blocs extends StatelessWidget {
  const _Blocs({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: AppSpacing.md), children[i]],
      ],
    );
  }
}

String _libelleSource(PaletteSource source) => switch (source) {
  PaletteSource.gerant => 'Couleur choisie par toi',
  PaletteSource.logo => 'Couleur extraite de ton logo',
  PaletteSource.api => 'Couleur de ta radio sur Radio Campus',
  PaletteSource.defaut => 'Couleur du réseau',
};

// Mini-page de la radio avec ses couleurs, mise à jour à chaque réglage.
class _ApercuPage extends StatelessWidget {
  const _ApercuPage({required this.radio, required this.reglages, required this.apercuFuture, this.onVoir});

  final CampusRadio radio;
  final RadioSettings reglages; // réglages en cours (pas forcément enregistrés)
  final Future<RadioPalette>? apercuFuture;
  final VoidCallback? onVoir;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return FutureBuilder<RadioPalette>(
      future: apercuFuture,
      builder: (context, snapshot) {
        final palette = snapshot.data ?? RadioPaletteResolver.immediate(radio, settings: reglages);
        final theme = palette.theme(brightness);
        return _Panneau(
          titre: 'Aperçu de ma page',
          description: _libelleSource(palette.source),
          action: onVoir == null ? null : TextButton(onPressed: onVoir, child: const Text('Ouvrir')),
          child: AnimatedTheme(
            data: theme,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 190,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: palette.fond(brightness),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Builder(
                builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
                  final textes = Theme.of(context).textTheme;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: palette.halo()),
                        child: RadioLogo(url: radio.logoUrl, bytes: reglages.logo, size: 64),
                      ),
                      const Spacer(),
                      Text(radio.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textes.titleLarge),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(99)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded, size: 18, color: scheme.onPrimary),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Écouter en direct',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textes.labelMedium!.copyWith(color: scheme.onPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tableau de bord
// ---------------------------------------------------------------------------

class DashboardSection extends StatelessWidget {
  const DashboardSection({
    required this.radio,
    required this.reglages,
    required this.detailsFuture,
    required this.contenuFuture,
    required this.apercuFuture,
    required this.onVoirMaPage,
    super.key,
  });

  final CampusRadio radio;
  final RadioSettings reglages;
  final Future<RadioDetails> detailsFuture;
  final Future<List<RadioContent>> contenuFuture;
  final Future<RadioPalette>? apercuFuture;
  final VoidCallback onVoirMaPage;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<RadioDetails>(
      future: detailsFuture,
      builder: (context, details) => FutureBuilder<List<RadioContent>>(
        future: contenuFuture,
        builder: (context, contenu) {
          final podcasts = (contenu.data ?? []).where((c) => c.type == RadioContentType.podcast).toList();
          final enCours = !contenu.hasData && !contenu.hasError;
          final flux = reglages.fluxDirect(radio);

          return _SectionScroll(
            children: [
              Text('Bonjour !', style: textes.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Voici un résumé de ${radio.name}.',
                style: textes.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              _GrilleKpi(
                kpis: [
                  _Kpi(
                    icone: Icons.podcasts_rounded,
                    titre: 'Podcasts publiés',
                    valeur: enCours ? '…' : '${podcasts.length}',
                    couleur: scheme.primary,
                  ),
                  _Kpi(
                    icone: Icons.mic_rounded,
                    titre: 'Émissions',
                    valeur: details.hasData ? '${details.data!.shows.length}' : '…',
                    couleur: scheme.tertiary,
                  ),
                  _Kpi(
                    icone: Icons.sensors_rounded,
                    titre: 'Direct',
                    valeur: flux != null ? 'Actif' : 'Aucun flux',
                    couleur: flux != null ? Colors.green : scheme.error,
                  ),
                  // Pas encore de statistiques d'écoute : elles viendront avec Supabase.
                  _Kpi(
                    icone: Icons.headphones_rounded,
                    titre: 'Écoutes',
                    valeur: '—',
                    couleur: scheme.secondary,
                    note: 'Bientôt disponible',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Blocs(
                children: [
                  _Panneau(
                    titre: 'Derniers podcasts',
                    description: 'Les 5 derniers épisodes de tes émissions',
                    child: enCours
                        ? const Skeleton(height: 160)
                        : podcasts.isEmpty
                        ? const EmptyState(message: 'Aucun podcast publié pour le moment.')
                        : _ListePodcastsSimple(podcasts: podcasts.take(5).toList()),
                  ),
                  _ApercuPage(radio: radio, reglages: reglages, apercuFuture: apercuFuture, onVoir: onVoirMaPage),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Kpi {
  const _Kpi({required this.icone, required this.titre, required this.valeur, required this.couleur, this.note});

  final IconData icone;
  final String titre;
  final String valeur;
  final Color couleur;
  final String? note;
}

class _GrilleKpi extends StatelessWidget {
  const _GrilleKpi({required this.kpis});

  final List<_Kpi> kpis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textes = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, contraintes) {
        // 2 x 2 sur téléphone, 4 sur une ligne sur tablette.
        final colonnes = contraintes.maxWidth >= 560 ? 4 : 2;
        final largeur = (contraintes.maxWidth - 12 * (colonnes - 1)) / colonnes;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final kpi in kpis)
              Container(
                width: largeur,
                height: 124,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kpi.couleur.withValues(alpha: 0.16), scheme.surfaceContainerLow],
                  ),
                  border: Border.all(color: kpi.couleur.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(kpi.icone, color: kpi.couleur, size: 22),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: kpi.note == null
                              ? const SizedBox.shrink()
                              : Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      kpi.note!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textes.labelSmall,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: FittedBox(
                        key: ValueKey(kpi.valeur),
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(kpi.valeur, style: textes.headlineSmall),
                      ),
                    ),
                    Text(
                      kpi.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textes.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ListePodcastsSimple extends StatelessWidget {
  const _ListePodcastsSimple({required this.podcasts});

  final List<RadioContent> podcasts;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final p in podcasts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(dimension: 44, child: CoverImage(url: p.imageUrl)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textes.bodyMedium),
                      Text(
                        [if (p.showTitle != null) p.showTitle!, p.date].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textes.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Apparence : site ou version appli, logo, couleur
// ---------------------------------------------------------------------------

class AppearanceSection extends StatelessWidget {
  const AppearanceSection({
    required this.radio,
    required this.brouillon,
    required this.siteController,
    required this.apercuFuture,
    required this.onChanged,
    required this.onMessage,
    super.key,
  });

  final CampusRadio radio;
  final AdminDraft brouillon;
  final TextEditingController siteController;
  final Future<RadioPalette>? apercuFuture;
  final ValueChanged<AdminDraft> onChanged;
  final ValueChanged<String> onMessage;

  Future<void> _choisirLogo() async {
    final fichier = await FilePicker.pickFile(type: FileType.image);
    if (fichier == null) {
      return; // le gérant a annulé
    }
    final octets = await fichier.readAsBytes();
    // L'image est enregistrée en texte : on évite les fichiers trop lourds.
    if (octets.length > 1000000) {
      onMessage('Image trop lourde (1 Mo maximum).');
      return;
    }
    onChanged(brouillon.copyWith(logo: () => octets));
  }

  Future<void> _choisirCouleur(BuildContext context) async {
    Color choix = brouillon.couleur ?? Theme.of(context).colorScheme.primary;
    final valide = await showSmoothDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Couleur de ma page'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: choix,
            enableAlpha: false, // pas de transparence
            onColorChanged: (couleur) {
              choix = couleur;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Valider')),
        ],
      ),
    );
    if (valide == true) {
      onChanged(brouillon.copyWith(couleur: () => choix));
    }
  }

  Future<void> _extraireDuLogo() async {
    final couleur = await RadioPaletteResolver.couleurDuLogo(logoBytes: brouillon.logo, logoUrl: radio.logoUrl);
    if (couleur == null) {
      onMessage("Impossible de lire les couleurs de ce logo. Sur le web, envoie ton logo ici pour l'utiliser.");
      return;
    }
    onChanged(brouillon.copyWith(couleur: () => couleur));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reglagesApercu = RadioSettings(
      radioId: radio.id,
      afficherSite: brouillon.afficherSite,
      siteUrl: null,
      logo: brouillon.logo,
      couleur: brouillon.couleur,
    );

    return _SectionScroll(
      children: [
        _Blocs(
          children: [
            _ApercuPage(radio: radio, reglages: reglagesApercu, apercuFuture: apercuFuture),
            _Panneau(
              titre: 'Quand on ouvre ma radio',
              description: brouillon.afficherSite
                  ? "Ton site web s'ouvre dans l'appli, sous un en-tête avec le direct."
                  : 'Version appli : présentation, émissions, podcasts et actualités.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, icon: Icon(Icons.apps_rounded), label: Text('Version appli')),
                      ButtonSegment(value: true, icon: Icon(Icons.language_rounded), label: Text('Mon site web')),
                    ],
                    selected: {brouillon.afficherSite},
                    onSelectionChanged: (choix) => onChanged(brouillon.copyWith(afficherSite: choix.first)),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: brouillon.afficherSite
                        ? Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: TextField(
                              controller: siteController,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Adresse du site',
                                hintText: 'https://...',
                                prefixIcon: Icon(Icons.link_rounded),
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
            _Panneau(
              titre: 'Logo',
              description: 'PNG ou JPG, 1 Mo maximum. Ses couleurs servent à colorer ta page.',
              child: Row(
                children: [
                  RadioLogo(url: radio.logoUrl, bytes: brouillon.logo, size: 72),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _choisirLogo,
                          icon: const Icon(Icons.upload_rounded),
                          label: const Text('Choisir une image'),
                        ),
                        if (brouillon.logo != null)
                          TextButton(
                            onPressed: () => onChanged(brouillon.copyWith(logo: () => null)),
                            child: const Text('Logo d\'origine'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Panneau(
              titre: 'Couleur de ma page',
              description: 'Par défaut, elle est tirée automatiquement de ton logo.',
              child: Row(
                children: [
                  FutureBuilder<RadioPalette>(
                    future: apercuFuture,
                    builder: (context, snapshot) {
                      final couleur = brouillon.couleur ?? snapshot.data?.seed ?? scheme.primary;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: couleur,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: couleur.withValues(alpha: 0.5), blurRadius: 18)],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _choisirCouleur(context),
                          icon: const Icon(Icons.colorize_rounded),
                          label: const Text('Choisir…'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _extraireDuLogo,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Extraire du logo'),
                        ),
                        if (brouillon.couleur != null)
                          TextButton(
                            onPressed: () => onChanged(brouillon.copyWith(couleur: () => null)),
                            child: const Text('Automatique'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Flux audio du direct
// ---------------------------------------------------------------------------

class StreamSection extends StatelessWidget {
  const StreamSection({required this.radio, required this.brouillon, required this.onChanged, super.key});

  final CampusRadio radio;
  final AdminDraft brouillon;
  final ValueChanged<AdminDraft> onChanged;

  Future<void> _modifier(BuildContext context) async {
    final adresse = await showSmoothDialog<String>(
      context: context,
      builder: (context) => _DialogueFlux(initial: brouillon.streamUrl ?? radio.streamUrl ?? ''),
    );
    if (adresse != null) {
      // Même adresse que l'API : pas besoin de la garder en réglage.
      onChanged(brouillon.copyWith(streamUrl: () => adresse == radio.streamUrl ? null : adresse));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textes = Theme.of(context).textTheme;
    final flux = brouillon.streamUrl ?? radio.streamUrl;
    final personnalise = brouillon.streamUrl != null;

    return _SectionScroll(
      children: [
        _Panneau(
          titre: 'Flux du direct',
          description: "C'est ce flux que lancent le bouton « Écouter en direct » et le lecteur.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(personnalise ? Icons.edit_rounded : Icons.cloud_done_outlined, size: 16),
                  label: Text(personnalise ? 'Personnalisé' : "Fourni par l'API"),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link_rounded, color: scheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SelectableText(
                        flux ?? 'Aucun flux pour le moment',
                        style: textes.bodyMedium!.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
              // Un site en https ne peut pas lire un flux en http (contenu mixte bloqué).
              if (flux != null && flux.startsWith('http://')) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.tertiary, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        "Ce flux est en http : certains navigateurs bloquent sa lecture. Préfère une adresse en https.",
                        style: textes.bodySmall!.copyWith(color: scheme.tertiary),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (flux != null)
                    FilledButton.icon(
                      onPressed: () => PlayerScope.read(context).play(
                        PlayerTrack(
                          url: flux,
                          title: radio.name,
                          subtitle: 'Test du flux',
                          isLive: true,
                          artworkUrl: radio.logoUrl,
                          artworkBytes: brouillon.logo,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text("Tester l'écoute"),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _modifier(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier…'),
                  ),
                  if (personnalise)
                    TextButton(
                      onPressed: () => onChanged(brouillon.copyWith(streamUrl: () => null)),
                      child: const Text("Revenir au flux de l'API"),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogueFlux extends StatefulWidget {
  const _DialogueFlux({required this.initial});

  final String initial;

  @override
  State<_DialogueFlux> createState() => _DialogueFluxState();
}

class _DialogueFluxState extends State<_DialogueFlux> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _valider(String? texte) {
    final uri = Uri.tryParse((texte ?? '').trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      return 'Adresse invalide (elle doit commencer par https://)';
    }
    return null;
  }

  void _ok() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adresse du flux'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            validator: _valider,
            onFieldSubmitted: (_) => _ok(),
            decoration: const InputDecoration(hintText: 'https://…/live.mp3', prefixIcon: Icon(Icons.sensors_rounded)),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _ok, child: const Text('Valider')),
      ],
    );
  }
}
