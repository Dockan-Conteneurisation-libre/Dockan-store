# Syncthing

Peer-to-peer file sync.

Required local image:

- `syncthing:local`

Install from Dockan Store:

```bash
./dockan-store install syncthing
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run once:

```bash
dockan compose up
dockan compose health
```

Start automatically after reboot:

```bash
sudo dockan compose autostart -f dockan.yml
```

Open:

```text
http://127.0.0.1:8384
```
