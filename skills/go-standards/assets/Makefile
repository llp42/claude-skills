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

## cover: run tests and open the HTML coverage report
cover:
	$(GO) test -race -coverprofile=coverage.out -covermode=atomic ./...
	$(GO) tool cover -html=coverage.out

## build: build the binary into ./bin
build:
	$(GO) build -o $(BIN_DIR)/$(BINARY) $(CMD)

## tidy: sync go.mod and go.sum
tidy:
	$(GO) mod tidy

## verify: everything CI runs, in CI's order
verify: tidy fmt-check lint test

## clean: remove build output and coverage data
clean:
	rm -rf $(BIN_DIR) coverage.out

.PHONY: help fmt fmt-check lint lint-new lint-fix test cover build tidy verify clean
