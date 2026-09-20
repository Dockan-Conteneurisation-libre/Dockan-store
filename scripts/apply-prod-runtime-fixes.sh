#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur: relance avec sudo." >&2
  echo "Exemple: sudo $0" >&2
  exit 1
fi

target_root="${DOCKAN_STORE_TARGET_ROOT:-/srv/dockan-apps}"
stamp="$(date +%Y%m%d-%H%M%S)"

stop_container() {
  name="$1"
  dockan stop "$name" >/dev/null 2>&1 || true
}

restore_archive_image() {
  tag="$1"
  image_dir="$2"
  archive="$3"

  if [ ! -f "$archive" ]; then
    echo "Archive absente pour $tag: $archive" >&2
    exit 1
  fi

  echo "Restauration image $tag"
  backup="/var/lib/dockan/images/$image_dir.bak-$stamp"
  if [ -e "/var/lib/dockan/images/$image_dir" ]; then
    mv "/var/lib/dockan/images/$image_dir" "$backup"
    echo "Sauvegarde image: $backup"
  fi

  mkdir -p "/var/lib/dockan/images/$image_dir"
  tar -xzf "$archive" -C "/var/lib/dockan/images/$image_dir"
  chown -R root:root "/var/lib/dockan/images/$image_dir"
}

copy_model() {
  app="$1"
  src="apps/$app/dockan.yml"
  dst="$target_root/$app/dockan.yml"
  [ -f "$src" ] || return 0
  [ -f "$dst" ] || return 0
  cp "$dst" "$dst.bak-$stamp"
  cp "$src" "$dst"
  echo "Modele mis a jour: $dst"
}

append_pg_hba() {
  volume="$1"
  cidr="$2"
  hba="$(find "/var/lib/dockan/volumes/$volume" -name pg_hba.conf -print 2>/dev/null | head -n 1)"
  [ -n "$hba" ] || return 0
  if ! grep -F "host all all $cidr scram-sha-256" "$hba" >/dev/null 2>&1; then
    cp "$hba" "$hba.bak-$stamp"
    printf '\nhost all all %s scram-sha-256\n' "$cidr" >> "$hba"
    echo "pg_hba autorise $cidr pour $volume"
  fi
}

clean_runtime_volume() {
  volume="$1"
  owner="${2:-999:999}"
  dir="/var/lib/dockan/volumes/$volume"

  mkdir -p "$dir"
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  chown "$owner" "$dir"
  chmod 775 "$dir"
  echo "Runtime nettoye: $volume"
}

fix_tree_owner_if_exists() {
  path="$1"
  owner="$2"
  [ -e "$path" ] || return 0
  chown -R "$owner" "$path"
}

quarantine_default_pgdata_if_allowed() {
  volume="$1"
  dir="/var/lib/dockan/volumes/$volume/18/docker"

  [ "${DOCKAN_REINIT_BROKEN_DB:-0}" = "1" ] || return 0
  [ -d "$dir" ] || return 0

  backup="$dir.broken-$stamp"
  mv "$dir" "$backup"
  echo "PGDATA par defaut mis de cote: $backup"
}

quarantine_custom_pgdata_if_allowed() {
  volume="$1"
  app="$2"
  dir="/var/lib/dockan/volumes/$volume/$app"

  [ "${DOCKAN_REINIT_BROKEN_DB:-0}" = "1" ] || return 0
  [ -d "$dir" ] || return 0

  backup="$dir.custom-$stamp"
  mv "$dir" "$backup"
  echo "Ancien PGDATA custom mis de cote: $backup"
}

quarantine_broken_mariadb_if_allowed() {
  volume="$1"
  dir="/var/lib/dockan/volumes/$volume"

  [ "${DOCKAN_REINIT_BROKEN_DB:-0}" = "1" ] || return 0
  [ -d "$dir/mysql" ] || return 0
  [ ! -f "$dir/mysql/db.MAI" ] || return 0

  backup="$dir.broken-$stamp"
  mv "$dir" "$backup"
  echo "MariaDB corrompu mis de cote pour reinitialisation: $backup"
}

network_cidr_for_container() {
  meta="/var/lib/dockan/containers/$1/meta.conf"
  awk -F= '/^networkIP=/{ split($2, parts, "."); split($2, cidr, "/"); if (cidr[2] != "") print parts[1]"."parts[2]"."parts[3]".0/"cidr[2] }' "$meta" 2>/dev/null | head -n 1
}

fix_prestashop_var() {
  [ -d /var/lib/dockan/volumes/prestashop-data ] || return 0
  echo "Correction ciblee PrestaShop var/"
  mkdir -p /var/lib/dockan/volumes/prestashop-data/var/cache /var/lib/dockan/volumes/prestashop-data/var/logs
  chown -R 33:33 /var/lib/dockan/volumes/prestashop-data/var
  chmod -R u+rwX,g+rwX /var/lib/dockan/volumes/prestashop-data/var
}

echo "Arret des conteneurs qui vont etre repares"
for c in mattermost-web mattermost-db vikunja-web vikunja-db immich-web immich-microservices immich-db discourse-web discourse-db plausible-web plausible-db prestashop-web prestashop-db forgejo-web forgejo-db anarcosyndicalismebook-web anarcosyndicalismebook-db; do
  stop_container "$c"
done

copy_model prestashop
copy_model immich
copy_model discourse
copy_model plausible
copy_model mattermost
copy_model vikunja
copy_model forgejo
copy_model anarcosyndicalismebook

restore_archive_image "mattermost:local" "mattermost_local.dockan" "/tmp/dockan-mattermost-registry/images/mattermost_local.tar.gz"
restore_archive_image "vikunja:local" "vikunja_local.dockan" "/tmp/dockan-vikunja-registry/images/vikunja_local.tar.gz"
restore_archive_image "immich-postgres:local" "immich-postgres_local.dockan" "/tmp/dockan-immich-postgres-registry/images/immich-postgres_local.tar.gz"

if [ ! -f /var/lib/dockan/images/postgres_local.dockan/meta.conf ]; then
  restore_archive_image "postgres:local" "postgres_local.dockan" "/tmp/dockan-mattermost-registry/images/postgres_local.tar.gz"
fi

fix_prestashop_var

clean_runtime_volume prestashop-db-run 999:999
clean_runtime_volume vikunja-db-run 999:999
clean_runtime_volume anarcosyndicalismebook-db-run 999:999
clean_runtime_volume discourse-db-run 999:999
clean_runtime_volume plausible-db-run 999:999
clean_runtime_volume mattermost-db-run 999:999
clean_runtime_volume forgejo-db-run 999:999
clean_runtime_volume forgejo-run 0:0

quarantine_default_pgdata_if_allowed discourse-db
quarantine_default_pgdata_if_allowed plausible-db
quarantine_default_pgdata_if_allowed mattermost-db
quarantine_default_pgdata_if_allowed forgejo-db
quarantine_custom_pgdata_if_allowed discourse-db discourse
quarantine_custom_pgdata_if_allowed plausible-db plausible
quarantine_custom_pgdata_if_allowed mattermost-db mattermost
quarantine_custom_pgdata_if_allowed forgejo-db forgejo
quarantine_broken_mariadb_if_allowed prestashop-db
quarantine_broken_mariadb_if_allowed vikunja-db
quarantine_broken_mariadb_if_allowed anarcosyndicalismebook-db

fix_tree_owner_if_exists /var/lib/dockan/volumes/prestashop-db 999:999
fix_tree_owner_if_exists /var/lib/dockan/volumes/vikunja-db 999:999
fix_tree_owner_if_exists /var/lib/dockan/volumes/anarcosyndicalismebook-db 999:999
fix_tree_owner_if_exists /var/lib/dockan/volumes/discourse-db 999:999
fix_tree_owner_if_exists /var/lib/dockan/volumes/plausible-db 999:999
fix_tree_owner_if_exists /var/lib/dockan/volumes/mattermost-db 999:999
fix_tree_owner_if_exists /var/lib/dockan/volumes/forgejo-db 999:999

for pair in "discourse-db discourse-db" "plausible-db plausible-db" "mattermost-db mattermost-db"; do
  set -- $pair
  cidr="$(network_cidr_for_container "$1" || true)"
  [ -n "$cidr" ] && append_pg_hba "$2" "$cidr"
done

echo "Redeploiement"
for app in prestashop immich discourse plausible mattermost vikunja forgejo anarcosyndicalismebook; do
  if [ -f "$target_root/$app/dockan.yml" ]; then
    dockan compose redeploy -f "$target_root/$app/dockan.yml" || true
  fi
done

fix_prestashop_var
dockan stop prestashop-web >/dev/null 2>&1 || true
[ -f "$target_root/prestashop/dockan.yml" ] && dockan compose redeploy -f "$target_root/prestashop/dockan.yml" || true
fix_prestashop_var

echo
echo "Verification conseillee:"
echo "  sudo dockan ps -a --scope all"
