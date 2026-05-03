# Grafana

Dashboards and visualization.

Required local image:

- `grafana:local`

Install from Dockan Store:

```bash
./dockan-store install grafana
```

Dockan Store imports the required prebuilt images from `registry/index.tsv` and `registry/images/` automatically.

Run:

```bash
dockan compose up
dockan compose health
```

Open:

```text
http://127.0.0.1:3002
```
