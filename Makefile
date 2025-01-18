-include .env

FORGE = forge
CAST = cast

# Contract Configuration
CONTRACT = AccountOps.s.sol
CONTRACT_NAME = AccountOps

# Runtime Configuration
PRIORITY_GAS = $(shell $(CAST) --to-wei 1.5 gwei)
BASE_GAS = $(shell $(CAST) --to-wei 50 gwei)

check-env:
ifndef MASTER_KEY
	$(error MASTER_KEY is undefined)
endif
ifndef CONSOLIDATION_TARGET
	$(error CONSOLIDATION_TARGET is undefined)
endif
ifndef RPC_URL
	$(error RPC_URL is undefined)
endif

install:
	@echo "Installing dependencies..."
	@$(FORGE) install foundry-rs/forge-std --no-git

build:
	@echo "Building contracts..."
	@$(FORGE) build --optimize --optimizer-runs 1000000

clean:
	@echo "Cleaning build artifacts..."
	@$(FORGE) clean

# Core Account Operations
gen-accounts: check-env build
	@echo "Generating deterministic accounts..."
	@$(FORGE) script $(CONTRACT):$(CONTRACT_NAME) \
		--sig "genAccounts()" \
		-vvvv \
		--fork-url $(RPC_URL)

distribute: check-env build
	@echo "Distributing initial funds..."
	@$(FORGE) script $(CONTRACT):$(CONTRACT_NAME) \
		--sig "distribute()" \
		-vvvv \
		--fork-url $(RPC_URL) \
		--broadcast \
		--priority-gas-price $(PRIORITY_GAS)

simulate: check-env build
	@echo "Simulating organic activity..."
	@$(FORGE) script $(CONTRACT):$(CONTRACT_NAME) \
		--sig "simulateActivity()" \
		-vvvv \
		--fork-url $(RPC_URL) \
		--broadcast

consolidate: check-env build
	@echo "Consolidating funds..."
	@$(FORGE) script $(CONTRACT):$(CONTRACT_NAME) \
		--sig "consolidate()" \
		-vvvv \
		--fork-url $(RPC_URL) \
		--broadcast

# Credential Management Operations
export-keys: check-env build
	@echo "Exporting account credentials to accounts.json..."
	@$(FORGE) script $(CONTRACT):$(CONTRACT_NAME) \
		--sig "exportAccounts()" \
		-vvvv \
		--fork-url $(RPC_URL) > accounts.json

list-keys: check-env build
	@echo "Extracting private keys to private_keys.txt..."
	@$(FORGE) script $(CONTRACT):$(CONTRACT_NAME) \
		--sig "genAccounts()" \
		-vvvv \
		--fork-url $(RPC_URL) | grep "PrivateKey:" | \
		awk '{print $$2}' > private_keys.txt
	@echo "Generated $(shell wc -l < private_keys.txt) private keys"

help:
	@echo "Core Operations:"
	@echo "  make install         - Install dependencies"
	@echo "  make build          - Build contracts"
	@echo "  make gen-accounts   - Generate deterministic accounts"
	@echo "  make distribute     - Distribute initial funds"
	@echo "  make simulate       - Simulate organic activity"
	@echo "  make consolidate    - Consolidate funds to target"
	@echo ""
	@echo "Credential Management:"
	@echo "  make export-keys    - Export full account credentials (JSON)"
	@echo "  make list-keys      - Extract clean private key list"
