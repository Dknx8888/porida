#!/usr/bin/env bash
# Porida Ubuntu bootstrap, revision 2.
# Run with bash, never source and never sudo the entire script.
# Sources:
# https://github.com/nvm-sh/nvm
# https://bun.com/docs/installation
# https://www.postgresql.org/download/linux/ubuntu/
set -Eeuo pipefail

# Prefix our constants: NVM uses names such as NVM_VERSION internally.
readonly PORIDA_NVM_VERSION="0.40.7"
readonly PORIDA_NODE_MAJOR="24"
readonly PORIDA_BUN_VERSION="1.4.2"
readonly PORIDA_PG_MAJOR="18"
PORIDA_TEMP_DIR=""

porida_info() { printf '\n==> %s\n' "$*"; }
porida_warn() { printf 'Warning: %s\n' "$*" >&2; }
porida_die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

porida_help() {
  cat <<'HELP'
Usage: bash porida-ubuntu-setup.sh [--check | --help]
No option: install tools after displaying changes and asking for confirmation.
--check: no sudo, downloads, installations, profile edits or database changes.
Checks Git, NVM, active Node 24.x, Bun 1.4.2, PostgreSQL 18 client,
and an online Ubuntu-managed PostgreSQL 18 cluster on port 5432.

Target: Ubuntu 22.04/24.04/26.04, amd64 or arm64, Bash.
Installation requires sudo, internet access, and running systemd.
New NVM installs use 0.40.7; existing NVM installations are retained.
Existing Node 24 installations are reused; fresh installs select latest 24.x.
Bun is pinned to 1.4.2. Other apt packages receive available updates.
Installation may update .bashrc, change NVM's default to 24, add the PGDG
repository if needed, and enable/start PostgreSQL. Existing databases,
passwords, authentication settings and cluster ports are not rewritten.
No clone, scaffolding, bun install, role creation or schema import is performed.
Review this file before running. Downloaded official installers execute as you.
HELP
}

porida_platform() {
  [[ -r /etc/os-release ]] || porida_die "Cannot identify OS."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == ubuntu ]] || porida_die "Ubuntu only; found ${ID:-unknown}."
  case "${VERSION_CODENAME:-}" in
    jammy|noble|resolute) ;;
    *) porida_die "Supported Ubuntu releases: jammy, noble, resolute." ;;
  esac
  case "$(uname -m)" in
    x86_64|aarch64) ;;
    *) porida_die "Supported CPUs: x86_64 and aarch64." ;;
  esac
}

porida_paths() {
  # Respect explicitly configured locations and NVM's documented XDG default.
  export NVM_DIR="${NVM_DIR:-${XDG_CONFIG_HOME:+${XDG_CONFIG_HOME}/nvm}}"
  export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
  export BUN_INSTALL="${BUN_INSTALL:-${HOME}/.bun}"
}

# NVM is not designed for Bash strict mode. Isolate it in a subshell,
# disable strict flags there, and explicitly propagate each failure.
# --no-use preserves the caller's active Node in --check.
porida_nvm() (
  set +e +u
  set +o pipefail
  . "$NVM_DIR/nvm.sh" --no-use || exit 1
  nvm "$@"
)

porida_check() {
  local porida_failures=0 porida_value porida_clusters porida_bun
  porida_info "Checking tools (no changes)"
  if porida_value=$(git --version 2>/dev/null); then
    printf 'OK: %s\n' "$porida_value"
  else
    porida_warn "Git missing or not executable."
    porida_failures=$((porida_failures + 1))
  fi
  if [[ -s "$NVM_DIR/nvm.sh" ]] && porida_value=$(porida_nvm --version); then
    printf 'OK: NVM %s (%s)\n' "$porida_value" "$NVM_DIR"
  else
    porida_warn "NVM missing or failed to load from $NVM_DIR."
    porida_failures=$((porida_failures + 1))
  fi

  # Do not silently replace the PATH inherited from the user's terminal.
  if porida_value=$(node --version 2>/dev/null) && [[ "$porida_value" == v${PORIDA_NODE_MAJOR}.* ]]; then
    printf 'OK: active Node %s (%s)\n' "$porida_value" "$(command -v node)"
  else
    porida_warn "Active Node is ${porida_value:-unavailable}; expected 24.x. In your terminal run: nvm use 24"
    porida_failures=$((porida_failures + 1))
  fi

  porida_value=""
  porida_bun=$(command -v bun || true)
  if [[ -z "$porida_bun" && -x "$BUN_INSTALL/bin/bun" ]]; then
    porida_bun="$BUN_INSTALL/bin/bun"
    porida_warn "Bun exists but is absent from PATH; open a new terminal."
  fi
  if [[ -n "$porida_bun" ]] && porida_value=$("$porida_bun" --version 2>/dev/null) && [[ "$porida_value" == "$PORIDA_BUN_VERSION" ]]; then
    printf 'OK: Bun %s (%s)\n' "$porida_value" "$porida_bun"
  else
    porida_warn "Expected Bun $PORIDA_BUN_VERSION; detected ${porida_value:-unavailable}."
    porida_failures=$((porida_failures + 1))
  fi

  if porida_value=$("/usr/lib/postgresql/$PORIDA_PG_MAJOR/bin/psql" --version 2>/dev/null); then
    printf 'OK: %s\n' "$porida_value"
  else
    porida_warn "PostgreSQL 18 client binaries missing."
    porida_failures=$((porida_failures + 1))
  fi
  if porida_clusters=$(pg_lsclusters --no-header 2>/dev/null) &&
     awk '$1 == 18 && $3 == 5432 && $4 ~ /^online/ { found=1 } END { exit !found }' <<<"$porida_clusters" &&
     "/usr/lib/postgresql/$PORIDA_PG_MAJOR/bin/pg_isready" -h localhost -p 5432 -t 3 >/dev/null 2>&1; then
    printf 'OK: local PostgreSQL 18 cluster online; localhost:5432 accepts connections.\n'
  else
    porida_warn "No ready Ubuntu-managed PostgreSQL 18 cluster on port 5432."
    printf '%s\n' "${porida_clusters:-No cluster listing available.}" >&2
    porida_failures=$((porida_failures + 1))
  fi
  ((porida_failures == 0)) || porida_die "$porida_failures check(s) failed. Nothing was repaired automatically."
  printf 'Checks passed. Application database credentials/schema are not tested.\n'
}

porida_download() {
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 --fail --silent --show-error \
    --location --connect-timeout 20 --max-time 180 --retry 2 "$1" --output "$2"
}

porida_cleanup() {
  # Delete only known installer files inside our own mktemp directory.
  if [[ -n "$PORIDA_TEMP_DIR" && -d "$PORIDA_TEMP_DIR" ]]; then
    rm -f -- "$PORIDA_TEMP_DIR/nvm-install.sh" "$PORIDA_TEMP_DIR/bun-install.sh"
    rmdir -- "$PORIDA_TEMP_DIR" || true
  fi
}

porida_install() {
  local porida_answer porida_candidate porida_node_path porida_cluster
  [[ "$EUID" -ne 0 ]] || porida_die "Run as your regular user, without sudo."
  command -v sudo >/dev/null || porida_die "sudo is required."
  [[ -d /run/systemd/system ]] || porida_die "Installation needs running systemd (including on WSL)."
  porida_help
  read -r -p "Proceed with these installation changes? [y/N] " porida_answer || porida_die "Confirmation required."
  [[ "$porida_answer" == y || "$porida_answer" == Y ]] || porida_die "Cancelled; no changes made."

  sudo -v
  PORIDA_TEMP_DIR=$(mktemp -d -t porida-setup.XXXXXXXX)
  trap porida_cleanup EXIT
  trap 'printf "Installation failed at line %s. Earlier steps may have completed.\n" "$LINENO" >&2' ERR
  sudo apt-get update
  sudo apt-get install -y build-essential ca-certificates curl git unzip vim postgresql-common

  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    porida_info "Installing NVM $PORIDA_NVM_VERSION"
    porida_download "https://raw.githubusercontent.com/nvm-sh/nvm/v$PORIDA_NVM_VERSION/install.sh" "$PORIDA_TEMP_DIR/nvm-install.sh"
    PROFILE="$HOME/.bashrc" bash "$PORIDA_TEMP_DIR/nvm-install.sh"
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

  if [[ ! -x "$BUN_INSTALL/bin/bun" ]] || [[ "$("$BUN_INSTALL/bin/bun" --version)" != "$PORIDA_BUN_VERSION" ]]; then
    porida_info "Installing Bun $PORIDA_BUN_VERSION"
    porida_download "https://bun.com/install" "$PORIDA_TEMP_DIR/bun-install.sh"
    SHELL=/bin/bash bash "$PORIDA_TEMP_DIR/bun-install.sh" "bun-v$PORIDA_BUN_VERSION"
  fi
  export PATH="$BUN_INSTALL/bin:$PATH"
  hash -r

  # Reuse any repository already offering version 18
  porida_candidate=$(apt-cache policy postgresql-18 | awk '/Candidate:/ {print $2}')
  if [[ -z "$porida_candidate" || "$porida_candidate" == "(none)" ]]; then
    if grep -rqs 'apt.postgresql.org' /etc/apt/sources.list /etc/apt/sources.list.d; then
      porida_die "Existing PGDG configuration offers no PostgreSQL 18. Review apt sources; left unchanged."
    fi
    porida_info "Adding official PGDG repository via its packaged helper"
    sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
    sudo apt-get update
  fi
  sudo apt-get install -y postgresql-18 postgresql-client-18
  sudo systemctl enable --now postgresql
  # Start only the intended existing cluster
  porida_cluster=$(pg_lsclusters --no-header | awk '$1 == 18 && $3 == 5432 {print $2}')
  [[ -n "$porida_cluster" && "$porida_cluster" != *$'\n'* ]] ||
    porida_die "No unique PostgreSQL 18 cluster on 5432. Inspect pg_lsclusters; no port/data changes made."
  sudo systemctl start "postgresql@18-$porida_cluster"
  porida_check
  printf '\nOpen a new terminal, enter Porida, run nvm use 24, then bun install --frozen-lockfile.\n'
  printf 'Configure or restore your database and .env separately. Existing data has not been recreated.\n'
}

porida_main() {
  (($# <= 1)) || porida_die "Expected at most one option. Use --help."
  case "${1:-}" in
    --help|-h) porida_help; return ;;
    ""|--check) ;;
    *) porida_die "Unknown option: $1. Use --help." ;;
  esac
  porida_platform
  porida_paths
  if [[ "${1:-}" == --check ]]; then
    porida_check
  else
    porida_install
  fi
}

# Guard also allows function-level tests without executing installation.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  porida_main "$@"
fi
