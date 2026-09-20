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

echo "=== [1/6] Arrêt des conteneurs ciblés pour libérer les verrous ==="
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

echo "=== [2/6] Nettoyage et sécurisation des volumes de base de données corrompus ==="
backup_and_reset_volume() {
  local vol_name="$1"
  local owner="${2:-999:999}"
  local dir="/var/lib/dockan/volumes/$vol_name"

  if [ -d "$dir" ]; then
    local backup="$dir.bak-$STAMP"
    echo "  -> Sauvegarde du volume $vol_name vers $backup"
    cp -a "$dir" "$backup"
    rm -rf "${dir:?}"/*
    chown -R "$owner" "$dir"
    chmod 750 "$dir"
    echo "  -> Volume $vol_name assaini et réinitialisé."
  else
    mkdir -p "$dir"
    chown -R "$owner" "$dir"
    chmod 750 "$dir"
  fi
}

# Assainissement des volumes MariaDB corrompus ou croisés
if [ -d /var/lib/dockan/volumes/anarcosyndicalismebook-db/prestashop ]; then
  echo "Détection de résidus PrestaShop dans anarcosyndicalismebook-db."
  backup_and_reset_volume "anarcosyndicalismebook-db" "999:999"
fi

if [ -d /var/lib/dockan/volumes/vikunja-db/prestashop ]; then
  echo "Détection de résidus PrestaShop dans vikunja-db."
  backup_and_reset_volume "vikunja-db" "999:999"
fi

# Assainissement des volumes PostgreSQL corrompus
if [ -d /var/lib/dockan/volumes/mattermost-db ] && { grep -q "PANIC" /var/lib/dockan/containers/mattermost-db/dockan.log 2>/dev/null || [ -e /var/lib/dockan/volumes/mattermost-db/forgejo.custom* ]; }; then
  echo "Détection de corruption/checkpoint invalide dans mattermost-db."
  backup_and_reset_volume "mattermost-db" "999:999"
fi

if [ -d /var/lib/dockan/volumes/plausible-db/data ] && [ -d /var/lib/dockan/volumes/plausible-db/18 ]; then
  echo "Détection de structure hybride corrompue dans plausible-db."
  backup_and_reset_volume "plausible-db" "999:999"
fi

if [ -d /var/lib/dockan/volumes/discourse-db/data ] && [ -d /var/lib/dockan/volumes/discourse-db/18 ]; then
  echo "Détection de structure hybride corrompue dans discourse-db."
  backup_and_reset_volume "discourse-db" "999:999"
fi

echo "=== [3/6] Préparation des volumes d'isolation de sockets (/run) ==="
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

echo "=== [4/6] Permissions applicatives spéciales ==="
# PrestaShop
if [ -d /var/lib/dockan/volumes/prestashop-data ]; then
  mkdir -p /var/lib/dockan/volumes/prestashop-data/var/cache /var/lib/dockan/volumes/prestashop-data/var/logs
  chown -R 33:33 /var/lib/dockan/volumes/prestashop-data/var
  chmod -R u+rwX,g+rwX /var/lib/dockan/volumes/prestashop-data/var
fi

# Forgejo
if [ -d /var/lib/dockan/volumes/forgejo-data ]; then
  chown -R 1000:1000 /var/lib/dockan/volumes/forgejo-data
fi

# Mattermost
if [ -d /var/lib/dockan/volumes/mattermost-data ]; then
  chown -R 2000:2000 /var/lib/dockan/volumes/mattermost-* 2>/dev/null || true
fi

echo "=== [5/6] Synchronisation des 31 modèles validés vers le Panel et les apps installées ==="
for app_dir in "$STORE_DIR"/apps/*; do
  [ -d "$app_dir" ] || continue
  app="$(basename "$app_dir")"
  src="$app_dir/dockan.yml"

  # Copie vers les applications installées sur le serveur
  dst="$TARGET_ROOT/$app/dockan.yml"
  if [ -d "$TARGET_ROOT/$app" ] && [ -f "$src" ]; then
    cp "$src" "$dst"
    echo "  -> Modèle synchronisé pour $app: $dst"
  fi

  # Copie vers le catalogue local du Dockan-Panel
  if [ -d "$PANEL_STORE/$app" ] && [ -f "$src" ]; then
    cp "$src" "$PANEL_STORE/$app/dockan.yml"
  fi
done

echo "=== [6/6] Redéploiement des applications ==="
for app in prestashop immich discourse plausible mattermost vikunja forgejo anarcosyndicalismebook stirling-pdf mealie; do
  yml="$TARGET_ROOT/$app/dockan.yml"
  if [ -f "$yml" ]; then
    echo "Redéploiement de $app..."
    dockan compose up -f "$yml" || true
  fi
done

echo ""
echo "✅ Opération terminée avec succès."
echo "Vérification des conteneurs :"
dockan ps -a --scope all
