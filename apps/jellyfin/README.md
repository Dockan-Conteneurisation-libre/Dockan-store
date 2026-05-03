# Jellyfin

Local media server.

Required local image:

- `jellyfin:local`

Put media files in:

```text
./media
```

Run:

```bash
mkdir -p media
dockan compose up
dockan compose health
```

Open:

```text
http://127.0.0.1:8096
```
