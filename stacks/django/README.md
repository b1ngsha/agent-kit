# Django API starter

This project was generated from agent-kit with Django, Django REST Framework,
SQLite, and a minimal liveness endpoint. Dependencies are locked in `uv.lock`.

## Commands

```bash
make fmt
make lint
make check
make test
make run
```

`GET /healthz` returns `204 No Content`. It checks only that the process can
answer; it does not check the database or another external service.

Run `make check-deploy` before deployment. It reports production settings that
must be reviewed; a passing local `make check` is not a production audit.

## Configuration

Install dependencies with [uv](https://docs.astral.sh/uv/). Copy `.env.example`
to `.env` for local configuration. Existing environment variables take
precedence over `.env`.

- `DJANGO_SECRET_KEY`: required when `DJANGO_DEBUG=false`.
- `DJANGO_DEBUG`: defaults to `true`; accepts `true`/`false` and common boolean forms.
- `DJANGO_ALLOWED_HOSTS`: comma-separated host names; required when debug is false.
- `DJANGO_SQLITE_PATH`: SQLite path relative to the project root, default `db.sqlite3`.

The generator runs the initial migrations. Run `uv run python manage.py migrate`
after adding or changing models.

## Hooks

After initializing Git, install the checks explicitly:

```bash
make setup-hooks
```

The generator does not initialize Git or install hooks automatically.
