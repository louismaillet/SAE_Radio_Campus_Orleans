import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  // Obligatoire avant d'utiliser des plugins avant runApp.
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  await NotificationService.initialiser();
  runApp(const RadioCampusApp());
  // Pas de "await" : on ne bloque pas l'affichage pendant la demande de permission.
  NotificationService.demarrer();
}
