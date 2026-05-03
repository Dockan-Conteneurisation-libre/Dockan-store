# Paperless-ngx

Document management with OCR, PostgreSQL, and Redis.

Required local images:

- `paperless-ngx:local`
- `postgres:local`
- `redis:local`

Install from Dockan Store:

```bash
./dockan-store install paperless-ngx
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run once:

```bash
mkdir -p consume export
dockan compose up
dockan compose health
```

Start automatically after reboot:

```bash
sudo dockan compose autostart -f dockan.yml
```

Open:

```text
http://127.0.0.1:8000
```
