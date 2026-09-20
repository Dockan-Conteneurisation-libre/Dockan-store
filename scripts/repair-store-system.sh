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
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "=== [1/6] Arrêt des conteneurs PrestaShop et Mattermost-web ==="
dockan stop prestashop-web prestashop-db mattermost-web >/dev/null 2>&1 || true

echo "=== [2/6] Nettoyage et initialisation vierge de prestashop-db ==="
dir="/var/lib/dockan/volumes/prestashop-db"
if [ -d "$dir" ]; then
  rm -rf "${dir:?}"/*
fi
mkdir -p "$dir"
chown -R 999:999 "$dir"
chmod 750 "$dir"

echo "=== [3/6] Nettoyage du socket runtime prestashop-db-run ==="
mkdir -p /var/lib/dockan/volumes/prestashop-db-run
rm -rf /var/lib/dockan/volumes/prestashop-db-run/*
chown -R 999:999 /var/lib/dockan/volumes/prestashop-db-run
chmod 775 /var/lib/dockan/volumes/prestashop-db-run

echo "=== [4/6] Permissions PrestaShop web ==="
mkdir -p /var/lib/dockan/volumes/prestashop-data/var/cache /var/lib/dockan/volumes/prestashop-data/var/logs
chown -R 33:33 /var/lib/dockan/volumes/prestashop-data/var
chmod -R u+rwX,g+rwX /var/lib/dockan/volumes/prestashop-data/var

echo "=== [5/6] Démarrage de prestashop-db seul pour installation propre des tables ==="
dockan start prestashop-db || dockan compose up -f "$TARGET_ROOT/prestashop/dockan.yml" prestashop-db || true
echo "Attente de l'installation des tables MariaDB PrestaShop (12 secondes)..."
sleep 12

echo "=== [6/6] Démarrage des conteneurs web (PrestaShop et Mattermost) ==="
dockan start prestashop-web || true
dockan start mattermost-web || true

echo ""
echo "✅ Opération terminée !"
echo "État actuel des conteneurs :"
dockan ps -a --scope all
