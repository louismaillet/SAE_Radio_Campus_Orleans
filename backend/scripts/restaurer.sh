#!/usr/bin/env bash
# Restaure une sauvegarde faite avec scripts/sauvegarder.sh.
# REMPLACE la base et les images (media/) actuelles par celles de la sauvegarde.
#
# Usage (depuis backend/, avec un .env rempli) :
#   ./scripts/restaurer.sh backups/sauvegarde_2026-11-23_23h59.tar.gz
#   ./scripts/restaurer.sh -y backups/...   # sans demander de confirmation
set -euo pipefail

cd "$(dirname "$0")/.."

confirmer=true
if [ "${1:-}" = "-y" ]; then
  confirmer=false
  shift
fi

archive=${1:-}
if [ -z "$archive" ] || [ ! -f "$archive" ]; then
  echo "Usage : $0 [-y] backups/sauvegarde_....tar.gz" >&2
  exit 1
fi
if [ ! -f .env ]; then
  echo "Fichier .env manquant : cp .env.example .env, puis le remplir (voir backend.md)." >&2
  exit 1
fi

if $confirmer; then
  read -r -p "La base et les images actuelles vont être remplacées. Continuer ? [o/N] " reponse
  case "$reponse" in
    o|O|oui|y|Y) ;;
    *) echo "Annulé."; exit 0 ;;
  esac
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tar xzf "$archive" -C "$tmp"
if [ ! -f "$tmp/base.sql" ]; then
  echo "Archive invalide : base.sql absent." >&2
  exit 1
fi

echo "Démarrage des conteneurs..."
docker compose up -d
echo -n "Attente de la base"
until docker compose exec -T db sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; do
  echo -n "."
  sleep 1
done
echo

echo "Restauration de la base..."
docker compose exec -T db sh -c \
  'psql -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  < "$tmp/base.sql" > /dev/null

if [ -d "$tmp/media" ]; then
  echo "Restauration des images (media/)..."
  # Écrites via le conteneur, comme les images envoyées depuis l'app.
  tar cf - -C "$tmp" media | docker compose exec -T api sh -c \
    'find /app/media -mindepth 1 -delete && tar xf - -C /app'
fi

# L'API repart sur une base propre (connexions, cache).
docker compose restart api > /dev/null
echo "Restauration terminée."
