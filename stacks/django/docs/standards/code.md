# Django Code Standard

How Django code is split across layers and written inside each. The
cross-cutting rules in `CODING_STANDARDS.md` apply; this file adds what is
specific to Django, DRF, and Celery. Migrations are generated and out of
scope.

## Layers

The leading word is **use case**: one request or one task runs one use case,
and that use case is a function in `services/`.

| Layer | Holds | Calls |
| --- | --- | --- |
| `apis/v1/<audience>/<area>/` | Views, serializers, throttles, URL confs | `services`, `apps` models for read-only querysets |
| `services/<area>/` | Use cases, business rules, transactions, error translation | `apps`, `clients`, `common` |
| `apps/<app>/` | Models, managers and querysets, admin, Celery tasks, management commands | `services` (tasks, admin, commands), `clients` |
| `clients/` | One adapter per outbound system | `schemas`, settings |
| `schemas/` | Typed payloads exchanged with outbound systems | Nothing in the project |
| `common/` | `AppError` bases, DRF exception handler, renderer, middleware, health | Nothing above it |

Paths are relative to the project package. Import-linter contracts in
`pyproject.toml` enforce the forbidden directions; this file covers what goes
inside each layer.

**Hard.**

- Business logic lives in `services`: a state transition, a permission rule
  beyond DRF's permission class, a multi-model write, a call to an outbound
  client. A view, serializer, admin action, management command, or task that
  needs one calls the service.
- A reusable query shape (a filter, an annotation, a `select_related` set)
  lives on the model's manager or queryset in `apps/<app>/managers.py`. A
  derived value of one row is a model `@property` or method.
- A model's `save()` and signals hold no business logic. A rule that must run
  on every write goes in the service that writes, or in a database
  constraint.

**Judgement.** A service module that collects unrelated use cases wants
re-cutting along concepts, one module per use case or concept (`accept.py`,
`retention.py`, `locking.py`).

## Views and serializers

The leading word is **thin**: a view parses, calls, and renders.

**Hard.**

- One `APIView` per operation. Its method validates an input serializer with
  `is_valid(raise_exception=True)`, calls one service function with the
  validated values as keyword arguments, and returns an output serializer's
  data.
- A serializer validates wire shape: types, required fields, lengths,
  formats, and the existence of referenced rows. A rule that reads other
  rows' state or the current user's history belongs to the service.
- Serializers are nested in the view they serve, named `InputSerializer` and
  `OutputSerializer`, as the HackSoft Django Styleguide prescribes. Each
  view has its own; a serializer is reused across views as little as
  possible, because a change to a shared serializer changes every endpoint
  that uses it. A nested object inside one serializer is an inner
  `Serializer` class or a field, not a module-level serializer.
- Every nested serializer declares a unique OpenAPI component name with
  `@extend_schema_serializer(component_name="<Concept><Action>Input")` (or
  `Output`). drf-spectacular names components by class name, and two
  `InputSerializer` classes would collide.
- Every view carries `@extend_schema` with its request and response
  serializers, so the OpenAPI schema states the contract.
- A view sets `permission_classes` explicitly, and `throttle_classes` when the
  endpoint is unauthenticated or writes.

**Judgement.** A view method longer than parse–call–render, or one that
branches on a service's result to choose a status code, has business logic
that wants moving into the service or into an `AppError`.

## Services

**Hard.**

- A service is a module-level function. Beyond a single argument, its
  arguments are keyword-only (`*,`) and type-annotated, and it returns a
  model instance, a dataclass, or a typed value, never a DRF `Response` or
  serializer data.
- A service owns its transaction. It opens `transaction.atomic()` around the
  writes that must succeed together, and takes `select_for_update()` on rows
  whose state it reads and then changes.
- `services` imports no DRF and no `request`. The caller passes the user and
  values the service needs.

**Judgement.** A service that takes a model instance and a separate ID for
the same row, or several arguments that always travel together, wants one
parameter (Data Clumps).

## Errors

The leading word is **handle once**: each exception is raised, or translated,
or recovered from, in exactly one place.

**Hard.**

- A business outcome the client sees is an `AppError` subclass, built on
  HTTP-semantic bases in `common/errors.py` (`ValidationFailed`,
  `PermissionDenied`, `NotFound`, `Conflict`, `ServiceUnavailable`), and is
  declared in the area's `services/<area>/errors.py`. The global DRF
  exception handler renders it; views do not catch it.
- Each `AppError` subclass sets its own `code`. A code is part of the API
  contract: clients branch on it, so it is renamed only together with every
  consumer.
- An outbound client raises its own error type. The service that called it
  translates the error into an `AppError` or a recorded state, or re-raises
  it as an internal error. A client failure is never reported as invalid
  input or not-found, and the global handler does not learn client error
  types.
- A `try` / `except` stays outside `transaction.atomic()`. Django decides
  commit or rollback by whether the block exits with an exception, and a
  handler inside the block hides the failure.
- `except Exception` appears only to record state and re-raise.

## Side effects and transactions

The leading word is **after commit**: a side effect that the database cannot
roll back runs after the transaction that justified it commits.

**Hard.**

- A Celery task started from a write path is enqueued with
  `task.delay_on_commit(...)` (Celery ≥ 5.4) or inside
  `transaction.on_commit(...)`, so a rolled-back write never starts work.
- An outbound call (HTTP, object storage, another service) runs outside
  `transaction.atomic()`. A transaction holds row locks while it waits, and
  rolling it back cannot undo the remote effect. The order is: outbound work,
  then a short transaction that records the result, or a recorded intent
  first and the outbound call after commit.
- Every outbound call is bounded in time. The client sets its timeout from
  settings, and the caller may pass a shorter one.

## Celery tasks

**Hard.**

- A task lives in `apps/<app>/tasks.py`, is a `@shared_task` with an
  explicit `name="<app>.<verb>_<noun>"`, and calls one service.
- A task takes IDs and plain values (`job_id: str`, timestamps as ISO text),
  re-fetches rows when it runs, and never receives a model instance.
- A task states its retry policy: either it is idempotent and declares its
  retries, or it sets `max_retries=0` and its docstring says why.
- A task does not wait on another task's result. Follow-up work is enqueued:
  a scanning task enqueues one task per claimed row.

## Models

**Hard.**

- Members follow Django's order: fields; custom managers; `class Meta`;
  `__str__` and other dunder methods; `save()`; `get_absolute_url()`; other
  methods and properties.
- A field with a closed value set uses a `models.TextChoices` /
  `IntegerChoices` class nested in the model, and code compares against its
  members (`Order.Status.PENDING`), never against string literals.
- An invariant the database can hold is a constraint (`UniqueConstraint`,
  `CheckConstraint`, `null=False`), so concurrent writers cannot both pass a
  Python check.

## Logging

The leading word is **boundary**: views, tasks, management commands, and
services that end a use case log; helpers return or raise.

**Hard.**

- A module that logs declares `logger = logging.getLogger(__name__)` at
  module scope, and nothing else names a logger.
- The message is a fixed phrase, with varying data as %-style arguments:
  `logger.info("scan_jobs finished: scanned=%s", count)`. No f-strings and no
  `.format()` in log calls, so a handler that filters the record never
  formats it.
- An error that is logged and not re-raised is logged with
  `logger.exception(...)` (inside `except`) so the traceback is kept.
- A log line holds identifiers (`job_id`, `user_id`), never credential
  material: passwords, tokens, invitation codes, webhook secrets, presigned
  URLs, and `Authorization` headers stay out of every message and argument.
- `print()` appears only in management commands, and those prefer
  `self.stdout.write`.

**Judgement.** Levels follow the Python logging HOWTO:

| Level | Meaning |
| --- | --- |
| ERROR | The operation failed and a person may need to act. |
| WARNING | Something unexpected happened; the code handled it and continued. |
| INFO | Lifecycle and completion of a request, task, or command. |
| DEBUG | Diagnostic detail, off in staging and production. |

## Time and configuration

**Hard.**

- The current time is `django.utils.timezone.now()`. `datetime.now()` and
  `datetime.utcnow()` are not used.
- Environment variables are read only in the settings package (for example
  through `django-environ`). Code elsewhere reads `django.conf.settings`.
- A setting that must be present in staging or production fails at startup
  through a Django system check, not at the first request that needs it.
