#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur: Ce script doit être exécuté avec les privilèges root." >&2
  echo "Usage: sudo $0" >&2
  exit 1
fi

STORE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET_ROOT="${DOCKAN_STORE_TARGET_ROOT:-/srv/dockan-apps}"

echo "=== [1/4] Arrêt des conteneurs cibles ==="
dockan stop prestashop-web prestashop-db mattermost-web >/dev/null 2>&1 || true
dockan rm prestashop-web prestashop-db mattermost-web >/dev/null 2>&1 || true

echo "=== [2/4] Nettoyage complet (y compris fichiers cachés) de prestashop-db ==="
dir="/var/lib/dockan/volumes/prestashop-db"
rm -rf "$dir"
mkdir -p "$dir"
chown -R 999:999 "$dir"
chmod 750 "$dir"

echo "Nettoyage du socket runtime..."
rm -rf /var/lib/dockan/volumes/prestashop-db-run
mkdir -p /var/lib/dockan/volumes/prestashop-db-run
chown -R 999:999 /var/lib/dockan/volumes/prestashop-db-run
chmod 775 /var/lib/dockan/volumes/prestashop-db-run

echo "Permissions PrestaShop web..."
mkdir -p /var/lib/dockan/volumes/prestashop-data/var/cache /var/lib/dockan/volumes/prestashop-data/var/logs
chown -R 33:33 /var/lib/dockan/volumes/prestashop-data/var
chmod -R u+rwX,g+rwX /var/lib/dockan/volumes/prestashop-data/var

echo "=== [3/4] Redéploiement de Mattermost ==="
dockan compose redeploy -f "$TARGET_ROOT/mattermost/dockan.yml" || dockan compose up -f "$TARGET_ROOT/mattermost/dockan.yml" || true

echo "=== [4/4] Redéploiement de PrestaShop ==="
dockan compose redeploy -f "$TARGET_ROOT/prestashop/dockan.yml" || dockan compose up -f "$TARGET_ROOT/prestashop/dockan.yml" || true

echo "Attente de finalisation (6 secondes)..."
sleep 6

echo ""
echo "✅ Redéploiement terminé !"
echo "État des conteneurs :"
dockan ps -a --scope all
