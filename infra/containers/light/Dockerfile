FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV CARGO_HOME=/root/.cargo
ENV RUSTUP_HOME=/root/.rustup
ENV PATH="${CARGO_HOME}/bin:/root/.local/share/solana/install/active_release/bin:${PATH}"

# Basics
RUN apt-get update && apt-get install -y \
  ca-certificates curl unzip git bash jq \
  build-essential pkg-config libssl-dev \
  && rm -rf /var/lib/apt/lists/*

# Rust
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
RUN rustc --version && cargo --version

# Node 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get update && apt-get install -y nodejs \
  && rm -rf /var/lib/apt/lists/*

# Solana CLI (legacy line compatible with Light CLI flags)
# NOTE: release.anza.xyz installs Agave 2.x, which breaks `light test-validator`
# due to removed flags like `--gossip-host`.
# Use legacy Solana 1.18 from release.solana.com instead.
RUN rm -rf /root/.local/share/solana || true
RUN sh -c "$(curl -sSfL https://release.solana.com/v1.18.26/install)"
RUN solana --version

# Photon para indexar bien de bien
RUN cargo install --git https://github.com/lightprotocol/photon.git \
  --rev 49b7e7f0d668babbc4d65fe8a0a7236df76f75a8 \
  --locked

# Light CLI
RUN npm cache clean --force
RUN npm i -g @lightprotocol/zk-compression-cli
RUN light --version

EXPOSE 8899 8784 3001
VOLUME ["/root/.config/solana", "/root/.local/share/solana"]
WORKDIR /work
EXPOSE 8899 8784 3001
WORKDIR /work

# Wrapper para forzar bind en 0.0.0.0 y mantener procesos vivos
RUN printf '#!/bin/bash\nset -e\n\
\n\
export SOLANA_RPC_URL=http://0.0.0.0:8899\n\
\n\
cleanup() {\n\
  echo "Shutting down..."\n\
  pkill -f solana-test-validator || true\n\
  pkill -f photon || true\n\
  pkill -f prover || true\n\
  exit 0\n\
}\n\
trap cleanup SIGTERM SIGINT\n\
\n\
echo "Starting light test-validator..."\n\
light test-validator "$@"\n\
\n\
echo "Setup complete. Monitoring processes..."\n\
\n\
# Esperar a que los servicios estén up\n\
sleep 3\n\
\n\
# Loop infinito monitoreando los procesos\n\
while true; do\n\
  # Verificar que solana-test-validator sigue corriendo\n\
  if ! pgrep -f solana-test-validator > /dev/null; then\n\
    echo "ERROR: solana-test-validator died, restarting..."\n\
    light test-validator "$@"\n\
    sleep 3\n\
  fi\n\
  sleep 10\n\
done\n' > /usr/local/bin/start-light.sh && chmod +x /usr/local/bin/start-light.sh

CMD ["/usr/local/bin/start-light.sh"]
