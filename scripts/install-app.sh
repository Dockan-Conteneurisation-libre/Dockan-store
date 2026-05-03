#!/usr/bin/env sh
set -eu

app="${1:-}"
target="${2:-}"
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ -z "$app" ]; then
  echo "Usage: $0 <app-id> [target-dir]" >&2
  echo "Example: $0 wordpress" >&2
  echo "Example: $0 wordpress /srv/apps/wordpress" >&2
  exit 1
fi

if [ -z "$target" ]; then
  target="$HOME/dockan-apps/$app"
fi

src="$root/apps/$app"

if [ ! -d "$src" ]; then
  echo "Unknown app: $app" >&2
  echo "Run: $root/scripts/list.sh" >&2
  exit 1
fi

if [ -e "$target" ] && [ "$(find "$target" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)" -gt 0 ]; then
  echo "Target exists and is not empty: $target" >&2
  exit 1
fi

"$root/scripts/prepare-images.sh" "$app"

mkdir -p "$target"
cp -a "$src/." "$target/"

echo "Installed template: $app -> $target"
echo "Next:"
echo "  cd \"$target\""
echo "  dockan compose up"
echo "  sudo dockan compose autostart -f dockan.yml"
