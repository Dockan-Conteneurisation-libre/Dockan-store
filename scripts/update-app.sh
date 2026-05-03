#!/usr/bin/env sh
set -eu

app="${1:-}"
target="${2:-}"
registry="${3:-${DOCKAN_STORE_REGISTRY:-}}"
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ -z "$app" ]; then
  echo "Usage: $0 <app-id> [target-dir] [registry-dir]" >&2
  echo "Example: $0 wordpress" >&2
  echo "Example: $0 wordpress /srv/dockan-apps/wordpress" >&2
  exit 1
fi

if [ ! -d "$root/apps/$app" ]; then
  echo "Unknown app: $app" >&2
  echo "Run: $root/scripts/list.sh" >&2
  exit 1
fi

if [ -z "$target" ]; then
  if [ -f "/srv/dockan-apps/$app/dockan.yml" ]; then
    target="/srv/dockan-apps/$app"
  elif [ -f "$HOME/dockan-apps/$app/dockan.yml" ]; then
    target="$HOME/dockan-apps/$app"
  else
    echo "Installed app not found: $app" >&2
    echo "Pass the app directory explicitly:" >&2
    echo "  $0 $app /path/to/$app" >&2
    exit 1
  fi
fi

compose_file="$target/dockan.yml"
if [ ! -f "$compose_file" ]; then
  echo "dockan.yml not found in: $target" >&2
  exit 1
fi

echo "Updating images for: $app"
DOCKAN_STORE_FORCE_IMAGES=1 DOCKAN_STORE_REFRESH_IMAGES="${DOCKAN_STORE_REFRESH_IMAGES:-1}" "$root/scripts/prepare-images.sh" "$app" "$registry"

echo "Redeploying: $compose_file"
dockan compose redeploy -f "$compose_file"

echo
dockan compose health -f "$compose_file"
echo "Updated app: $app -> $target"
