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

# Pin Noir to a known-good version that matches SDK dependencies.
RUN /root/.nargo/bin/noirup -v 0.36.0

WORKDIR /app

ENTRYPOINT ["nargo"]
