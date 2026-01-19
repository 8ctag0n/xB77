# Sunspot Toolchain Image

Image for Sunspot CLI + Noir + Rust, built from Debian.

## Build
```bash
podman build -f containers/sunspot/Containerfile -t xb77-sunspot:local .
```

## Run (dev shell)
```bash
SUNSPOT_REPO="$(pwd)" podman run -d --name sunspot-dev \
  --network=host \
  -v "${SUNSPOT_REPO}:/work" \
  -w /work \
  --entrypoint bash \
  xb77-sunspot:local \
  -lc "tail -f /dev/null"
```

## Use
```bash
podman exec -it sunspot-dev bash -lc "sunspot --help | head -n 1"
```
