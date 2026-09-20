#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur: Ce script doit être exécuté avec les privilèges root." >&2
  echo "Usage: sudo $0" >&2
  exit 1
fi

STORE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET_ROOT="${DOCKAN_STORE_TARGET_ROOT:-/srv/dockan-apps}"

echo "=== [1/4] Arrêt et nettoyage propre de Discourse et Forgejo ==="
dockan stop discourse-web discourse-db forgejo-web forgejo-db vikunja-web >/dev/null 2>&1 || true
dockan rm discourse-web discourse-db forgejo-web forgejo-db vikunja-web >/dev/null 2>&1 || true

reset_clean_dir() {
  local dir="$1"
  local owner="${2:-999:999}"
  rm -rf "$dir"
  mkdir -p "$dir"
  chown -R "$owner" "$dir"
  chmod 750 "$dir"
}

reset_clean_dir "/var/lib/dockan/volumes/discourse-db" "999:999"
reset_clean_dir "/var/lib/dockan/volumes/discourse-db-run" "999:999"

reset_clean_dir "/var/lib/dockan/volumes/forgejo-db" "999:999"
reset_clean_dir "/var/lib/dockan/volumes/forgejo-db-run" "999:999"
reset_clean_dir "/var/lib/dockan/volumes/forgejo-run" "1000:1000"

echo "=== [2/4] Redéploiement de Vikunja ==="
dockan compose redeploy -f "$TARGET_ROOT/vikunja/dockan.yml" || dockan compose up -f "$TARGET_ROOT/vikunja/dockan.yml" || true

echo "=== [3/4] Redéploiement de Forgejo ==="
dockan compose redeploy -f "$TARGET_ROOT/forgejo/dockan.yml" || dockan compose up -f "$TARGET_ROOT/forgejo/dockan.yml" || true

echo "=== [4/4] Redéploiement de Discourse ==="
dockan compose redeploy -f "$TARGET_ROOT/discourse/dockan.yml" || dockan compose up -f "$TARGET_ROOT/discourse/dockan.yml" || true

echo "Attente de démarrage (8 secondes)..."
sleep 8

echo ""
echo "✅ Toutes les applications ont été déployées !"
echo "État actuel des conteneurs :"
dockan ps -a --scope all
