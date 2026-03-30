# ── openclaw-setup test runner ────────────────────────────────────────────────
#
# Usage:
#   make test              Run all tests
#   make test-patches      Patch system unit tests (fast, ~5s)
#   make test-integration  Patch integration test (applies real patches, ~60s)
#   make test-web          Web configurator tests (bun)
#   make test-aws          AWS script static tests
#   make test-ci           Same as `make test` but skip integration (for CI without openclaw)
#
# Prerequisites: bash, jq, bun (for web tests), openclaw (for integration tests)
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: test test-patches test-integration test-web test-aws test-ci help

SHELL := /bin/bash

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Individual suites ────────────────────────────────────────────────────────

test-patches: ## Patch system unit tests (each step type)
	@echo "═══ Patch unit tests ═══"
	bash shared/patches/tests/run-tests.sh

test-integration: ## Patch integration test (real openclaw, ~60s)
	@echo "═══ Patch integration test ═══"
	bash shared/patches/tests/integration-test.sh

test-web: ## Web configurator tests (bun)
	@echo "═══ Web tests ═══"
	cd web && bun test

test-aws: ## AWS script static validation
	@echo "═══ AWS cloud-init tests ═══"
	bash aws/terraform/tests/test-cloud-init-slim.sh
	@echo ""
	@echo "═══ AWS post-clone-setup tests ═══"
	bash aws/scripts/tests/test-post-clone-setup.sh

# ── Aggregate targets ────────────────────────────────────────────────────────

test: test-patches test-web test-aws test-integration ## Run all tests
	@echo ""
	@echo "✅ All tests passed"

test-ci: test-patches test-web test-aws ## Run all tests except integration (no openclaw needed)
	@echo ""
	@echo "✅ CI tests passed (integration skipped)"
