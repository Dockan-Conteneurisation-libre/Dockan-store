# Matomo

Web analytics with MariaDB.

Required local images:

- `matomo:local`
- `mariadb:local`

Install from Dockan Store:

```bash
./dockan-store install matomo
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run:

```bash
dockan compose up
dockan compose health
```

Open:

```text
http://127.0.0.1:8083
```
