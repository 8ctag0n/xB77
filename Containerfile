FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    curl \
    git \
    bash \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Configure git to use https always and no prompt
RUN git config --global url."https://github.com/".insteadOf git@github.com:
RUN git config --global url."https://".insteadOf git://

# Install noirup
RUN curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash

# Add to PATH
ENV PATH="/root/.nargo/bin:$PATH"

# Install specific version (latest stable usually better, but let's try explicit bleeding edge if needed, or just run noirup)
# Running noirup without args installs latest stable.
RUN /root/.nargo/bin/noirup

WORKDIR /app

ENTRYPOINT ["nargo"]

