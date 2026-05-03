#!/usr/bin/env sh
set -eu

app="${1:-}"
registry="${2:-${DOCKAN_STORE_REGISTRY:-}}"
output="${3:-}"
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ -z "$app" ]; then
  echo "Usage: $0 <app-id> [registry-dir] [output.tar.gz]" >&2
  echo "Example: $0 wordpress ./registry dist/dockan-store-images-wordpress.tar.gz" >&2
  exit 1
fi

if [ -z "$registry" ]; then
  registry="$root/registry"
fi

if [ -z "$output" ]; then
  output="$root/dist/dockan-store-images-$app.tar.gz"
fi

case "$output" in
  /*) ;;
  *) output="$root/$output" ;;
esac

meta="$root/apps/$app/dockan-store.yml"
if [ ! -f "$meta" ]; then
  echo "Unknown app: $app" >&2
  exit 1
fi

if [ ! -f "$registry/index.tsv" ]; then
  echo "Missing registry index: $registry/index.tsv" >&2
  exit 1
fi

safe_ref() {
  printf "%s" "$1" | sed 's/[^A-Za-z0-9._-]/_/g'
}

requires_for_app() {
  awk '
    /^requires:/ { in_requires=1; next }
    in_requires && /^[^[:space:]-]/ { in_requires=0 }
    in_requires && /^[[:space:]]*-/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      gsub(/["'\'']/, "", line)
      if (line != "") print line
    }
  ' "$meta" | sort -u
}

tmp="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

mkdir -p "$tmp/registry/images" "$(dirname "$output")"
: > "$tmp/registry/index.tsv"

missing=0
for image in $(requires_for_app); do
  archive="$(safe_ref "$image").tar.gz"
  if ! awk -F '\t' -v image="$image" 'NF >= 4 && $1 == image { found=1 } END { exit found ? 0 : 1 }' "$registry/index.tsv"; then
    echo "Missing registry entry: $image" >&2
    missing=1
    continue
  fi
  if [ ! -f "$registry/images/$archive" ]; then
    echo "Missing image archive: $registry/images/$archive" >&2
    missing=1
    continue
  fi

  awk -F '\t' -v image="$image" 'NF >= 4 && $1 == image { print }' "$registry/index.tsv" >> "$tmp/registry/index.tsv"
  cp "$registry/images/$archive" "$tmp/registry/images/$archive"
  if [ -f "$registry/images/$archive.sha256" ]; then
    cp "$registry/images/$archive.sha256" "$tmp/registry/images/$archive.sha256"
  fi
done

if [ "$missing" -ne 0 ]; then
  exit 1
fi

(cd "$tmp" && tar -czf "$output" registry)
echo "App image pack ready: $output"
