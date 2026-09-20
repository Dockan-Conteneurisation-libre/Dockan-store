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

echo "=== [1/6] Arrêt des conteneurs pour libérer les processus et verrous ==="
containers=(
  anarcosyndicalismebook-web anarcosyndicalismebook-db
  discourse-web discourse-db discourse-redis
  forgejo-web forgejo-db
  immich-web immich-microservices immich-db immich-redis
  mattermost-web mattermost-db
  mealie-web
  plausible-web plausible-db plausible-clickhouse
  prestashop-web prestashop-db
  stirling-pdf-web
  vikunja-web vikunja-db
)
for c in "${containers[@]}"; do
  dockan stop "$c" >/dev/null 2>&1 || true
done

echo "=== [2/6] Nettoyage des segments de mémoire partagée orphelins (IPC) ==="
for id in $(ipcs -m 2>/dev/null | awk '$6 == 0 {print $2}'); do
  ipcrm -m "$id" >/dev/null 2>&1 || true
done

echo "=== [3/6] Réinitialisation propre des 5 bases de données corrompues ==="
fresh_init_volume() {
  local vol_name="$1"
  local owner="${2:-999:999}"
  local dir="/var/lib/dockan/volumes/$vol_name"

  if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
    local backup="$dir.bak-$STAMP"
    echo "  -> Sauvegarde du volume $vol_name vers $backup"
    cp -a "$dir" "$backup"
    rm -rf "${dir:?}"/*
  fi
  mkdir -p "$dir"
  chown -R "$owner" "$dir"
  chmod 750 "$dir"
  echo "  -> Volume $vol_name prêt et vierge pour initialisation propre."
}

# Ces 5 bases de données avaient des résidus corrompus empêchant initdb/mariadb-install-db
fresh_init_volume "prestashop-db" "999:999"
fresh_init_volume "discourse-db" "999:999"
fresh_init_volume "forgejo-db" "999:999"
fresh_init_volume "mattermost-db" "999:999"
fresh_init_volume "plausible-db" "999:999"

echo "=== [4/6] Préparation des volumes d'isolation de sockets (/run) ==="
clean_run_volume() {
  local vol_name="$1"
  local owner="${2:-999:999}"
  local dir="/var/lib/dockan/volumes/$vol_name"
  mkdir -p "$dir"
  rm -rf "${dir:?}"/*
  chown -R "$owner" "$dir"
  chmod 775 "$dir"
}

clean_run_volume "prestashop-db-run" "999:999"
clean_run_volume "vikunja-db-run" "999:999"
clean_run_volume "anarcosyndicalismebook-db-run" "999:999"
clean_run_volume "discourse-db-run" "999:999"
clean_run_volume "plausible-db-run" "999:999"
clean_run_volume "mattermost-db-run" "999:999"
clean_run_volume "forgejo-db-run" "999:999"
clean_run_volume "forgejo-run" "1000:1000"
clean_run_volume "immich-db-run" "999:999"

echo "=== [5/6] Configuration des permissions applicatives ciblées ==="
# PrestaShop
if [ -d /var/lib/dockan/volumes/prestashop-data ]; then
  mkdir -p /var/lib/dockan/volumes/prestashop-data/var/cache /var/lib/dockan/volumes/prestashop-data/var/logs
  chown -R 33:33 /var/lib/dockan/volumes/prestashop-data/var
  chmod -R u+rwX,g+rwX /var/lib/dockan/volumes/prestashop-data/var
fi

# Forgejo (UID 1000 pour git)
if [ -d /var/lib/dockan/volumes/forgejo-data ]; then
  chown -R 1000:1000 /var/lib/dockan/volumes/forgejo-data
fi

# Mattermost (UID 2000 pour l'application, mais DB reste à 999)
for v in mattermost-data mattermost-logs mattermost-config mattermost-plugins; do
  dir="/var/lib/dockan/volumes/$v"
  [ -d "$dir" ] && chown -R 2000:2000 "$dir" || true
done

echo "=== [6/6] Synchronisation des modèles et Redéploiement ordonné ==="
for app_dir in "$STORE_DIR"/apps/*; do
  [ -d "$app_dir" ] || continue
  app="$(basename "$app_dir")"
  src="$app_dir/dockan.yml"

  dst="$TARGET_ROOT/$app/dockan.yml"
  if [ -d "$TARGET_ROOT/$app" ] && [ -f "$src" ]; then
    cp "$src" "$dst"
  fi

  if [ -d "$PANEL_STORE/$app" ] && [ -f "$src" ]; then
    cp "$src" "$PANEL_STORE/$app/dockan.yml"
  fi
done

# Redéploiement d'abord des bases de données
echo "Démarrage des bases de données..."
for app in prestashop discourse forgejo mattermost plausible vikunja; do
  yml="$TARGET_ROOT/$app/dockan.yml"
  if [ -f "$yml" ]; then
    dockan compose up -f "$yml" || true
  fi
done

echo "Attente de l'initialisation des bases (5 secondes)..."
sleep 5

# Redéploiement des services web dépendants
for app in prestashop immich discourse plausible mattermost vikunja forgejo anarcosyndicalismebook stirling-pdf mealie; do
  yml="$TARGET_ROOT/$app/dockan.yml"
  if [ -f "$yml" ]; then
    dockan compose up -f "$yml" || true
  fi
done

echo ""
echo "✅ Toutes les applications ont été réinitialisées proprement et redéployées !"
echo "État des conteneurs :"
dockan ps -a --scope all
