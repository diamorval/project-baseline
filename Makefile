.PHONY: up down logs build restart clean ps

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
