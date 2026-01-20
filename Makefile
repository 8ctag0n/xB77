.PHONY: noir-compile noir-execute sunspot proof-badge localnet-start localnet-start-bg localnet-start-light localnet-stop localnet-verifier localnet-gateway localnet-init localnet-verify localnet-setup localnet-e2e demo-payment

noir-compile:
	./scripts/build-noir-artifacts.sh

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

demo-payment:
	cd sdk && bun run scripts/demo_payment.ts
