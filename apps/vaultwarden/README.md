# Vaultwarden

Bitwarden-compatible password manager.

Required local image:

- `vaultwarden:local`

Install from Dockan Store:

```bash
./dockan-store install vaultwarden
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run:

```bash
dockan compose up
dockan compose health
```

Open:

```text
http://127.0.0.1:8082
```

Use HTTPS in production and replace `ADMIN_TOKEN`.
