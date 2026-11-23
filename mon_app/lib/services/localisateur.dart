import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// Résultat d'une demande de position.
sealed class ResultatPosition {}

class PositionTrouvee extends ResultatPosition {
  PositionTrouvee(this.position);
  final LatLng position;
}

// L'utilisateur a refusé l'accès à sa position.
class PositionRefusee extends ResultatPosition {}

// Position impossible à obtenir (service coupé, site non HTTPS, délai dépassé…).
class PositionIndisponible extends ResultatPosition {
  PositionIndisponible(this.message);
  final String message;
}

// Remplaçable dans les tests.
abstract class Localisateur {
  Future<ResultatPosition> position();
}

class LocalisateurGeolocator implements Localisateur {
  const LocalisateurGeolocator();

  @override
  Future<ResultatPosition> position() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return PositionIndisponible('La localisation est désactivée.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return PositionRefusee();
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
      );
      return PositionTrouvee(LatLng(p.latitude, p.longitude));
    } catch (e) {
      return PositionIndisponible(e.toString());
    }
  }
}
