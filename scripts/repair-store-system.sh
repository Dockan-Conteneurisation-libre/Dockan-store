#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur: Ce script doit être exécuté avec les privilèges root." >&2
  echo "Usage: sudo $0" >&2
  exit 1
fi

TARGET_ROOT="${DOCKAN_STORE_TARGET_ROOT:-/srv/dockan-apps}"

echo "=== [1/3] Finalisation de PrestaShop ==="
dockan compose down -f "$TARGET_ROOT/prestashop/dockan.yml" >/dev/null 2>&1 || true
rm -rf /var/lib/dockan/volumes/prestashop-db
mkdir -p /var/lib/dockan/volumes/prestashop-db
chown -R 999:999 /var/lib/dockan/volumes/prestashop-db
chmod 750 /var/lib/dockan/volumes/prestashop-db
dockan compose up -f "$TARGET_ROOT/prestashop/dockan.yml" || true

echo "=== [2/3] Démarrage de Mattermost-web ==="
dockan compose up -f "$TARGET_ROOT/mattermost/dockan.yml" || true

echo "=== [3/3] Démarrage de Discourse ==="
dockan compose up -f "$TARGET_ROOT/discourse/dockan.yml" || true

echo "Attente de stabilisation (10 secondes)..."
sleep 10

echo ""
echo "✅ Statut global final des conteneurs :"
dockan ps -a --scope all
