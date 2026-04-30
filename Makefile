COMPOSE_FILE = .docker/docker-compose.yml
DC = docker compose -f $(COMPOSE_FILE)

.PHONY: up down build clean shell

up:
	@echo "🚀 Запуск среды Аналитика..."
	$(DC) up -d
	@echo "✅ Среда готова. Подключайтесь к порту 2226."

build:
	@echo "🏗️  Сборка контейнера Аналитика..."
	$(DC) up -d --build
	@echo "✅ Сборка завершена."

down:
	@echo "🛑 Остановка среды..."
	$(DC) down

clean: down
	@echo "🧹 Удаление контейнера..."
	$(DC) down --rmi all

shell:
	@echo "🔌 Вход в консоль контейнера..."
	docker exec -it antigravity_analyst bash
