# Wallabag

Read-it-later app with PostgreSQL.

Required local images:

- `wallabag:local`
- `postgres:local`

Install from Dockan Store:

```bash
./dockan-store install wallabag
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run:

```bash
dockan compose up
dockan compose health
```

Open:

```text
http://127.0.0.1:8086
```
