.PHONY: fmt lint check check-deploy test run setup-hooks

fmt:
	uv run ruff check --fix .
	uv run ruff format .

lint:
	uv run ruff check .
	uv run ruff format --check .
	uv run ty check

check:
	uv run python manage.py check
	uv run python manage.py makemigrations --check --dry-run

check-deploy:
	uv run python manage.py check --deploy

test:
	uv run pytest

run:
	uv run python manage.py runserver

setup-hooks:
	uv run pre-commit install --install-hooks
