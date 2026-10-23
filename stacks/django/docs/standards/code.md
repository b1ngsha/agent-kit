# Django Code Standard

How the generated Django API starter and later Django/DRF code are split. The
cross-cutting rules in `CODING_STANDARDS.md` apply. The starter initially owns
only `config/` and the `health/` liveness app; business layers appear with a
real use case.

## Starter boundaries

The generated project has these owners:

| Area | Holds |
| --- | --- |
| `config/` | Settings, root URLs, ASGI, and WSGI entry points |
| `health/` | The native Django `/healthz` liveness endpoint |
| `tests/<feature>/` | Tests arranged by behavior |

`GET /healthz` is an operational endpoint. It returns an empty `204` response
and does not check the database or another external service. It uses a native
Django view, not a serializer, service, schema, or OpenAPI operation. This is a
starter and framework-entry-point exception to the business endpoint rules
below.

## Layers when a use case appears

The leading word is **use case**: one request or task runs one use case, and
that use case is a function in a concept-named service module.

| Layer | Holds |
| --- | --- |
| `apis/v1/<audience>/<area>/` | DRF views, serializers, throttles, and URL confs |
| `services/<area>/` | Use cases, business rules, transactions, and error translation |
| `apps/<app>/` | Models, managers, querysets, admin, tasks, and commands |
| `clients/` | One adapter per outbound system |
| `schemas/` | Typed payloads exchanged with outbound systems |
| `common/` | Cross-cutting errors or middleware, only when a real second owner needs them |

Create a layer when a real caller needs it. Do not create empty directories or
placeholder abstractions. If import-linter contracts are later introduced,
they record the project's chosen dependency directions.

**Hard.**

- Business logic lives beside the use case that owns it. A view, admin action,
  command, or task that needs it calls the service; services do not import DRF
  or a request.
- A reusable query shape lives on its model manager or queryset. A derived
  value of one row is a model property or method.
- A model `save()` and signal hold no business logic. A rule that must run on
  every write belongs in the writing service or a database constraint.

## DRF endpoints

The leading word is **thin**: a business view parses, calls, and renders.
These rules apply to DRF business endpoints, not native operational endpoints
such as `/healthz`.

**Hard.**

- One `APIView` serves one operation. Its method validates an input serializer
  with `is_valid(raise_exception=True)`, calls one service with validated
  keyword arguments, and returns the declared output.
- A serializer validates wire shape: types, required fields, lengths, formats,
  and referenced-row existence. Rules that read other rows' state belong in
  the service.
- A view-local serializer is named `InputSerializer` or `OutputSerializer`.
  Nested serializers are kept close to the view they serve; reuse one only
  when the shared contract is intentional.
- A view sets `permission_classes` explicitly and sets throttles for
  unauthenticated or write endpoints.
- Add `drf-spectacular` and its schema annotations when the project adopts
  OpenAPI. The starter does not install it and `/healthz` is not an OpenAPI
  operation.

**Judgement.** A view longer than parse–call–render has business logic that
wants moving into a service or a typed application error.

## Services and failures

**Hard.**

- A service is a module-level function. Beyond one argument, its arguments are
  keyword-only and type-annotated; it returns a model, dataclass, or typed
  value, never a DRF `Response`.
- A service owns its transaction. It uses `transaction.atomic()` around writes
  that must succeed together and locks rows whose state it reads and changes.
- A business outcome exposed by a DRF API gets the project's typed application
  error convention when one exists. The view does not catch service errors.
- An outbound client raises its own error type; the calling service translates
  it into a client-facing outcome or re-raises it as an internal error.
- An outbound call has a bounded timeout and runs outside the transaction that
  records its result.

Celery is optional. When a project adds it, tasks take IDs and plain values,
re-fetch their rows, state an explicit retry policy, and enqueue write-triggered
work after commit. The starter does not install a broker or Celery.

## Models and configuration

- A closed model value set uses `TextChoices` or `IntegerChoices`; code compares
  against members rather than string literals.
- An invariant the database can hold is a database constraint.
- The current time is `django.utils.timezone.now()`.
- Environment variables are loaded in `config/settings.py` and application
  code reads `django.conf.settings`. The starter uses `python-dotenv` to load
  the root `.env` without overriding process environment variables.
- A setting required in staging or production fails through a Django system
  check or startup configuration error, not at the first request that needs it.
