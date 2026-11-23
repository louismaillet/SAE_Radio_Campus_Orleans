import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// Résultat d'une demande de position.
sealed class ResultatPosition {}

class PositionTrouvee extends ResultatPosition {
  PositionTrouvee(this.position);
  final LatLng position;
}

// L'utilisateur a refusé l'accès à sa position.
// Refus définitif (« Ne plus demander ») : seule la page des réglages de l'app permet de l'autoriser.
class PositionRefusee extends ResultatPosition {
  PositionRefusee({this.definitif = false});
  final bool definitif;
}

// Position impossible à obtenir (service coupé, site non HTTPS, délai dépassé…).
class PositionIndisponible extends ResultatPosition {
  PositionIndisponible(this.message, {this.serviceDesactive = false});
  final String message;
  final bool serviceDesactive; // la localisation du téléphone est coupée
}

// Remplaçable dans les tests.
abstract class Localisateur {
  Future<ResultatPosition> position();

  // Ouvre les réglages de localisation du téléphone, ou ceux de l'app (permission).
  Future<void> ouvrirReglages({required bool localisation});
}

class LocalisateurGeolocator implements Localisateur {
  const LocalisateurGeolocator();

  @override
  Future<ResultatPosition> position() async {
    try {
      // La permission d'abord : la demande s'affiche même si la localisation est coupée.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return PositionRefusee(definitif: true);
      }
      if (permission == LocationPermission.denied) {
        return PositionRefusee();
      }
      try {
        // Sur Android, si la localisation est coupée, le système propose de l'activer.
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
        );
        return PositionTrouvee(LatLng(p.latitude, p.longitude));
      } on LocationServiceDisabledException {
        return PositionIndisponible('La localisation est désactivée.', serviceDesactive: true);
      } catch (_) {
        // Pas de position fraîche (délai dépassé…) : la dernière connue suffit pour trouver la ville.
        final derniere = await Geolocator.getLastKnownPosition();
        if (derniere != null) return PositionTrouvee(LatLng(derniere.latitude, derniere.longitude));
        rethrow;
      }
    } catch (e) {
      return PositionIndisponible(e.toString());
    }
  }

  @override
  Future<void> ouvrirReglages({required bool localisation}) async {
    try {
      if (localisation) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {
      // Pas de page de réglages sur cette plateforme.
    }
  }
}
