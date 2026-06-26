.PHONY: help init up down logs build restart clean ps rename
.DEFAULT_GOAL := help

help:          ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

init:          ## First-time setup: personalise the project interactively, then optionally boot it
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

clean:         ## Stop and delete everything, including DB volumes (fresh realm import)
	docker compose down -v

rename:        ## Rename-only (no prompts/boot); prefer 'make init'. Usage: make rename NAME=acme
	@test -n "$(NAME)" || { echo "usage: make rename NAME=<new-name>"; exit 1; }
	bash scripts/rename.sh $(NAME)
