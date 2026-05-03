# Dockan Store

Dockan Store is a local catalog of ready-to-copy Dockan app templates.

The goal is simple: keep popular self-hosted apps in one place, with a clear
`dockan.yml`, persistent volumes, ports, healthchecks, and install notes.

This store does not automatically pull from Docker Hub. Each template points to
local Dockan image names such as `wordpress:local` or `gitea:local`. Build,
import, or pull those images into Dockan first, then deploy the app.

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
  install-app.sh
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

To choose a custom target directory:

```bash
./dockan-store install wordpress /srv/apps/wordpress
```

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

The page lists all apps, required local images, and the copy-ready install
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
- For updates, replace local images, then run `dockan compose redeploy`.
