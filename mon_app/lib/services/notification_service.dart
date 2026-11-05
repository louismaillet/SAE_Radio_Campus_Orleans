import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../config.dart';

// Réception des notifications push (Firebase Cloud Messaging).
// Chaque téléphone s'abonne à deux "topics" :
//   - "toutes" : notifications du gérant national (Radio Campus France) ;
//   - "radio_<slug>" : notifications de sa radio par défaut.
// L'envoi est fait par la fonction Supabase "envoyer-notification".
class NotificationService {
  // Les notifications ne marchent que sur Android, et seulement si Firebase est configuré.
  static bool get actif => Platform.isAndroid && firebaseOptions.apiKey.isNotEmpty;

  // Sert à afficher un bandeau quand une notification arrive avec l'app ouverte.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // À appeler au lancement de l'app, avant runApp.
  static Future<void> initialiser() async {
    if (!actif) {
      return;
    }
    await Firebase.initializeApp(options: firebaseOptions);
  }

  // À appeler après runApp : demande la permission et s'abonne aux notifications nationales.
  static Future<void> demarrer() async {
    if (!actif) {
      return;
    }
    // Android 13+ affiche une fenêtre « Autoriser les notifications ? ».
    await FirebaseMessaging.instance.requestPermission();
    await FirebaseMessaging.instance.subscribeToTopic('toutes');

    // App fermée ou en arrière-plan : Android affiche la notification tout seul.
    // App ouverte : on l'affiche nous-mêmes dans un bandeau.
    FirebaseMessaging.onMessage.listen(_afficherBandeau);
  }

  static void _afficherBandeau(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) {
      return;
    }
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('${notification.title}\n${notification.body}')),
    );
  }

  // Quand l'utilisateur change de radio par défaut : on se désabonne de
  // l'ancienne (si il y en avait une) et on s'abonne à la nouvelle.
  static Future<void> abonnerRadio(String? ancienneRadio, String nouvelleRadio) async {
    if (!actif) {
      return;
    }
    if (ancienneRadio != null && ancienneRadio != nouvelleRadio) {
      await FirebaseMessaging.instance.unsubscribeFromTopic('radio_$ancienneRadio');
    }
    await FirebaseMessaging.instance.subscribeToTopic('radio_$nouvelleRadio');
  }
}
