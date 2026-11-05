import 'package:firebase_core/firebase_core.dart';

// Projet Firebase (notifications push sur Android).
// Ces valeurs viennent du fichier google-services.json (elles ne sont pas secrètes).
// Tant que apiKey est vide, l'app fonctionne sans notifications.
// (La connexion Supabase est dans supabase_config.dart.)
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAELRnvqRy8762sECHFHelUpM0ic_YcvWU', // "current_key"
  appId: '1:440783380601:android:f022d8f99fd727103334a8', // "mobilesdk_app_id"
  messagingSenderId: '440783380601', // "project_number"
  projectId: 'sae-radio-campus', // "project_id"
);
