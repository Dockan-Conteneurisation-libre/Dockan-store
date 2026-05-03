#!/usr/bin/env bash
set -euo pipefail

app="${1:-}"
registry="${2:-${DOCKAN_STORE_REGISTRY:-}}"
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
sources="$root/scripts/image-sources.tsv"

if [ -z "$app" ]; then
  echo "Usage: $0 <app-id|all> [registry-dir]" >&2
  echo "Example: $0 all ./registry" >&2
  exit 1
fi

if [ -z "$registry" ]; then
  registry="$root/registry"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Erreur: jq est requis pour convertir les metadonnees OCI." >&2
  exit 1
fi

dockan_bin="${DOCKAN_BIN:-dockan}"
if ! command -v "$dockan_bin" >/dev/null 2>&1; then
  echo "Erreur: $dockan_bin est introuvable dans PATH." >&2
  exit 1
fi

if command -v podman >/dev/null 2>&1; then
  engine="podman"
elif command -v docker >/dev/null 2>&1; then
  engine="docker"
else
  echo "Erreur: podman ou docker est requis pour recuperer les images upstream." >&2
  exit 1
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

source_for() {
  local ref="$1"
  awk -F '\t' -v ref="$ref" 'NF >= 2 && $1 == ref { print $2; found=1 } END { exit found ? 0 : 1 }' "$sources"
}

shell_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

write_start_script() {
  local inspect_json="$1"
  local image_dir="$2"
  local workdir="$3"
  local command_line="$4"
  local start="$image_dir/start.sh"

  {
    printf '#!/bin/sh\n'
    printf 'set -eu\n'
    jq -r '
      .[0].Config.Env // []
      | .[]
      | select(test("^[A-Za-z_][A-Za-z0-9_]*="))
      | capture("^(?<k>[^=]+)=(?<v>.*)$")
      | "export \(.k)=\(.v|@sh)"
    ' "$inspect_json"
    printf 'if [ -n "${DOCKAN_ENTRYPOINT:-}" ]; then\n'
    printf '  if [ -n "${DOCKAN_RUN_COMMAND:-}" ]; then\n'
    printf '    exec sh -lc "$DOCKAN_ENTRYPOINT $DOCKAN_RUN_COMMAND"\n'
    printf '  fi\n'
    printf '  exec sh -lc "$DOCKAN_ENTRYPOINT"\n'
    printf 'fi\n'
    printf 'if [ -n "${DOCKAN_RUN_COMMAND:-}" ]; then\n'
    printf '  exec sh -lc "$DOCKAN_RUN_COMMAND"\n'
    printf 'fi\n'
    if [ -n "$workdir" ] && [ "$workdir" != "/" ]; then
      printf 'cd %s\n' "$(shell_quote "$workdir")"
    fi
    printf 'exec %s\n' "$command_line"
  } > "$start"
  chmod +x "$start"
  cp "$start" "$image_dir/rootfs/.dockan-start.sh"
  chmod +x "$image_dir/rootfs/.dockan-start.sh"
}

build_one() {
  local local_ref="$1"
  local upstream
  upstream="$(source_for "$local_ref")" || {
    echo "Source OCI manquante pour $local_ref dans $sources" >&2
    return 1
  }

  echo
  echo "== $local_ref <- $upstream =="

  if [ "${DOCKAN_STORE_DRY_RUN:-}" = "1" ]; then
    return 0
  fi

  local build_home="$root/.dockan-store/build-home"
  local image_dir="$build_home/images/$(safe_ref "$local_ref").dockan"
  local tmp
  tmp="$(mktemp -d "$root/.dockan-store/oci.XXXXXX")"
  local cid=""
  cleanup() {
    if [ -n "$cid" ]; then
      "$engine" rm -f "$cid" >/dev/null 2>&1 || true
    fi
    rm -rf "$tmp"
  }
  trap cleanup RETURN

  "$engine" pull "$upstream"
  "$engine" image inspect "$upstream" > "$tmp/inspect.json"
  cid="$("$engine" create "$upstream")"

  rm -rf "$image_dir"
  mkdir -p "$image_dir/rootfs" "$image_dir/hooks" "$image_dir/volumes"
  "$engine" export "$cid" | tar -C "$image_dir/rootfs" -xf -
  if [ ! -e "$image_dir/rootfs/bin/sh" ] && [ ! -L "$image_dir/rootfs/bin/sh" ] && [ -x "$image_dir/rootfs/bin/busybox" ]; then
    ln -s busybox "$image_dir/rootfs/bin/sh"
  fi

  local name workdir ports command_line
  name="${local_ref%%:*}"
  workdir="$(jq -r '.[0].Config.WorkingDir // ""' "$tmp/inspect.json")"
  ports="$(jq -r '.[0].Config.ExposedPorts // {} | keys | map(split("/")[0]) | unique | join(",")' "$tmp/inspect.json")"
  command_line="$(jq -r '
    def arr(x): if x == null then [] elif (x|type) == "array" then x else [x] end;
    (arr(.[0].Config.Entrypoint) + arr(.[0].Config.Cmd)) | @sh
  ' "$tmp/inspect.json")"
  if [ -z "$command_line" ]; then
    command_line="sh"
  fi

  {
    echo "name=$name"
    echo "tag=$local_ref"
    echo "source=$upstream"
    echo "rootfs.mode=oci"
    [ -n "$workdir" ] && echo "workdir=$workdir"
    [ -n "$ports" ] && echo "ports=$ports"
  } > "$image_dir/meta.conf"

  write_start_script "$tmp/inspect.json" "$image_dir" "$workdir" "$command_line"
  DOCKAN_HOME="$build_home" "$dockan_bin" push "$local_ref" "$registry"
}

mkdir -p "$root/.dockan-store" "$registry/images"

for image in $(all_requires); do
  build_one "$image"
done

echo
echo "Prebuilt image registry ready: $registry"
