#!/usr/bin/env sh
set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
target_root="${DOCKAN_STORE_TARGET_ROOT:-/srv/dockan-apps}"

if [ "$#" -eq 0 ]; then
  set -- prestashop immich plausible forgejo discourse mattermost stirling-pdf mealie vikunja anarcosyndicalismebook
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur: relance avec sudo pour reparer les apps systeme sous $target_root." >&2
  echo "Exemple: sudo $0 $*" >&2
  exit 1
fi

stamp="$(date +%Y%m%d-%H%M%S)"

postgres_volume_for() {
  case "$1" in
    discourse) printf '%s\n' discourse-db ;;
    forgejo) printf '%s\n' forgejo-db ;;
    mattermost) printf '%s\n' mattermost-db ;;
    plausible) printf '%s\n' plausible-db ;;
    *) return 1 ;;
  esac
}

warn_postgres_layout() {
  app="$1"
  volume="$(postgres_volume_for "$app" 2>/dev/null || true)"
  [ -n "$volume" ] || return 0

  path="/var/lib/dockan/volumes/$volume"
  [ -d "$path" ] || return 0

  if [ -d "$path/data" ] && [ -d "$path/18/docker" ]; then
    echo "Attention: $volume contient a la fois data/ et 18/docker/."
    echo "Je ne supprime rien en prod. Si PostgreSQL refuse de demarrer, sauvegarde puis migre/nettoie ce volume manuellement."
  fi
}

for app in "$@"; do
  src="$root/apps/$app/dockan.yml"
  dst="$target_root/$app/dockan.yml"

  if [ ! -f "$src" ]; then
    echo "App inconnue dans le Store: $app" >&2
    exit 1
  fi
  if [ ! -d "$target_root/$app" ]; then
    echo "Installation absente, ignoree: $target_root/$app"
    continue
  fi

  echo
  echo "== $app =="
  warn_postgres_layout "$app"
  "$root/scripts/prepare-images.sh" "$app"

  if [ -f "$dst" ]; then
    cp "$dst" "$dst.bak-$stamp"
    echo "Sauvegarde: $dst.bak-$stamp"
  fi

  cp "$src" "$dst"
  echo "Modele mis a jour: $dst"

  dockan compose redeploy -f "$dst"
done

echo
echo "Reparation terminee. Verifie l'etat avec:"
echo "  sudo dockan ps -a --scope all"
