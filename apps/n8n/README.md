# n8n

Workflow automation with PostgreSQL.

Required local images:

- `n8n:local`
- `postgres:local`

Install from Dockan Store:

```bash
./dockan-store install n8n
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run:

```bash
dockan compose up
dockan compose health
```

Open:

```text
http://127.0.0.1:5678
```
