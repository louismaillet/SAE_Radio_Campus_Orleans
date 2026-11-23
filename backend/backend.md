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
**Sauvegarde :** il faut sauvegarder à la fois la base ET le dossier `media/`.

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

# Enregistrer un appareil pour les notifications
curl -X POST localhost:8000/devices/register -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"push_endpoint_url":"https://exemple.org/endpoint","platform":"android"}'
```

Dans Swagger (`/docs`) : bouton **Authorize**, avec le nom d'utilisateur dans `username`.

## 5. Endpoints

| Méthode | Route | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | non | Créer un compte |
| POST | `/auth/login` | non | Token JWT (form `username` = nom, `password`) |
| GET | `/auth/me` | oui | Utilisateur courant |
| GET | `/radios` | non | Liste des radios |
| GET | `/radios/{slug}` | non | Une radio |
| PATCH | `/radios/{slug}` | admin de la radio | Modifier `site`, `url`, `color` |
| PUT | `/radios/{slug}/logo` | admin de la radio | Envoyer/remplacer le logo (multipart, champ `image`) |
| DELETE | `/radios/{slug}/logo` | admin de la radio | Retirer le logo |
| GET | `/posts` | non | Liste (`?skip=0&limit=20`) |
| GET | `/posts/{id}` | non | Un post |
| POST | `/posts` | oui | Créer (multipart : `title`, `content`, `image` optionnel) |
| DELETE | `/posts/{id}` | oui | Supprimer (auteur uniquement) |
| POST | `/devices/register` | oui | Enregistrer/mettre à jour un endpoint push |
| GET | `/media/<fichier>` | non | Image uploadée |

Images : JPEG, PNG, WebP, GIF, 5 Mo max (`MAX_UPLOAD_SIZE_MB`).

## 6. Base de données

Schéma repris de Supabase, plus `url` et `color` sur les radios.

**`radios`**

| Colonne | Type | Rôle |
|---|---|---|
| `id` | int8 | Clé primaire |
| `created_at` | timestamptz | Date de création |
| `site` | bool | `true` = afficher le site web, `false` = version appli |
| `slug` | text, unique | Identifiant de la radio (ex. `radio-campus-orleans`) |
| `url` | text | Adresse du site web (obligatoire si `site = true`) |
| `color` | text | Couleur de la page, format `#RRGGBB` (null = couleur par défaut) |
| `logo_url` | text | Adresse du logo, ex. `/media/logos/<uuid>.webp` (null = logo par défaut) |

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

Plus `posts` et `user_devices` (notifications push).

### Créer une radio et son admin

Pas de route pour ça (sinon n'importe qui pourrait se déclarer admin) : on passe par la base.
L'utilisateur doit d'abord s'être inscrit via `/auth/register`.

```bash
docker compose exec db sh -c 'psql -U $POSTGRES_USER -d $POSTGRES_DB'
```

```sql
INSERT INTO radios (slug) VALUES ('radio-campus-orleans');

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

## Dépannage

| Problème | Cause / solution |
|---|---|
| `port is already allocated` (8000) | Un autre service utilise le port : l'arrêter ou changer `8000:8000` dans `docker-compose.yml` |
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
