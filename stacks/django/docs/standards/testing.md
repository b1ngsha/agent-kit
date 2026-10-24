# Django Testing Standard

How tests under `tests/` are laid out and written. Pytest with
pytest-django is configured in `pyproject.toml`.

## Layout

The leading word is **feature-first**: a test file sits under the directory of
the feature or behavior it verifies, not the layer.

**Hard.**

- A feature's tests live under `tests/<feature>/`, and outbound adapters under
  `tests/clients/`.
- `tests/conftest.py` holds only suite-wide isolation. A fixture whose scope is
  one subtree lives in that subtree's `conftest.py`.
- Reusable database builders live in a concept-named module of the feature.
  `create_*` helpers write database state; `build_*` helpers only construct
  in-memory values or clients.
- Scenario-specific setup and URL helpers stay in the test module that owns the
  behavior. A helper needed by a second module moves to a concept-named support
  module.
- Keep the non-package layout: no `__init__.py` files under `tests/`, and every
  `test_*.py` basename is unique across the suite.

## What a test covers

**Hard.**

- Test a business use case through its service function, or test its HTTP
  contract through DRF's `APIClient`. A native Django operational endpoint,
  such as the starter's `/healthz`, may use Django's `Client`.
- Request database access only when the behavior needs it; mark those tests
  with `pytest-django`'s database marker. A liveness test that does not query
  the database needs no marker.
- Assert the endpoint's actual contract: status and body for a native `204`
  endpoint, or status, fields, and error code for a JSON API response. Do not
  invent a response envelope for an endpoint that has none.
- Replace an outbound system at its client. Keep Django models and services
  real in tests of application behavior.
- Pin time by patching `timezone.now` where the module under test looks it up;
  do not sleep.

**Judgement.** A mock of a project module hides the integration the test should
catch. Prefer the real service and a fake at the outbound client.

If a project later relies on PostgreSQL behavior that SQLite cannot verify,
mark those tests explicitly and run them in the project's PostgreSQL job.
