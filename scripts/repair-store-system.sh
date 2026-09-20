#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur: Ce script doit être exécuté avec les privilèges root." >&2
  echo "Usage: sudo $0" >&2
  exit 1
fi

TARGET_ROOT="${DOCKAN_STORE_TARGET_ROOT:-/srv/dockan-apps}"

echo "=== Redéploiement propre des 4 services (sans toucher aux volumes) ==="
for app in mattermost plausible discourse n8n; do
  yml="$TARGET_ROOT/$app/dockan.yml"
  if [ -f "$yml" ]; then
    echo "Redémarrage de $app..."
    dockan compose up -f "$yml" || true
  fi
done

echo "Attente de stabilisation (6 secondes)..."
sleep 6

echo ""
echo "✅ Statut global final des conteneurs :"
dockan ps -a --scope all
