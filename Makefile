# Raccourcis vers Docker Compose. Toutes les commandes se lancent depuis WSL2 (Ubuntu).
COMPOSE ?= docker compose
BACKEND := $(COMPOSE) exec backend
FRONTEND := $(COMPOSE) run --rm frontend

.PHONY: help up down logs ps migrate superuser seed test test-backend test-frontend lint lint-backend lint-frontend schema gen-api build-frontend

help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

up: ## Démarre toute la stack
	$(COMPOSE) up -d --build

down: ## Arrête la stack
	$(COMPOSE) down

logs: ## Suit les journaux
	$(COMPOSE) logs -f --tail=100

ps: ## État des conteneurs
	$(COMPOSE) ps

migrate: ## Applique les migrations
	$(BACKEND) python manage.py migrate

superuser: ## Crée un super-utilisateur
	$(BACKEND) python manage.py createsuperuser

seed: ## Charge des données fictives de démonstration
	$(BACKEND) python manage.py seed_demo

test: test-backend test-frontend ## Lance tous les tests

test-backend: ## Tests backend avec couverture
	$(BACKEND) pytest --cov

test-frontend: ## Tests frontend
	$(FRONTEND) npm test

lint: lint-backend lint-frontend ## Lint backend et frontend

lint-backend: ## ruff check et format
	$(BACKEND) ruff check .
	$(BACKEND) ruff format --check .

lint-frontend: ## ESLint, Prettier, tsc
	$(FRONTEND) npm run lint

schema: ## Régénère le schéma OpenAPI
	$(BACKEND) python manage.py spectacular --file schema.yml --validate

gen-api: schema ## Régénère le client TypeScript depuis le schéma
	$(FRONTEND) npm run gen:api

build-frontend: ## Construit l'export statique du frontend
	$(FRONTEND) npm run build
