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
./scripts/list.sh
```

## Install An App Template

```bash
./scripts/install-app.sh wordpress ~/dockan-apps/wordpress
cd ~/dockan-apps/wordpress
dockan compose up
```

## First Catalog

- WordPress
- Nextcloud
- Gitea
- Vaultwarden
- Uptime Kuma
- Matomo
- Ghost
- Jellyfin
- Static Site

## Production Notes

- Change every password and secret before exposing an app.
- Put HTTPS in front of public apps with Caddy, Nginx, Traefik, Pangolin, or
  another reverse proxy.
- Back up volumes with `dockan volume backup`.
- Check readiness with `dockan compose health`.
- For updates, replace local images, then run `dockan compose redeploy`.
