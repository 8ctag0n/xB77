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

# Solana CLI - VERSIÓN ACTUALIZADA
RUN rm -rf /root/.local/share/solana || true
RUN sh -c "$(curl -sSfL https://release.anza.xyz/v2.2.2/install)"
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

# Wrapper para forzar bind en 0.0.0.0
RUN printf '#!/bin/bash\n\
# Reemplazar 127.0.0.1 por 0.0.0.0 en los comandos que lanza Light CLI\n\
export SOLANA_RPC_URL=http://0.0.0.0:8899\n\
\n\
# Ejecutar light con variables de entorno modificadas\n\
light test-validator "$@" & LIGHT_PID=$!\n\
\n\
# Esperar a que arranque y patchear procesos si es necesario\n\
sleep 5\n\
\n\
# Mantener el proceso vivo\n\
wait $LIGHT_PID\n' > /usr/local/bin/start-light.sh && chmod +x /usr/local/bin/start-light.sh

CMD ["/usr/local/bin/start-light.sh"]
