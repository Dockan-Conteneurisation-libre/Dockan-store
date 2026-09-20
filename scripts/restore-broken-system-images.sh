#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur: relance avec sudo." >&2
  echo "Exemple: sudo $0" >&2
  exit 1
fi

restore_image() {
  tag="$1"
  archive="$2"
  dir="/var/lib/dockan/images/$3"

  if [ ! -f "$archive" ]; then
    echo "Archive absente: $archive" >&2
    exit 1
  fi

  mkdir -p "$dir"

  if [ -f "$dir/meta.conf" ] && [ -f "$dir/start.sh" ]; then
    echo "Image deja lisible: $tag"
    return 0
  fi

  echo "Restauration image: $tag"
  tar -xzf "$archive" -C "$dir"
  chown -R root:root "$dir"

  if [ ! -f "$dir/meta.conf" ] || [ ! -f "$dir/start.sh" ]; then
    echo "Restauration incomplete: $tag" >&2
    exit 1
  fi
}

restore_image "postgres:local" \
  "/tmp/dockan-mattermost-registry/images/postgres_local.tar.gz" \
  "postgres_local.dockan"

restore_image "immich-postgres:local" \
  "/tmp/dockan-immich-postgres-registry/images/immich-postgres_local.tar.gz" \
  "immich-postgres_local.dockan"

restore_image "vikunja:local" \
  "/tmp/dockan-vikunja-registry/images/vikunja_local.tar.gz" \
  "vikunja_local.dockan"

echo
echo "Images restaurees. Prochaine etape conseillee:"
echo "  sudo dockan compose redeploy -f /srv/dockan-apps/immich/dockan.yml"
echo "  sudo dockan compose redeploy -f /srv/dockan-apps/discourse/dockan.yml"
echo "  sudo dockan compose redeploy -f /srv/dockan-apps/plausible/dockan.yml"
echo "  sudo dockan compose redeploy -f /srv/dockan-apps/mattermost/dockan.yml"
echo "  sudo dockan compose redeploy -f /srv/dockan-apps/vikunja/dockan.yml"
