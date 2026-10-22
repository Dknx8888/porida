#!/usr/bin/env bash
# Porida setup: Ubuntu, Ultramarine, and native Windows through Git Bash.
# See SETUP.md for platform requirements, version sources, and operation modes.
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
readonly PORIDA_DOTNET_CHANNEL="10.0"

readonly PORIDA_DB_ROLE="portfolio_app"
readonly PORIDA_DB_NAME="portfolio_risk_dashboard"
readonly PORIDA_DB_PORT="5432"
readonly PORIDA_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PORIDA_SCHEMA_FILE="${PORIDA_SCHEMA_FILE:-$PORIDA_SCRIPT_DIR/database/schema.sql}"
PORIDA_PG_DATA=""
PORIDA_PG_SERVICE=""
PORIDA_PSQL=""
PORIDA_PG_ISREADY=""
PORIDA_PG_SOCKET=""

PORIDA_PLATFORM=""
PORIDA_RELEASE=""
PORIDA_UBUNTU_CLUSTER=""
PORIDA_TEMP_DIR=""
PORIDA_PROFILE_FILE=""

porida_info() { printf '\n==> %s\n' "$*"; }
porida_warn() { printf 'Warning: %s\n' "$*" >&2; }
porida_die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

porida_help() {
  cat <<'HELP'
Usage:
  bash porida-setup.sh
  bash porida-setup.sh --check
  bash porida-setup.sh --plan
  bash porida-setup.sh --db-only
  bash porida-setup.sh --configure-api
  bash porida-setup.sh --help

No option: show a plan, ask for confirmation, install development tools,
start PostgreSQL, and initialize Porida's missing role/database/schema.
--check: read-only tool/service/readiness checks; no sudo/elevation or
database writes. Does not authenticate application credentials or check schema.
--plan: print intended actions without installing or initializing anything.
--db-only: initialize Porida using existing PostgreSQL 18; no tool installs,
service starts, profile edits, or authentication-file changes.
--configure-api: prompt privately for the DB password, save
ConnectionStrings:Porida in .NET User Secrets, and create frontend .env.local
from its example only if it is missing.

Platforms:
  Ubuntu 22.04/24.04/26.04, Ultramarine 43/44: x86_64 or aarch64.
  Linux full setup needs Bash, sudo, internet, systemd, a Bash/Zsh login shell.
  Windows x64: Git Bash, Windows PowerShell 5.1+, WinGet (App Installer).
  Windows tools and PostgreSQL run natively; the PostgreSQL installer is
  interactive so you choose its administrator password privately.
  WSL uses the detected Linux distribution and requires systemd for full setup.

Versions:
  .NET SDK 10.0; Node 24.x; Bun 1.4.2; PostgreSQL 18 on localhost:5432.
  Linux uses NVM 0.40.7 for new installs and retains existing NVM.
  Windows selects a Node 24.x version from WinGet explicitly.

Existing passwords, ownership, schema, and data are preserved.
Conflicting clusters/custom service layouts are rejected, not upgraded.
Import schema only when no user objects exist. Nonempty databases are
preserved; their schema completeness is not checked.
Ultramarine full setup backs up pg_hba.conf before adding only Porida's
localhost SCRAM rules. --db-only does not edit authentication.
Windows DB setup uses an owner-only temporary pgpass file, deleted afterward.

Default schema: database/schema.sql beside this script.
Override: PORIDA_SCHEMA_FILE=/absolute/path/schema.sql.
Full Linux setup maintains a backed-up Porida block in .bashrc or .zshrc.
Local credentials are configured separately with --configure-api.
See SETUP.md for platform instructions and build/API-type commands.
HELP
}

porida_read_os_release() {
  [[ -r /etc/os-release ]] || porida_die "Cannot identify Linux distribution."
  # shellcheck disable=SC1091
  . /etc/os-release
}

porida_platform() {
  local porida_kernel porida_arch
  porida_kernel=$(uname -s)
  porida_arch=$(uname -m)
  case "$porida_kernel" in
    MINGW*|MSYS*|CYGWIN*)
      [[ "$porida_arch" == x86_64 || "$porida_arch" == amd64 ]] ||
        porida_die "Windows setup currently supports x64."
      PORIDA_PLATFORM=windows
      return
      ;;
    Linux) ;;
    *) porida_die "Supported platforms: Ubuntu, Ultramarine, Windows (Git Bash)." ;;
  esac
  case "$porida_arch" in
    x86_64|aarch64) ;;
    *) porida_die "Supported Linux CPUs: x86_64 and aarch64." ;;
  esac
  porida_read_os_release
  case "${ID:-}" in
    ubuntu)
      case "${VERSION_ID:-}" in
        22.04|24.04|26.04) ;;
        *) porida_die "Supported Ubuntu releases: 22.04, 24.04, 26.04." ;;
      esac
      PORIDA_PLATFORM=ubuntu
      PORIDA_RELEASE=$VERSION_ID
      PORIDA_PSQL="/usr/lib/postgresql/$PORIDA_PG_MAJOR/bin/psql"
      PORIDA_PG_SOCKET=/var/run/postgresql
      PORIDA_PG_SERVICE=postgresql.service
      ;;
    ultramarine)
      case "${VERSION_ID:-}" in
        43|44) ;;
        *) porida_die "Supported Ultramarine releases: 43 and 44." ;;
      esac
      PORIDA_PLATFORM=ultramarine
      PORIDA_RELEASE=$VERSION_ID
      PORIDA_PSQL=/usr/bin/psql
      PORIDA_PG_SOCKET=/run/postgresql
      PORIDA_PG_SERVICE=postgresql.service
      PORIDA_PG_DATA=/var/lib/pgsql/data
      ;;
    *) porida_die "Unsupported Linux distribution: ${ID:-unknown}." ;;
  esac
  PORIDA_PG_ISREADY="${PORIDA_PSQL%/psql}/pg_isready"
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
  local porida_server_version porida_data porida_port porida_hba porida_clusters
  porida_require_client
  if [[ "$PORIDA_PLATFORM" == ubuntu ]]; then
    command -v pg_lsclusters >/dev/null || porida_die "pg_lsclusters missing."
    porida_clusters=$(pg_lsclusters --no-header)
    PORIDA_UBUNTU_CLUSTER=$(awk -v version="$PORIDA_PG_MAJOR" -v port="$PORIDA_DB_PORT" \
      '$1 == version && $3 == port && $4 ~ /^online/ {print $2}' <<< "$porida_clusters")
    [[ -n "$PORIDA_UBUNTU_CLUSTER" && "$PORIDA_UBUNTU_CLUSTER" != *$'\n'* ]] ||
      porida_die "Expected one online PostgreSQL 18 cluster on 5432; inspect pg_lsclusters."
    PORIDA_PG_DATA="/var/lib/postgresql/$PORIDA_PG_MAJOR/$PORIDA_UBUNTU_CLUSTER"
  else
    systemctl is-active --quiet "$PORIDA_PG_SERVICE" ||
      porida_die "$PORIDA_PG_SERVICE is not running."
  fi
  porida_server_version=$(porida_admin -Atc 'SHOW server_version_num;')
  [[ "$porida_server_version" =~ ^[0-9]+$ ]] &&
    ((porida_server_version / 10000 == PORIDA_PG_MAJOR)) ||
    porida_die "Expected running PostgreSQL 18; found $porida_server_version."
  porida_data=$(porida_admin -Atc 'SHOW data_directory;')
  porida_port=$(porida_admin -Atc 'SHOW port;')
  porida_hba=$(porida_admin -Atc 'SHOW hba_file;')
  [[ "$porida_data" == "$PORIDA_PG_DATA" && "$porida_port" == "$PORIDA_DB_PORT" ]] ||
    porida_die "Custom PostgreSQL data/port configuration; configure it separately."
  if [[ "$PORIDA_PLATFORM" == ubuntu ]]; then
    [[ "$porida_hba" == "/etc/postgresql/$PORIDA_PG_MAJOR/$PORIDA_UBUNTU_CLUSTER/pg_hba.conf" ]] ||
      porida_die "Custom Ubuntu authentication file; configure it separately."
  else
    [[ "$porida_hba" == "$PORIDA_PG_DATA/pg_hba.conf" ]] ||
      porida_die "Custom Ultramarine authentication file; configure it separately."
  fi
  env -u PGHOSTADDR -u PGSERVICE -u PGSERVICEFILE "$PORIDA_PG_ISREADY" \
    -h localhost -p "$PORIDA_DB_PORT" -t 3 >/dev/null ||
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

  if porida_has_dotnet_sdk; then
    printf 'OK: .NET SDK %s installed.\n' "$PORIDA_DOTNET_CHANNEL"
  else
    porida_warn "Expected a stable .NET SDK $PORIDA_DOTNET_CHANNEL."
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

  if [[ "$PORIDA_PLATFORM" == ubuntu ]]; then
    if ! command -v pg_lsclusters >/dev/null ||
       ! pg_lsclusters --no-header |
         awk -v version="$PORIDA_PG_MAJOR" -v port="$PORIDA_DB_PORT" \
           '$1 == version && $3 == port && $4 ~ /^online/ {found=1} END {exit !found}'; then
      porida_warn "No online Ubuntu PostgreSQL 18 cluster on 5432."
      porida_failures=$((porida_failures + 1))
    fi
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
    printf '\nSet the local application-role password; use it for the API User Secrets.\n'
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

  [[ "$(porida_admin -Atc "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = '$PORIDA_DB_NAME';")" == "$PORIDA_DB_ROLE" ]] ||
    porida_die "Existing Porida database has another owner; configure it separately."

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

  printf '\nConfigure ConnectionStrings:Porida in .NET User Secrets with:\n'
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
  case "$PORIDA_PLATFORM" in
    ubuntu) command -v apt-get >/dev/null || porida_die "APT is required." ;;
    ultramarine) command -v dnf >/dev/null || porida_die "DNF is required." ;;
  esac
  [[ -d /run/systemd/system ]] ||
    porida_die "Installation requires running systemd."

  [[ -f "$PORIDA_SCHEMA_FILE" && -r "$PORIDA_SCHEMA_FILE" && -s "$PORIDA_SCHEMA_FILE" ]] ||
    porida_die "Sync the schema file first: $PORIDA_SCHEMA_FILE"
  porida_profile_path

  porida_help
  porida_plan
  printf '\nShell profile: %s\nSchema: %s\n' "$PORIDA_PROFILE_FILE" "$PORIDA_SCHEMA_FILE"
  read -r -p "Proceed with installation and DB initialization? [y/N] " \
    porida_answer || porida_die "Confirmation required."
  [[ "$porida_answer" == y || "$porida_answer" == Y ]] ||
    porida_die "Cancelled; no changes made."

  sudo -v
  # Reject existing incompatible data before any package or profile changes.
  umask 077
  PORIDA_TEMP_DIR=$(mktemp -d -t porida-setup.XXXXXXXX)
  trap porida_cleanup EXIT
  trap 'printf "Setup failed at line %s. Earlier steps may have completed.\n" "$LINENO" >&2' ERR
  case "$PORIDA_PLATFORM" in
    ubuntu) porida_install_ubuntu ;;
    ultramarine) porida_install_ultramarine ;;
  esac

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
  if [[ "$PORIDA_PLATFORM" == ultramarine ]]; then
    porida_database --configure-auth
  else
    porida_database
  fi

  porida_next_steps
}



porida_plan() {
  printf 'Detected platform: %s %s\n' "$PORIDA_PLATFORM" "$PORIDA_RELEASE"
  if [[ "$PORIDA_PLATFORM" == ubuntu ]]; then
    printf 'apt: build tools, curl, Git, unzip, vim, postgresql-common,\n'
    printf '     dotnet-sdk-10.0, postgresql-18, postgresql-client-18.\n'
    [[ "$PORIDA_RELEASE" != 22.04 ]] ||
      printf '.NET 10 on 22.04: Canonical ppa:dotnet/backports when SDK is missing.\n'
    printf 'Add official PGDG only when PostgreSQL 18 has no apt candidate.\n'
  else
    printf 'dnf: build tools, curl, Git, unzip, vim-enhanced,\n'
    printf '     dotnet-sdk-10.0 and native PostgreSQL 18.\n'
  fi
  printf 'Install/reuse NVM and Node 24; install Bun 1.4.2.\n'
  printf 'Initialize only missing Porida DB objects; preserve existing data.\n'
}

porida_has_dotnet_sdk() {
  local porida_sdks
  porida_sdks=$(dotnet --list-sdks 2>/dev/null) || return 1
  awk -v channel="$PORIDA_DOTNET_CHANNEL." \
    'index($1, channel) == 1 && $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ {found=1}
     END {exit !found}' <<< "$porida_sdks"
}

porida_ubuntu_preflight() {
  local porida_clusters porida_conflicts
  command -v pg_lsclusters >/dev/null || return 0
  porida_clusters=$(pg_lsclusters --no-header)
  porida_conflicts=$(awk -v version="$PORIDA_PG_MAJOR" -v port="$PORIDA_DB_PORT" \
    '($3 == port && $1 != version) || ($1 == version && $3 != port) {print}' \
    <<< "$porida_clusters")
  [[ -z "$porida_conflicts" ]] ||
    porida_die "Existing clusters conflict with PostgreSQL 18 on 5432; inspect pg_lsclusters."
}

porida_install_ubuntu() {
  local porida_candidate porida_clusters porida_cluster
  porida_ubuntu_preflight
  sudo apt-get update
  sudo apt-get install -y \
    build-essential ca-certificates curl git unzip vim postgresql-common
  if ! porida_has_dotnet_sdk; then
    if grep -rqs 'packages.microsoft.com.*ubuntu' \
      /etc/apt/sources.list /etc/apt/sources.list.d; then
      porida_die "Microsoft's Ubuntu feed is configured; review .NET package sources before setup."
    fi
    if [[ "$PORIDA_RELEASE" == 22.04 ]]; then
      sudo apt-get install -y software-properties-common
      sudo add-apt-repository -y ppa:dotnet/backports
      sudo apt-get update
    fi
    sudo apt-get install -y dotnet-sdk-10.0
  fi
  porida_candidate=$(apt-cache policy postgresql-18 | awk '/Candidate:/ {print $2}')
  if [[ -z "$porida_candidate" || "$porida_candidate" == "(none)" ]]; then
    if grep -rqs 'apt.postgresql.org' /etc/apt/sources.list /etc/apt/sources.list.d; then
      porida_die "Existing PGDG feed offers no PostgreSQL 18; review apt sources."
    fi
    sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
    sudo apt-get update
  fi
  sudo apt-get install -y postgresql-18 postgresql-client-18
  porida_ubuntu_preflight
  sudo systemctl enable --now postgresql
  porida_clusters=$(pg_lsclusters --no-header)
  porida_cluster=$(awk -v version="$PORIDA_PG_MAJOR" -v port="$PORIDA_DB_PORT" \
    '$1 == version && $3 == port {print $2}' <<< "$porida_clusters")
  [[ -n "$porida_cluster" && "$porida_cluster" != *$'\n'* ]] ||
    porida_die "Expected one PostgreSQL 18 cluster on 5432; inspect pg_lsclusters."
  sudo systemctl start "postgresql@$PORIDA_PG_MAJOR-$porida_cluster"
}

porida_install_ultramarine() {
  porida_service_preflight
  porida_data_preflight
  sudo dnf install --refresh -y \
    gcc gcc-c++ make openssl-devel ca-certificates curl git unzip vim-enhanced \
    dotnet-sdk-10.0 \
    "postgresql-${PORIDA_PG_MAJOR}.*" "postgresql-server-${PORIDA_PG_MAJOR}.*"
  porida_require_client
  porida_service_preflight
  porida_data_preflight
  if ! sudo test -e "$PORIDA_PG_DATA/PG_VERSION"; then
    sudo env PGSETUP_INITDB_OPTIONS='--auth-local=peer --auth-host=scram-sha-256 --encoding=UTF8' \
      /usr/bin/postgresql-setup --initdb --unit postgresql \
      --datadir "$PORIDA_PG_DATA" --port "$PORIDA_DB_PORT"
  fi
  sudo systemctl enable --now "$PORIDA_PG_SERVICE"
}

porida_next_steps() {
  printf '\nOpen a new terminal, then from the repository root:\n'
  printf '  bun install --frozen-lockfile\n'
  printf '  bash porida-setup.sh --configure-api\n'
  printf 'Start in separate terminals: bun run dev:api and bun run dev:web\n'
  printf 'See SETUP.md for API types and build checks.\n'
}

porida_configure_api() {
  local porida_password porida_project="$PORIDA_SCRIPT_DIR/apps/api/Porida.Api.csproj"
  [[ -r "$porida_project" ]] || porida_die "API project missing: $porida_project"
  porida_has_dotnet_sdk || porida_die ".NET SDK 10.0 is required."
  command -v node >/dev/null || porida_die "Node is needed to safely encode the secret."
  IFS= read -r -s -p "Local portfolio_app database password: " porida_password ||
    porida_die "Could not read password."
  printf '\n'
  if ! printf '%s' "$porida_password" |
    node -e '
      const fs = require("node:fs");
      const password = fs.readFileSync(0, "utf8").replaceAll("\"", "\"\"");
      const connection = "Host=localhost;Port=5432;Database=portfolio_risk_dashboard;Username=portfolio_app;Password=\"" + password + "\"";
      process.stdout.write(JSON.stringify({"ConnectionStrings:Porida": connection}));
    ' |
    dotnet user-secrets set --project "$porida_project"; then
    unset porida_password
    porida_die "Could not save API secrets."
  fi
  unset porida_password
  if [[ ! -e "$PORIDA_SCRIPT_DIR/apps/web/.env.local" ]]; then
    [[ -r "$PORIDA_SCRIPT_DIR/apps/web/.env.example" ]] ||
      porida_die "Frontend environment example missing."
    (umask 077; cp -- "$PORIDA_SCRIPT_DIR/apps/web/.env.example" \
      "$PORIDA_SCRIPT_DIR/apps/web/.env.local")
  fi
  printf 'API connection configured for this OS/user. Start with bun run dev:api.\n'
}

porida_windows() {
  local porida_mode="${1#--}" porida_ps_file porida_exit=0
  command -v powershell.exe >/dev/null ||
    porida_die "Windows PowerShell is required; run this file through Git Bash."
  command -v cygpath >/dev/null || porida_die "Use Git Bash on Windows."
  porida_ps_file=$(mktemp -t porida-windows.XXXXXXXX.ps1)
  trap "$(printf 'rm -f -- %q' "$porida_ps_file")" EXIT
  cat > "$porida_ps_file" <<'POWERSHELL'
#Requires -Version 5.1
param(
  [ValidateSet('install', 'check', 'plan', 'db-only', 'configure-api')]
  [string]$Mode,
  [string]$ProjectRoot,
  [string]$SchemaFile,
  [string]$BunVersion,
  [string]$NodeMajor,
  [string]$PgMajor,
  [string]$DotnetChannel
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PoridaRole = 'portfolio_app'
$PoridaDatabase = 'portfolio_risk_dashboard'
$PoridaPort = '5432'
$PoridaPgBin = $null
$PoridaServiceName = 'postgresql-x64-' + $PgMajor

function Invoke-PoridaCommand {
  param([string]$Executable, [string[]]$Arguments)
  & $Executable @Arguments
  if ($LASTEXITCODE -eq 3010) { throw 'Restart Windows, then rerun setup to finish installation.' }
  if ($LASTEXITCODE -ne 0) { throw ($Executable + ' failed with exit code ' + $LASTEXITCODE) }
}
function Update-PoridaPath {
  $PoridaPaths = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path
    (Join-Path $env:USERPROFILE '.bun\bin')
    (Join-Path $env:ProgramFiles 'dotnet')
    (Join-Path $env:ProgramFiles 'nodejs')
  )
  $env:Path = ($PoridaPaths | Where-Object { $_ } | Select-Object -Unique) -join ';'
}
function Get-PoridaVersion([string]$Executable) {
  if (-not (Get-Command $Executable -ErrorAction SilentlyContinue)) { return '' }
  $PoridaOutput = @(& $Executable --version 2>$null)
  if ($LASTEXITCODE -ne 0) { return '' }
  return (($PoridaOutput -join '').Trim())
}
function Test-PoridaSdk {
  if (-not (Get-Command dotnet.exe -ErrorAction SilentlyContinue)) { return $false }
  $PoridaOutput = @(& dotnet.exe --list-sdks 2>$null)
  if ($LASTEXITCODE -ne 0) { return $false }
  return [bool]($PoridaOutput | Where-Object {
    $_ -match ('^' + [regex]::Escape($DotnetChannel) + '\.[0-9]+\s')
  })
}
function Get-PoridaPgBin {
  $PoridaCandidates = @((Join-Path $env:ProgramFiles ('PostgreSQL\' + $PgMajor + '\bin')))
  $PoridaPsqlCommand = Get-Command psql.exe -ErrorAction SilentlyContinue
  if ($PoridaPsqlCommand) { $PoridaCandidates += Split-Path -Parent $PoridaPsqlCommand.Source }
  foreach ($PoridaCandidate in $PoridaCandidates) {
    $PoridaPsql = Join-Path $PoridaCandidate 'psql.exe'
    if (Test-Path -LiteralPath $PoridaPsql -PathType Leaf) {
      $PoridaVersion = @(& $PoridaPsql --version)
      if ($LASTEXITCODE -eq 0 -and ($PoridaVersion -join '') -match
        ('^psql \(PostgreSQL\) ' + [regex]::Escape($PgMajor) + '\.')) {
        return $PoridaCandidate
      }
    }
  }
  throw 'PostgreSQL 18 client missing. Use full setup or add its bin directory to PATH.'
}
function Show-PoridaPlan {
  Write-Host 'Detected platform: Windows x64 (native tools through Git Bash/PowerShell)'
  Write-Host ('WinGet: OpenJS.NodeJS.LTS, explicitly selecting a ' + $NodeMajor + '.x version.')
  Write-Host 'WinGet: Microsoft.DotNet.SDK.10.'
  Write-Host ('Official Bun installer: version ' + $BunVersion + ' for this user.')
  Write-Host 'WinGet: PostgreSQL.PostgreSQL.18 with an interactive installer.'
  Write-Host 'Choose port 5432 and the default PostgreSQL 18 Windows service.'
  Write-Host 'Create only missing Porida DB objects; import schema only when empty.'
  Write-Host 'Configure per-user .NET secrets separately with --configure-api.'
}
function Test-PoridaTools {
  $PoridaFailures = 0
  $PoridaGit = Get-PoridaVersion git.exe
  $PoridaNode = Get-PoridaVersion node.exe
  $PoridaBun = Get-PoridaVersion bun.exe
  foreach ($PoridaTest in @(
    @('Git', [bool]$PoridaGit, $PoridaGit),
    @('Node 24.x', ($PoridaNode -match '^v24\.'), $PoridaNode),
    @('Bun 1.4.2', ($PoridaBun -eq $BunVersion), $PoridaBun),
    @('.NET SDK 10.0', (Test-PoridaSdk), $DotnetChannel)
  )) {
    if ($PoridaTest[1]) { Write-Host ('OK: ' + $PoridaTest[0] + ' ' + $PoridaTest[2]) }
    else { Write-Warning ('Missing/incompatible: ' + $PoridaTest[0]); $PoridaFailures++ }
  }
  try {
    $script:PoridaPgBin = Get-PoridaPgBin
    Write-Host ('OK: PostgreSQL 18 client (' + $PoridaPgBin + ')')
    $PoridaService = Get-Service -Name $PoridaServiceName -ErrorAction Stop
    if ($PoridaService.Status -ne 'Running') { throw 'PostgreSQL 18 service is not running.' }
    & (Join-Path $PoridaPgBin 'pg_isready.exe') -h localhost -p $PoridaPort -t 3 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL is not ready on localhost:5432.' }
  } catch { Write-Warning $_.Exception.Message; $PoridaFailures++ }
  if ($PoridaFailures -ne 0) { throw ($PoridaFailures.ToString() + ' check(s) failed.') }
  Write-Host 'Tool checks passed. Server version/application credentials/schema not tested.'
}
function Get-PoridaNodeVersion {
  $PoridaWingetArgs = @('show', '--id', 'OpenJS.NodeJS.LTS', '--exact', '--versions',
    '--source', 'winget', '--accept-source-agreements')
  $PoridaLines = @(& winget.exe @PoridaWingetArgs)
  if ($LASTEXITCODE -ne 0) { throw 'Could not list available Node.js LTS versions.' }
  $PoridaVersions = @(
    foreach ($PoridaLine in $PoridaLines) {
      if ($PoridaLine -match ('^\s*(' + [regex]::Escape($NodeMajor) + '\.\d+\.\d+)\s*$')) {
        $Matches[1]
      }
    }
  )
  if ($PoridaVersions.Count -eq 0) { throw 'WinGet has no Node 24.x version; update its source and retry.' }
  return ($PoridaVersions | Sort-Object { [version]$_ } -Descending | Select-Object -First 1)
}
function Install-PoridaTools {
  $PoridaIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $PoridaPrincipal = [System.Security.Principal.WindowsPrincipal]::new($PoridaIdentity)
  if (-not $PoridaPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Full Windows setup needs Git Bash started as Administrator, using your usual Windows account.'
  }
  if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'WinGet is missing. Install/update Microsoft App Installer, then retry.'
  }
  if (-not (Test-Path -LiteralPath $SchemaFile -PathType Leaf)) { throw ('Schema missing: ' + $SchemaFile) }
  Show-PoridaPlan
  $PoridaAnswer = Read-Host 'Proceed with installation and Porida database initialization? [y/N]'
  if ($PoridaAnswer -notmatch '^[yY]$') { throw 'Cancelled; no changes made.' }
  $PoridaOtherServices = @(Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne $PoridaServiceName })
  if ($PoridaOtherServices.Count -gt 0) {
    throw 'Other PostgreSQL services exist. Review ports/data before running this default setup.'
  }
  $PoridaNode = Get-PoridaVersion node.exe
  if ($PoridaNode -and $PoridaNode -notmatch '^v24\.') {
    throw 'Another Node major is active. Switch to Node 24 deliberately, then rerun setup.'
  }
  if (-not $PoridaNode) {
    $PoridaVersion = Get-PoridaNodeVersion
    Invoke-PoridaCommand -Executable winget.exe -Arguments @(
      'install', '--id', 'OpenJS.NodeJS.LTS', '--exact', '--version', $PoridaVersion,
      '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements',
      '--silent', '--architecture', 'x64', '--installer-type', 'wix'
    )
  }
  if (-not (Test-PoridaSdk)) {
    Invoke-PoridaCommand -Executable winget.exe -Arguments @(
      'install', '--id', 'Microsoft.DotNet.SDK.10', '--exact', '--source', 'winget',
      '--accept-source-agreements', '--accept-package-agreements', '--silent',
      '--architecture', 'x64'
    )
  }
  Update-PoridaPath
  if ((Get-PoridaVersion bun.exe) -ne $BunVersion) {
    $PoridaInstaller = Join-Path ([IO.Path]::GetTempPath()) ('porida-bun-' + [guid]::NewGuid() + '.ps1')
    try {
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      Invoke-WebRequest -UseBasicParsing -Uri 'https://bun.com/install.ps1' -OutFile $PoridaInstaller
      & $PoridaInstaller -Version $BunVersion
    } finally { Remove-Item -LiteralPath $PoridaInstaller -Force -ErrorAction SilentlyContinue }
    Update-PoridaPath
  }
  $PoridaPsqlInstalled = $true
  try { $script:PoridaPgBin = Get-PoridaPgBin } catch { $PoridaPsqlInstalled = $false }
  if (-not $PoridaPsqlInstalled) {
    Write-Host 'Choose PostgreSQL 18, port 5432, and a private postgres password in the installer.'
    Invoke-PoridaCommand -Executable winget.exe -Arguments @(
      'install', '--id', 'PostgreSQL.PostgreSQL.18', '--exact', '--source', 'winget',
      '--accept-source-agreements', '--accept-package-agreements', '--interactive',
      '--architecture', 'x64'
    )
    $script:PoridaPgBin = Get-PoridaPgBin
  }
  $PoridaService = Get-Service -Name $PoridaServiceName -ErrorAction Stop
  if ($PoridaService.Status -ne 'Running') { Start-Service -Name $PoridaServiceName }
  Test-PoridaTools
  Initialize-PoridaDatabase
  Write-Host 'Open a new terminal. From the repository root:'
  Write-Host '  bun install --frozen-lockfile'
  Write-Host '  bash porida-setup.sh --configure-api'
  Write-Host 'Start in separate terminals: bun run dev:api and bun run dev:web'
}
function Invoke-PoridaPsql {
  param([string]$Database, [string]$UserName, [string[]]$Arguments)
  $PoridaPsqlArgs = @('-X', '-h', 'localhost', '-p', $PoridaPort, '-U', $UserName,
    '-d', $Database, '--no-password', '--set=ON_ERROR_STOP=on') + $Arguments
  $PoridaResult = @(& (Join-Path $PoridaPgBin 'psql.exe') @PoridaPsqlArgs)
  if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL command failed; existing data was not replaced.' }
  return (($PoridaResult -join [Environment]::NewLine).Trim())
}
function Initialize-PoridaDatabase {
  if (-not (Test-Path -LiteralPath $SchemaFile -PathType Leaf) -or
      (Get-Item -LiteralPath $SchemaFile).Length -eq 0) { throw ('Schema missing/empty: ' + $SchemaFile) }
  $script:PoridaPgBin = Get-PoridaPgBin
  $PoridaService = Get-Service -Name $PoridaServiceName -ErrorAction Stop
  if ($PoridaService.Status -ne 'Running') { throw 'Start PostgreSQL 18 before --db-only.' }
  $PoridaTemp = Join-Path ([IO.Path]::GetTempPath()) ('porida-db-' + [guid]::NewGuid())
  $PoridaSavedEnvironment = @{}
  $PoridaEnvironmentNames = @('PGPASSFILE', 'PGPASSWORD', 'PGHOSTADDR', 'PGOPTIONS',
    'PGSERVICE', 'PGSERVICEFILE', 'PGCLIENTENCODING')
  $PoridaSecret = $null
  $PoridaPointer = [IntPtr]::Zero
  try {
    New-Item -ItemType Directory -Path $PoridaTemp | Out-Null
    $PoridaSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $PoridaAcl = [System.Security.AccessControl.DirectorySecurity]::new()
    $PoridaAcl.SetOwner($PoridaSid)
    $PoridaAcl.SetAccessRuleProtection($true, $false)
    $PoridaRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
      $PoridaSid, [System.Security.AccessControl.FileSystemRights]::FullControl,
      ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit),
      [System.Security.AccessControl.PropagationFlags]::None, [System.Security.AccessControl.AccessControlType]::Allow)
    $PoridaAcl.AddAccessRule($PoridaRule)
    Set-Acl -LiteralPath $PoridaTemp -AclObject $PoridaAcl
    $PoridaSecret = Read-Host 'Local postgres administrator password' -AsSecureString
    $PoridaPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($PoridaSecret)
    $PoridaPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($PoridaPointer)
    $PoridaEscaped = $PoridaPlain.Replace('\', '\\').Replace(':', '\:')
    $PoridaPassFile = Join-Path $PoridaTemp 'pgpass'
    [IO.File]::WriteAllText($PoridaPassFile,
      ('localhost:' + $PoridaPort + ':*:postgres:' + $PoridaEscaped + [Environment]::NewLine),
      [Text.UTF8Encoding]::new($false))
    $PoridaPlain = $null
    $PoridaEscaped = $null
    foreach ($PoridaName in $PoridaEnvironmentNames) {
      $PoridaSavedEnvironment[$PoridaName] = [Environment]::GetEnvironmentVariable($PoridaName, 'Process')
      [Environment]::SetEnvironmentVariable($PoridaName, $null, 'Process')
    }
    $env:PGPASSFILE = $PoridaPassFile
    $env:PGCLIENTENCODING = 'UTF8'
    $PoridaServer = Invoke-PoridaPsql -Database postgres -UserName postgres -Arguments @('-Atc', 'SHOW server_version_num;')
    if ($PoridaServer -notmatch '^[0-9]+$' -or [math]::Floor([double]$PoridaServer / 10000) -ne [int]$PgMajor) {
      throw 'localhost:5432 is not PostgreSQL 18; configure that cluster separately.'
    }
    $PoridaData = Invoke-PoridaPsql -Database postgres -UserName postgres -Arguments @('-Atc', 'SHOW data_directory;')
    $PoridaExpectedData = Join-Path (Split-Path -Parent $PoridaPgBin) 'data'
    if ([IO.Path]::GetFullPath($PoridaData).TrimEnd('\') -ne [IO.Path]::GetFullPath($PoridaExpectedData).TrimEnd('\')) {
      throw 'Custom PostgreSQL data directory; configure that installation separately.'
    }
    $PoridaRoleExists = Invoke-PoridaPsql -Database postgres -UserName postgres -Arguments @(
      '-Atc', "SELECT 1 FROM pg_roles WHERE rolname = '$PoridaRole';")
    if ($PoridaRoleExists -ne '1') {
      Write-Host 'Choose the portfolio_app password; use the same password for --configure-api.'
      $PoridaCreateArgs = @('-X', '-h', 'localhost', '-p', $PoridaPort, '-U', 'postgres',
        '-d', 'postgres', '--no-password', '--set=ON_ERROR_STOP=on',
        '-c', "BEGIN; SET LOCAL password_encryption = 'scram-sha-256';",
        '-c', "CREATE ROLE $PoridaRole LOGIN;", '-c', ("\password " + $PoridaRole), '-c', 'COMMIT;')
      Invoke-PoridaCommand -Executable (Join-Path $PoridaPgBin 'psql.exe') -Arguments $PoridaCreateArgs
    } else { Write-Host 'Existing portfolio_app password preserved.' }
    $PoridaCanLogin = Invoke-PoridaPsql -Database postgres -UserName postgres -Arguments @(
      '-Atc', "SELECT rolcanlogin FROM pg_roles WHERE rolname = '$PoridaRole';")
    if ($PoridaCanLogin -ne 't') { throw 'Existing portfolio_app cannot log in; configure it separately.' }
    $PoridaDbExists = Invoke-PoridaPsql -Database postgres -UserName postgres -Arguments @(
      '-Atc', "SELECT 1 FROM pg_database WHERE datname = '$PoridaDatabase';")
    if ($PoridaDbExists -ne '1') {
      Invoke-PoridaPsql -Database postgres -UserName postgres -Arguments @(
        '-c', "CREATE DATABASE $PoridaDatabase OWNER $PoridaRole;") | Out-Host
    }
    $PoridaOwner = Invoke-PoridaPsql -Database postgres -UserName postgres -Arguments @(
      '-Atc', "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = '$PoridaDatabase';")
    if ($PoridaOwner -ne $PoridaRole) { throw 'Existing Porida database has another owner; configure it separately.' }
    $PoridaObjectQuery = @'
SELECT (
  EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname !~ '^pg_' AND n.nspname <> 'information_schema')
  OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname !~ '^pg_' AND n.nspname <> 'information_schema')
  OR EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname !~ '^pg_' AND n.nspname <> 'information_schema')
  OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname !~ '^pg_' AND nspname NOT IN ('public','information_schema'))
  OR EXISTS (SELECT 1 FROM pg_extension WHERE extname <> 'plpgsql')
);
'@
    $PoridaHasObjects = Invoke-PoridaPsql -Database $PoridaDatabase -UserName postgres -Arguments @('-Atc', $PoridaObjectQuery)
    if ($PoridaHasObjects -eq 't') {
      Write-Host 'Existing user objects found; schema import skipped. Existing data preserved.'
    } elseif ($PoridaHasObjects -eq 'f') {
      Write-Host ('Importing empty database from: ' + $SchemaFile)
      Write-Host 'Enter the portfolio_app password when psql prompts.'
      $PoridaImportArgs = @('-X', '-h', 'localhost', '-p', $PoridaPort, '-U', $PoridaRole,
        '-d', $PoridaDatabase, '--password', '--set=ON_ERROR_STOP=on',
        '--single-transaction', '--file', $SchemaFile)
      Invoke-PoridaCommand -Executable (Join-Path $PoridaPgBin 'psql.exe') -Arguments $PoridaImportArgs
    } else { throw 'Could not determine whether the database is empty.' }
    Write-Host 'Configure ConnectionStrings:Porida in .NET User Secrets using --configure-api.'
  } finally {
    foreach ($PoridaName in $PoridaSavedEnvironment.Keys) {
      [Environment]::SetEnvironmentVariable($PoridaName, $PoridaSavedEnvironment[$PoridaName], 'Process')
    }
    if ($PoridaPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PoridaPointer) }
    if ($PoridaSecret) { $PoridaSecret.Dispose() }
    if (Test-Path -LiteralPath $PoridaTemp) { Remove-Item -LiteralPath $PoridaTemp -Recurse -Force }
  }
}
function Set-PoridaApi {
  $PoridaProject = Join-Path $ProjectRoot 'apps\api\Porida.Api.csproj'
  if (-not (Test-Path -LiteralPath $PoridaProject -PathType Leaf)) { throw ('API project missing: ' + $PoridaProject) }
  if (-not (Test-PoridaSdk)) { throw '.NET SDK 10.0 is required.' }
  $PoridaSecret = Read-Host 'Local portfolio_app database password' -AsSecureString
  $PoridaPointer = [IntPtr]::Zero
  $PoridaOldEncoding = $OutputEncoding
  try {
    $PoridaPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($PoridaSecret)
    $PoridaBuilder = [System.Data.Common.DbConnectionStringBuilder]::new()
    $PoridaBuilder['Host'] = 'localhost'
    $PoridaBuilder['Port'] = $PoridaPort
    $PoridaBuilder['Database'] = $PoridaDatabase
    $PoridaBuilder['Username'] = $PoridaRole
    $PoridaBuilder['Password'] = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($PoridaPointer)
    $PoridaJson = @{ 'ConnectionStrings:Porida' = $PoridaBuilder.ConnectionString } | ConvertTo-Json -Compress
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $PoridaJson | & dotnet.exe user-secrets set --project $PoridaProject
    if ($LASTEXITCODE -ne 0) { throw 'Could not save API secrets.' }
    $PoridaJson = $null
    $PoridaBuilder.Clear()
    $PoridaLocal = Join-Path $ProjectRoot 'apps\web\.env.local'
    if (-not (Test-Path -LiteralPath $PoridaLocal)) {
      Copy-Item -LiteralPath (Join-Path $ProjectRoot 'apps\web\.env.example') -Destination $PoridaLocal
    }
    Write-Host 'API connection configured for this Windows account. Start with bun run dev:api.'
  } finally {
    $OutputEncoding = $PoridaOldEncoding
    if ($PoridaPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PoridaPointer) }
    $PoridaSecret.Dispose()
  }
}
try {
  Update-PoridaPath
  switch ($Mode) {
    'plan' { Show-PoridaPlan }
    'check' { Test-PoridaTools }
    'install' { Install-PoridaTools }
    'db-only' { Initialize-PoridaDatabase }
    'configure-api' { Set-PoridaApi }
  }
  exit 0
} catch { Write-Error $_.Exception.Message -ErrorAction Continue; exit 1 }
POWERSHELL
  local -a porida_ps_args=(
    -NoLogo -NoProfile -ExecutionPolicy Bypass
    -File "$(cygpath -w "$porida_ps_file")"
    -Mode "$porida_mode"
    -ProjectRoot "$(cygpath -w "$PORIDA_SCRIPT_DIR")"
    -SchemaFile "$(cygpath -w "$PORIDA_SCHEMA_FILE")"
    -BunVersion "$PORIDA_BUN_VERSION" -NodeMajor "$PORIDA_NODE_MAJOR"
    -PgMajor "$PORIDA_PG_MAJOR" -DotnetChannel "$PORIDA_DOTNET_CHANNEL"
  )
  # Mintty needs a pseudoconsole for native interactive password prompts.
  if [[ -t 0 && -t 1 && "${TERM:-}" == xterm* ]] && command -v winpty >/dev/null; then
    winpty powershell.exe "${porida_ps_args[@]}" || porida_exit=$?
  else
    powershell.exe "${porida_ps_args[@]}" || porida_exit=$?
  fi
  rm -f -- "$porida_ps_file"
  trap - EXIT
  return "$porida_exit"
}

porida_main() {
  (($# <= 1)) || porida_die "Expected at most one option."
  case "${1:-}" in
    --help|-h) porida_help; return ;;
    ""|--check|--plan|--db-only|--configure-api) ;;
    *) porida_die "Unknown option: $1. Use --help." ;;
  esac
  porida_platform
  if [[ "$PORIDA_PLATFORM" == windows ]]; then
    porida_windows "${1:---install}"
    return
  fi
  porida_paths
  case "${1:-}" in
    --plan) porida_plan ;;
    --check) porida_check ;;
    --db-only) porida_database ;;
    --configure-api) porida_configure_api ;;
    "") porida_install ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  porida_main "$@"
fi
