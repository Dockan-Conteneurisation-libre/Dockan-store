#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur: Ce script doit être exécuté avec les privilèges root." >&2
  echo "Usage: sudo $0" >&2
  exit 1
fi

TARGET_ROOT="${DOCKAN_STORE_TARGET_ROOT:-/srv/dockan-apps}"

reset_pg_vol() {
  local vol="$1"
  local dir="/var/lib/dockan/volumes/$vol"
  rm -rf "$dir"
  mkdir -p "$dir"
  chown -R 999:999 "$dir"
  chmod 750 "$dir"
}

echo "=== [1/4] Arrêt et assainissement des volumes postgres corrompus ==="
dockan compose down -f "$TARGET_ROOT/mattermost/dockan.yml" >/dev/null 2>&1 || true
dockan compose down -f "$TARGET_ROOT/plausible/dockan.yml" >/dev/null 2>&1 || true
dockan compose down -f "$TARGET_ROOT/discourse/dockan.yml" >/dev/null 2>&1 || true

reset_pg_vol "mattermost-db"
reset_pg_vol "plausible-db"
reset_pg_vol "discourse-db"

# Nettoyage mémoire partagée résiduelle
for id in $(ipcs -m 2>/dev/null | awk '$6 == 0 {print $2}'); do
  ipcrm -m "$id" >/dev/null 2>&1 || true
done

echo "=== [2/4] Démarrage de Mattermost ==="
dockan compose up -f "$TARGET_ROOT/mattermost/dockan.yml"

echo "=== [3/4] Démarrage de Plausible ==="
dockan compose up -f "$TARGET_ROOT/plausible/dockan.yml"

echo "=== [4/4] Démarrage de Discourse et n8n ==="
dockan compose up -f "$TARGET_ROOT/discourse/dockan.yml"
dockan compose up -f "$TARGET_ROOT/n8n/dockan.yml"

echo "Attente de stabilisation (8 secondes)..."
sleep 8

echo ""
echo "✅ Statut global final des conteneurs :"
dockan ps -a --scope all
