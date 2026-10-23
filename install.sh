#!/usr/bin/env bash
# Link this repo's own skills, and point every agent at the npx skills tree.
#
# Upstream skills are owned by `npx skills` (`~/.agents/skills` and
# `~/.agents/.skill-lock.json`). This script must not replace those copies
# with a checkout under vendor/. Agent directories get a symlink to
# `~/.agents/skills/<name>`, so Cursor and Codex read the same tree Claude
# reads. Skills in this repo that npx does not own are still symlinked into
# `~/.agents/skills` from here.
#
#   ./install.sh             # (default) git pull + vendor submodules, then (re)link
#   ./install.sh update      # same as above (explicit alias)
#   ./install.sh link        # only (re)link symlinks — no network access
#   ./install.sh dry-run     # preview what would be linked (no network, no writes)
#   ./install.sh uninstall   # remove only the symlinks this repo created
#
# The git pull / submodule step only runs when this script lives in a real git
# checkout (a local clone). It is skipped automatically for remote one-liners
# and other copies that contain no .git.
# Set SKIP_UPDATE=1 to skip the network step even inside a clone.
#
# Run this script from a complete checkout or synced copy of agent-kit.

# Bash 3.2 nounset does not support empty arrays; all state arrays are
# initialized before use.
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MODE="${1:-install}"
SKIP_UPDATE="${SKIP_UPDATE:-0}"
case "$MODE" in
  install|update|link|dry-run|uninstall) ;;
  *)
    echo "unknown mode: $MODE (use install|update|link|uninstall|dry-run)" >&2
    exit 1
    ;;
esac

CANON="$HOME/.agents/skills"
LOCK="$HOME/.agents/.skill-lock.json"
STATE_DIR="$HOME/.local/state/agent-kit"
MANIFEST="$STATE_DIR/install.state"
WRITE_LOCK="$STATE_DIR/install.lock.d"
TARGETS=(
  "$CANON"
  "$HOME/.claude/skills"
  "$HOME/.cursor/skills"
  "$HOME/.codex/skills"
)
LOCK_HELD=0
STATE_TEMP=""
fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}
cleanup() {
  [ -z "$STATE_TEMP" ] || rm -f "$STATE_TEMP"
  if [ "$LOCK_HELD" = 1 ]; then
    rmdir "$WRITE_LOCK"
  fi
  return 0
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# ---------------------------------------------------------------------------
# update_repo: bring this checkout up to date (git pull + vendor submodules).
# Linking continues even if the update fails so the current (possibly stale)
# content stays installed; UPDATE_FAILED makes the script exit non-zero at the
# end so the problem is not silently ignored.
# ---------------------------------------------------------------------------
UPDATE_FAILED=0
update_repo() {
  if [ "$SKIP_UPDATE" = "1" ]; then
    printf "[update] skipped (SKIP_UPDATE=1)\n"
    return 0
  fi

  local git_root
  if ! git_root="$(git -C "$REPO_DIR" rev-parse --show-toplevel 2>/dev/null)" || [ -z "$git_root" ]; then
    printf "[update] skipped: %s is not a git checkout (remote one-liner / synced copy?)\n" "$REPO_DIR"
    return 0
  fi

  printf "[update] repo: %s\n" "$git_root"

  # 1. Pull latest commits. --ff-only: never fabricate a merge, fail loudly instead.
  if ! git -C "$git_root" pull --ff-only 2>&1 | sed 's/^/    /'; then
    printf "WARN: git pull --ff-only failed (offline / uncommitted changes / unpushed local commits / diverged).\n" >&2
    printf "      Fix: push local commits, or run 'git pull --rebase', or commit/stash uncommitted changes.\n" >&2
    printf "      Then rerun. Use SKIP_UPDATE=1 to only relink without touching git.\n" >&2
    UPDATE_FAILED=1
  fi

  # 2. Refresh vendor submodules (kami and other curated sources)
  #    to their upstream tips. This stages the new gitlink pointers in the
  #    superproject but does not commit them.
  if ! git -C "$git_root" submodule update --recursive --remote 2>&1 | sed 's/^/    /'; then
    printf "WARN: 'git submodule update --recursive --remote' failed.\n" >&2
    printf "      Check network access to the submodule remotes and local submodule state.\n" >&2
    UPDATE_FAILED=1
  elif [ -n "$(git -C "$git_root" status --porcelain -- vendor 2>/dev/null)" ]; then
    printf "[update] vendor pointers moved. To keep the bump, commit them:\n"
    printf "        git -C %q add vendor\n" "$git_root"
    printf "        git -C %q commit -m 'chore: bump vendor skills'\n" "$git_root"
  fi

  return 0
}

# ---------------------------------------------------------------------------
# npx lock: read the skills object from the npx lock file with Bash builtins.
# Parser state is passed through load_npx_lock's local variables.
# ---------------------------------------------------------------------------
_npx_lock_space() {
  while (( _pos < ${#_json} )); do
    case "${_json:_pos:1}" in
      ' '|$'\t'|$'\r'|$'\n') _pos=$((_pos + 1)) ;;
      *) break ;;
    esac
  done
  return 0
}

_npx_lock_string() {
  local ch
  _str=''
  [ "${_json:_pos:1}" = '"' ] || return 1
  _pos=$((_pos + 1))
  while (( _pos < ${#_json} )); do
    ch=${_json:_pos:1}
    _pos=$((_pos + 1))
    case "$ch" in
      '"') return 0 ;;
      '\')
        ch=${_json:_pos:1}
        _pos=$((_pos + 1))
        case "$ch" in
          '"'|'\'|'/') ;;
          b) ch=$'\b' ;;
          f) ch=$'\f' ;;
          n) ch=$'\n' ;;
          r) ch=$'\r' ;;
          t) ch=$'\t' ;;
          u)
            _error='unsupported JSON \\uXXXX escape; use raw UTF-8'
            return 1
            ;;
          *) return 1 ;;
        esac
        ;;
      [$'\001'-$'\037']) return 1 ;;
      [$'\200'-$'\377'])
        # Validate UTF-8 byte by byte, rejecting overlong encodings, surrogates,
        # and out-of-range code points.
        _pos=$((_pos - 1))
        [[ ${_json:_pos:4} =~ $_utf8 ]] || return 1
        ch=${BASH_REMATCH[0]}
        _pos=$((_pos + ${#ch}))
        ;;
    esac
    _str+=$ch
  done
  return 1
}

_npx_lock_value() {
  local mode=${1:-other} depth=$((depth + 1)) ch key close name
  (( depth <= 128 )) || {
    _error='JSON nesting exceeds 128 levels'
    return 1
  }
  _npx_lock_space
  ch=${_json:_pos:1}
  case "$mode" in
    root|skills) [ "$ch" = '{' ] || return 1 ;;
  esac
  case "$ch" in
    '{'|'[')
      close='}'
      [ "$ch" = '{' ] || close=']'
      _pos=$((_pos + 1))
      _npx_lock_space
      if [ "${_json:_pos:1}" = "$close" ]; then
        _pos=$((_pos + 1))
        return 0
      fi
      while :; do
        key=''
        if [ "$close" = '}' ]; then
          _npx_lock_string || return 1
          key=$_str
          _npx_lock_space
          [ "${_json:_pos:1}" = ':' ] || return 1
          _pos=$((_pos + 1))
        fi
        if [ "$mode" = root ] && [ "$key" = skills ]; then
          [ "$_seen" = 0 ] || {
            _error='duplicate skills in root object'
            return 1
          }
          _seen=1
          _npx_lock_value skills || return 1
        else
          if [ "$mode" = skills ]; then
            [[ $key =~ $_safe_name ]] || {
              _error='unsupported skill name'
              return 1
            }
            for name in "${_names[@]}"; do
              [ "$name" != "$key" ] || {
                _error='duplicate skill name'
                return 1
              }
            done
            _names+=("$key")
          fi
          _npx_lock_value other || return 1
        fi
        _npx_lock_space
        ch=${_json:_pos:1}
        _pos=$((_pos + 1))
        [ "$ch" != "$close" ] || return 0
        [ "$ch" = ',' ] || return 1
        _npx_lock_space
      done
      ;;
    '"') _npx_lock_string || return 1 ;;
    t)
      [ "${_json:_pos:4}" = true ] || return 1
      _pos=$((_pos + 4))
      ;;
    f)
      [ "${_json:_pos:5}" = false ] || return 1
      _pos=$((_pos + 5))
      ;;
    n)
      [ "${_json:_pos:4}" = null ] || return 1
      _pos=$((_pos + 4))
      ;;
    '-'|[0-9])
      [[ ${_json:_pos} =~ $_number ]] || return 1
      _pos=$((_pos + ${#BASH_REMATCH[0]}))
      ;;
    *) return 1 ;;
  esac
  return 0
}

load_npx_lock() {
  local LC_ALL=C _json='' _pos=0 _str='' _seen=0 depth=0
  local _error='invalid JSON, missing skills, or skills is not an object' _status=0
  local _number='^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?'
  local _safe_name='^[A-Za-z0-9][A-Za-z0-9._-]*$'
  local _utf8=$'^([\302-\337][\200-\277]|\340[\240-\277][\200-\277]|[\341-\354\356-\357][\200-\277]{2}|\355[\200-\237][\200-\277]|\360[\220-\277][\200-\277]{2}|[\361-\363][\200-\277]{3}|\364[\200-\217][\200-\277]{2})'
  local -a _names=()
  NPX=()
  if [ ! -e "$LOCK" ] && [ ! -L "$LOCK" ]; then
    return 0
  fi
  if [ ! -f "$LOCK" ] || [ ! -r "$LOCK" ]; then
    fail "Cannot read npx lock file: $LOCK"
  fi
  # Read the file with a NUL terminator to preserve a trailing newline; a NUL
  # in the content must fail.
  IFS= read -r -d '' _json < "$LOCK" || _status=$?
  [ "$_status" = 1 ] || fail "npx lock file contains NUL or cannot be read: $LOCK"
  # All parsing runs in the current shell; results are published only after
  # full validation.
  _npx_lock_value root || fail "npx lock file parse failed: $_error ($LOCK)"
  _npx_lock_space
  if [ "$_seen" != 1 ] || (( _pos != ${#_json} )); then
    fail "npx lock file parse failed: $_error ($LOCK)"
  fi
  NPX=("${_names[@]}")
  return 0
}

# ---------------------------------------------------------------------------
# State: the install manifest is a versioned header and end marker with
# NUL-separated fields. It is read as data only, never sourced or evaluated.
# ---------------------------------------------------------------------------
valid_name() {
  case "$1" in
    ''|.|..|*/*|*$'\n'*|*$'\r'*) return 1 ;;
  esac
}
valid_state_path() {
  case "$1" in
    /*) ;;
    *) return 1 ;;
  esac
  case "/${1#/}/" in
    */./*|*/../*|*$'\n'*|*$'\r'*) return 1 ;;
  esac
}
# Historical link targets may be relative; preserve them verbatim for later
# verification.
valid_link_target() {
  case "$1" in
    ''|*$'\n'*|*$'\r'*) return 1 ;;
  esac
}
validate_link_record() {
  valid_state_path "$1" && valid_name "${1##*/}" || fail "Invalid link path: $1"
  valid_link_target "$2" || fail "Invalid link target: $1"
}
read_link_target() {
  # The sentinel preserves trailing newlines in readlink output that belong to
  # the target itself.
  LINK_TARGET="$(readlink "$1" && printf '.')" || fail "Cannot read symlink: $1"
  LINK_TARGET="${LINK_TARGET%.}"
  LINK_TARGET="${LINK_TARGET%$'\n'}"
  valid_link_target "$LINK_TARGET" || fail "Invalid symlink target: $1"
}
read_state_field() {
  IFS= read -r -d '' "$1" || fail "Truncated install manifest: $MANIFEST"
}
read_state_records() {
  local kind path owner dest extra
  read_state_field kind
  [ "$kind" = agent-kit-state-v1 ] || fail "Invalid install manifest version"
  while :; do
    read_state_field kind
    if [ "$kind" = end ]; then
      extra=""
      if IFS= read -r -d '' extra || [ -n "$extra" ]; then
        fail "Trailing manifest data"
      fi
      break
    fi
    read_state_field path
    read_state_field owner
    read_state_field dest
    valid_state_path "$path" && valid_name "${path##*/}" || fail "Invalid manifest path: $path"
    case "$kind" in
      link)
        valid_state_path "$owner" || fail "Invalid manifest owner: $owner"
        validate_link_record "$path" "$dest"
        contains "$path" "${M_PATH[@]}" && fail "Duplicate manifest link: $path"
        M_PATH+=("$path")
        M_REPO+=("$owner")
        M_DEST+=("$dest")
        ;;
      pending)
        [ -z "$owner" ] || fail "Invalid pending record"
        validate_link_record "$path" "$dest"
        P_PATH+=("$path")
        P_DEST+=("$dest")
        ;;
      released)
        [ -z "$owner$dest" ] || fail "Invalid released record"
        RELEASED+=("$path")
        ;;
      *) fail "Unknown manifest record: $kind" ;;
    esac
  done
}
load_state() {
  M_PATH=()
  M_REPO=()
  M_DEST=()
  P_PATH=()
  P_DEST=()
  RELEASED=()
  NPX=()
  if [ -e "$STATE_DIR/install.json" ] || [ -L "$STATE_DIR/install.json" ]; then
    fail "Legacy install.json found; uninstall with the previous installer and archive that manifest before switching"
  fi
  if [ -e "$MANIFEST" ] || [ -L "$MANIFEST" ]; then
    [ -f "$MANIFEST" ] && [ -r "$MANIFEST" ] || fail "Cannot read install manifest"
    read_state_records < "$MANIFEST"
  fi
  load_npx_lock
}
emit_state() {
  local i
  for i in "${!M_PATH[@]}"; do
    [ -n "${M_PATH[$i]}" ] || continue
    printf 'link\0%s\0%s\0%s\0' "${M_PATH[$i]}" "${M_REPO[$i]}" "${M_DEST[$i]}"
  done
  for i in "${!P_PATH[@]}"; do
    [ -n "${P_PATH[$i]}" ] || continue
    printf 'pending\0%s\0\0%s\0' "${P_PATH[$i]}" "${P_DEST[$i]}"
  done
  for i in "${RELEASED[@]}"; do
    printf 'released\0%s\0\0\0' "$i"
  done
}
save_state() {
  local i
  # Validate every record before creating the temp file, including retained
  # state from other checkouts.
  for i in "${!M_PATH[@]}"; do
    [ -n "${M_PATH[$i]}" ] || continue
    validate_link_record "${M_PATH[$i]}" "${M_DEST[$i]}"
    valid_state_path "${M_REPO[$i]}" || fail "Invalid manifest owner: ${M_REPO[$i]}"
  done
  for i in "${!P_PATH[@]}"; do
    [ -n "${P_PATH[$i]}" ] || continue
    validate_link_record "${P_PATH[$i]}" "${P_DEST[$i]}"
  done
  for i in "${RELEASED[@]}"; do
    valid_state_path "$i" && valid_name "${i##*/}" || fail "Invalid released path: $i"
  done
  STATE_TEMP="$(mktemp "$STATE_DIR/.install-XXXXXXXX")"
  {
    printf 'agent-kit-state-v1\0'
    emit_state
    printf 'end\0'
  } > "$STATE_TEMP"
  mv -f "$STATE_TEMP" "$MANIFEST"
  STATE_TEMP=""
}

# The directory may not exist yet; resolve only existing parent directories and
# reject dangling aliases.
resolve_directory() {
  local path="$1" depth="${2:-0}" parent base
  valid_state_path "$path" || fail "Invalid directory path: $path"
  [ "$depth" -lt 80 ] || fail "Too many directory levels: $path"
  if [ -d "$path" ]; then
    RESOLVED="$(cd -P "$path" && pwd -P)" || fail "Cannot resolve directory: $path"
  elif [ -L "$path" ]; then
    fail "Dangling or inaccessible directory symlink: $path"
  elif [ -e "$path" ]; then
    fail "Not a directory: $path"
  else
    if [ "$path" = / ]; then
      fail "Cannot access root directory"
    fi
    path="${path%/}"
    base="${path##*/}"
    parent="${path%/*}"
    resolve_directory "${parent:-/}" "$((depth + 1))"
    RESOLVED="${RESOLVED%/}/$base"
  fi
  valid_state_path "$RESOLVED" || fail "Invalid resolved directory: $path"
}
# Migration resolves only the physical parent of the target; do not collapse ..
# or follow the final skill link.
legacy_location() {
  local parent base="${1##*/}"
  valid_name "$base" || return 1
  parent="$(cd -P "${1%/*}" 2>/dev/null && pwd -P)" || return 1
  valid_state_path "$parent" || return 1
  LOCATION="${parent%/}/$base"
}
contains() {
  local needle="$1" value
  shift
  for value in "$@"; do
    [ "$value" != "$needle" ] || return 0
  done
  return 1
}
location() {
  resolve_directory "${1%/*}"
  LOCATION="${RESOLVED%/}/${1##*/}"
}
skill_in_lock() {
  contains "$1" "${NPX[@]}"
}
is_canon_target() {
  resolve_directory "$1"
  [ "$RESOLVED" = "$CANON_REAL" ]
}
prepare_targets() {
  TARGET_PATHS=()
  TARGET_REAL=()
  ALLOWED=()
  local target
  resolve_directory "$CANON"
  CANON_REAL="$RESOLVED"
  for target in "${TARGETS[@]}"; do
    resolve_directory "$target"
    ALLOWED+=("$RESOLVED")
    [ -d "${target%/*}" ] || continue
    if [ -e "$target" ] && [ ! -d "$target" ]; then
      continue
    fi
    contains "$RESOLVED" "${TARGET_REAL[@]}" && continue
    TARGET_PATHS+=("$target")
    TARGET_REAL+=("$RESOLVED")
  done
  if [ "${#TARGET_PATHS[@]}" = 0 ] && [ "$MODE" != uninstall ]; then
    fail "No available agent directory; create an agent parent directory before installing or previewing"
  fi
}

# ---------------------------------------------------------------------------
# Ownership: decide which existing links this checkout is allowed to manage.
# ---------------------------------------------------------------------------
find_owned() {
  contains "$1" "${O_KEY[@]}"
}
add_owned() {
  local path="$1" dest="$2" key="$3" i
  validate_link_record "$path" "$dest"
  valid_state_path "$key" && valid_name "${key##*/}" || fail "Invalid owned location: $key"
  find_owned "$key" && return 0
  for i in "${!TARGET_REAL[@]}"; do
    if [ "${TARGET_REAL[$i]}" = "${key%/*}" ]; then
      path="${TARGET_PATHS[$i]}/${key##*/}"
      break
    fi
  done
  O_PATH+=("$path")
  O_DEST+=("$dest")
  O_KEY+=("$key")
}
prepare_ownership() {
  O_PATH=()
  O_DEST=()
  O_KEY=()
  FOREIGN=()
  RECORDED=()
  PROTECTED=()
  local i j path key actual accepted target dest name known
  # Keep original paths and add current physical paths so user takeover records
  # survive directory moves.
  for path in "${RELEASED[@]}"; do
    location "$path"
    contains "$LOCATION" "${RELEASED[@]}" || RELEASED+=("$LOCATION")
  done
  for i in "${!M_PATH[@]}"; do
    path="${M_PATH[$i]}"
    location "$path"
    key="$LOCATION"
    RECORDED+=("$key")
    if [ "${M_REPO[$i]}" != "$REPO_DIR" ]; then
      FOREIGN+=("$key")
    fi
    if [ "${M_REPO[$i]}" = "$REPO_DIR" ]; then
      contains "${key%/*}" "${ALLOWED[@]}" || fail "Manifest link outside agent skill directories: $path"
    fi
  done
  for i in "${!M_PATH[@]}"; do
    [ "${M_REPO[$i]}" = "$REPO_DIR" ] || continue
    path="${M_PATH[$i]}"
    location "$path"
    key="$LOCATION"
    contains "$key" "${FOREIGN[@]}" && continue
    if [ "${key%/*}" = "$CANON_REAL" ] && skill_in_lock "${key##*/}"; then
      continue
    fi
    accepted=0
    if [ -L "$path" ]; then
      read_link_target "$path"
      actual="$LINK_TARGET"
      if [ "$actual" = "${M_DEST[$i]}" ]; then
        accepted=1
      fi
      for j in "${!P_PATH[@]}"; do
        if [ "${P_PATH[$j]}" = "$path" ] && [ "${P_DEST[$j]}" = "$actual" ]; then
          accepted=1
        fi
      done
    fi
    if [ "$accepted" = 1 ]; then
      add_owned "$path" "$actual" "$key"
    elif [ -e "$path" ] || [ -L "$path" ]; then
      PROTECTED+=("$key")
    fi
  done
  # Claim only explicit historical paths of this checkout; recorded user
  # changes are never migrated again.
  for target in "${TARGET_PATHS[@]}"; do
    for path in "$target"/*; do
      [ -L "$path" ] || continue
      location "$path"
      key="$LOCATION"
      name="${path##*/}"
      contains "$key" "${RECORDED[@]}" "${RELEASED[@]}" "${FOREIGN[@]}" && continue
      if [ "${key%/*}" = "$CANON_REAL" ] && skill_in_lock "$name"; then
        continue
      fi
      read_link_target "$path"
      actual="$LINK_TARGET"
      dest="$actual"
      case "$dest" in
        /*) ;;
        *) dest="$target/$dest" ;;
      esac
      legacy_location "$dest" || continue
      dest="$LOCATION"
      known=0
      case "$dest" in
        "$REPO_DIR/vendor/"*) known=1 ;;
      esac
      [ "$dest" != "$REPO_DIR/skills/$name" ] || known=1
      case "$name" in
        my-doc-style|release-tag|find-simplifications)
          [ "$dest" != "$REPO_DIR/$name" ] || known=1
          ;;
      esac
      if [ "$known" = 1 ]; then
        add_owned "$path" "$actual" "$key"
      fi
    done
  done
  # Migrate legacy canonical forwarding links only when the canonical entry
  # itself has provenance.
  for target in "${TARGET_PATHS[@]}"; do
    is_canon_target "$target" && continue
    for path in "$target"/*; do
      [ -L "$path" ] || continue
      location "$path"
      key="$LOCATION"
      contains "$key" "${RECORDED[@]}" "${RELEASED[@]}" "${FOREIGN[@]}" && continue
      read_link_target "$path"
      actual="$LINK_TARGET"
      dest="$actual"
      case "$dest" in
        /*) ;;
        *) dest="$target/$dest" ;;
      esac
      legacy_location "$dest" || continue
      if [ "${LOCATION%/*}" = "$CANON_REAL" ] &&
         [ "${LOCATION##*/}" = "${path##*/}" ] && find_owned "$LOCATION"; then
        add_owned "$path" "$actual" "$key"
      fi
    done
  done
}

# ---------------------------------------------------------------------------
# Keep the existing authored-first, find-based discovery and vendor allowlist
# structure. uninstall does not depend on source directories or allowlists;
# empty discovery still cleans up retired links.
# ---------------------------------------------------------------------------
SKILL_DIRS=()
SKILL_NAMES=()
add_skill() {
  local dir="$1" name="$2" i
  valid_name "$name" || fail "Invalid skill name: $name"
  valid_state_path "$dir" || fail "Invalid skill directory: $dir"
  for i in "${!SKILL_NAMES[@]}"; do
    if [ "${SKILL_NAMES[$i]}" = "$name" ]; then
      printf "WARN: duplicate skill name '%s' (%s vs %s); keeping the first\n" "$name" "${SKILL_DIRS[$i]}" "$dir" >&2
      return
    fi
  done
  SKILL_DIRS+=("$dir")
  SKILL_NAMES+=("$name")
}
discover_files() {
  local root="$1" invalid
  shift
  DISCOVERED=""
  valid_state_path "$root" || fail "Invalid source directory: $root"
  if [ ! -e "$root" ] && [ ! -L "$root" ]; then
    return 0
  fi
  [ -d "$root" ] && [ -r "$root" ] && [ -x "$root" ] || fail "Cannot read source directory: $root"
  # Reject CR/LF names before newline-delimited discovery so one file cannot be
  # misread as multiple skills.
  invalid="$(find -H "$root" \( -name "*"$'\n'"*" -o -name "*"$'\r'"*" \) -print)" || fail "Source discovery failed: $root"
  [ -z "$invalid" ] || fail "Source paths contain newline or CR: $root"
  DISCOVERED="$(find -H "$root" "$@" -name SKILL.md -not -path '*/.git/*' | LC_ALL=C sort)" || fail "Source discovery failed: $root"
}
discover_skills() {
  local file dir sub allowfile line entry source name hit allowlisted
  local ALLOW=()
  [ "$MODE" != uninstall ] || return 0
  discover_files "$REPO_DIR/skills" -mindepth 2 -maxdepth 2
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    dir="$(dirname "$file")"
    add_skill "$dir" "$(basename "$dir")"
  done <<< "$DISCOVERED"
  if [ -e "$REPO_DIR/vendor" ] || [ -L "$REPO_DIR/vendor" ]; then
    [ -d "$REPO_DIR/vendor" ] && [ -r "$REPO_DIR/vendor" ] && [ -x "$REPO_DIR/vendor" ] || fail "Cannot read vendor directory"
  fi
  for sub in "$REPO_DIR"/vendor/*; do
    if [ -L "$sub" ] && [ ! -d "$sub" ]; then
      fail "Invalid vendor directory symlink: $sub"
    fi
    [ -d "$sub" ] || continue
    ALLOW=()
    allowfile="$REPO_DIR/vendor/.allowlists/$(basename "$sub")"
    if [ -e "$allowfile" ] || [ -L "$allowfile" ]; then
      [ -f "$allowfile" ] && [ -r "$allowfile" ] || fail "Cannot read allowlist: $allowfile"
      while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -n "$line" ] || continue
        source="${line%%=*}"
        name="${line#*=}"
        valid_name "$source" && valid_name "$name" || fail "Invalid allowlist entry: $line"
        ALLOW+=("$line")
      done < "$allowfile"
      allowlisted=1
    else
      allowlisted=0
    fi
    discover_files "${sub%/}"
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      dir="$(dirname "$file")"
      name="$(basename "$dir")"
      if [ "$allowlisted" = 1 ]; then
        hit=""
        for entry in "${ALLOW[@]}"; do
          case "$entry" in
            "$name"=*) hit="${entry#*=}" ;;
            "$name") hit="$name" ;;
          esac
        done
        [ -n "$hit" ] || continue
        name="$hit"
      fi
      add_skill "$dir" "$name"
    done <<< "$DISCOVERED"
  done
}

# ---------------------------------------------------------------------------
# Plan: compute every action before touching any filesystem entry.
# ---------------------------------------------------------------------------
PLAN_ACTION=()
PLAN_PATH=()
PLAN_DEST=()
PLAN_OLD=()
PLAN_KEY=()
plan_link() {
  local path="$1" dest="$2" key actual="" action
  validate_link_record "$path" "$dest"
  valid_state_path "$dest" || fail "Invalid planned target: $dest"
  location "$path"
  key="$LOCATION"
  contains "$key" "${PLAN_KEY[@]}" && return 0
  if [ -L "$path" ]; then
    read_link_target "$path"
    actual="$LINK_TARGET"
  fi
  action=CREATE
  if contains "$key" "${FOREIGN[@]}" ||
     { ! find_owned "$key" && { [ -e "$path" ] || [ -L "$path" ]; }; }; then
    action=SKIP
  elif [ -L "$path" ]; then
    if [ "$actual" = "$dest" ]; then
      action=KEEP
    else
      action=REPLACE
    fi
  fi
  PLAN_ACTION+=("$action")
  PLAN_PATH+=("$path")
  PLAN_DEST+=("$dest")
  PLAN_OLD+=("$actual")
  PLAN_KEY+=("$key")
}
canon_exists() {
  local path="$CANON/$1" i
  for i in "${!PLAN_PATH[@]}"; do
    if [ "${PLAN_KEY[$i]}" = "$CANON_REAL/$1" ] && [ "${PLAN_ACTION[$i]}" != SKIP ]; then
      return 0
    fi
  done
  [ -e "$path" ]
}
build_plan() {
  local target i skill name link dest key
  for target in "${TARGET_PATHS[@]}"; do
    if [ "$MODE" != uninstall ]; then
      for i in "${!SKILL_DIRS[@]}"; do
        skill="${SKILL_DIRS[$i]}"
        name="${SKILL_NAMES[$i]}"
        link="$target/$name"
        if is_canon_target "$target"; then
          skill_in_lock "$name" && continue
          dest="$skill"
        elif canon_exists "$name"; then
          dest="$CANON/$name"
        elif skill_in_lock "$name"; then
          continue
        else
          dest="$skill"
        fi
        plan_link "$link" "$dest"
      done
      if ! is_canon_target "$target"; then
        for dest in "$CANON"/*; do
          [ -e "$dest/SKILL.md" ] || continue
          name="${dest##*/}"
          contains "$name" "${SKILL_NAMES[@]}" && continue
          location "$dest"
          find_owned "$LOCATION" && continue
          plan_link "$target/$name" "$dest"
        done
      fi
    fi
  done
  for i in "${!O_PATH[@]}"; do
    key="${O_KEY[$i]}"
    contains "$key" "${PLAN_KEY[@]}" && continue
    PLAN_ACTION+=(REMOVE)
    PLAN_PATH+=("${O_PATH[$i]}")
    PLAN_DEST+=("")
    PLAN_OLD+=("${O_DEST[$i]}")
    PLAN_KEY+=("$key")
  done
}
set_record() {
  local path="$1" dest="$2" i
  validate_link_record "$path" "$dest"
  valid_state_path "$REPO_DIR" || fail "Invalid repository path: $REPO_DIR"
  for i in "${!M_PATH[@]}"; do
    if [ "${M_PATH[$i]}" = "$path" ]; then
      M_DEST[$i]="$dest"
      return
    fi
  done
  M_PATH+=("$path")
  M_REPO+=("$REPO_DIR")
  M_DEST+=("$dest")
}
clear_pending() {
  local i
  for i in "${!P_PATH[@]}"; do
    if [ "${P_PATH[$i]}" = "$1" ]; then
      P_PATH[$i]=""
    fi
  done
}
assert_planned_link() {
  local path="$1" expected="$2" key="$3"
  location "$path"
  [ "$LOCATION" = "$key" ] || fail "Agent directory changed since planning: $path"
  if [ -n "$expected" ]; then
    [ -L "$path" ] || fail "Link changed since planning: $path"
    read_link_target "$path"
    [ "$LINK_TARGET" = "$expected" ] || fail "Link changed since planning: $path"
  elif [ -e "$path" ] || [ -L "$path" ]; then
    fail "Link appeared since planning: $path"
  fi
}
apply_plan() {
  local i j path dest old action key
  # Save recognized legacy ownership and user takeover records first,
  # preserving the state of other checkouts.
  for i in "${!M_PATH[@]}"; do
    if [ "${M_REPO[$i]}" = "$REPO_DIR" ]; then
      clear_pending "${M_PATH[$i]}"
      M_PATH[$i]=""
    fi
  done
  for i in "${!O_PATH[@]}"; do
    set_record "${O_PATH[$i]}" "${O_DEST[$i]}"
  done
  for path in "${PROTECTED[@]}"; do
    find_owned "$path" && continue
    contains "$path" "${RELEASED[@]}" || RELEASED+=("$path")
  done
  save_state
  for i in "${!PLAN_PATH[@]}"; do
    action="${PLAN_ACTION[$i]}"
    [ "$action" != SKIP ] || continue
    path="${PLAN_PATH[$i]}"
    dest="${PLAN_DEST[$i]}"
    old="${PLAN_OLD[$i]}"
    key="${PLAN_KEY[$i]}"
    assert_planned_link "$path" "$old" "$key"
    [ "$action" != KEEP ] || continue
    if [ "$action" = REMOVE ]; then
      rm "$path"
      for j in "${!M_PATH[@]}"; do
        if [ "${M_PATH[$j]}" = "$path" ]; then
          M_PATH[$j]=""
        fi
      done
    else
      mkdir -p "${path%/*}"
      set_record "$path" "$dest"
      if [ -n "$old" ]; then
        P_PATH+=("$path" "$path")
        P_DEST+=("$old" "$dest")
      fi
      # Record old/new targets first; re-check after the slower manifest save to
      # narrow the race window before deletion.
      save_state
      assert_planned_link "$path" "$old" "$key"
      if [ "$action" = REPLACE ]; then
        rm "$path"
      fi
      assert_planned_link "$path" "" "$key"
      # -n avoids following a concurrently appearing directory symlink; callers
      # must still prevent concurrent replacement of normal directories.
      ln -sn "$dest" "$path"
    fi
    clear_pending "$path"
    save_state
  done
}

# The first validation pass is read-only; a corrupt manifest, npx lock, or
# out-of-bounds path must not touch HOME.
prepare_targets
load_state
prepare_ownership
if [ "$MODE" = install ] || [ "$MODE" = update ]; then
  update_repo
fi
discover_skills
if [ "$MODE" != dry-run ]; then
  mkdir -p "$STATE_DIR"
  mkdir "$WRITE_LOCK" 2>/dev/null || fail "Installer lock exists: $WRITE_LOCK (remove it only after confirming no installer is running)"
  LOCK_HELD=1
  # Re-read after acquiring the write lock to avoid stale ownership information
  # from the wait.
  prepare_targets
  load_state
  prepare_ownership
fi
build_plan
printf 'repo:   %s\nmode:   %s\nskills: %d\n\n' "$REPO_DIR" "$MODE" "${#SKILL_DIRS[@]}"
for i in "${!PLAN_PATH[@]}"; do
  printf '%-7s %s' "${PLAN_ACTION[$i]}" "${PLAN_PATH[$i]}"
  if [ -n "${PLAN_DEST[$i]}" ]; then
    printf ' -> %s' "${PLAN_DEST[$i]}"
  fi
  printf '\n'
done
if [ "$MODE" != dry-run ]; then
  apply_plan
fi

if [ "$UPDATE_FAILED" = 1 ]; then
  echo "Update step failed — see the WARN messages above. Fix the problem and rerun," >&2
  echo "or use SKIP_UPDATE=1 to only relink the current content." >&2
  exit 1
fi
