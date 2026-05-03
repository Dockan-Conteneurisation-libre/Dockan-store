# Gitea

Lightweight Git hosting with PostgreSQL.

Required local images:

- `gitea:local`
- `postgres:local`

Install from Dockan Store:

```bash
./dockan-store install gitea
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run:

```bash
dockan compose up
dockan compose health
```

Open:

```text
http://127.0.0.1:3000
```

SSH is mapped to host port `2222`.
