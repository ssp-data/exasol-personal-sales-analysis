# Sales analytics on Exasol Personal — a declarative data stack in one file.
#
#   make all     CSV on disk -> data marts you can ask questions about
#   make ask     what to ask, and where
#
SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

PROFILE   ?= starter-kit
CSV       ?= data/E-Commerce Sales Analytics.csv
RAW_TABLE ?= RAW_SALES.SALES_ORDERS
PW_FILE   ?= $(HOME)/.exasol-starter-kit/credentials/nano_sys_password

export EXASOL_PASSWORD  ?= $(shell cat "$(PW_FILE)" 2>/dev/null)
export DBT_PROFILES_DIR := $(CURDIR)/transform

DBT := uv run --quiet dbt
SQL := exapump sql -p $(PROFILE)

## ---------------------------------------------------------------------------

help: ## Show this help
	@echo "Sales analytics on Exasol Personal"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  Config lives in stack.yaml. Everything else is generated."

all: setup check render load transform grants verify ## Run the whole stack, start to finish
	@echo
	@echo "Done. Now run 'make ask'."

setup: ## Create the Python environment (uv)
	@uv sync --quiet
	@echo "env ready: $$($(DBT) --version 2>/dev/null | head -2 | tail -1 | xargs)"

check: ## Confirm the database is up and the tools are installed
	@command -v uv       >/dev/null || { echo "uv not found — https://docs.astral.sh/uv/"; exit 1; }
	@command -v exapump  >/dev/null || { echo "exapump not found — install the Exasol starter kit"; exit 1; }
	@test -n "$(EXASOL_PASSWORD)" || { echo "no password at $(PW_FILE)"; exit 1; }
	@$(SQL) "SELECT 1" >/dev/null 2>&1 || { echo "database not reachable — try 'exakit start'"; exit 1; }
	@echo "database up, tools present"

render: ## Compile stack.yaml into SQL and dbt models
	@uv run --quiet python engine/render.py

load: ## Create the raw table and load the CSV
	@$(SQL) < build/01_raw_schema.sql 2>&1 | tail -1
	@mkdir -p build
	@tr -d '\r' < "$(CSV)" > "build/source.csv"   # the file ships with CRLF line endings
	@exapump upload -p $(PROFILE) -t $(RAW_TABLE) "build/source.csv"

transform: ## Build staging + marts with dbt-exasol
	@$(DBT) build --project-dir transform

grants: ## Give the MCP user read-only access
	@$(SQL) < build/02_grants.sql 2>&1 | tail -1

verify: ## Assert the numbers add up
	@$(SQL) < build/03_verify.sql

ask: ## Show what to ask, and where
	@echo
	@echo "  The marts are live. Now open the agent of choice — Claude Code, Codex,"
	@echo "  Cursor — with the 'exasol' MCP server connected, and ask your questions."
	@echo
	@echo "  Example questions and the full mart catalogue: serve/questions.md"
	@echo
	@cat serve/questions.md

docs: ## Browse the model docs in a browser
	@$(DBT) docs generate --project-dir transform && $(DBT) docs serve --project-dir transform

clean: ## Drop both schemas — the stack is disposable
	@$(SQL) "DROP SCHEMA IF EXISTS SALES CASCADE" | tail -1
	@$(SQL) "DROP SCHEMA IF EXISTS RAW_SALES CASCADE" | tail -1
	@rm -rf build transform/target transform/logs

.PHONY: help all setup check render load transform grants verify ask docs clean
