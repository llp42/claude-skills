# Makefile for a project following the Standard Go Project Layout.
# Copy to the repo root. Substitute MODULE_PATH and BINARY_NAME.
#
# Convention from the layout: keep this file small and call scripts from /scripts.

MODULE      := MODULE_PATH
BINARY      := BINARY_NAME
CMD         := ./cmd/$(BINARY)
BIN_DIR     := ./bin

GOLANGCI    := golangci-lint
GO          := go

# Stamped into the binary and read back with `-version`. Keep the variable path
# in sync with the package that declares them.
VERSION     ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT      ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo none)
DATE        ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS     := -s -w \
               -X main.version=$(VERSION) \
               -X main.commit=$(COMMIT) \
               -X main.date=$(DATE)

.DEFAULT_GOAL := help

## help: list targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //' | column -t -s ':'

## fmt: rewrite all Go files with the configured formatters (gofumpt + goimports)
fmt:
	$(GOLANGCI) fmt

## fmt-check: fail if anything is unformatted; makes no changes
fmt-check:
	$(GOLANGCI) fmt --diff

## vet: run the go vet analyzer suite
# Overlaps golangci-lint's govet, but runs the *installed toolchain's* analyzer
# set, which is newer than the one golangci-lint vendors.
vet:
	$(GO) vet ./...

## lint: run golangci-lint over the whole module
lint:
	$(GOLANGCI) run ./...

## lint-new: lint only what this branch changed
lint-new:
	$(GOLANGCI) run --new-from-merge-base=origin/main ./...

## lint-fix: run golangci-lint and apply every fix it can
lint-fix:
	$(GOLANGCI) run --fix ./...

## test: run the test suite with the race detector
test:
	$(GO) test -race ./...

## test-short: skip anything guarded by testing.Short()
test-short:
	$(GO) test -short ./...

## cover: run tests and open the HTML coverage report
cover:
	$(GO) test -race -coverprofile=coverage.out -covermode=atomic ./...
	$(GO) tool cover -html=coverage.out

## bench: run benchmarks only, with allocation counts
bench:
	$(GO) test -run '^$$' -bench . -benchmem ./...

## build: build a stamped, trimmed binary into ./bin
build:
	$(GO) build -trimpath -ldflags '$(LDFLAGS)' -o $(BIN_DIR)/$(BINARY) $(CMD)

## tidy: sync go.mod and go.sum
tidy:
	$(GO) mod tidy

## tidy-check: fail if go.mod or go.sum is out of date; makes no changes
tidy-check:
	$(GO) mod tidy -diff

## vuln: report known vulnerabilities reachable from this code
# Pin it instead once it is a tool dependency: `go get -tool
# golang.org/x/vuln/cmd/govulncheck` then `go tool govulncheck ./...`.
vuln:
	$(GO) run golang.org/x/vuln/cmd/govulncheck@latest ./...

## verify: everything CI runs, in CI's order
verify: tidy-check fmt-check vet lint test vuln

## clean: remove build output and coverage data
clean:
	rm -rf $(BIN_DIR) coverage.out

.PHONY: help fmt fmt-check vet lint lint-new lint-fix test test-short cover bench build tidy tidy-check vuln verify clean
