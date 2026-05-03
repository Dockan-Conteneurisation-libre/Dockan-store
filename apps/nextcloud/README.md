# Nextcloud

Private cloud storage with MariaDB and Redis.

Required local images:

- `nextcloud:local`
- `mariadb:local`
- `redis:local`

Install from Dockan Store:

```bash
./dockan-store install nextcloud
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run once:

```bash
dockan compose up
dockan compose health
```

Start automatically after reboot:

```bash
sudo dockan compose autostart -f dockan.yml
```

Open:

```text
http://127.0.0.1:8081
```

For public use, put HTTPS in front of it and configure trusted domains inside
Nextcloud.
