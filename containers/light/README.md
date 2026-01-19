# Light Devcontainer (Base Image + Local Overrides)

This builds a local image based on `ghcr.io/lightprotocol/devcontainer-core:main`
and mounts the Light repo into `/work`.

## Build
```bash
podman build -f containers/light/Containerfile -t xb77-light-devcontainer:local .
```

## Run
```bash
podman run -d --name light-devcontainer \
  --network=host \
  -v "$(pwd)/private/toolchains/light-protocol:/work" \
  -v lightprotocol-solana-config:/home/node/.config/solana \
  -w /work \
  xb77-light-devcontainer:local \
  tail -f /dev/null
```

## Enter
```bash
podman exec -it --user node light-devcontainer bash -lc "pwd"
```

## Start Light localnet
```bash
podman exec -it --user node light-devcontainer bash -lc "./cli/test_bin/run test-validator"
```

## Notes
- If downloads fail with permission errors, fix host perms once:
  `chmod -R a+rwX private/toolchains/light-protocol/cli/bin`
