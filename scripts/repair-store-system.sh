#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur: Ce script doit être exécuté avec les privilèges root." >&2
  echo "Usage: sudo $0" >&2
  exit 1
fi

STORE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET_ROOT="${DOCKAN_STORE_TARGET_ROOT:-/srv/dockan-apps}"

echo "=== [1/4] Arrêt propre de Discourse, Forgejo et Vikunja ==="
dockan compose down -f "$TARGET_ROOT/discourse/dockan.yml" >/dev/null 2>&1 || true
dockan compose down -f "$TARGET_ROOT/forgejo/dockan.yml" >/dev/null 2>&1 || true
dockan compose down -f "$TARGET_ROOT/vikunja/dockan.yml" >/dev/null 2>&1 || true

reset_clean_dir() {
  local dir="$1"
  local owner="${2:-999:999}"
  if [ -d "$dir" ]; then
    find "$dir" -mindepth 1 -delete 2>/dev/null || rm -rf "${dir:?}"/* 2>/dev/null || true
  else
    mkdir -p "$dir"
  fi
  chown -R "$owner" "$dir" 2>/dev/null || true
  chmod 750 "$dir" 2>/dev/null || true
}

reset_clean_dir "/var/lib/dockan/volumes/discourse-db" "999:999"
reset_clean_dir "/var/lib/dockan/volumes/discourse-db-run" "999:999"

reset_clean_dir "/var/lib/dockan/volumes/forgejo-db" "999:999"
reset_clean_dir "/var/lib/dockan/volumes/forgejo-db-run" "999:999"
reset_clean_dir "/var/lib/dockan/volumes/forgejo-run" "1000:1000"

echo "=== [2/4] Redéploiement de Vikunja ==="
dockan compose up -f "$TARGET_ROOT/vikunja/dockan.yml" || true

echo "=== [3/4] Redéploiement de Forgejo ==="
dockan compose up -f "$TARGET_ROOT/forgejo/dockan.yml" || true

echo "=== [4/4] Redéploiement de Discourse ==="
dockan compose up -f "$TARGET_ROOT/discourse/dockan.yml" || true

echo "Attente de démarrage (8 secondes)..."
sleep 8

echo ""
echo "✅ Redéploiement terminé !"
echo "État actuel des conteneurs :"
dockan ps -a --scope all
