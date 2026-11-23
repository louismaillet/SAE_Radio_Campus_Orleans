-- Mise à jour d'une base créée avant le 23/11/2026 : la liste des radios vient
-- désormais de la table "radios" (catalogue) + flux choisi par le gérant.
-- Une base neuve n'en a pas besoin (les tables sont créées au démarrage de l'API).
-- Relançable sans risque.
--
--   docker compose exec -T db sh -c 'psql -U $POSTGRES_USER -d $POSTGRES_DB' < migrations/001_catalogue_radios.sql
--   docker compose exec api python -m app.catalogue

ALTER TABLE radios
    ADD COLUMN IF NOT EXISTS stream_url     VARCHAR(500),
    ADD COLUMN IF NOT EXISTS position       INTEGER,
    ADD COLUMN IF NOT EXISTS name           VARCHAR(200) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS city           VARCHAR(100),
    ADD COLUMN IF NOT EXISTS excerpt        TEXT,
    ADD COLUMN IF NOT EXISTS slogan         VARCHAR(500),
    ADD COLUMN IF NOT EXISTS category_color VARCHAR(20),
    ADD COLUMN IF NOT EXISTS image_url      VARCHAR(500),
    ADD COLUMN IF NOT EXISTS live_url       VARCHAR(500),
    ADD COLUMN IF NOT EXISTS website_url    VARCHAR(500);
