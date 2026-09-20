#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur: Ce script doit être exécuté avec les privilèges root." >&2
  echo "Usage: sudo $0" >&2
  exit 1
fi

STORE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET_ROOT="${DOCKAN_STORE_TARGET_ROOT:-/srv/dockan-apps}"
PANEL_STORE="/var/lib/dockan/volumes/dockan-panel-data/store/Dockan-Store/apps"

echo "=== [1/3] Suppression du conteneur obsolète immich-microservices ==="
dockan rm immich-microservices >/dev/null 2>&1 || true

echo "=== [2/3] Redémarrage de n8n ==="
if [ -d "$TARGET_ROOT/n8n" ]; then
  cp "$STORE_DIR/apps/n8n/dockan.yml" "$TARGET_ROOT/n8n/dockan.yml"
  [ -d "$PANEL_STORE/n8n" ] && cp "$STORE_DIR/apps/n8n/dockan.yml" "$PANEL_STORE/n8n/dockan.yml" || true
  dockan compose up -f "$TARGET_ROOT/n8n/dockan.yml" || true
fi

echo "=== [3/3] Démarrage de Discourse ==="
if [ -d "$TARGET_ROOT/discourse" ]; then
  cp "$STORE_DIR/apps/discourse/dockan.yml" "$TARGET_ROOT/discourse/dockan.yml"
  [ -d "$PANEL_STORE/discourse" ] && cp "$STORE_DIR/apps/discourse/dockan.yml" "$PANEL_STORE/discourse/dockan.yml" || true
  dockan compose up -f "$TARGET_ROOT/discourse/dockan.yml" || true
fi

echo "Attente de démarrage (8 secondes)..."
sleep 8

echo ""
echo "✅ Statut global final des conteneurs :"
dockan ps -a --scope all
