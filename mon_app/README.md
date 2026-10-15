# mon_app

Application Flutter minimale « Radio Campus » pour Windows et mobile : sélection d'une radio, écoute du direct et affichage du site web (ou des podcasts/news si la radio n'a pas de site web). Les données viennent du fichier `assets/db.json`.

## Lancer l'application

```bash
flutter pub get
flutter run -d windows
```

Sur Android :

```bash
flutter emulators --launch mon_app_pixel
flutter run -d emulator-5554
```

## Structure minimale de `lib/`

| Fichier | Rôle |
| --- | --- |
| `lib/main.dart` | Point d'entrée (`runApp`) |
| `lib/app.dart` | `MaterialApp` et page d'accueil |
| `lib/models/campus_radio.dart` | Modèles de données et classe `RadioRepository` |
| `lib/pages/radio_list_page.dart` | Liste des radios avec `FutureBuilder` |
| `lib/pages/radio_details_page.dart` | Direct + WebView du site (ou podcasts/news) avec `FutureBuilder` |
| `lib/widgets/live_player_tile.dart` | Contrôle de la lecture audio en direct |
