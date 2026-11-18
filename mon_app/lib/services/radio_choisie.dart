import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

// La radio choisie par l'utilisateur (son slug), mémorisée sur l'appareil.
class RadioChoisie {
  static const cle = 'radio_choisie';

  static Future<String?> lire() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(cle);
  }

  // Mémorise la radio et fait passer l'abonnement aux notifications de l'ancienne à la nouvelle.
  static Future<void> enregistrer(String radioId) async {
    final prefs = await SharedPreferences.getInstance();
    final ancienne = prefs.getString(cle);
    await prefs.setString(cle, radioId);
    NotificationService.abonnerRadio(ancienne, radioId);
  }
}
