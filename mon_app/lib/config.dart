import 'package:firebase_core/firebase_core.dart';

// Projet Supabase (base de données + connexion des gérants).
// La clé "publishable" est faite pour être dans l'app : elle n'est pas secrète.
const String supabaseUrl = 'https://vjesgnurlhcijhlzcrvs.supabase.co';
const String supabaseKey = 'sb_publishable_4_zfGh331KgdXnxjRZ0iyQ_RXZh8-At';

// Projet Firebase (notifications push sur Android).
// Valeurs à recopier depuis la console Firebase : Paramètres du projet >
// Vos applications > l'app Android (ou le fichier google-services.json).
// Tant que apiKey est vide, l'app fonctionne sans notifications.
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAELRnvqRy8762sECHFHelUpM0ic_YcvWU', // "current_key" dans google-services.json
  appId: '1:440783380601:android:f022d8f99fd727103334a8', // "mobilesdk_app_id"
  messagingSenderId: '440783380601', // "project_number"
  projectId: 'sae-radio-campus', // "project_id"
);
