build-web:
	flutter build web --release

up-dev:
	cd infra && docker compose -f docker-compose.dev.yml up -d --build

down-dev:
	cd infra && docker compose -f docker-compose.dev.yml down

up-prod:
	cd infra && docker compose -f docker-compose.prod.yml up -d --build

down-prod:
	cd infra && docker compose -f docker-compose.prod.yml down
