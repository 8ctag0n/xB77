.PHONY: noir-compile noir-execute sunspot proof-badge localnet-start localnet-verifier

noir-compile:
	./scripts/build-noir-artifacts.sh

noir-execute:
	./scripts/noir-execute.sh

sunspot:
	./scripts/sunspot.sh --help

proof-badge:
	cd sdk && bun run proof:badge

localnet-start:
	./scripts/localnet/start-validator.sh

localnet-verifier:
	./scripts/localnet/deploy-verifier.sh
