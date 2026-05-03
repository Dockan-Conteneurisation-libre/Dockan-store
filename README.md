<p align="center">
  <img src="docs/dockan-logo.svg" alt="Dockan Store" width="110">
</p>

<h1 align="center">Dockan Store</h1>

<p align="center">
  <a href="https://github.com/Dockan-Conteneurisation-libre/Dockan-store/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/Dockan-Conteneurisation-libre/Dockan-store?label=release"></a>
  <a href="https://dockan-conteneurisation-libre.github.io/Dockan-store/"><img alt="GitHub Pages" src="https://img.shields.io/badge/pages-online-176b48"></a>
  <img alt="Apps" src="https://img.shields.io/badge/apps-21-1d5f89">
  <img alt="Images" src="https://img.shields.io/badge/images-prebuilt-a56110">
  <a href="https://github.com/Dockan-Conteneurisation-libre/Dockan"><img alt="Dockan" src="https://img.shields.io/badge/runtime-Dockan-176b48"></a>
</p>

Dockan Store is a local catalog of ready-to-copy Dockan app templates.

The goal is simple: keep popular self-hosted apps in one place, with a clear
`dockan.yml`, persistent volumes, ports, healthchecks, and install notes.

This store does not pull from Docker Hub at install time. Each app uses local
Dockan images such as `wordpress:local` or `gitea:local`, and the Store imports
those prebuilt images from the bundled Dockan registry before copying the app.
The user should not have to build app images manually.

## Layout

```text
catalog.json
apps/
  wordpress/
    dockan-store.yml
    dockan.yml
    README.md
scripts/
  list.sh
  prepare-images.sh
  install-app.sh
  pack-images.sh
  validate-store.sh
registry/
  images/
```

## Download Ready Release

Normal users should download the release archive, not `git clone`. The release
archive includes the Store files and templates. Image packs are downloaded per
app on demand, because GitHub release assets must stay under 2 GB.

```bash
curl -L -o dockan-store.tar.gz https://github.com/Dockan-Conteneurisation-libre/Dockan-store/releases/latest/download/dockan-store.tar.gz
tar -xzf dockan-store.tar.gz
cd Dockan-Store
```

Use `git clone` only when developing the Store itself.

## List Apps

```bash
./dockan-store list
```

## Install An App Template

```bash
./dockan-store install wordpress
cd ~/dockan-apps/wordpress
dockan compose up
```

To make the app come back after reboot without adding a Dockan daemon:

```bash
sudo dockan compose autostart -f dockan.yml
```

`install` automatically runs:

```bash
./dockan-store images wordpress
```

To choose a custom target directory:

```bash
./dockan-store install wordpress /srv/apps/wordpress
```

## Update An Installed App

`update` imports the latest prebuilt images for an app even when the image tag
already exists locally, then redeploys the installed app with its current
`dockan.yml`. It keeps existing volumes and does not overwrite local app files.

```bash
./dockan-store update wordpress
```

If the app is installed outside the default locations, pass its directory:

```bash
./dockan-store update wordpress /srv/apps/wordpress
```

## Prebuilt Images

Normal users should only need:

```bash
./dockan-store install APP_ID
```

For release maintainers, pack the already-built local Dockan images into the
Store registry before publishing:

```bash
./dockan-store pack-images all
```

To build the registry directly from upstream OCI images with Podman or Docker:

```bash
./dockan-store build-images all
./dockan-store build-images mysql:local
DOCKAN_STORE_ENGINE=docker ./dockan-store build-images mysql:local
```

To publish smaller packs, generate only the image archives required by one app:

```bash
./dockan-store export-app-images wordpress
```

The generated `registry/` folder can be shipped next to the Store checkout.
`./dockan-store install APP_ID` imports the required images automatically. If
the images are not already present locally, the Store downloads
`dockan-store-images-APP_ID.tar.gz` from the latest GitHub Release.

## Template Validation

Every Store change should pass:

```bash
./scripts/validate-store.sh
DOCKAN_STORE_DRY_RUN=1 ./dockan-store images all
```

The validator checks that catalog entries, app metadata, compose templates,
published ports, required local images, upstream image sources, and known bad
port mappings stay consistent before a release can build image packs.

## First Catalog

- BookStack
- draw.io
- Ghost
- Gitea
- Grafana
- HedgeDoc
- Jellyfin
- LibreTranslate
- Matomo
- Miniflux
- n8n
- Nextcloud
- Nginx Proxy Manager
- Paperless-ngx
- Prometheus
- Static Site
- Syncthing
- Uptime Kuma
- Vaultwarden
- Wallabag
- WordPress

## GitHub Pages

The store site lives in `docs/index.html`. On GitHub, enable Pages with:

```text
Settings -> Pages -> Build and deployment -> Deploy from a branch -> main /docs
```

The page lists all apps, required prebuilt images, and the copy-ready install
command:

```bash
./dockan-store install APP_ID
cd ~/dockan-apps/APP_ID
dockan compose up
```

## Releases

GitHub Actions builds the Store release when a `v*` tag is pushed, or when the
`Store Release` workflow is launched manually.

The release contains:

- `dockan-store.tar.gz`: latest Store archive with templates and image index.
- `dockan-store-VERSION.tar.gz`: versioned Store archive with templates and image index.
- `dockan-store-images-APP_ID.tar.gz`: image registry for one app only.
- `SHA256SUMS`: checksums for release archives.
- release notes listing every image included in the pack.

Maintainers can create a release from the GitHub UI by running the workflow with
a version such as `v0.1.0`, or from git:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## Production Notes

- Change every password and secret before exposing an app.
- Put HTTPS in front of public apps with Caddy, Nginx, Traefik, Pangolin, or
  another reverse proxy.
- Back up volumes with `dockan volume backup`.
- Check readiness with `dockan compose health`.
- For updates, publish a fresh image registry pack, then run
  `./dockan-store update APP_ID`.
# Dockan-store-
