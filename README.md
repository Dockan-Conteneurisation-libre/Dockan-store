# Dockan Store

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
registry/
  images/
```

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

`install` automatically runs:

```bash
./dockan-store images wordpress
```

To choose a custom target directory:

```bash
./dockan-store install wordpress /srv/apps/wordpress
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

The generated `registry/` folder can be shipped in a release archive or restored
next to the Store checkout. `./dockan-store install APP_ID` will import the
required images automatically.

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

## Production Notes

- Change every password and secret before exposing an app.
- Put HTTPS in front of public apps with Caddy, Nginx, Traefik, Pangolin, or
  another reverse proxy.
- Back up volumes with `dockan volume backup`.
- Check readiness with `dockan compose health`.
- For updates, publish a fresh image registry pack, then run
  `dockan compose redeploy`.
