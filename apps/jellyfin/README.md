# Jellyfin

Local media server.

Required local image:

- `jellyfin:local`

Install from Dockan Store:

```bash
./dockan-store install jellyfin
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

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
