# Paperless-ngx

Document management with OCR, PostgreSQL, and Redis.

Required local images:

- `paperless-ngx:local`
- `postgres:local`
- `redis:local`

Run:

```bash
mkdir -p consume export
dockan compose up
dockan compose health
```

Open:

```text
http://127.0.0.1:8000
```
