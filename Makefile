.PHONY: help init up down logs build restart clean ps rename test release
.DEFAULT_GOAL := help

help:          ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

init:          ## Scaffold a personalised copy into a new folder (keeps this base pristine)
	bash scripts/init.sh

up:            ## Build (if needed) and start the whole stack
	docker compose up --build

down:          ## Stop and remove containers (keeps DB volumes)
	docker compose down

logs:          ## Tail logs for all services
	docker compose logs -f

build:         ## Rebuild images
	docker compose build

restart:       ## Recreate containers
	docker compose up -d --force-recreate

ps:            ## Show running services
	docker compose ps

test:          ## Run the backend test suite (pytest) in a one-off container
	docker compose run --rm --no-deps backend sh -c "pip install -q -r requirements-dev.txt && pytest"

release:       ## Bump version, regenerate CHANGELOG, and tag (Conventional Commits)
	@command -v cz >/dev/null || { echo "commitizen not found — install: uv tool install commitizen (or pipx install commitizen)"; exit 1; }
	cz bump --changelog

clean:         ## Stop and delete everything, including DB volumes (fresh realm import)
	docker compose down -v

rename:        ## Rename-only (no prompts/boot); prefer 'make init'. Usage: make rename NAME=acme
	@test -n "$(NAME)" || { echo "usage: make rename NAME=<new-name>"; exit 1; }
	bash scripts/rename.sh $(NAME)
