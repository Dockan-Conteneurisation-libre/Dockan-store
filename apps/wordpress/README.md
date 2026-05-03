# WordPress

WordPress with MariaDB.

Required local images:

- `wordpress:local`
- `mariadb:local`

Install from Dockan Store:

```bash
./dockan-store install wordpress
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run:

```bash
dockan compose up
dockan compose health
```

Open:

```text
http://127.0.0.1:8080
```

Change all database passwords before production.
