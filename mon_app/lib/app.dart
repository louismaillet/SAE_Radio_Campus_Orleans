import 'package:flutter/material.dart';

import 'pages/radio_list_page.dart';
import 'services/notification_service.dart';

class RadioCampusApp extends StatelessWidget {
  const RadioCampusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Radio Campus France',
        debugShowCheckedModeBanner: false,
        // Pour afficher les notifications reçues quand l'app est ouverte.
        scaffoldMessengerKey: NotificationService.messengerKey,
        theme: ThemeData(
          colorSchemeSeed: Colors.deepOrange,
          scaffoldBackgroundColor: Colors.orange.shade50,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
        ),
        home: const RadioListPage(),
      );
}
