#!/usr/bin/env bash
# Porida Ultramarine bootstrap, revision 2.
# Native Fedora PostgreSQL packaging; no Ubuntu/PGDG repositories.
# References:
# https://www.postgresql.org/download/linux/redhat/
# https://packages.fedoraproject.org/pkgs/postgresql18/postgresql-server/fedora-44.html
# https://github.com/devexp-db/postgresql-setup
# https://www.postgresql.org/docs/18/auth-pg-hba-conf.html
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
readonly PORIDA_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PORIDA_SCHEMA_FILE="${PORIDA_SCHEMA_FILE:-$PORIDA_SCRIPT_DIR/database/schema.sql}"
readonly PORIDA_PG_DATA="/var/lib/pgsql/data"
readonly PORIDA_PG_SERVICE="postgresql.service"
readonly PORIDA_PSQL="/usr/bin/psql"
readonly PORIDA_PG_ISREADY="/usr/bin/pg_isready"
readonly PORIDA_PG_SOCKET="/run/postgresql"

PORIDA_TEMP_DIR=""
PORIDA_PROFILE_FILE=""

porida_info() { printf '\n==> %s\n' "$*"; }
porida_warn() { printf 'Warning: %s\n' "$*" >&2; }
porida_die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

porida_help() {
  cat <<'HELP'
Usage (run as your regular user, never sudo the entire script):
  bash porida-ultramarine-setup.sh
  bash porida-ultramarine-setup.sh --check
  bash porida-ultramarine-setup.sh --db-only
  bash porida-ultramarine-setup.sh --help

No option:
  Install development tools, initialize/start native PostgreSQL,
  configure Porida-only localhost password authentication, and create
  Porida's role/database and schema when missing.
  Shows this summary and asks for confirmation before making changes.

--check:
  Check Git, NVM, active Node/Bun, native PostgreSQL client/service,
  and localhost readiness. No sudo, installs, profile or DB changes.
  Does not verify server version, application credentials, or schema.

--db-only:
  Initialize Porida's role/database using a running native PostgreSQL 18.
  Does not install tools, start services, edit profiles, or change auth.
  TCP password authentication must already allow portfolio_app.

Target:
  Ultramarine 43/44, x86_64 or aarch64, Bash script.
  Full setup requires sudo, internet, running systemd, and Bash or Zsh
  as your login shell. Zsh's ZDOTDIR is supported when exported.

Versions:
  New NVM installs: 0.40.7; existing NVM retained.
  Node: 24.x; existing NVM installation reused.
  Bun: 1.4.2, matching package.json.
  PostgreSQL: 18 from native repositories (postgresql/postgresql-server).

Database behavior:
  Use postgresql.service, /var/lib/pgsql/data, localhost:5432.
  Refuse older clusters or a nonempty uninitialized data directory.
  Do not upgrade databases or replace custom service/data paths.
  Create portfolio_app only if missing, prompting for its password.
  Preserve existing passwords, database ownership, schema, and data.
  Full setup requires the role to have a SCRAM password already;
  an existing MD5/missing password requires a deliberate manual reset.
  Back up pg_hba.conf before adding Porida's IPv4/IPv6 loopback rules.
  Preserve other auth rules, file permissions, and SELinux labels.
  Import schema.sql as portfolio_app only if no user objects exist.
  The dump contains schema only; existing portfolio data is not restored.

Default schema:
  database/schema.sql beside this script (independent of working directory).

Override schema path:
  PORIDA_SCHEMA_FILE=/absolute/path/schema.sql bash porida-ultramarine-setup.sh --db-only

Full setup may update your .bashrc or .zshrc, set NVM's default Node
to 24, install packages, and enable/start PostgreSQL.
It does not clone the repo, install project dependencies, read/write
the API's .env, open firewall ports, or change SELinux settings.
HELP
}

porida_platform() {
  [[ -r /etc/os-release ]] || porida_die "Cannot identify OS."
  # shellcheck disable=SC1091
  . /etc/os-release

  [[ "${ID:-}" == ultramarine ]] ||
    porida_die "Ultramarine only; found ${ID:-unknown}."

  case "${VERSION_ID:-}" in
    43|44) ;;
    *) porida_die "Supported Ultramarine releases: 43 and 44 (native PostgreSQL 18)." ;;
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

porida_profile_path() {
  local porida_shell="${SHELL:-/bin/bash}"
  case "${porida_shell##*/}" in
    bash) PORIDA_PROFILE_FILE="$HOME/.bashrc" ;;
    zsh) PORIDA_PROFILE_FILE="${ZDOTDIR:-$HOME}/.zshrc" ;;
    *) porida_die "Full setup supports Bash/Zsh login shells; run from one with SHELL set accordingly." ;;
  esac
}

porida_configure_profile() {
  local porida_profile_temp="$PORIDA_TEMP_DIR/profile"
  local porida_profile_body="$PORIDA_TEMP_DIR/profile-body"

  mkdir -p -- "$(dirname -- "$PORIDA_PROFILE_FILE")"
  [[ -e "$PORIDA_PROFILE_FILE" ]] || touch -- "$PORIDA_PROFILE_FILE"
  [[ -f "$PORIDA_PROFILE_FILE" && -w "$PORIDA_PROFILE_FILE" ]] ||
    porida_die "Cannot update shell profile: $PORIDA_PROFILE_FILE"

  # Replace only our marked block, then append the current paths.
  porida_strip_block "$PORIDA_PROFILE_FILE" \
    '# BEGIN Porida development tools' '# END Porida development tools' \
    > "$porida_profile_body" || porida_die "Malformed Porida block in shell profile."
  cat "$porida_profile_body" > "$porida_profile_temp"
  {
    printf '# BEGIN Porida development tools\n'
    # Bash's %q quotes path values safely for Bash and Zsh.
    printf 'export NVM_DIR=%q\n' "$NVM_DIR"
    printf '[ ! -s "$NVM_DIR/nvm.sh" ] || . "$NVM_DIR/nvm.sh"\n'
    printf 'export BUN_INSTALL=%q\n' "$BUN_INSTALL"
    printf 'case ":$PATH:" in *":$BUN_INSTALL/bin:"*) ;; *) export PATH="$BUN_INSTALL/bin:$PATH" ;; esac\n'
    printf '# END Porida development tools\n'
  } >> "$porida_profile_temp"

  if ! cmp -s -- "$PORIDA_PROFILE_FILE" "$porida_profile_temp"; then
    cp -L --preserve=all --backup=numbered -- "$PORIDA_PROFILE_FILE" "$PORIDA_PROFILE_FILE.porida-backup"
    # Keep the existing inode/permissions, including when .zshrc is a symlink.
    cat "$porida_profile_temp" > "$PORIDA_PROFILE_FILE"
    printf 'Updated %s (backup: %s.porida-backup).\n' \
      "$PORIDA_PROFILE_FILE" "$PORIDA_PROFILE_FILE"
  fi
}

# Remove a single well-formed managed block, preserving all other lines.
# An EOF without a newline is normalized so appended shell code is not joined.
porida_strip_block() {
  awk -v porida_begin="$2" -v porida_end="$3" '
    $0 == porida_begin {
      if (porida_inside || porida_seen++) {porida_bad=1; exit 1}
      porida_inside=1; next
    }
    $0 == porida_end {
      if (!porida_inside) {porida_bad=1; exit 1}
      porida_inside=0; next
    }
    !porida_inside {print}
    END {if (porida_inside || porida_bad) exit 1}
  ' "$1"
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

porida_require_client() {
  local porida_version
  [[ -x "$PORIDA_PSQL" && -x "$PORIDA_PG_ISREADY" ]] ||
    porida_die "Native PostgreSQL client tools missing; run full setup first."
  porida_version=$("$PORIDA_PSQL" --version)
  [[ "$porida_version" == "psql (PostgreSQL) $PORIDA_PG_MAJOR."* ]] ||
    porida_die "Expected PostgreSQL $PORIDA_PG_MAJOR client; found $porida_version."
}

porida_require_cluster() {
  local porida_server_version porida_data porida_port porida_hba
  porida_require_client
  systemctl is-active --quiet "$PORIDA_PG_SERVICE" ||
    porida_die "Native $PORIDA_PG_SERVICE is not running."

  porida_server_version=$(porida_admin -Atc 'SHOW server_version_num;')
  [[ "$porida_server_version" =~ ^[0-9]+$ ]] &&
    ((porida_server_version / 10000 == PORIDA_PG_MAJOR)) ||
    porida_die "Expected running PostgreSQL 18; found version number $porida_server_version."

  porida_data=$(porida_admin -Atc 'SHOW data_directory;')
  porida_port=$(porida_admin -Atc 'SHOW port;')
  porida_hba=$(porida_admin -Atc 'SHOW hba_file;')
  [[ "$porida_data" == "$PORIDA_PG_DATA" &&
     "$porida_port" == "$PORIDA_DB_PORT" &&
     "$porida_hba" == "$PORIDA_PG_DATA/pg_hba.conf" ]] ||
    porida_die "Expected native data/auth files in $PORIDA_PG_DATA on port $PORIDA_DB_PORT; custom setup left unchanged."

  env -u PGHOSTADDR -u PGSERVICE -u PGSERVICEFILE "$PORIDA_PG_ISREADY" -h localhost -p "$PORIDA_DB_PORT" -t 3 >/dev/null ||
    porida_die "PostgreSQL is not ready on localhost:$PORIDA_DB_PORT."
}

porida_data_preflight() {
  local porida_existing_version porida_first_entry porida_package_version
  if rpm -q postgresql-server >/dev/null 2>&1; then
    porida_package_version=$(rpm -q --queryformat '%{VERSION}' postgresql-server)
    [[ "$porida_package_version" == "$PORIDA_PG_MAJOR."* ]] ||
      porida_die "Installed PostgreSQL server is $porida_package_version; migrate it separately before setup."
  fi

  if sudo test -e "$PORIDA_PG_DATA/PG_VERSION"; then
    porida_existing_version=$(sudo cat "$PORIDA_PG_DATA/PG_VERSION")
    [[ "$porida_existing_version" == "$PORIDA_PG_MAJOR" ]] ||
      porida_die "Existing cluster is PostgreSQL $porida_existing_version; it will not be upgraded or overwritten."
  elif sudo test -d "$PORIDA_PG_DATA"; then
    porida_first_entry=$(sudo find "$PORIDA_PG_DATA" -mindepth 1 -maxdepth 1 -print -quit)
    [[ -z "$porida_first_entry" ]] ||
      porida_die "Nonempty data directory has no PG_VERSION; inspect $PORIDA_PG_DATA before initializing."
  elif sudo test -e "$PORIDA_PG_DATA"; then
    porida_die "Data path is not a directory: $PORIDA_PG_DATA"
  fi
}

porida_service_preflight() {
  local porida_load_state porida_fragment porida_dropins porida_envfiles
  local porida_dropin
  local porida_environment porida_token porida_unit_data="" porida_unit_port=""
  local porida_reload_needed porida_verification
  local -a porida_environment_tokens porida_dropin_paths

  porida_load_state=$(systemctl show --property=LoadState --value "$PORIDA_PG_SERVICE")
  [[ "$porida_load_state" != not-found ]] || return 0
  [[ "$porida_load_state" == loaded ]] ||
    porida_die "Native PostgreSQL service is $porida_load_state; inspect its configuration before setup."

  porida_fragment=$(systemctl show --property=FragmentPath --value "$PORIDA_PG_SERVICE")
  porida_dropins=$(systemctl show --property=DropInPaths --value "$PORIDA_PG_SERVICE")
  porida_envfiles=$(systemctl show --property=EnvironmentFiles --value "$PORIDA_PG_SERVICE")
  [[ "$porida_fragment" == /usr/lib/systemd/system/postgresql.service &&
     -z "$porida_envfiles" ]] ||
    porida_die "Custom PostgreSQL service or overrides found; configure that installation separately."

  # Fedora's systemd package applies this timeout policy to every service.
  # It changes stop behavior only; it does not change PostgreSQL's data or
  # startup command. Accept its expected content, keeping custom overrides out.
  read -r -a porida_dropin_paths <<< "$porida_dropins"
  for porida_dropin in "${porida_dropin_paths[@]}"; do
    [[ "$porida_dropin" == /usr/lib/systemd/system/service.d/10-timeout-abort.conf ]] &&
      awk '
        /^[[:space:]]*([#;]|$)/ {next}
        /^[[:space:]]*\[Service\][[:space:]]*$/ {next}
        /^[[:space:]]*TimeoutStopFailureMode[[:space:]]*=[[:space:]]*abort[[:space:]]*$/ {known=1; next}
        {bad=1}
        END {exit (bad || !known)}
      ' "$porida_dropin" ||
      porida_die "Custom PostgreSQL service override found: $porida_dropin; configure that installation separately."
  done

  porida_reload_needed=$(systemctl show --property=NeedDaemonReload --value "$PORIDA_PG_SERVICE")
  [[ "$porida_reload_needed" == no ]] ||
    porida_die "PostgreSQL unit files changed; inspect/reload them before running setup."

  # Detect edits to the packaged unit itself, in addition to normal overrides.
  rpm -q postgresql-server >/dev/null 2>&1 ||
    porida_die "Existing service is not provided by native postgresql-server."
  porida_verification=$(rpm -V postgresql-server 2>/dev/null || true)
  if awk -v porida_unit="$porida_fragment" \
    '$NF == porida_unit {found=1} END {exit !found}' <<< "$porida_verification"; then
    porida_die "Packaged PostgreSQL unit was modified; custom installation left unchanged."
  fi

  porida_environment=$(systemctl show --property=Environment --value "$PORIDA_PG_SERVICE")
  read -r -a porida_environment_tokens <<< "$porida_environment"
  for porida_token in "${porida_environment_tokens[@]}"; do
    case "$porida_token" in
      PGDATA=*) porida_unit_data="${porida_token#PGDATA=}" ;;
      PGPORT=*) porida_unit_port="${porida_token#PGPORT=}" ;;
    esac
  done
  [[ "${porida_unit_data%/}" == "$PORIDA_PG_DATA" &&
     ( -z "$porida_unit_port" || "$porida_unit_port" == "$PORIDA_DB_PORT" ) ]] ||
    porida_die "Service must use $PORIDA_PG_DATA on port $PORIDA_DB_PORT; custom installation left unchanged."
}

porida_configure_auth() {
  local porida_hba="$PORIDA_PG_DATA/pg_hba.conf"
  local porida_body="$PORIDA_TEMP_DIR/hba-body"
  local porida_proposed="$PORIDA_TEMP_DIR/pg_hba.conf"
  local porida_backup porida_errors porida_reload
  local porida_role_scram

  # Never display password hashes or silently change an existing password.
  porida_role_scram=$(porida_admin -Atc \
    "SELECT COALESCE(rolpassword LIKE 'SCRAM-SHA-256\$%', false) FROM pg_authid WHERE rolname = '$PORIDA_DB_ROLE';")
  [[ "$porida_role_scram" == t ]] ||
    porida_die "Role $PORIDA_DB_ROLE has no SCRAM password. Set one deliberately with psql's \\password under password_encryption=scram-sha-256, then rerun. Existing password/auth left unchanged."

  sudo cat -- "$porida_hba" > "$PORIDA_TEMP_DIR/hba-original"
  porida_strip_block "$PORIDA_TEMP_DIR/hba-original" \
    '# BEGIN Porida loopback authentication' '# END Porida loopback authentication' \
    > "$porida_body" || porida_die "Malformed Porida block in pg_hba.conf; auth left unchanged."
  {
    printf '# BEGIN Porida loopback authentication\n'
    printf 'host %s %s 127.0.0.1/32 scram-sha-256\n' "$PORIDA_DB_NAME" "$PORIDA_DB_ROLE"
    printf 'host %s %s ::1/128 scram-sha-256\n' "$PORIDA_DB_NAME" "$PORIDA_DB_ROLE"
    printf '# END Porida loopback authentication\n'
    cat "$porida_body"
  } > "$porida_proposed"

  if sudo cmp -s -- "$porida_hba" "$porida_proposed"; then
    porida_info "Porida loopback authentication already configured"
    return
  fi

  porida_backup=$(sudo mktemp "$porida_hba.porida-backup.XXXXXXXX")
  sudo cp --preserve=all -- "$porida_hba" "$porida_backup"
  # Write through the existing inode to preserve owner/mode/SELinux context.
  if ! sudo tee "$porida_hba" < "$porida_proposed" >/dev/null; then
    sudo cp --preserve=all -- "$porida_backup" "$porida_hba"
    porida_die "Could not write pg_hba.conf; backup restored from $porida_backup."
  fi

  if ! porida_errors=$(porida_admin -Atc 'SELECT count(*) FROM pg_hba_file_rules WHERE error IS NOT NULL;') ||
     [[ "$porida_errors" != 0 ]]; then
    sudo cp --preserve=all -- "$porida_backup" "$porida_hba"
    porida_die "Invalid authentication configuration; backup restored from $porida_backup."
  fi
  if ! porida_reload=$(porida_admin -Atc 'SELECT pg_reload_conf();') ||
     [[ "$porida_reload" != t ]]; then
    sudo cp --preserve=all -- "$porida_backup" "$porida_hba"
    porida_die "Could not reload authentication; backup restored from $porida_backup."
  fi
  printf 'Configured Porida-only localhost SCRAM authentication. Backup: %s\n' "$porida_backup"
}

porida_check() {
  local porida_failures=0 porida_value porida_bun
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

  if [[ -x "$PORIDA_PSQL" ]] &&
     porida_value=$("$PORIDA_PSQL" --version 2>/dev/null) &&
     [[ "$porida_value" == "psql (PostgreSQL) $PORIDA_PG_MAJOR."* ]]; then
    printf 'OK: %s\n' "$porida_value"
  else
    porida_warn "Expected native PostgreSQL 18 client at $PORIDA_PSQL."
    porida_failures=$((porida_failures + 1))
  fi

  if systemctl is-active --quiet "$PORIDA_PG_SERVICE" 2>/dev/null &&
     env -u PGHOSTADDR -u PGSERVICE -u PGSERVICEFILE "$PORIDA_PG_ISREADY" -h localhost -p "$PORIDA_DB_PORT" -t 3 >/dev/null 2>&1; then
    printf 'OK: %s active; localhost:%s accepts connections.\n' "$PORIDA_PG_SERVICE" "$PORIDA_DB_PORT"
  else
    porida_warn "Native PostgreSQL service is inactive or localhost:$PORIDA_DB_PORT is not ready."
    porida_failures=$((porida_failures + 1))
  fi

  ((porida_failures == 0)) ||
    porida_die "$porida_failures check(s) failed."

  printf 'Tool checks passed. Server version/application credentials/schema not tested.\n'
}

# Use a specific local socket and port, not inherited PGHOST/PGPORT.
porida_admin() {
  sudo -u postgres env -u PGHOSTADDR -u PGOPTIONS -u PGSERVICE -u PGSERVICEFILE -u PGPASSWORD \
    "$PORIDA_PSQL" \
    -X \
    --host="$PORIDA_PG_SOCKET" \
    --port="$PORIDA_DB_PORT" \
    --username=postgres \
    --dbname=postgres \
    --no-password \
    --set=ON_ERROR_STOP=on \
    "$@"
}

porida_database() {
  local porida_role_exists porida_role_login
  local porida_db_exists porida_has_objects

  porida_require_user

  # Check before creating anything.
  [[ -f "$PORIDA_SCHEMA_FILE" && -r "$PORIDA_SCHEMA_FILE" &&
     -s "$PORIDA_SCHEMA_FILE" ]] ||
    porida_die "Schema file missing, unreadable, or empty: $PORIDA_SCHEMA_FILE"

  sudo -v
  porida_require_cluster
  porida_info "Initializing Porida database"

  porida_role_exists=$(
    porida_admin -Atc \
      "SELECT 1 FROM pg_roles WHERE rolname = '$PORIDA_DB_ROLE';"
  )

  if [[ "$porida_role_exists" != 1 ]]; then
    printf '\nSet the password to match your API .env.\n'
    printf 'The password will not be displayed or placed in shell history.\n'

    # Create the role and its password together; a failed prompt rolls back.
    porida_admin \
      -c "BEGIN; SET LOCAL password_encryption = 'scram-sha-256';" \
      -c "CREATE ROLE $PORIDA_DB_ROLE LOGIN;" \
      -c "\\password $PORIDA_DB_ROLE" \
      -c "COMMIT;"
  else
    printf 'Role %s already exists; password preserved.\n' "$PORIDA_DB_ROLE"
  fi

  porida_role_login=$(
    porida_admin -Atc \
      "SELECT rolcanlogin FROM pg_roles WHERE rolname = '$PORIDA_DB_ROLE';"
  )

  [[ "$porida_role_login" == t ]] ||
    porida_die "Existing role $PORIDA_DB_ROLE cannot log in; left unchanged."

  if [[ "${1:-}" == --configure-auth ]]; then
    porida_configure_auth
  fi

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
          WHERE n.nspname !~ '^pg_'
            AND n.nspname <> 'information_schema'
        )
        OR EXISTS (
          SELECT 1
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname !~ '^pg_'
            AND n.nspname <> 'information_schema'
        )
        OR EXISTS (
          SELECT 1
          FROM pg_type t
          JOIN pg_namespace n ON n.oid = t.typnamespace
          WHERE n.nspname !~ '^pg_'
            AND n.nspname <> 'information_schema'
        )
        OR EXISTS (
          SELECT 1 FROM pg_namespace
          WHERE nspname !~ '^pg_'
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
    if ! env -u PGHOSTADDR -u PGOPTIONS -u PGSERVICE -u PGSERVICEFILE -u PGPASSWORD \
      "$PORIDA_PSQL" \
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
      "$PORIDA_TEMP_DIR/bun-install.sh" \
      "$PORIDA_TEMP_DIR/profile" \
      "$PORIDA_TEMP_DIR/profile-body" \
      "$PORIDA_TEMP_DIR/hba-original" \
      "$PORIDA_TEMP_DIR/hba-body" \
      "$PORIDA_TEMP_DIR/pg_hba.conf"
    rmdir -- "$PORIDA_TEMP_DIR" || true
  fi
}

porida_install() {
  local porida_answer porida_node_path

  porida_require_user
  command -v dnf >/dev/null || porida_die "DNF is required."
  [[ -d /run/systemd/system ]] ||
    porida_die "Installation requires running systemd."

  [[ -f "$PORIDA_SCHEMA_FILE" && -r "$PORIDA_SCHEMA_FILE" && -s "$PORIDA_SCHEMA_FILE" ]] ||
    porida_die "Sync the schema file first: $PORIDA_SCHEMA_FILE"
  porida_profile_path

  porida_help
  printf '\nShell profile: %s\nSchema: %s\n' "$PORIDA_PROFILE_FILE" "$PORIDA_SCHEMA_FILE"
  read -r -p "Proceed with installation and DB initialization? [y/N] " \
    porida_answer || porida_die "Confirmation required."
  [[ "$porida_answer" == y || "$porida_answer" == Y ]] ||
    porida_die "Cancelled; no changes made."

  sudo -v
  # Reject existing incompatible data before any package or profile changes.
  porida_service_preflight
  porida_data_preflight
  umask 077
  PORIDA_TEMP_DIR=$(mktemp -d -t porida-setup.XXXXXXXX)
  trap porida_cleanup EXIT
  trap 'printf "Setup failed at line %s. Earlier steps may have completed.\n" "$LINENO" >&2' ERR

  porida_info "Installing native development tools and PostgreSQL"
  sudo dnf install --refresh -y \
    gcc gcc-c++ make openssl-devel ca-certificates curl git unzip vim-enhanced \
    "postgresql-${PORIDA_PG_MAJOR}.*" "postgresql-server-${PORIDA_PG_MAJOR}.*"
  porida_require_client
  porida_service_preflight
  porida_data_preflight

  if ! sudo test -e "$PORIDA_PG_DATA/PG_VERSION"; then
    porida_info "Initializing native PostgreSQL 18 data directory"
    sudo env PGSETUP_INITDB_OPTIONS='--auth-local=peer --auth-host=scram-sha-256 --encoding=UTF8' \
      /usr/bin/postgresql-setup --initdb --unit postgresql --datadir "$PORIDA_PG_DATA" --port "$PORIDA_DB_PORT"
  fi
  sudo systemctl enable --now "$PORIDA_PG_SERVICE"
  porida_require_cluster

  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    porida_info "Installing NVM $PORIDA_NVM_VERSION"
    porida_download \
      "https://raw.githubusercontent.com/nvm-sh/nvm/v$PORIDA_NVM_VERSION/install.sh" \
      "$PORIDA_TEMP_DIR/nvm-install.sh"
    # Porida manages one marked profile block for existing and new installs.
    PROFILE=/dev/null bash "$PORIDA_TEMP_DIR/nvm-install.sh"
  fi
  [[ -s "$NVM_DIR/nvm.sh" ]] || porida_die "NVM installer did not produce nvm.sh."
  porida_nvm --version

  if ! porida_node_path=$(porida_nvm which "$PORIDA_NODE_MAJOR"); then
    porida_nvm install "$PORIDA_NODE_MAJOR"
    porida_node_path=$(porida_nvm which "$PORIDA_NODE_MAJOR")
  fi
  [[ -x "$porida_node_path" ]] || porida_die "NVM returned no usable Node executable."
  porida_nvm alias default "$PORIDA_NODE_MAJOR"
  export PATH="$(dirname "$porida_node_path"):$PATH"

  if [[ ! -x "$BUN_INSTALL/bin/bun" ]] ||
     [[ "$("$BUN_INSTALL/bin/bun" --version)" != "$PORIDA_BUN_VERSION" ]]; then
    porida_info "Installing Bun $PORIDA_BUN_VERSION"
    porida_download "https://bun.com/install" "$PORIDA_TEMP_DIR/bun-install.sh"
    # The installer's generic-shell path leaves rc files to our marked block.
    SHELL=porida-manual-profile bash "$PORIDA_TEMP_DIR/bun-install.sh" \
      "bun-v$PORIDA_BUN_VERSION"
  fi
  export PATH="$BUN_INSTALL/bin:$PATH"
  hash -r
  porida_configure_profile

  porida_check
  porida_database --configure-auth

  printf '\nOpen a new terminal, enter Porida, then run:\n'
  printf '  nvm use 24\n  bun install --frozen-lockfile\n'
  printf 'Configure apps/api/.env using apps/api/.env.example and the local DB password.\n'
  printf 'Configure apps/web/.env.local using apps/web/.env.example if needed.\n'
  printf 'Then, in separate terminals: bun run dev:api and bun run dev:web\n'
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
