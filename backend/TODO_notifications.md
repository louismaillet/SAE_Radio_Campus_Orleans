# TODO : notifications push envoyées par les gérants de radio

Document de reprise : à relire avant de coder.

## Objectif

1. Un auditeur ouvre l'app (**sans compte**), choisit une radio et s'y **abonne**. **Une seule radio par appareil** ; en choisir une autre remplace la précédente.
2. Le **gérant d'une radio** (`users.is_admin = true` et `users.radio = radio.id`, connecté par la page de connexion) écrit une notification dans l'app et l'envoie.
3. Tous les appareils abonnés à cette radio la reçoivent, **même app fermée**.

L'envoi part **uniquement d'une route admin**, déclenchée depuis l'app. Pas de tâche planifiée.

## Décisions prises

| Sujet | Décision |
|---|---|
| Backend | Supabase abandonné, tout dans FastAPI (`backend/`) |
| Transport | **FCM** (Firebase Cloud Messaging), via `firebase-admin` |
| Plateformes | **Android seulement** pour l'instant, iOS ignoré (garder le champ `platform` pour plus tard) |
| Comptes | **Aucun compte pour les auditeurs.** Seuls les gérants ont un compte (`users`) |
| Abonnement | Lié à l'**appareil**, **une seule radio** par appareil |
| Limite | **5 notifications par radio et par jour** (24 h glissantes) |

## Modèle de données

### `user_devices` → renommer en `devices` (modifier l'existant)

Les auditeurs n'ont pas de compte : l'appareil devient l'« utilisateur ».

| Colonne | Type | Notes |
|---|---|---|
| `id` | int8 | PK |
| `push_token` | text, **unique** | Jeton FCM (remplace `push_endpoint_url`) |
| `platform` | text | `android` pour l'instant |
| `radio` | int8 → `radios.id`, **nullable** | La radio suivie (null = aucune). `ON DELETE SET NULL`. Index (requête d'envoi) |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |

- **Supprimer `user_id`** et la relation `User.devices`.
- « Une seule radio » est garanti par la structure (une colonne), pas besoin de contrainte.

### `notifications` (nouvelle, historique des envois)

| Colonne | Type | Notes |
|---|---|---|
| `id` | int8 | PK |
| `radio_id` | int8 → `radios.id` | `ON DELETE CASCADE`. Index (`radio_id`, `created_at`) pour la limite |
| `sender_id` | int8 → `users.id`, nullable | Le gérant (`ON DELETE SET NULL`) |
| `title` | text | 1 à 100 caractères |
| `body` | text | 1 à 500 caractères |
| `created_at` | timestamptz | |
| `recipients_count` | int | Nombre d'appareils visés |
| `success_count` | int, nullable | Rempli après l'envoi en tâche de fond |

## Routes

### Appareil (public, sans connexion) : remplace `app/routers/devices.py`

| Méthode | Route | Corps | Rôle |
|---|---|---|---|
| PUT | `/devices` | `{push_token, platform, radio_slug}` | **Upsert** sur `push_token`. Crée l'appareil ou met à jour sa radio. `radio_slug: null` = se désabonner. 404 si le slug n'existe pas |
| GET | `/devices/{push_token}` | – | Radio actuellement suivie (pour l'afficher au démarrage). Optionnel : l'app peut aussi la garder en `shared_preferences` |
| DELETE | `/devices/{push_token}` | – | Oublier l'appareil |

Une seule route d'écriture suffit : l'app l'appelle au démarrage, quand le jeton change (`onTokenRefresh`) et quand l'auditeur choisit une radio.

Pas d'authentification : le jeton FCM fait office d'identifiant secret (seul l'appareil le connaît). Le risque est faible : au pire, quelqu'un qui connaît un jeton change l'abonnement de cet appareil.

### Envoi (gérant connecté, admin de la radio) : dans `app/routers/radios.py`

| Méthode | Route | Rôle |
|---|---|---|
| POST | `/radios/{slug}/notifications` | Corps `{title, body}`. Envoie aux appareils abonnés |
| GET | `/radios/{slug}/notifications` | Historique + nombre d'envois restants aujourd'hui (`remaining_today`) |
| GET | `/radios/{slug}/subscribers/count` | Nombre d'appareils abonnés, à afficher au gérant avant d'envoyer (optionnel, peut aller dans la réponse du GET précédent) |

Logique de `POST /radios/{slug}/notifications` :

1. `ensure_radio_admin` (existe déjà dans `radios.py`) → 403 sinon.
2. Compter les `notifications` de cette radio sur les dernières 24 h. Si ≥ 5 → **429** avec un message clair (« limite de 5 notifications par jour atteinte »).
3. Récupérer les `push_token` des `devices` WHERE `radio = X`.
4. Créer la ligne `notifications` (même s'il n'y a 0 abonné : ça compte dans la limite, plus simple et évite le contournement).
5. Répondre **202** avec la notification créée.
6. **Tâche de fond** (`BackgroundTasks`) :
   - découper en lots de **500 jetons max** (limite FCM) ;
   - données jointes : `{"radio_slug": "...", "notification_id": "..."}` (FCM n'accepte que des chaînes) ;
   - **supprimer les appareils** dont le jeton est rejeté (`UNREGISTERED`, `INVALID_ARGUMENT` / `SenderIdMismatch`) : app désinstallée ;
   - mettre à jour `success_count`. La tâche de fond ouvre **sa propre session** (`SessionLocal()`), pas celle de la requête.
7. Texte brut uniquement, longueurs validées par Pydantic.

## Module d'envoi `app/push.py`

- `send_push(tokens, title, body, data) -> (success_count, invalid_tokens)`.
- Toute la logique FCM reste dans ce fichier.
- `firebase_admin.messaging.send_each_for_multicast` avec `MulticastMessage(notification=..., data=..., android=AndroidConfig(priority="high"))`.
- Initialiser Firebase **une seule fois** dans le `lifespan` de `app/main.py`, seulement si `FIREBASE_CREDENTIALS` est défini.
- **Sans clé** (dev/tests) : logger la notification et considérer l'envoi réussi. Tout le reste reste testable sans Firebase.

## Configuration

- [ ] `requirements.txt` : `firebase-admin` (version fixée).
- [ ] `app/config.py` : `FIREBASE_CREDENTIALS: Path | None = None`.
- [ ] `.env.example` : `FIREBASE_CREDENTIALS=/app/secrets/firebase.json` (commenté).
- [ ] `docker-compose.yml` : volume `./secrets:/app/secrets:ro` sur `api`.
- [ ] `.gitignore` + `.dockerignore` : `secrets/`.
- [ ] Changement de schéma → rappeler `docker compose down -v`.
- [ ] `backend.md` : nouvelles routes, tables, section « Configurer Firebase ».

## Configuration Firebase (à faire par l'utilisateur, ce soir)

Le projet Firebase est créé. Étapes restantes, dans l'ordre. Rien de tout ça ne demande d'écrire du code.

### Étape 0 : choisir l'identifiant Android définitif (5 min, AVANT tout le reste)

L'app s'appelle aujourd'hui `com.example.mon_app` (dans `mon_app/android/app/build.gradle.kts`, lignes `namespace` et `applicationId`).

- Firebase lie l'app à cet identifiant. **Le changer après oblige à refaire l'étape 2.**
- Google Play **refuse** les identifiants en `com.example`.
- Conseil : choisir maintenant un identifiant comme `fr.radiocampusorleans.app` (minuscules, points, pas de tiret), et le remplacer dans `applicationId`.
- Si tu ne veux pas t'en occuper maintenant, garde `com.example.mon_app`. Ça fonctionne pour les tests.

### Étape 1 : installer les outils (une seule fois sur le PC)

```bash
# Firebase CLI (nécessite Node.js)
npm install -g firebase-tools
firebase login                       # ouvre le navigateur, compte Google du projet

# FlutterFire CLI
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"   # à ajouter aussi dans ~/.bashrc
flutterfire --version                # vérifie que la commande est trouvée
```

### Étape 2 : relier l'app Flutter au projet

```bash
cd mon_app
flutterfire configure --platforms=android
```

- Choisir le projet Firebase dans la liste.
- La commande **crée l'app Android dans Firebase** avec l'`applicationId` actuel. Pas besoin de passer par la console.
- Elle génère :
  - `mon_app/lib/firebase_options.dart`
  - `mon_app/android/app/google-services.json`
  - et ajoute le plugin `com.google.gms.google-services` dans les fichiers Gradle.
- Ces deux fichiers **peuvent être commités** : ils identifient l'app, ce ne sont pas des secrets (contrairement à la clé de l'étape 4). Les coéquipiers en ont besoin pour compiler.
- Pas besoin d'empreinte SHA-1 : elle sert à la connexion Google, pas aux notifications.

Vérifier que le build passe toujours :

```bash
flutter pub get
flutter build apk --debug
```

### Étape 3 : vérifier que l'API d'envoi est active

Console Firebase → ⚙️ **Paramètres du projet** → onglet **Cloud Messaging** :

- « API Firebase Cloud Messaging (V1) » doit être **Activée**. C'est normalement le cas sur un nouveau projet.
- Si elle est désactivée : cliquer sur les ⋮ → « Gérer l'API dans Google Cloud Console » → **Activer**.
- **Ne pas** activer l'« ancienne API » (legacy) : elle est supprimée par Google.

### Étape 4 : clé du serveur (compte de service)

Console Firebase → ⚙️ **Paramètres du projet** → onglet **Comptes de service** → **Générer une nouvelle clé privée** → un fichier JSON est téléchargé.

```bash
mkdir -p backend/secrets
mv ~/Téléchargements/<nom-du-projet>-firebase-adminsdk-*.json backend/secrets/firebase.json
```

- **C'est un vrai secret** : il permet d'envoyer des notifications à tous les utilisateurs. **Ne jamais le commiter**, ne pas l'envoyer sur Discord. Vérifier avec `git status` qu'il n'apparaît pas.
- En cas de fuite : le supprimer dans Google Cloud Console → IAM → Comptes de service → Clés, puis en générer un nouveau.
- Si la génération est **bloquée** (« Key creation is disabled »), le projet est sous une organisation (compte Google de l'école) qui l'interdit. Recréer le projet avec un **compte Google personnel**.

### Étape 5 : partager avec l'équipe (optionnel)

Console Firebase → ⚙️ **Paramètres du projet** → **Utilisateurs et autorisations** → ajouter les coéquipiers (rôle « Éditeur » suffit). Chacun peut alors générer sa propre clé de l'étape 4 au lieu de se la passer.

### Étape 6 : vérifier que tout marche (après le code de ce soir)

Quand l'app saura afficher son jeton FCM (dans les logs `flutter run`) :

Console Firebase → **Messaging** → **Nouvelle campagne** → **Notifications** → saisir un titre et un texte → **Envoyer un message test** → coller le jeton → **Tester**.

- La notif arrive : la partie Flutter est bonne. Il reste à tester l'envoi via le backend (`POST /radios/{slug}/notifications`).
- Elle n'arrive pas : vérifier la permission de notifications du téléphone (Android 13+) et que l'émulateur a les **Google Play Services** (image « Google Play » ou « Google APIs », pas « AOSP »).

### Récapitulatif

- [ ] Étape 0 : `applicationId` choisi (ou `com.example.mon_app` gardé pour l'instant)
- [ ] Étape 1 : `firebase` et `flutterfire` installés et connectés
- [ ] Étape 2 : `flutterfire configure` lancé, `flutter build apk --debug` OK
- [ ] Étape 3 : API Cloud Messaging V1 activée
- [ ] Étape 4 : `backend/secrets/firebase.json` présent et **absent de `git status`**
- [ ] Étape 5 : coéquipiers ajoutés (optionnel)
- [ ] Étape 6 : message test reçu (après le code)

## Tests à écrire (venv scratchpad, SQLite, TestClient, `send_push` remplacé par un faux)

- [ ] `PUT /devices` : création, changement de radio (remplace), `radio_slug: null`, slug inconnu → 404, même jeton deux fois → une seule ligne.
- [ ] Envoi : non connecté → 401, non-admin → 403, admin d'une autre radio → 403.
- [ ] Seuls les appareils de **cette** radio sont visés (abonnés à une autre radio exclus).
- [ ] 6e envoi dans la journée → 429 ; un envoi vieux de plus de 24 h ne compte plus.
- [ ] Jeton invalide renvoyé par le faux `send_push` → appareil supprimé ; `success_count` mis à jour.

## App Flutter (à brancher ensuite)

- [ ] Dépendances : `firebase_core`, `firebase_messaging`, `flutter_local_notifications` (affichage quand l'app est ouverte).
- [ ] `AndroidManifest.xml` : permission `POST_NOTIFICATIONS` (Android 13+), demandée au premier lancement.
- [ ] Au démarrage : récupérer le jeton FCM → `PUT /devices` avec la radio mémorisée.
- [ ] `onTokenRefresh` → `PUT /devices` avec le nouveau jeton.
- [ ] Page radio : bouton **cloche « Recevoir les notifications »**. Activer → `PUT /devices` avec ce slug (remplace l'ancienne radio, prévenir l'auditeur s'il en suivait une autre). Désactiver → `radio_slug: null`.
- [ ] Page admin : formulaire titre + message, nombre d'abonnés, compteur « X / 5 envois aujourd'hui », historique. Bouton → `POST /radios/{slug}/notifications`.
- [ ] Clic sur une notification → ouvrir la page de la radio grâce à `radio_slug`.

## Hors périmètre pour l'instant

- iOS (nécessite un compte Apple Developer + clé APNs dans Firebase).
- Envois programmés.
- Plusieurs radios par appareil (il faudrait alors une table `device_subscriptions`).
