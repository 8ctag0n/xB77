.PHONY: noir-compile noir-execute sunspot proof-badge localnet-start localnet-start-bg localnet-start-light localnet-stop localnet-verifier localnet-gateway localnet-init localnet-verify localnet-setup localnet-e2e demo-payment infra-up infra-down

infra-up:
	podman build -t xb77-infra -f infra/Containerfile.infra .
	podman run -d --name xb77-infra-dev -p 8545:8545 xb77-infra

infra-down:
	podman stop xb77-infra-dev || true
	podman rm xb77-infra-dev || true

noir-execute:
	./scripts/noir-execute.sh

.PHONY: light-bootstrap light-up light-down

light-bootstrap:
	./scripts/light/bootstrap.sh

light-up:
	./scripts/light/start-validator.sh

light-down:
	./scripts/light/stop-validator.sh

sunspot:
	./scripts/sunspot.sh --help

proof-badge:
	cd sdk && bun run proof:badge

localnet-start:
	./scripts/localnet/start-validator.sh

localnet-start-bg:
	./scripts/localnet/start-validator-bg.sh

localnet-start-light:
	./scripts/localnet/start-validator-light.sh

localnet-stop:
	./scripts/localnet/stop-validator.sh


localnet-verifier:
	./scripts/localnet/deploy-verifier.sh

localnet-gateway:
	./scripts/localnet/deploy-gateway.sh

localnet-init:
	./scripts/localnet/init-gateway.sh

localnet-verify:
	./scripts/localnet/verify-badge.sh

localnet-setup: localnet-verifier localnet-gateway localnet-init

localnet-e2e: localnet-start-bg proof-badge localnet-setup localnet-verify

deploy-app:
	cd apps/web && bunx wrangler@latest pages deploy . --project-name xb77-public-app

webapp-dev:
	cd apps/web && bunx wrangler@latest pages dev . --port 8788

docs-dev:
	cd docs && npm run docs:dev

docs-build:
	cd docs && npm run docs:build

# Docs ship to GitHub Pages via .github/workflows/deploy-docs.yml — no manual deploy needed.

demo-payment:
	cd sdk && bun run scripts/demo_payment.ts

# --- Deluxe Orchestration ---

node-up:
	@echo "\x1b[32;1m[xB77] Starting Sovereign Z-Node + Agent Mesh...\x1b[0m"
	@./zig-out/bin/xb77 serve --run-local &
	@sleep 2
	@echo "\x1b[36m[xB77] Z-Node active. Spawning agents...\x1b[0m"
	@./zig-out/bin/xb77 -p alpha-1 init
	@./zig-out/bin/xb77 -p alpha-2 init
	@echo "\x1b[32m[xB77] Swarm is live. Dashboard: http://localhost:8788/network\x1b[0m"

release:
	./scripts/release.sh
