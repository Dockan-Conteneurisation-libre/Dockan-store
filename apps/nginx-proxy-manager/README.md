# Nginx Proxy Manager

Reverse proxy manager with a browser UI.

Required local image:

- `nginx-proxy-manager:local`

Install from Dockan Store:

```bash
./dockan-store install nginx-proxy-manager
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

Open the admin UI:

```text
http://127.0.0.1:8181
```
