#!/usr/bin/env sh
set -eu

app="${1:-}"
registry="${2:-${DOCKAN_STORE_REGISTRY:-}}"
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ -z "$app" ]; then
  echo "Usage: $0 <app-id|all> [registry-dir]" >&2
  echo "Example: $0 wordpress" >&2
  exit 1
fi

if [ "${DOCKAN_STORE_SKIP_IMAGES:-}" = "1" ]; then
  echo "Skipping image preparation because DOCKAN_STORE_SKIP_IMAGES=1"
  exit 0
fi

if [ -z "$registry" ]; then
  if [ -d "$root/registry/images" ]; then
    registry="$root/registry"
  elif [ -d "$root/.dockan-store/registry/images" ]; then
    registry="$root/.dockan-store/registry"
  else
    registry="$root/registry"
  fi
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

safe_ref() {
  printf "%s" "$1" | sed 's/[^A-Za-z0-9._-]/_/g'
}

download_app_registry_pack() {
  if [ "$app" = "all" ] || [ "${DOCKAN_STORE_AUTO_DOWNLOAD_IMAGES:-1}" = "0" ]; then
    return 1
  fi
  base="${DOCKAN_STORE_RELEASE_BASE:-https://github.com/Dockan-Conteneurisation-libre/Dockan-store/releases/latest/download}"
  url="$base/dockan-store-images-$app.tar.gz"
  tmp="$(mktemp -d)"
  cleanup_download() {
    rm -rf "$tmp"
  }
  trap cleanup_download EXIT INT TERM

  echo "Downloading prebuilt image pack for $app"
  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "$url" -o "$tmp/images.tar.gz"; then
      echo "Unable to download app image pack: $url" >&2
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -qO "$tmp/images.tar.gz" "$url"; then
      echo "Unable to download app image pack: $url" >&2
      return 1
    fi
  else
    echo "curl or wget is required to download app image packs." >&2
    return 1
  fi

  mkdir -p "$registry"
  if ! tar -xzf "$tmp/images.tar.gz" -C "$tmp"; then
    echo "Invalid app image pack archive: $url" >&2
    return 1
  fi
  if [ ! -d "$tmp/registry" ]; then
    echo "Invalid app image pack: $url" >&2
    return 1
  fi
  cp -a "$tmp/registry/." "$registry/"
  rm -rf "$tmp"
  trap - EXIT INT TERM
  return 0
}

image_exists() {
  dockan images 2>/dev/null | awk 'NR > 1 { print $1 }' | grep -Fx "$1" >/dev/null 2>&1
}

if [ "${DOCKAN_STORE_DRY_RUN:-}" = "1" ]; then
  echo "Would prepare images for: $app"
  all_requires
  exit 0
fi

if ! command -v dockan >/dev/null 2>&1; then
  echo "Erreur: dockan est introuvable dans PATH." >&2
  echo "Installe Dockan puis relance: ./dockan-store install $app" >&2
  exit 1
fi

missing=0
downloaded=0

if [ "${DOCKAN_STORE_REFRESH_IMAGES:-0}" = "1" ] && [ "$app" != "all" ]; then
  if download_app_registry_pack; then
    downloaded=1
  fi
fi

for image in $(all_requires); do
  if [ "${DOCKAN_STORE_FORCE_IMAGES:-0}" != "1" ] && image_exists "$image"; then
    echo "Image ready: $image"
    continue
  fi

  if [ "${DOCKAN_STORE_FORCE_IMAGES:-0}" = "1" ] && image_exists "$image"; then
    echo "Updating prebuilt image: $image"
  fi

  archive="$registry/images/$(safe_ref "$image").tar.gz"
  if [ ! -f "$archive" ]; then
    if [ "$downloaded" -eq 0 ] && download_app_registry_pack; then
      downloaded=1
    fi
  fi

  archive="$registry/images/$(safe_ref "$image").tar.gz"
  if [ ! -f "$archive" ]; then
    echo "Image prebuilt missing: $image" >&2
    echo "Expected: $archive" >&2
    missing=1
    continue
  fi

  echo "Importing prebuilt image: $image"
  dockan pull "$image" "$registry"
done

if [ "$missing" -ne 0 ]; then
  echo >&2
  echo "Le pack d'images prebuild est incomplet." >&2
  echo "Ce Store doit etre publie avec un dossier registry/ contenant les images Dockan deja buildees." >&2
  echo "Cote release, prepare le pack avec:" >&2
  echo "  ./dockan-store pack-images $app" >&2
  exit 1
fi

echo "Images ready for: $app"
