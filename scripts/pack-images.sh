#!/usr/bin/env sh
set -eu

app="${1:-}"
registry="${2:-${DOCKAN_STORE_REGISTRY:-}}"
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ -z "$app" ]; then
  echo "Usage: $0 <app-id|all> [registry-dir]" >&2
  echo "Example: $0 all ./registry" >&2
  exit 1
fi

if [ -z "$registry" ]; then
  registry="$root/registry"
fi

requires_for_app() {
  app_id="$1"
  meta="$root/apps/$app_id/dockan-store.yml"
  if [ ! -f "$meta" ]; then
    echo "Unknown app: $app_id" >&2
    return 1
  fi
  awk '
    /^requires:/ { in_requires=1; next }
    in_requires && /^[^[:space:]-]/ { in_requires=0 }
    in_requires && /^[[:space:]]*-/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      gsub(/["'\'']/, "", line)
      if (line != "") print line
    }
  ' "$meta"
}

all_requires() {
  if [ "$app" = "all" ]; then
    for dir in "$root"/apps/*; do
      [ -d "$dir" ] || continue
      requires_for_app "$(basename "$dir")"
    done
  else
    requires_for_app "$app"
  fi | sort -u
}

if ! command -v dockan >/dev/null 2>&1; then
  echo "Erreur: dockan est introuvable dans PATH." >&2
  exit 1
fi

if [ "${DOCKAN_STORE_DRY_RUN:-}" = "1" ]; then
  echo "Would pack images for: $app"
  all_requires
  exit 0
fi

mkdir -p "$registry/images"

for image in $(all_requires); do
  echo "Packing image: $image"
  dockan push "$image" "$registry"
done

echo "Image registry ready: $registry"
