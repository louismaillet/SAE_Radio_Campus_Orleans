#!/usr/bin/env bash
# Sauvegarde complète : la base PostgreSQL + les images uploadées (media/).
# Crée backups/sauvegarde_AAAA-MM-JJ_HHhMM.tar.gz, à copier sur un autre PC
# puis à restaurer avec scripts/restaurer.sh.
#
# Usage (depuis backend/, les conteneurs doivent tourner) :
#   ./scripts/sauvegarder.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if ! docker compose ps --status running --services | grep -qx db; then
  echo "La base ne tourne pas : lance d'abord 'docker compose up -d'." >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Export de la base..."
# --clean --if-exists : la restauration remplace les tables existantes.
# --no-owner --no-privileges : restaurable même avec un autre POSTGRES_USER.
docker compose exec -T db sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner --no-privileges' \
  > "$tmp/base.sql"

echo "Copie des images (media/)..."
# Lues via le conteneur : les fichiers qu'il a créés appartiennent à root.
docker compose exec -T api tar cf - -C /app media | tar xf - -C "$tmp"

mkdir -p backups
fichier="backups/sauvegarde_$(date +%Y-%m-%d_%Hh%M).tar.gz"
tar czf "$fichier" -C "$tmp" base.sql media

echo "Sauvegarde créée : backend/$fichier ($(du -h "$fichier" | cut -f1))"
echo "Pour la restaurer sur un autre PC : ./scripts/restaurer.sh $fichier"
