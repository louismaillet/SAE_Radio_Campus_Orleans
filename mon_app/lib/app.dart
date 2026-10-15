import 'package:flutter/material.dart';

import 'pages/radio_list_page.dart';

class RadioCampusApp extends StatelessWidget {
  const RadioCampusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Radio Campus France',
        debugShowCheckedModeBanner: false,
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
