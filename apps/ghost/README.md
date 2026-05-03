# Ghost

Publishing platform with MySQL.

Required local images:

- `ghost:local`
- `mysql:local`

Install from Dockan Store:

```bash
./dockan-store install ghost
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run:

```bash
dockan compose up
dockan compose health
```

Open:

```text
http://127.0.0.1:2368
```

Change the `url` value before production.
