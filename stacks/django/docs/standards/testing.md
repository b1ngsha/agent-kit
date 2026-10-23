# Django Testing Standard

How tests under `tests/` are laid out and written. Pytest with
pytest-django is configured in `pyproject.toml`.

## Layout

The leading word is **feature-first**: a test file sits under the directory of
the feature it verifies, not the layer.

**Hard.**

- A feature's tests live under `tests/<feature>/`, and outbound adapters
  under `tests/clients/`.
- `tests/conftest.py` holds only suite-wide isolation. A pytest fixture whose
  scope is one subtree lives in that subtree's `conftest.py`.
- Reusable database builders live in a concept-named module of the feature
  (`tests/<feature>/factories.py`). `create_*` helpers write database state;
  `build_*` helpers only construct in-memory values or clients.
- Scenario-specific setup and URL helpers stay in the test module that owns
  the behavior. Ordinary helpers are not imported from `test_*.py` or
  `conftest.py`; a helper a second module needs moves to a concept-named
  support module (`webhook_signing.py`).
- The suite keeps the non-package layout: no `__init__.py` files, and every
  `test_*.py` basename is unique across the suite. Pytest's default
  `prepend` import mode needs unique basenames.

## What a test covers

**Hard.**

- A use case is tested through its service function, or through its endpoint
  with DRF's `APIClient` when the test asserts the HTTP contract (status,
  envelope, error `code`, permission). Both hit the test database
  (`@pytest.mark.django_db`).
- An endpoint test asserts the response's `code` and fields, not only the
  status, because clients branch on the code.
- An outbound system is replaced at its client: patch the transport inside
  the client to test the adapter, or patch the client method a service calls
  to test the service. Django models and services under test are real.
- Time-dependent behavior pins the clock by patching `timezone.now` where
  the module under test looks it up (`<package>.services.<area>.<module>.timezone.now`),
  not by sleeping.
- A test that needs PostgreSQL behavior (row locks, constraints SQLite does
  not enforce) carries a dedicated marker (such as `@pytest.mark.postgres`)
  and runs in the job that provides PostgreSQL.

**Judgement.**

- A test name states the behavior: `test_accept_rejects_busy_station`, not
  `test_accept_2`. Test docstrings, when present, state the expected
  behavior without "Tests that".
- A mock of a module inside the project (a service mocked from a view test)
  hides the integration the test should catch. Prefer the real service and a
  fake at the outbound client.
