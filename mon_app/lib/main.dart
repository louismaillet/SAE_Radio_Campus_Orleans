import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseCle);
  await NotificationService.initialiser();
  // Appli mobile : en portrait uniquement, et l'écran entier (sous les barres système).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const RadioCampusApp());
  // Pas de "await" : on ne bloque pas l'affichage pendant la demande de permission.
  NotificationService.demarrer();
}
