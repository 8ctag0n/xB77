# Arcium Toolchain Image

Minimal image with Solana CLI installed via the official installer URL.

## Build
```bash
podman build -f containers/arcium/Containerfile -t xb77-arcium:local .
```

## Run (dev shell)
```bash
ARCIUM_REPO="$(pwd)" podman run -d --name arcium-dev \
  --network=host \
  -v "${ARCIUM_REPO}:/work" \
  -w /work \
  --entrypoint bash \
  xb77-arcium:local \
  -lc "tail -f /dev/null"
```

## Use
```bash
podman exec -it arcium-dev bash -lc "solana --version"
```

## Notes
- If Arcium docs require extra tools, add them to `containers/arcium/Containerfile`.
