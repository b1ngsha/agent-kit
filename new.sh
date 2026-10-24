#!/usr/bin/env bash
# Create a project from a stack overlay.
#
#   ./new.sh gin <dir>
#   ./new.sh react <dir>
#   ./new.sh django <dir>
#
# Official tooling creates the project. This script then copies the stack's
# coding standard and the small set of files that standard assumes.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "usage: ./new.sh gin <dir> | ./new.sh react <dir> | ./new.sh django <dir>" >&2
  exit 2
}

[ $# -eq 2 ] || usage
stack="$1"
raw_dest="$2"

case "$stack" in
  gin|react|django) ;;
  *) usage ;;
esac

if [ -e "$raw_dest" ] || [ -L "$raw_dest" ]; then
  echo "destination exists: $raw_dest" >&2
  exit 1
fi

parent="$(dirname "$raw_dest")"
name="$(basename "$raw_dest")"
if [ ! -d "$parent" ]; then
  echo "parent directory does not exist: $parent" >&2
  exit 1
fi
if [[ ! "$name" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]; then
  echo "directory name must match [A-Za-z][A-Za-z0-9_-]*: $name" >&2
  exit 1
fi

dest="$(cd "$parent" && pwd)/$name"

copy_gin_overlay() {
  mkdir -p "$dest"
  tar -C "$ROOT/stacks/gin" --exclude cmd -cf - . | tar -C "$dest" -xf -
  mkdir -p "$dest/cmd/$name"
  cp "$ROOT/stacks/gin/cmd/service/main.go" "$ROOT/stacks/gin/cmd/service/main_test.go" "$dest/cmd/$name/"
}

copy_react_overlay() {
  cp "$ROOT/stacks/react/AGENTS.md" "$ROOT/stacks/react/CODING_STANDARDS.md" "$dest/"
  mkdir -p "$dest/docs/standards" "$dest/src/routes" "$dest/src/test"
  cp "$ROOT/stacks/react/docs/standards/"*.md "$dest/docs/standards/"
  cp "$ROOT/stacks/react/.oxlintrc.json" "$ROOT/stacks/react/.oxfmtrc.json" "$ROOT/stacks/react/vite.config.ts" "$ROOT/stacks/react/.pre-commit-config.yaml" "$dest/"
  mkdir -p "$dest/scripts"
  cp "$ROOT/stacks/react/scripts/check-file-tokens.sh" "$dest/scripts/"
  cp "$ROOT/stacks/react/src/main.tsx" "$dest/src/main.tsx"
  cp "$ROOT/stacks/react/src/routes/__root.tsx" "$ROOT/stacks/react/src/routes/index.tsx" "$dest/src/routes/"
  cp "$ROOT/stacks/react/src/test/setup.ts" "$dest/src/test/"
  python3 - "$dest/index.html" <<'PY'
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(re.sub(r"\s*<title>.*?</title>", "", path.read_text(), flags=re.DOTALL))
PY
  python3 - "$dest/package.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    pkg = json.load(f)
scripts = pkg.setdefault("scripts", {})
scripts["test"] = "vitest run"
scripts["lint"] = "oxlint --type-aware ."
scripts["format"] = "oxfmt --write ."
scripts["format:check"] = "oxfmt --check ."
scripts["setup-hooks"] = "pre-commit install --install-hooks"
with open(path, "w") as f:
    json.dump(pkg, f, indent=2)
    f.write("\n")
PY
}

if [ "$stack" = "django" ]; then
  command -v uv >/dev/null 2>&1 || { echo "uv is required" >&2; exit 1; }
  mkdir -p "$dest"
  sed "s/__PROJECT_NAME__/$name/" "$ROOT/stacks/django/pyproject.toml" >"$dest/pyproject.toml"
  cp "$ROOT/stacks/django/.python-version" "$ROOT/stacks/django/.gitignore" "$ROOT/stacks/django/.env.example" "$dest/"
  (
    cd "$dest"
    uv sync --python 3.13
    uv run --locked django-admin startproject config .
    uv run --locked python manage.py startapp health
    rm "$dest/health/admin.py" "$dest/health/models.py" "$dest/health/tests.py"
  )
  cp "$ROOT/stacks/django/config/settings.py" "$ROOT/stacks/django/config/urls.py" "$dest/config/"
  cp "$ROOT/stacks/django/health/__init__.py" "$ROOT/stacks/django/health/apps.py" "$ROOT/stacks/django/health/urls.py" "$ROOT/stacks/django/health/views.py" "$dest/health/"
  mkdir -p "$dest/tests/health" "$dest/docs/standards" "$dest/scripts"
  cp "$ROOT/stacks/django/tests/health/test_healthz.py" "$dest/tests/health/"
  cp "$ROOT/stacks/django/docs/standards/"*.md "$dest/docs/standards/"
  cp "$ROOT/stacks/django/AGENTS.md" "$ROOT/stacks/django/CODING_STANDARDS.md" "$ROOT/stacks/django/Makefile" "$ROOT/stacks/django/.pre-commit-config.yaml" "$ROOT/stacks/django/README.md" "$dest/"
  cp "$ROOT/stacks/django/scripts/check-file-tokens.sh" "$dest/scripts/"
  (
    cd "$dest"
    uv run --locked python manage.py migrate --noinput
    make fmt
    make check
    make test
  )
  echo "created $dest"
  echo "Next steps:"
  echo "  cd $dest"
  echo "  make setup-hooks"
  echo "  make run"
  exit 0
fi

if [ "$stack" = "gin" ]; then
  command -v go >/dev/null 2>&1 || { echo "go is required" >&2; exit 1; }
  mkdir -p "$dest"
  (
    cd "$dest"
    go mod init "$name"
    go get github.com/gin-gonic/gin
  )
  copy_gin_overlay
  (
    cd "$dest"
    gofmt -w .
    go test ./...
  )
  echo "created $dest"
  exit 0
fi

command -v pnpm >/dev/null 2>&1 || { echo "pnpm is required" >&2; exit 1; }
# create-vite treats an absolute path as a relative project name.
(
  cd "$(dirname "$dest")"
  pnpm create vite "$name" --template react-ts
)
(
  cd "$dest"
  pnpm add @tanstack/react-router @tanstack/react-query
  pnpm add -D @tanstack/router-plugin @tanstack/router-cli vitest jsdom \
    @testing-library/react @testing-library/jest-dom @testing-library/user-event \
    oxlint oxlint-tsgolint oxfmt
)
copy_react_overlay
(
  cd "$dest"
  pnpm exec tsr generate
  pnpm format
  pnpm test
)
echo "created $dest"
