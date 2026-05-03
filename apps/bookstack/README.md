# BookStack

Documentation wiki with MariaDB.

Required local images:

- `bookstack:local`
- `mariadb:local`

Install from Dockan Store:

```bash
./dockan-store install bookstack
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
http://127.0.0.1:8087
```
