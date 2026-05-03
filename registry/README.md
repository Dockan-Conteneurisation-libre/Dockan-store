# Dockan Store Image Registry

This directory is reserved for prebuilt Dockan image packs.

Release packages can include:

```text
registry/
  index.tsv
  images/
    wordpress_local.tar.gz
    wordpress_local.tar.gz.sha256
```

Users should not have to build app images manually. The normal command:

```bash
./dockan-store install wordpress
```

imports the required prebuilt images first, then copies the app template.

Maintainers can generate this registry with:

```bash
./dockan-store build-images all
./dockan-store build-images mysql:local
DOCKAN_STORE_ENGINE=docker ./dockan-store build-images mysql:local
```
