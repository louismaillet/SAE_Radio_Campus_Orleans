import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

// La radio choisie par l'utilisateur (son slug), mémorisée sur l'appareil.
class RadioChoisie {
  static const cle = 'radio_choisie';

  // Valeur actuelle, pour que les onglets se mettent à jour quand elle change.
  static final ValueNotifier<String?> courante = ValueNotifier<String?>(null);

  static Future<String?> lire() async {
    final prefs = await SharedPreferences.getInstance();
    return courante.value = prefs.getString(cle);
  }

  // Mémorise la radio et fait passer l'abonnement aux notifications de l'ancienne à la nouvelle.
  static Future<void> enregistrer(String radioId) async {
    final prefs = await SharedPreferences.getInstance();
    final ancienne = prefs.getString(cle);
    await prefs.setString(cle, radioId);
    courante.value = radioId;
    NotificationService.abonnerRadio(ancienne, radioId);
  }
}
