import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

// La radio choisie par l'utilisateur (son slug), mémorisée sur l'appareil.
class RadioChoisie {
  static const cle = 'radio_choisie';
  static const cleChoixFait = 'choix_radio_fait';

  // Valeur actuelle, pour que les onglets se mettent à jour quand elle change.
  static final ValueNotifier<String?> courante = ValueNotifier<String?>(null);

  // Vrai une fois le choix fait (sur la carte, ou radio par défaut dans Explorer) :
  // la carte n'est alors plus proposée, ni la question de la radio par défaut.
  static final ValueNotifier<bool> choixFait = ValueNotifier<bool>(false);

  static Future<String?> lire() async {
    final prefs = await SharedPreferences.getInstance();
    final radio = prefs.getString(cle);
    // Une radio déjà mémorisée (ancienne version de l'app) vaut choix fait.
    choixFait.value = (prefs.getBool(cleChoixFait) ?? false) || radio != null;
    return courante.value = radio;
  }

  // Mémorise la radio et fait passer l'abonnement aux notifications de l'ancienne à la nouvelle.
  static Future<void> enregistrer(String radioId) async {
    final prefs = await SharedPreferences.getInstance();
    final ancienne = prefs.getString(cle);
    await prefs.setString(cle, radioId);
    await prefs.setBool(cleChoixFait, true);
    courante.value = radioId;
    choixFait.value = true;
    NotificationService.abonnerRadio(ancienne, radioId);
  }

  // Choix fait sur la carte sans définir de radio par défaut.
  static Future<void> terminerChoix() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(cleChoixFait, true);
    choixFait.value = true;
  }
}
