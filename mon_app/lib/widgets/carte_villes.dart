import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../villes/villes.dart';

// Carte des villes du réseau : fond épuré (clair ou sombre selon le thème),
// un marqueur par ville, boutons de zoom et de recentrage à portée de pouce.
class CarteVilles extends StatefulWidget {
  const CarteVilles({
    required this.villes,
    required this.onChoisir,
    this.selection,
    this.margeHaut = 0,
    this.margeBas = 0,
    this.margeAttribution,
    super.key,
  });

  final List<VilleRadio> villes;
  final VilleRadio? selection;
  final ValueChanged<VilleRadio> onChoisir;
  // Place occupée par la barre de recherche (haut) et le panneau (bas) posés sur la carte.
  final double margeHaut;
  final double margeBas;
  // Hauteur du panneau au repos, pour placer le bouton de crédits juste au-dessus.
  final double? margeAttribution;

  @override
  State<CarteVilles> createState() => _CarteVillesState();
}

class _CarteVillesState extends State<CarteVilles> with TickerProviderStateMixin {
  static const _esri = 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas';
  static const _centreFrance = LatLng(46.6, 2.4);
  static const _zoomFrance = 5.0;
  static const _zoomVille = 9.0;

  final MapController _controleur = MapController();
  AnimationController? _animation;
  bool _prete = false;

  @override
  void didUpdateWidget(CarteVilles ancien) {
    super.didUpdateWidget(ancien);
    // Nouvelle ville choisie (recherche, position, raccourci) : on y va en douceur.
    final position = widget.selection?.position;
    if (position != null && widget.selection != ancien.selection) {
      _allerA(position, _zoomVille);
    }
  }

  @override
  void dispose() {
    _animation?.dispose();
    _controleur.dispose();
    super.dispose();
  }

  // Le point visé apparaît au centre de la partie visible (entre barre et panneau).
  Offset get _decalage => Offset(0, (widget.margeHaut - widget.margeBas) / 2);

  void _allerA(LatLng cible, double zoom) {
    if (!_prete) return;
    _animation?.dispose();
    final depart = _controleur.camera;
    final lat = Tween<double>(begin: depart.center.latitude, end: cible.latitude);
    final lng = Tween<double>(begin: depart.center.longitude, end: cible.longitude);
    final z = Tween<double>(begin: depart.zoom, end: zoom);
    final animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    final courbe = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
    animation.addListener(() {
      _controleur.move(
        LatLng(lat.evaluate(courbe), lng.evaluate(courbe)),
        z.evaluate(courbe),
        offset: _decalage * courbe.value,
      );
    });
    _animation = animation..forward();
  }

  void _zoomer(double delta) {
    final camera = _controleur.camera;
    _allerA(camera.center, (camera.zoom + delta).clamp(2, 18).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controleur,
          options: MapOptions(
            initialCenter: widget.selection?.position ?? _centreFrance,
            initialZoom: widget.selection?.position != null ? _zoomVille : _zoomFrance,
            minZoom: 2,
            maxZoom: 18,
            backgroundColor: sombre ? const Color(0xFF1B1D22) : const Color(0xFFE9ECEF),
            // Pas de rotation : sur téléphone, on la déclenche sans le vouloir.
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () => _prete = true,
          ),
          children: [
            // Fond Esri « Canvas » : gris neutre, sans clé d'API, puis les noms de lieux par-dessus.
            TileLayer(
              urlTemplate: '$_esri/World_${sombre ? 'Dark' : 'Light'}_Gray_Base/MapServer/tile/{z}/{y}/{x}',
              maxNativeZoom: 16,
              userAgentPackageName: 'fr.radiocampus.mon_app',
            ),
            TileLayer(
              urlTemplate: '$_esri/World_${sombre ? 'Dark' : 'Light'}_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
              maxNativeZoom: 16,
              userAgentPackageName: 'fr.radiocampus.mon_app',
            ),
            _CoucheVilles(villes: widget.villes, selection: widget.selection, onChoisir: widget.onChoisir),
            Padding(
              padding: EdgeInsets.only(bottom: widget.margeAttribution ?? widget.margeBas),
              child: const RichAttributionWidget(
                alignment: AttributionAlignment.bottomRight,
                attributions: [
                  TextSourceAttribution('Esri, HERE, Garmin'),
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ),
          ],
        ),
        // Commandes à droite, sous la barre de recherche.
        Positioned(
          top: widget.margeHaut + 12,
          right: 12,
          child: Column(
            children: [
              _BoutonCarte(icone: Icons.add_rounded, label: 'Zoomer', onPressed: () => _zoomer(1)),
              const SizedBox(height: 8),
              _BoutonCarte(icone: Icons.remove_rounded, label: 'Dézoomer', onPressed: () => _zoomer(-1)),
              const SizedBox(height: 8),
              _BoutonCarte(
                icone: Icons.zoom_out_map_rounded,
                label: 'Voir toute la France',
                onPressed: () => _allerA(_centreFrance, _zoomFrance),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoutonCarte extends StatelessWidget {
  const _BoutonCarte({required this.icone, required this.label, required this.onPressed});

  final IconData icone;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black45,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icone, color: scheme.onSurface),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      ),
    );
  }
}

// Marqueurs des villes ; les noms s'affichent quand on a assez zoomé.
class _CoucheVilles extends StatelessWidget {
  const _CoucheVilles({required this.villes, required this.selection, required this.onChoisir});

  final List<VilleRadio> villes;
  final VilleRadio? selection;
  final ValueChanged<VilleRadio> onChoisir;

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    final avecPosition = villes.where((v) => v.position != null).toList()
      // La ville choisie est dessinée en dernier, donc au-dessus des autres.
      ..sort((a, b) => (a == selection ? 1 : 0) - (b == selection ? 1 : 0));
    return MarkerLayer(
      markers: [
        for (final ville in avecPosition)
          Marker(
            point: ville.position!,
            width: 150,
            height: 100,
            child: _MarqueurVille(
              ville: ville,
              choisie: ville == selection,
              afficherNom: zoom >= 6.5 || ville == selection,
              onTap: () => onChoisir(ville),
            ),
          ),
      ],
    );
  }
}

class _MarqueurVille extends StatelessWidget {
  const _MarqueurVille({required this.ville, required this.choisie, required this.afficherNom, required this.onTap});

  final VilleRadio ville;
  final bool choisie;
  final bool afficherNom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final couleur = choisie ? scheme.tertiary : scheme.primary;
    final taille = choisie ? 30.0 : 18.0;
    return Semantics(
      button: true,
      selected: choisie,
      label: '${ville.nom}, ${ville.radios.map((r) => r.name).join(', ')}',
      excludeSemantics: true,
      child: Column(
        children: [
          // Espace pour que le centre du point tombe pile sur la ville.
          const SizedBox(height: 26),
          // Zone tactile de 48 dp autour du point.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  width: taille,
                  height: taille,
                  decoration: BoxDecoration(
                    color: couleur,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: choisie ? 4 : 3),
                    boxShadow: [
                      BoxShadow(color: couleur.withValues(alpha: 0.45), blurRadius: choisie ? 16 : 8, spreadRadius: choisie ? 4 : 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (afficherNom)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: choisie ? scheme.tertiary : scheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Text(
                  ville.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: choisie ? scheme.onTertiary : scheme.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
