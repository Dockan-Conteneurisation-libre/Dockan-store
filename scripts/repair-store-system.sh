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

echo "=== Synchronisation du modèle Discourse (port 4000:80) ==="
cp "$STORE_DIR/apps/discourse/dockan.yml" "$TARGET_ROOT/discourse/dockan.yml"
[ -d "$PANEL_STORE/discourse" ] && cp "$STORE_DIR/apps/discourse/dockan.yml" "$PANEL_STORE/discourse/dockan.yml" || true

echo "=== Lancement de Discourse ==="
dockan compose up -f "$TARGET_ROOT/discourse/dockan.yml"

echo "Attente de démarrage (8 secondes)..."
sleep 8

echo ""
echo "✅ Statut global complet des conteneurs :"
dockan ps -a --scope all
