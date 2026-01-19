# Noir Toolchain Image

Base image for Noir (nargo) using a pinned noirup version.

## Build
```bash
podman build -f containers/noir/Containerfile -t xb77-noir:local .
```

## Run (dev shell)
```bash
NOIR_REPO="$(pwd)" podman run -d --name noir-dev \
  --network=host \
  -v "${NOIR_REPO}:/work" \
  -w /work \
  --entrypoint bash \
  xb77-noir:local \
  -lc "tail -f /dev/null"
```

## Use
```bash
podman exec -it noir-dev bash -lc "nargo --version"
```
