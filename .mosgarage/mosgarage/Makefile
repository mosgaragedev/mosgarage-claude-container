# ============================================================
# mosgarage · Makefile
# ============================================================

.PHONY: help up down build push logs shell db-shell migrate dev clean

COMPOSE  = docker compose
IMAGE    = docker.io/mosgarage/mosgarage
VERSION ?= latest

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ── Development ──────────────────────────────────────────────────
up: ## Start all services (detached)
	$(COMPOSE) up -d

down: ## Stop all services
	$(COMPOSE) down

logs: ## Tail all logs
	$(COMPOSE) logs -f

build: ## Build images locally
	$(COMPOSE) build

# ── .NET dev server (hot-reload) ─────────────────────────────────
dev: ## Run .NET server locally with hot-reload (requires dotnet + postgres)
	cd src/Mosgarage.Server && dotnet watch run

# ── Database ─────────────────────────────────────────────────────
migrate: ## Apply EF Core migrations
	cd src/Mosgarage.Server && \
		dotnet ef database update --connection "$$(grep MOSGARAGE_PG_CONNECTION .env | cut -d= -f2-)"

migration: ## Add a new migration (ARGS="MigrationName")
	cd src/Mosgarage.Server && dotnet ef migrations add $(ARGS)

db-shell: ## Connect to PostgreSQL
	$(COMPOSE) exec database psql -U mosgarage -d mosgarage

# ── Build + push to Docker Hub ───────────────────────────────────
push: ## Build and push to docker.io/mosgarage/mosgarage
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--target runtime \
		--tag $(IMAGE):$(VERSION) \
		--tag $(IMAGE):latest \
		--push .
	@echo "✅  Pushed $(IMAGE):$(VERSION)"

push-workspace: ## Build and push workspace image
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--target workspace-base \
		--tag docker.io/mosgarage/workspace:$(VERSION) \
		--tag docker.io/mosgarage/workspace:latest \
		--push .

# ── Ops ──────────────────────────────────────────────────────────
shell: ## Shell into control plane
	$(COMPOSE) exec mosgarage bash

server-logs: ## Tail control plane logs
	$(COMPOSE) exec mosgarage tail -f /var/log/mosgarage/server.log

git-status: ## Show git sync status
	$(COMPOSE) exec mosgarage git-status

git-push-now: ## Force immediate git sync
	$(COMPOSE) exec mosgarage git-push-now

clean: ## Remove all containers, volumes, networks
	$(COMPOSE) down -v --remove-orphans
	docker volume rm mosgarage_home mosgarage_postgres_data 2>/dev/null || true
	@echo "⚠️  Tunnel identity reset — new URL on next start"

reset-tunnel: ## Reset tunnel DNA (forces new *.try.mosgarage.app URL)
	docker volume rm mosgarage_home 2>/dev/null || true
	@echo "♻️  mosgarage_home removed — tunnel identity will regenerate on next start"

# ── Deploy key ────────────────────────────────────────────────────
gen-key: ## Generate SSH deploy key for GitHub
	@chmod +x scripts/gen-deploy-key.sh && ./scripts/gen-deploy-key.sh

# ── SSH ───────────────────────────────────────────────────────────
ssh: ## SSH into the running workspace
	ssh -p 2222 mosgarage@localhost

ssh-setup: ## Re-run SSH key setup inside container
	$(COMPOSE) exec mosgarage ssh-setup

ssh-connect: ## Auto-configure local ~/.ssh/config for mosgarage
	@chmod +x scripts/ssh-connect.sh && MOSGARAGE_HOST=localhost MOSGARAGE_PORT=2222 ./scripts/ssh-connect.sh

# ── Entra ID ──────────────────────────────────────────────────────
entra-setup: ## Create Entra ID App Registration (requires az CLI + login)
	@chmod +x deploy/entra-setup.sh && ./deploy/entra-setup.sh

entra-setup-ps: ## Create Entra ID App Registration (PowerShell)
	powershell -ExecutionPolicy RemoteSigned -File deploy/entra-setup.ps1
