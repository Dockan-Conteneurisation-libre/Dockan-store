#!/usr/bin/env sh
set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
failures=0

fail() {
  echo "ERROR: $*" >&2
  failures=$((failures + 1))
}

need_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

requires_for_app() {
  meta="$root/apps/$1/dockan-store.yml"
  awk '
    /^requires:/ { in_requires=1; next }
    in_requires && /^[^[:space:]-]/ { in_requires=0 }
    in_requires && /^[[:space:]]*-/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      gsub(/["'\''"]/, "", line)
      if (line != "") print line
    }
  ' "$meta"
}

images_for_compose() {
  awk '
    /^[[:space:]]*image:/ {
      line=$0
      sub(/^[[:space:]]*image:[[:space:]]*/, "", line)
      gsub(/["'\''"]/, "", line)
      if (line != "") print line
    }
  ' "$1"
}

host_ports_for_compose() {
  awk '
    /^[[:space:]]*-[[:space:]]*[0-9]+:[0-9]+/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      split(line, parts, ":")
      print parts[1]
    }
  ' "$1"
}

source_exists() {
  awk -F '\t' -v ref="$1" 'NF >= 2 && $1 == ref { found=1 } END { exit found ? 0 : 1 }' "$root/scripts/image-sources.tsv"
}

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required for Store validation." >&2
  exit 1
}

need_file "$root/catalog.json"
need_file "$root/scripts/image-sources.tsv"
jq -e '.apps | type == "array" and length > 0' "$root/catalog.json" >/dev/null

for app in $(jq -r '.apps[].id' "$root/catalog.json" | sort); do
  dir="$root/apps/$app"
  compose="$dir/dockan.yml"
  meta="$dir/dockan-store.yml"
  readme="$dir/README.md"
  need_file "$compose"
  need_file "$meta"
  need_file "$readme"
  [ -d "$dir" ] || fail "missing app directory: $dir"

  default_port="$(awk '/^default_port:/ { print $2 }' "$meta" | head -n 1)"
  if [ -z "$default_port" ]; then
    fail "$app: missing default_port"
  elif ! host_ports_for_compose "$compose" | grep -Fx "$default_port" >/dev/null 2>&1; then
    fail "$app: default_port $default_port is not published in dockan.yml"
  fi

  tmp_required="$(mktemp)"
  tmp_images="$(mktemp)"
  requires_for_app "$app" | sort -u > "$tmp_required"
  images_for_compose "$compose" | sort -u > "$tmp_images"
  if ! diff -u "$tmp_required" "$tmp_images" >/tmp/dockan-store-validate.diff 2>&1; then
    cat /tmp/dockan-store-validate.diff >&2
    fail "$app: required images do not match dockan.yml images"
  fi
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    source_exists "$ref" || fail "$app: missing upstream source for $ref"
  done < "$tmp_required"
  rm -f "$tmp_required" "$tmp_images"
done

if rg -n 'test -d /var/lib/mysql|8081:8080|8083:8080|8080:8080' "$root/apps" >/tmp/dockan-store-known-bad.txt 2>/dev/null; then
  cat /tmp/dockan-store-known-bad.txt >&2
  fail "known-bad Store template pattern found"
fi

if [ "$failures" -gt 0 ]; then
  echo "Store validation failed with $failures problem(s)." >&2
  exit 1
fi

echo "Store validation OK"
