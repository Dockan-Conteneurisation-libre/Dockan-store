#!/usr/bin/env sh
set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

printf '%-16s %-14s %s\n' "APP" "CATEGORY" "PATH"
printf '%-16s %-14s %s\n' "---" "--------" "----"

find "$root/apps" -mindepth 2 -maxdepth 2 -name dockan-store.yml | sort | while IFS= read -r file; do
  app="$(basename "$(dirname "$file")")"
  category="$(sed -n 's/^category: //p' "$file" | head -n 1)"
  printf '%-16s %-14s %s\n' "$app" "${category:-unknown}" "apps/$app"
done
