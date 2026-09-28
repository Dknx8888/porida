#!/usr/bin/env bash
# Porida Ubuntu bootstrap, revision 3.
# Run with bash, never source and never sudo the entire script.
set -Eeuo pipefail

# Prefix constants to avoid collisions with NVM's internal variables.
readonly PORIDA_NVM_VERSION="0.40.7"
readonly PORIDA_NODE_MAJOR="24"
readonly PORIDA_BUN_VERSION="1.4.2"
readonly PORIDA_PG_MAJOR="18"

readonly PORIDA_DB_ROLE="portfolio_app"
readonly PORIDA_DB_NAME="portfolio_risk_dashboard"
readonly PORIDA_DB_PORT="5432"
readonly PORIDA_SCHEMA_FILE="${PORIDA_SCHEMA_FILE:-$HOME/Workshop/ProgrammingOutlet/Projects/Personal/PortfolioRiskDashboard/porida/database/schema.sql}"

PORIDA_TEMP_DIR=""

porida_info() { printf '\n==> %s\n' "$*"; }
porida_warn() { printf 'Warning: %s\n' "$*" >&2; }
porida_die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

porida_help() {
  cat <<'HELP'
Usage:
  bash porida-ubuntu-setup.sh
  bash porida-ubuntu-setup.sh --check
  bash porida-ubuntu-setup.sh --db-only
  bash porida-ubuntu-setup.sh --help

No option:
  Install development tools, start PostgreSQL, and initialize Porida's DB.

--check:
  Check tools and PostgreSQL readiness.
  No sudo, installation, profile edits, or database changes.
  Does not verify application credentials or schema.

--db-only:
  Initialize Porida's role/database using existing PostgreSQL tools.
  Does not install tools or change PostgreSQL authentication settings.

Target:
  Ubuntu 22.04/24.04/26.04, amd64 or arm64, Bash.
  Full installation requires sudo, internet, and running systemd.

Versions:
  New NVM installs: 0.40.7; existing NVM retained.
  Node: 24.x; existing installation reused.
  Bun: 1.4.2.
  PostgreSQL: 18, local Ubuntu-managed cluster on port 5432.

Database behavior:
  Create portfolio_app only if missing.
  Prompt for its password only when creating the role.
  Create portfolio_risk_dashboard only if missing.
  Import schema.sql only if no user objects exist.
  Preserve existing passwords, databases, ownership, and data.
  Stop if an existing role cannot log in.

Default schema:
  $HOME/Workshop/ProgrammingOutlet/Projects/Personal/PortfolioRiskDashboard/porida/database/schema.sql

Override schema path:
  PORIDA_SCHEMA_FILE=/absolute/path/schema.sql bash porida-ubuntu-setup.sh --db-only

The script does not clone the repo, install project dependencies,
copy data from another computer, or modify the API's .env.

Full installation may update .bashrc, set NVM's default Node to 24,
add PGDG when necessary, and enable/start PostgreSQL.
Review the script before running.
HELP
}

porida_platform() {
  [[ -r /etc/os-release ]] || porida_die "Cannot identify OS."
  # shellcheck disable=SC1091
  . /etc/os-release

  [[ "${ID:-}" == ubuntu ]] ||
    porida_die "Ubuntu only; found ${ID:-unknown}."

  case "${VERSION_CODENAME:-}" in
    jammy|noble|resolute) ;;
    *) porida_die "Supported releases: jammy, noble, resolute." ;;
  esac

  case "$(uname -m)" in
    x86_64|aarch64) ;;
    *) porida_die "Supported CPUs: x86_64 and aarch64." ;;
  esac
}

porida_paths() {
  export NVM_DIR="${NVM_DIR:-${XDG_CONFIG_HOME:+${XDG_CONFIG_HOME}/nvm}}"
  export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
  export BUN_INSTALL="${BUN_INSTALL:-${HOME}/.bun}"
}

# NVM is not designed for Bash strict mode.
porida_nvm() (
  set +e +u
  set +o pipefail
  . "$NVM_DIR/nvm.sh" --no-use || exit 1
  nvm "$@"
)

porida_require_user() {
  [[ "$EUID" -ne 0 ]] ||
    porida_die "Run as your regular user, without sudo."
  command -v sudo >/dev/null ||
    porida_die "sudo is required."
}

porida_require_cluster() {
  local porida_cluster

  command -v pg_lsclusters >/dev/null ||
    porida_die "PostgreSQL cluster tools are missing."

  [[ -x "/usr/lib/postgresql/$PORIDA_PG_MAJOR/bin/psql" ]] ||
    porida_die "PostgreSQL $PORIDA_PG_MAJOR client is missing."

  porida_cluster=$(
    pg_lsclusters --no-header |
      awk -v version="$PORIDA_PG_MAJOR" -v port="$PORIDA_DB_PORT" \
        '$1 == version && $3 == port && $4 ~ /^online/ {print $2}'
  )

  [[ -n "$porida_cluster" && "$porida_cluster" != *$'\n'* ]] ||
    porida_die "Expected one online PostgreSQL 18 cluster on port 5432. Inspect pg_lsclusters."
}

porida_check() {
  local porida_failures=0 porida_value porida_clusters porida_bun
  porida_info "Checking tools (no changes)"

  if porida_value=$(git --version 2>/dev/null); then
    printf 'OK: %s\n' "$porida_value"
  else
    porida_warn "Git missing."
    porida_failures=$((porida_failures + 1))
  fi

  if [[ -s "$NVM_DIR/nvm.sh" ]] &&
     porida_value=$(porida_nvm --version); then
    printf 'OK: NVM %s (%s)\n' "$porida_value" "$NVM_DIR"
  else
    porida_warn "NVM missing or failed to load."
    porida_failures=$((porida_failures + 1))
  fi

  if porida_value=$(node --version 2>/dev/null) &&
     [[ "$porida_value" == v${PORIDA_NODE_MAJOR}.* ]]; then
    printf 'OK: active Node %s (%s)\n' \
      "$porida_value" "$(command -v node)"
  else
    porida_warn "Expected active Node 24.x; run: nvm use 24"
    porida_failures=$((porida_failures + 1))
  fi

  porida_value=""
  porida_bun=$(command -v bun || true)

  if [[ -z "$porida_bun" && -x "$BUN_INSTALL/bin/bun" ]]; then
    porida_bun="$BUN_INSTALL/bin/bun"
    porida_warn "Bun exists but is absent from PATH; open a new terminal."
  fi

  if [[ -n "$porida_bun" ]] &&
     porida_value=$("$porida_bun" --version 2>/dev/null) &&
     [[ "$porida_value" == "$PORIDA_BUN_VERSION" ]]; then
    printf 'OK: Bun %s (%s)\n' "$porida_value" "$porida_bun"
  else
    porida_warn "Expected Bun $PORIDA_BUN_VERSION; found ${porida_value:-unavailable}."
    porida_failures=$((porida_failures + 1))
  fi

  if porida_value=$(
    "/usr/lib/postgresql/$PORIDA_PG_MAJOR/bin/psql" --version 2>/dev/null
  ); then
    printf 'OK: %s\n' "$porida_value"
  else
    porida_warn "PostgreSQL 18 client missing."
    porida_failures=$((porida_failures + 1))
  fi

  if porida_clusters=$(pg_lsclusters --no-header 2>/dev/null) &&
     awk '$1 == 18 && $3 == 5432 && $4 ~ /^online/ {found=1}
          END {exit !found}' <<<"$porida_clusters" &&
     "/usr/lib/postgresql/$PORIDA_PG_MAJOR/bin/pg_isready" \
       -h localhost -p "$PORIDA_DB_PORT" -t 3 >/dev/null 2>&1; then
    printf 'OK: local PostgreSQL 18 online on port 5432.\n'
  else
    porida_warn "No ready PostgreSQL 18 cluster on port 5432."
    printf '%s\n' "${porida_clusters:-No cluster listing available.}" >&2
    porida_failures=$((porida_failures + 1))
  fi

  ((porida_failures == 0)) ||
    porida_die "$porida_failures check(s) failed."

  printf 'Tool checks passed. Application credentials/schema not tested.\n'
}

# Use a specific local socket and port, not inherited PGHOST/PGPORT.
porida_admin() {
  sudo -u postgres \
    "/usr/lib/postgresql/$PORIDA_PG_MAJOR/bin/psql" \
    -X \
    --host=/var/run/postgresql \
    --port="$PORIDA_DB_PORT" \
    --username=postgres \
    --dbname=postgres \
    --set=ON_ERROR_STOP=on \
    "$@"
}

porida_database() {
  local porida_role_exists porida_role_login
  local porida_db_exists porida_has_objects

  porida_require_user
  porida_require_cluster

  # Check before creating anything.
  [[ -f "$PORIDA_SCHEMA_FILE" && -r "$PORIDA_SCHEMA_FILE" &&
     -s "$PORIDA_SCHEMA_FILE" ]] ||
    porida_die "Schema file missing, unreadable, or empty: $PORIDA_SCHEMA_FILE"

  sudo -v
  porida_info "Initializing Porida database"

  porida_role_exists=$(
    porida_admin -Atc \
      "SELECT 1 FROM pg_roles WHERE rolname = '$PORIDA_DB_ROLE';"
  )

  if [[ "$porida_role_exists" != 1 ]]; then
    porida_admin -c "CREATE ROLE $PORIDA_DB_ROLE LOGIN;"

    printf '\nSet the password to match your API .env.\n'
    printf 'The password will not be displayed or placed in shell history.\n'

    porida_admin -c "\\password $PORIDA_DB_ROLE"
  else
    printf 'Role %s already exists; password preserved.\n' "$PORIDA_DB_ROLE"
  fi

  porida_role_login=$(
    porida_admin -Atc \
      "SELECT rolcanlogin FROM pg_roles WHERE rolname = '$PORIDA_DB_ROLE';"
  )

  [[ "$porida_role_login" == t ]] ||
    porida_die "Existing role $PORIDA_DB_ROLE cannot log in; left unchanged."

  porida_db_exists=$(
    porida_admin -Atc \
      "SELECT 1 FROM pg_database WHERE datname = '$PORIDA_DB_NAME';"
  )

  if [[ "$porida_db_exists" != 1 ]]; then
    porida_admin -c \
      "CREATE DATABASE $PORIDA_DB_NAME OWNER $PORIDA_DB_ROLE;"
  else
    printf 'Database %s already exists; ownership preserved.\n' "$PORIDA_DB_NAME"
  fi

  # Conservatively skip import if there are user relations, routines,
  # types, custom schemas, or extensions other than default plpgsql.
  porida_has_objects=$(
    porida_admin --dbname="$PORIDA_DB_NAME" -Atc "
      SELECT (
        EXISTS (
          SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname NOT LIKE 'pg_%'
            AND n.nspname <> 'information_schema'
        )
        OR EXISTS (
          SELECT 1
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname NOT LIKE 'pg_%'
            AND n.nspname <> 'information_schema'
        )
        OR EXISTS (
          SELECT 1
          FROM pg_type t
          JOIN pg_namespace n ON n.oid = t.typnamespace
          WHERE n.nspname NOT LIKE 'pg_%'
            AND n.nspname <> 'information_schema'
        )
        OR EXISTS (
          SELECT 1 FROM pg_namespace
          WHERE nspname NOT LIKE 'pg_%'
            AND nspname NOT IN ('public', 'information_schema')
        )
        OR EXISTS (
          SELECT 1 FROM pg_extension WHERE extname <> 'plpgsql'
        )
      );"
  )

  if [[ "$porida_has_objects" == t ]]; then
    porida_info "Existing user objects found; schema import skipped"
    printf 'Existing schema/data preserved. Schema completeness is not checked.\n'
  elif [[ "$porida_has_objects" == f ]]; then
    porida_info "Importing schema into the empty database"
    printf 'Schema: %s\n' "$PORIDA_SCHEMA_FILE"
    printf 'Enter the portfolio_app password when prompted.\n'

    # Authenticate as the application role so it owns created objects.
    # -X ignores local psql startup files.
    # ON_ERROR_STOP stops at the first SQL error.
    # Single transaction rolls back a failed transactional schema import.
    if ! "/usr/lib/postgresql/$PORIDA_PG_MAJOR/bin/psql" \
      -X \
      --host=localhost \
      --port="$PORIDA_DB_PORT" \
      --username="$PORIDA_DB_ROLE" \
      --dbname="$PORIDA_DB_NAME" \
      --password \
      --set=ON_ERROR_STOP=on \
      --single-transaction \
      --file="$PORIDA_SCHEMA_FILE"; then
      porida_die "Schema import failed. Role/database remain. Review the error before retrying --db-only."
    fi

    printf 'Schema import completed.\n'
  else
    porida_die "Could not determine whether the database is empty."
  fi

  printf '\nEnsure the API .env uses:\n'
  printf '  Host: localhost\n  Port: %s\n  User: %s\n  Database: %s\n' \
    "$PORIDA_DB_PORT" "$PORIDA_DB_ROLE" "$PORIDA_DB_NAME"
  printf 'Use the password assigned to this local PostgreSQL role.\n'
}

porida_download() {
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --fail --silent --show-error --location \
    --connect-timeout 20 --max-time 180 --retry 2 \
    "$1" --output "$2"
}

porida_cleanup() {
  if [[ -n "$PORIDA_TEMP_DIR" && -d "$PORIDA_TEMP_DIR" ]]; then
    rm -f -- \
      "$PORIDA_TEMP_DIR/nvm-install.sh" \
      "$PORIDA_TEMP_DIR/bun-install.sh"
    rmdir -- "$PORIDA_TEMP_DIR" || true
  fi
}

porida_install() {
  local porida_answer porida_candidate porida_node_path porida_cluster

  porida_require_user
  [[ -d /run/systemd/system ]] ||
    porida_die "Installation requires running systemd, including on WSL."

  [[ -r "$PORIDA_SCHEMA_FILE" && -s "$PORIDA_SCHEMA_FILE" ]] ||
    porida_die "Sync the schema file first: $PORIDA_SCHEMA_FILE"

  porida_help
  read -r -p "Proceed with installation and DB initialization? [y/N] " \
    porida_answer || porida_die "Confirmation required."

  [[ "$porida_answer" == y || "$porida_answer" == Y ]] ||
    porida_die "Cancelled; no changes made."

  sudo -v
  PORIDA_TEMP_DIR=$(mktemp -d -t porida-setup.XXXXXXXX)
  trap porida_cleanup EXIT
  trap 'printf "Setup failed at line %s. Earlier steps may have completed.\n" "$LINENO" >&2' ERR

  sudo apt-get update
  sudo apt-get install -y \
    build-essential ca-certificates curl git unzip vim postgresql-common

  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    porida_info "Installing NVM $PORIDA_NVM_VERSION"
    porida_download \
      "https://raw.githubusercontent.com/nvm-sh/nvm/v$PORIDA_NVM_VERSION/install.sh" \
      "$PORIDA_TEMP_DIR/nvm-install.sh"
    PROFILE="$HOME/.bashrc" bash "$PORIDA_TEMP_DIR/nvm-install.sh"
  fi

  [[ -s "$NVM_DIR/nvm.sh" ]] ||
    porida_die "NVM installer did not produce nvm.sh."

  porida_nvm --version

  if ! porida_node_path=$(porida_nvm which "$PORIDA_NODE_MAJOR"); then
    porida_nvm install "$PORIDA_NODE_MAJOR"
    porida_node_path=$(porida_nvm which "$PORIDA_NODE_MAJOR")
  fi

  [[ -x "$porida_node_path" ]] ||
    porida_die "NVM returned no usable Node executable."

  porida_nvm alias default "$PORIDA_NODE_MAJOR"
  export PATH="$(dirname "$porida_node_path"):$PATH"

  if [[ ! -x "$BUN_INSTALL/bin/bun" ]] ||
     [[ "$("$BUN_INSTALL/bin/bun" --version)" != "$PORIDA_BUN_VERSION" ]]; then
    porida_info "Installing Bun $PORIDA_BUN_VERSION"
    porida_download "https://bun.com/install" "$PORIDA_TEMP_DIR/bun-install.sh"
    SHELL=/bin/bash bash "$PORIDA_TEMP_DIR/bun-install.sh" \
      "bun-v$PORIDA_BUN_VERSION"
  fi

  export PATH="$BUN_INSTALL/bin:$PATH"
  hash -r

  porida_candidate=$(
    apt-cache policy postgresql-18 | awk '/Candidate:/ {print $2}'
  )

  if [[ -z "$porida_candidate" || "$porida_candidate" == "(none)" ]]; then
    if grep -rqs 'apt.postgresql.org' \
      /etc/apt/sources.list /etc/apt/sources.list.d; then
      porida_die "Existing PGDG configuration offers no PostgreSQL 18. Review apt sources."
    fi

    porida_info "Adding official PGDG repository"
    sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
    sudo apt-get update
  fi

  sudo apt-get install -y postgresql-18 postgresql-client-18
  sudo systemctl enable --now postgresql

  porida_cluster=$(
    pg_lsclusters --no-header |
      awk '$1 == 18 && $3 == 5432 {print $2}'
  )

  [[ -n "$porida_cluster" && "$porida_cluster" != *$'\n'* ]] ||
    porida_die "No unique PostgreSQL 18 cluster on 5432. Inspect pg_lsclusters."

  sudo systemctl start "postgresql@18-$porida_cluster"

  porida_check
  porida_database

  printf '\nOpen a new terminal, enter Porida, then run:\n'
  printf '  nvm use 24\n  bun install --frozen-lockfile\n'
  printf 'Configure the API .env with the local database credentials.\n'
}

porida_main() {
  (($# <= 1)) || porida_die "Expected at most one option."

  case "${1:-}" in
    --help|-h) porida_help; return ;;
    ""|--check|--db-only) ;;
    *) porida_die "Unknown option: $1. Use --help." ;;
  esac

  porida_platform
  porida_paths

  case "${1:-}" in
    --check) porida_check ;;
    --db-only) porida_database ;;
    "") porida_install ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  porida_main "$@"
fi
