# Backend Radio Campus Orléans

API FastAPI + PostgreSQL, lancée avec Docker Compose. Remplace Firebase.

## Prérequis

- Docker et Docker Compose v2 (`docker compose version` doit répondre)
- Un terminal ouvert dans le dossier `backend/`

## 1. Configuration

```bash
cp .env.example .env
```

Puis éditer `.env` :

| Variable | À faire |
|---|---|
| `POSTGRES_PASSWORD` | Mettre un mot de passe de ton choix |
| `JWT_SECRET_KEY` | Générer avec la commande ci-dessous |

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
```

Ne jamais commiter `.env` (déjà dans `.gitignore`).

## 2. Lancer

```bash
docker compose up --build
```

- Le premier lancement télécharge les images et peut prendre quelques minutes.
- L'API attend que PostgreSQL soit prêt (healthcheck) avant de démarrer.
- Les tables sont créées automatiquement au démarrage.
- Le code de `app/` est monté dans le conteneur : une modification de fichier recharge l'API toute seule.

Remplir la liste des radios (35 radios du réseau, lues sur l'API Radio Campus) :

```bash
docker compose exec api python -m app.catalogue
```

Sans cette étape, l'app n'affiche aucune radio. Relançable à tout moment pour mettre à jour noms, logos et flux : les réglages des gérants ne sont jamais écrasés.

Vérifier que ça tourne :

- Swagger (documentation interactive) : <http://localhost:8000/docs>
- Santé : <http://localhost:8000/health> → `{"status":"ok"}`

En arrière-plan : `docker compose up -d --build`, puis `docker compose logs -f api` pour les logs.

## 3. Arrêter

```bash
docker compose down        # arrête, garde les données
docker compose down -v     # arrête ET supprime la base (repart de zéro)
```

Les images uploadées sont dans `backend/media/` (non supprimées par `down -v`), les logos dans `backend/media/logos/`.

### Sauvegarder et changer de PC

Une sauvegarde contient la base **et** les images (`media/`), dans une seule archive :

```bash
./scripts/sauvegarder.sh
# -> backups/sauvegarde_2026-11-23_23h52.tar.gz
```

Sur l'autre PC (Docker installé, dépôt cloné) :

1. Copier l'archive dans `backend/backups/` (clé USB, Drive...). Le dossier `backups/` n'est pas dans git.
2. Créer le `.env` (`cp .env.example .env`, voir § 1). Les mots de passe peuvent être différents de ceux de l'autre PC.
3. Pour les notifications : copier aussi `secrets/firebase.json` (jamais par git ni Discord).
4. Restaurer :
   ```bash
   docker compose up -d --build
   ./scripts/restaurer.sh backups/sauvegarde_2026-11-23_23h52.tar.gz
   ```

La restauration **remplace** la base et les images du PC par celles de l'archive (confirmation demandée, `-y` pour s'en passer).
Les gérants gardent leur mot de passe. Si `JWT_SECRET_KEY` est différent, ils doivent seulement se reconnecter.


## 4. Tester rapidement (curl)

```bash
# Inscription
curl -X POST localhost:8000/auth/register -H "Content-Type: application/json" \
  -d '{"name":"test","password":"motdepasse1"}'

# Connexion -> récupère le token (envoyé en formulaire, pas en JSON)
TOKEN=$(curl -s -X POST localhost:8000/auth/login \
  -d "username=test&password=motdepasse1" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

# Créer un post avec image
curl -X POST localhost:8000/posts -H "Authorization: Bearer $TOKEN" \
  -F "title=Premier post" -F "content=Bonjour" -F "image=@photo.jpg;type=image/jpeg"

# Lister les radios / modifier sa radio (admin de cette radio uniquement)
curl localhost:8000/radios
curl -X PATCH localhost:8000/radios/radio-campus-orleans -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"site":true,"url":"https://exemple.fr","color":"#E30613"}'

# Changer le logo de sa radio (admin de cette radio uniquement)
curl -X PUT localhost:8000/radios/radio-campus-orleans/logo -H "Authorization: Bearer $TOKEN" \
  -F "image=@logo.png"

# Retirer le logo (l'app revient au logo par défaut)
curl -X DELETE localhost:8000/radios/radio-campus-orleans/logo -H "Authorization: Bearer $TOKEN"

# Lister les posts
curl localhost:8000/posts

# Abonner un appareil aux notifications d'une radio (sans compte)
curl -X PUT localhost:8000/devices -H "Content-Type: application/json" \
  -d '{"push_token":"jeton-fcm-de-test","platform":"android","radio_slug":"radio-campus-orleans"}'

# Envoyer une notification aux abonnés (admin de la radio uniquement, 5 par jour)
curl -X POST localhost:8000/radios/radio-campus-orleans/notifications \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"title":"Concert ce soir","body":"Rendez-vous à 20 h au campus"}'

# Historique, envois restants aujourd'hui, nombre d'abonnés
curl localhost:8000/radios/radio-campus-orleans/notifications -H "Authorization: Bearer $TOKEN"
```

Sans clé Firebase, l'envoi est simulé : il apparaît dans `docker compose logs -f api` (`[notification simulée] ...`).

Dans Swagger (`/docs`) : bouton **Authorize**, avec le nom d'utilisateur dans `username`.

## 5. Endpoints

| Méthode | Route | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | non | Créer un compte |
| POST | `/auth/login` | non | Token JWT (form `username` = nom, `password`) |
| GET | `/auth/me` | oui | Utilisateur courant (avec `radio_slug` : la radio qu'il gère) |
| GET | `/radios` | non | Liste des radios |
| GET | `/radios/{slug}` | non | Une radio |
| PATCH | `/radios/{slug}` | admin de la radio | Modifier `site`, `url`, `color`, `stream_url` |
| PUT | `/radios/{slug}/logo` | admin de la radio | Envoyer/remplacer le logo (multipart, champ `image`) |
| DELETE | `/radios/{slug}/logo` | admin de la radio | Retirer le logo |
| GET | `/posts` | non | Liste (`?skip=0&limit=20`) |
| GET | `/posts/{id}` | non | Un post |
| POST | `/posts` | oui | Créer (multipart : `title`, `content`, `image` optionnel) |
| DELETE | `/posts/{id}` | oui | Supprimer (auteur uniquement) |
| POST | `/radios/{slug}/notifications` | admin de la radio | Envoyer une notification aux abonnés (`title` ≤ 100, `body` ≤ 500). 202, ou 429 au-delà de 5 par 24 h |
| GET | `/radios/{slug}/notifications` | admin de la radio | Historique (`?limit=20`), `remaining_today`, `subscribers_count` |
| GET | `/radios/{slug}/subscribers/count` | admin de la radio | Nombre d'appareils abonnés |
| PUT | `/devices` | non | Abonner l'appareil à une radio (`push_token`, `platform`, `radio_slug`, `null` = se désabonner) |
| GET | `/devices/{push_token}` | non | Radio suivie par l'appareil |
| DELETE | `/devices/{push_token}` | non | Oublier l'appareil |
| GET | `/proxy/radiocampus?chemin=/api/...` | non | Relais en lecture vers `api.radiocampus.org` (Flutter web, bloqué par CORS sinon) |
| GET | `/media/<fichier>` | non | Image uploadée |

Images : JPEG, PNG, WebP, GIF, 5 Mo max (`MAX_UPLOAD_SIZE_MB`).

## 6. Base de données

Schéma repris de Supabase, complété par le catalogue des radios et les réglages des gérants.

**`radios`** : la liste des radios de l'app vient de cette table.

Colonnes du **catalogue**, remplies par `python -m app.catalogue` depuis l'API Radio Campus :

| Colonne | Type | Rôle |
|---|---|---|
| `id` | int8 | Clé primaire |
| `created_at` | timestamptz | Date de création |
| `slug` | text, unique | Identifiant de la radio (ex. `radio-campus-orleans`), le même que dans l'API Radio Campus |
| `position` | int | Rang dans la liste de l'app (null = en fin de liste) |
| `name` | text | Nom affiché |
| `city` | text | Ville (recherche, carte) |
| `excerpt` | text | Courte présentation |
| `slogan` | text | Phrase du lecteur, ex. « RADIO CAMPUS ORLÉANS - 88.3 FM » |
| `category_color` | text | Couleur de la catégorie, ex. `#2154ff` |
| `image_url` | text | Logo d'origine (adresse externe) |
| `live_url` | text | Flux du direct d'origine |
| `website_url` | text | Site officiel (null = pas de site, l'app affiche sa version appli) |

Colonnes des **réglages du gérant** (`PATCH /radios/{slug}`), prioritaires sur le catalogue :

| Colonne | Type | Rôle |
|---|---|---|
| `site` | bool | `true` = afficher le site web, `false` = version appli |
| `url` | text | Adresse du site web (null = `website_url`) |
| `color` | text | Couleur de la page, format `#RRGGBB` (null = couleur par défaut) |
| `logo_url` | text | Logo envoyé par le gérant, ex. `/media/logos/<uuid>.webp` (null = `image_url`) |
| `stream_url` | text | Flux du direct choisi par le gérant (null = `live_url`) |

Une radio peut aussi être ajoutée à la main (`INSERT INTO radios (slug, name, live_url) VALUES (...)`) : elle apparaît en fin de liste.

### Logos des radios

Envoyés avec `PUT /radios/{slug}/logo`, puis traités par le serveur (`app/media.py`) :

- **Vraie image vérifiée** : le contenu est lu avec Pillow, le type MIME annoncé est ignoré. PNG, JPEG, WebP et GIF acceptés ; SVG refusé (il peut contenir du code).
- **Redressé** selon l'orientation EXIF (photos de téléphone).
- **Réduit à 512×512 max** (proportions gardées) et **converti en WebP** : quelques dizaines de Ko au lieu de plusieurs Mo. La transparence est conservée.
- **Nouveau nom à chaque envoi** et suppression de l'ancien fichier : les téléphones ne gardent pas l'ancien logo en cache.
- Limite de taille : `MAX_UPLOAD_SIZE_MB` (5 Mo par défaut).

**`users`**

| Colonne | Type | Rôle |
|---|---|---|
| `id` | int8 | Clé primaire |
| `created_at` | timestamptz | Date de création |
| `radio` | int8 → `radios.id` | Radio gérée (null = simple utilisateur) |
| `is_admin` | bool | Admin de sa radio |
| `password` | text | **Hash bcrypt**, jamais le mot de passe en clair |
| `name` | text, unique | Nom d'utilisateur (sert à la connexion) |

**`devices`** (appareils abonnés aux notifications ; les auditeurs n'ont pas de compte)

| Colonne | Type | Rôle |
|---|---|---|
| `id` | int8 | Clé primaire |
| `push_token` | text, unique | Jeton FCM de l'appareil |
| `platform` | text | `android` (iOS plus tard) |
| `radio` | int8 → `radios.id` | Radio suivie (null = aucune). Une seule radio par appareil |
| `created_at`, `updated_at` | timestamptz | |

**`notifications`** (historique des envois, sert aussi à la limite de 5 par jour)

| Colonne | Type | Rôle |
|---|---|---|
| `id` | int8 | Clé primaire |
| `radio_id` | int8 → `radios.id` | Radio émettrice |
| `sender_id` | int8 → `users.id` | Gérant qui a envoyé (null s'il a été supprimé) |
| `title`, `body` | text | Texte brut, 100 et 500 caractères max |
| `created_at` | timestamptz | Date d'envoi |
| `recipients_count` | int | Appareils visés |
| `success_count` | int | Appareils atteints, rempli à la fin de l'envoi (null = en cours) |

Plus `posts`.

### Créer une radio et son admin

Pas de route pour ça (sinon n'importe qui pourrait se déclarer admin) : on passe par la base.
L'utilisateur doit d'abord s'être inscrit via `/auth/register`.

```bash
docker compose exec db sh -c 'psql -U $POSTGRES_USER -d $POSTGRES_DB'
```

La radio doit exister dans `radios` (après `python -m app.catalogue`, les 35 radios y sont) :

```sql
UPDATE users
SET is_admin = true,
    radio = (SELECT id FROM radios WHERE slug = 'radio-campus-orleans')
WHERE name = 'test';
```

### Couleur côté Flutter

L'app stocke aujourd'hui un `int` ARGB (`toARGB32()`), l'API un texte `#RRGGBB` :

```dart
String versHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color depuisHex(String hex) => Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
```

## 7. Utilisation depuis Flutter

L'app est branchée sur l'API dans `mon_app/lib/services/api.dart` :

| Fonction de l'app | Routes utilisées |
|---|---|
| Liste des radios (`campus_radio.dart`) | `GET /radios` |
| Connexion du gérant (`login_page.dart`) | `POST /auth/login`, `GET /auth/me` |
| Réglages des radios : site, couleur, logo, flux (`radio_settings.dart`) | `GET /radios`, `GET/PATCH /radios/{slug}`, `PUT/DELETE /radios/{slug}/logo` |
| Catalogue radiocampus.org sur Flutter web (`campus_radio.dart`) | `GET /proxy/radiocampus` |

La liste des radios vient de notre base. Le détail d'une radio, ses podcasts et les actualités restent lus sur `api.radiocampus.org`.
Sans serveur, l'app ne peut pas afficher la liste des radios (bouton « Réessayer »).
Les notifications passent encore par Supabase.

Adresse du serveur : `http://10.0.2.2:8000` sur l'émulateur Android, `http://localhost:8000` ailleurs. Pour une autre adresse :

```bash
flutter run --dart-define=API_URL=http://192.168.1.20:8000
```

URL de base selon la cible :

| Cible | URL |
|---|---|
| Émulateur Android | `http://10.0.2.2:8000` |
| Simulateur iOS / Flutter web | `http://localhost:8000` |
| Téléphone réel | `http://<IP-du-PC>:8000` (même Wi-Fi) |

```dart
final login = await http.post(Uri.parse('$baseUrl/auth/login'),
    body: {'username': nom, 'password': motDePasse}); // form-urlencoded
final token = jsonDecode(login.body)['access_token'];

final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts'))
  ..headers['Authorization'] = 'Bearer $token'
  ..fields['title'] = 'Titre'
  ..fields['content'] = 'Contenu'
  ..files.add(await http.MultipartFile.fromPath('image', file.path,
      contentType: MediaType('image', 'jpeg'))); // package http_parser
await req.send();

// Afficher une image : Image.network('$baseUrl${post['image_url']}')

// Changer le logo (admin) : pas besoin de contentType, le serveur vérifie lui-même l'image
final logo = http.MultipartRequest('PUT', Uri.parse('$baseUrl/radios/$slug/logo'))
  ..headers['Authorization'] = 'Bearer $token'
  ..files.add(await http.MultipartFile.fromPath('image', fichier.path));
await logo.send();

// Afficher le logo, avec un logo par défaut si la radio n'en a pas
radio['logo_url'] != null
    ? Image.network('$baseUrl${radio['logo_url']}')
    : Image.asset('assets/logo_defaut.png');
```

- Sans `contentType` explicite, l'image part en `application/octet-stream` et l'API répond **415**.
- Téléphone Android réel en HTTP : ajouter `android:usesCleartextTraffic="true"` dans `AndroidManifest.xml`.

## 8. Notifications push (Firebase Cloud Messaging)

Fonctionnement :

1. L'app récupère son jeton FCM et appelle `PUT /devices` avec la radio choisie (au démarrage, quand le jeton change, quand l'auditeur appuie sur la cloche).
2. Le gérant envoie `POST /radios/{slug}/notifications`. L'API répond **202** tout de suite et envoie en tâche de fond (`app/push.py`), par lots de 500 jetons.
3. Les appareils dont le jeton est rejeté (app désinstallée) sont supprimés de `devices`, puis `success_count` est rempli.

Chaque notification contient les données `radio_slug` et `notification_id` : l'app s'en sert pour ouvrir la bonne radio au clic.

### Configurer Firebase

Sans clé, tout fonctionne mais les envois sont seulement écrits dans les logs. Pour envoyer pour de vrai :

1. Console Firebase → ⚙️ **Paramètres du projet** → **Comptes de service** → **Générer une nouvelle clé privée**.
2. Ranger le fichier téléchargé :
   ```bash
   mv ~/Téléchargements/<projet>-firebase-adminsdk-*.json backend/secrets/firebase.json
   ```
3. Dans `.env`, ajouter :
   ```
   FIREBASE_CREDENTIALS=/app/secrets/firebase.json
   ```
4. `docker compose up -d` (redémarre l'API). Les logs doivent afficher « Firebase initialisé ».

`backend/secrets/` est monté en lecture seule dans le conteneur et ignoré par git. **Ne jamais commiter la clé** : elle permet d'envoyer des notifications à tous les utilisateurs. Vérifier avec `git status` qu'elle n'apparaît pas.

La limite d'envois se règle avec `NOTIFICATIONS_PER_DAY` dans `.env` (5 par défaut).

## 9. Tests

Sans Docker ni Firebase (SQLite en mémoire, envoi FCM remplacé par un faux) :

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/pytest
```

## Dépannage

| Problème | Cause / solution |
|---|---|
| Table `user_devices` encore présente après la mise à jour des notifications | Ancienne table remplacée par `devices`, inutilisée : `DROP TABLE user_devices;` dans psql, ou `docker compose down -v` pour repartir de zéro |
| L'API ne démarre pas : `FIREBASE_CREDENTIALS pointe vers ...` | La variable est dans `.env` mais `backend/secrets/firebase.json` manque : ajouter la clé ou commenter la ligne |
| 429 sur l'envoi de notification | Limite de 5 envois sur 24 h glissantes atteinte pour cette radio |
| `port is already allocated` (8000) | Un autre service utilise le port : l'arrêter ou changer `8000:8000` dans `docker-compose.yml` |
| 500 sur `/radios` après une mise à jour (`column radios.... does not exist`) | Base créée avant l'ajout du catalogue : `docker compose exec -T db sh -c 'psql -U $POSTGRES_USER -d $POSTGRES_DB' < migrations/001_catalogue_radios.sql`, puis `docker compose exec api python -m app.catalogue` |
| L'app n'affiche aucune radio | Table `radios` vide : `docker compose exec api python -m app.catalogue` |
| Erreur de colonne inconnue après une mise à jour du schéma | Les tables ne sont créées qu'une fois : `docker compose down -v` puis relancer (efface les données) |
| L'API ne démarre pas, erreur de connexion à la base | Regarder `docker compose logs db`. Si le mot de passe de `.env` a changé après le 1er lancement : `docker compose down -v` puis relancer |
| 403 sur `PATCH /radios/...` | L'utilisateur n'est pas `is_admin` ou n'est pas rattaché à cette radio |
| 401 sur une route protégée | Token manquant/expiré : se reconnecter (durée par défaut : 7 jours) |
| 415 à l'upload | Post : le type MIME n'est pas une image autorisée. Logo : format non accepté (BMP, TIFF...) |
| 422 sur l'upload du logo | Le fichier n'est pas une image lisible (fichier corrompu, SVG, image gigantesque) |
| Téléphone réel n'atteint pas l'API | Vérifier l'IP du PC, le pare-feu, et que les deux sont sur le même réseau |

Pour inspecter la base en local, décommenter `ports: "5432:5432"` du service `db` (jamais en production).

## Production

- Remplacer `allow_origins=["*"]` dans `app/main.py` par les origines autorisées.
- Retirer `--reload` et le montage `./app` du service `api`.
- Mettre l'API derrière un proxy HTTPS (Caddy, Nginx...).
- Passer à Alembic pour les migrations de schéma.
