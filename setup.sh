#!/usr/bin/env bash

# ─── Mimir v4 — GAIN WordPress Project Setup ────────────────────────────────
# Portable setup script for new WordPress projects using the Erebus parent
# theme / child theme approach. Requires WP-CLI, git, and PHP.
#
# Usage: ./setup.sh [--help]

set -e

trap 'echo -e "\n  \033[0;31m\033[1m✗ Setup failed on line ${LINENO}. See output above for details.\033[0m" >&2' ERR

# ─── Config ──────────────────────────────────────────────────────────────────

readonly MIMIR_VERSION="4.2.0"
readonly MIMIR_REPO="thisisgain/Mimir"

readonly EREBUS_REPO="git@github.com:thisisgain/Erebus.git"
readonly EREBUS_THEME_DIR="wp-content/themes/erebus"
readonly EREBUS_VERSION="3.0.0"
readonly DEFAULT_ADMIN_EMAIL="harry.finn@thisisgain.com"
readonly DEFAULT_ADMIN_USER="super.user"
readonly DEFAULT_DB_HOST="127.0.0.1"

# Ensure Homebrew binary paths are available — WP-CLI db commands need the mysql binary
for _p in "/opt/homebrew/bin" "/opt/homebrew/opt/mysql/bin" "/opt/homebrew/opt/mysql-client/bin" "/usr/local/bin"; do
  [[ -d "$_p" ]] && PATH="$_p:$PATH"
done
export PATH
unset _p

# ─── Colours ─────────────────────────────────────────────────────────────────
# Must be set before the exec redirects below — once stdout is a pipe [[ -t 1 ]]
# returns false and would incorrectly blank all colour variables.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

if [[ ! -t 1 ]]; then
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

# Suppress PHP deprecation notices in WP-CLI output.
#
# Homebrew installs wp-cli as a phar with a #!/usr/bin/env php shebang — when invoked
# that way WP_CLI_PHP_ARGS is never seen by PHP. Detecting the shebang lets us call
# PHP directly with the right ini flags, bypassing the issue entirely.
# WP_CLI_PHP_ARGS is kept as a fallback for bash-wrapper installations.
export WP_CLI_PHP_ARGS="-d error_reporting=8191 -d display_errors=stderr"
_MIMIR_WP_BIN=$(command -v wp 2>/dev/null || true)
if [[ -n "$_MIMIR_WP_BIN" ]] && head -1 "$_MIMIR_WP_BIN" 2>/dev/null | grep -q 'php'; then
  wp() { php -d error_reporting=8191 -d display_errors=stderr "$_MIMIR_WP_BIN" "$@"; }
fi

# Belt-and-suspenders: filter any deprecation/notice lines that still reach stderr.
exec 2> >(grep --line-buffered -Ev 'Deprecated:|^(PHP )?Notice: ' >&2)

# ─── Output helpers ──────────────────────────────────────────────────────────

banner() {
  echo -e "${BLUE}${BOLD}" >&2
  echo "  ╔══════════════════════════════════════════════╗" >&2
  echo "  ║   Mimir v4 — GAIN WordPress Project Setup   ║" >&2
  echo "  ╚══════════════════════════════════════════════╝" >&2
  echo -e "${RESET}" >&2
}

step() {
  local title="$1"
  local divider
  divider=$(printf '─%.0s' $(seq 1 $((${#title} + 4))))
  echo "" >&2
  echo -e "${BLUE}${BOLD}  ▶ ${title}${RESET}" >&2
  echo -e "${BLUE}  ${divider}${RESET}" >&2
}

success() { echo -e "  ${GREEN}✓ $1${RESET}" >&2; }
warn()    { echo -e "  ${YELLOW}⚠ $1${RESET}" >&2; }
info()    { echo -e "  ${BLUE}→ $1${RESET}" >&2; }

error() {
  echo -e "\n  ${RED}${BOLD}✗ $1${RESET}" >&2
  exit 1
}

# ─── Prompt helpers ──────────────────────────────────────────────────────────

# ask "Label" "default" → echoes answer
# Writes prompt to /dev/tty so it is unaffected by the stderr filter.
ask() {
  local label="$1"
  local default="${2:-}"

  if [[ -n "$default" ]]; then
    echo -ne "${BOLD}  ${label} (${default}): ${RESET}" > /dev/tty
  else
    echo -ne "${BOLD}  ${label}: ${RESET}" > /dev/tty
  fi

  local value
  read -r value < /dev/tty
  echo "${value:-$default}"
}

# ask_secret "Label" → echoes answer, no echo (password input)
ask_secret() {
  local label="$1"
  local value
  echo -ne "${BOLD}  $label: ${RESET}" > /dev/tty
  read -rs value < /dev/tty
  echo "" > /dev/tty
  echo "$value"
}

# ask_validated "Label" "default" regex "Error message" → echoes validated answer
ask_validated() {
  local label="$1"
  local default="$2"
  local pattern="$3"
  local err_msg="$4"
  local value

  while true; do
    value=$(ask "$label" "$default")
    if [[ -z "$value" ]]; then
      warn "This field is required."
    elif [[ ! "$value" =~ $pattern ]]; then
      warn "$err_msg"
    else
      break
    fi
  done

  echo "$value"
}

generate_password() {
  openssl rand -base64 16 | tr -d '\n'
}

# ─── Step 1: Requirements check ──────────────────────────────────────────────

check_requirements() {
  step "Checking requirements"

  local missing=0

  for cmd in wp git php; do
    if command -v "$cmd" &>/dev/null; then
      success "${cmd} found"
    else
      echo -e "  ${RED}✗ ${cmd} not found${RESET}" >&2
      missing=1
    fi
  done

  [[ $missing -eq 1 ]] && error "Install missing requirements before continuing."

  # Confirm wp-cli is functional
  if ! wp --info &>/dev/null; then
    error "WP-CLI found but not functional. Check your environment."
  fi
}

# ─── Step 2: WordPress core ──────────────────────────────────────────────────

# These are set in setup_core and referenced by setup_git/print_summary
SITE_URL=""
SITE_TITLE=""
ADMIN_USER=""
ADMIN_PASSWORD=""

setup_core() {
  step "Database configuration"

  local db_name db_user db_password db_host
  db_name=$(ask_validated    "Database name"     ""               "^[A-Za-z0-9_]+$" "Use letters, numbers and underscores only.")
  db_user=$(ask_validated    "Database user"     "root"           "^[A-Za-z0-9_]+$" "Use letters, numbers and underscores only.")
  db_password=$(ask_secret   "Database password")
  db_host=$(ask              "Database host"     "$DEFAULT_DB_HOST")

  step "Site configuration"

  SITE_URL=$(ask_validated   "Site URL (e.g. http://my-project.test)" "" "^https?://.+" "Enter a valid URL starting with http:// or https://")
  SITE_TITLE=$(ask           "Site title"        "WordPress Site")
  local admin_email
  admin_email=$(ask          "Admin email"       "$DEFAULT_ADMIN_EMAIL")
  ADMIN_USER=$(ask           "Admin username"    "$DEFAULT_ADMIN_USER")

  local rand_pass
  rand_pass=$(generate_password)
  local ADMIN_PASSWORD_INPUT
  echo -ne "${BOLD}  Admin password (press Enter to use auto-generated): ${RESET}" > /dev/tty
  read -rs ADMIN_PASSWORD_INPUT < /dev/tty
  echo "" > /dev/tty
  ADMIN_PASSWORD="${ADMIN_PASSWORD_INPUT:-$rand_pass}"

  step "Downloading WordPress"
  if [[ -f "wp-includes/version.php" ]]; then
    success "WordPress core already present, skipping download"
  else
    wp core download --locale='en_GB' --skip-content
    success "WordPress core downloaded"
  fi

  step "Creating wp-config.php"
  if [[ -f "wp-config.php" ]]; then
    success "wp-config.php already exists, skipping"
  else
    wp config create \
      --dbname="$db_name" \
      --dbuser="$db_user" \
      --dbpass="$db_password" \
      --dbhost="$db_host" \
      --locale='en_GB'
    wp config set WP_HOME    "$SITE_URL"  --type=constant
    wp config set WP_SITEURL "$SITE_URL"  --type=constant
    wp config set WP_DEBUG   false        --type=constant --raw
    success "wp-config.php created"
  fi

  step "Creating database & installing WordPress"
  if wp db query "SELECT 1;" &>/dev/null; then
    success "Database already exists, skipping creation"
  else
    wp db create || error "Could not create database. Check your credentials are correct, that MySQL is running, and try 127.0.0.1 as the DB host rather than localhost."
  fi

  if wp core is-installed &>/dev/null; then
    success "WordPress already installed, skipping"
  else
    wp core install \
      --locale='en_GB' \
      --url="$SITE_URL" \
      --title="$SITE_TITLE" \
      --admin_user="$ADMIN_USER" \
      --admin_email="$admin_email" \
      --admin_password="$ADMIN_PASSWORD" \
      --skip-email
    success "WordPress installed at ${SITE_URL}"
  fi
}

# ─── Step 3: Theme setup ─────────────────────────────────────────────────────

# Set by --theme-version flag; falls back to EREBUS_VERSION constant.
THEME_VERSION_OVERRIDE=""

setup_themes() {
  step "Theme setup"

  local erebus_tag
  if [[ -n "$THEME_VERSION_OVERRIDE" ]]; then
    erebus_tag=$(normalise_version "$THEME_VERSION_OVERRIDE")
  else
    erebus_tag="v${EREBUS_VERSION}"
  fi

  if [[ -d "$EREBUS_THEME_DIR" ]]; then
    success "Erebus already present at ${EREBUS_THEME_DIR}, skipping clone"
  else
    info "Cloning Erebus ${erebus_tag}..."
    git clone --branch "$erebus_tag" --depth 1 "$EREBUS_REPO" "$EREBUS_THEME_DIR" \
      || error "Could not clone Erebus ${erebus_tag}. Check the tag exists: https://github.com/thisisgain/Erebus/releases"
    rm -rf "${EREBUS_THEME_DIR}/.git"
    success "Erebus ${erebus_tag} cloned to ${EREBUS_THEME_DIR}"
  fi

  if wp theme is-active erebus &>/dev/null; then
    success "Erebus already active, skipping"
  else
    wp theme activate erebus
    success "Erebus theme activated"
  fi
}

# ─── Step 4: GitHub Actions deploy workflow ──────────────────────────────────

setup_deploy() {
  step "GitHub Actions deploy workflow"

  local workflows_dir=".github/workflows"
  local deploy_dest="${workflows_dir}/deploy.yml"
  local deploy_src="https://raw.githubusercontent.com/thisisgain/Mimir/main/deploy.yml"

  if [[ -f "$deploy_dest" ]]; then
    success "Deploy workflow already exists, skipping"
    return
  fi

  mkdir -p "$workflows_dir"
  curl -fsSL "$deploy_src" -o "$deploy_dest" \
    || error "Failed to download deploy workflow from ${deploy_src}"

  success "Deploy workflow written to ${deploy_dest}"
  info "Configure the following in your GitHub repo settings before pushing:"
  echo "" >&2
  echo -e "    ${BOLD}Variables:${RESET}  THEME_DIR, WPE_ENV, NODE_VERSION, PHP_VERSION" >&2
  echo -e "    ${BOLD}Secret:${RESET}     WPE_SSHG_KEY_PRIVATE" >&2
  echo "" >&2
}

# ─── Step 5: Plugins (placeholder) ───────────────────────────────────────────

setup_plugins() {
  # TODO: Install default plugin set.
  # Planned: prompt user to select from a predefined list, or pass a plugins
  # config file (e.g. plugins.json) containing slugs / zip URLs to install via
  # `wp plugin install` and activate.
  :
}

# ─── Step 6: Optional config (placeholder) ───────────────────────────────────

setup_config() {
  # TODO: Apply optional WordPress settings (permalink structure, timezone,
  # reading/writing settings, etc.) using `wp option update`.
  # Planned: interactive menu or a config flags file.
  :
}

# ─── Step 7: Build dependencies (placeholder) ────────────────────────────────

setup_build() {
  # TODO: Install front-end build dependencies once build tooling in Erebus
  # is confirmed. Likely: `npm install` in both theme directories, followed
  # by an initial build run.
  :
}

# ─── Step 8: Git initialisation ──────────────────────────────────────────────

setup_git() {
  step "Git repository setup"

  # Write project .gitignore — wp-config.php is intentionally excluded
  cat > .gitignore << 'GITIGNORE'
# WordPress core (downloaded by setup, not version-controlled)
/wp-admin/
/wp-includes/
/wp-*.php
/xmlrpc.php
/license.txt
/readme.html
/index.php

# Config — managed per-environment; added manually on WP Engine
wp-config.php

# Uploads & generated content
wp-content/uploads/
wp-content/upgrade/
wp-content/cache/

# Dependencies
vendor/
node_modules/

# Theme build output
wp-content/themes/*/dist/
wp-content/themes/*/build/
wp-content/themes/**/.cache/

# Environment & OS
.env
.DS_Store
Thumbs.db
*.log

# IDE
.idea/
.vscode/
*.swp
*.swo
GITIGNORE

  success ".gitignore written"

  local git_remote
  git_remote=$(ask "Git remote URL (leave blank to skip)" "")

  git init
  git add .
  git commit -m "Initial project setup for ${SITE_TITLE}"
  git branch -M main

  if [[ -n "$git_remote" ]]; then
    git remote add origin "$git_remote"
    git push -u origin main
    success "Pushed initial commit to ${git_remote}"
  else
    warn "No remote set — run the following when ready:"
    echo "" >&2
    echo -e "    git remote add origin <url>" >&2
    echo -e "    git push -u origin main" >&2
    echo "" >&2
  fi

  success "Git repository initialised on branch 'main'"
}

# ─── Completion summary ───────────────────────────────────────────────────────

print_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}"
  echo "  ╔════════════════════════════════════════════════════════════╗"
  echo "  ║       Setup complete — your project is ready!             ║"
  echo "  ╚════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  echo -e "  ${BOLD}Site URL:${RESET}        ${SITE_URL}"
  echo -e "  ${BOLD}WP Admin:${RESET}        ${SITE_URL}/wp-admin"
  echo -e "  ${BOLD}Admin user:${RESET}      ${ADMIN_USER}"
  echo -e "  ${BOLD}Admin password:${RESET}  ${ADMIN_PASSWORD}"
  echo -e "  ${BOLD}Theme:${RESET}           Erebus v${THEME_VERSION_OVERRIDE:-$EREBUS_VERSION}"
  echo ""
  echo -e "  ${YELLOW}Note: wp-config.php is excluded from git. Add it manually${RESET}"
  echo -e "  ${YELLOW}per environment (e.g. via WP Engine SSH access).${RESET}"
  echo ""
}

# ─── Version helpers ─────────────────────────────────────────────────────────

# Normalise a version string to vX.Y.Z — strips a leading 'v' then re-adds it.
normalise_version() {
  local v="${1#v}"
  echo "v${v}"
}

# Fetch the latest release tag from GitHub.
latest_release_tag() {
  local tag
  tag=$(curl -fsSL "https://api.github.com/repos/${MIMIR_REPO}/releases/latest" \
    | grep '"tag_name"' \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/') \
    || error "Could not reach GitHub — check your internet connection."
  [[ -z "$tag" ]] && error "Could not determine the latest Mimir release."
  echo "$tag"
}

# ─── Update CLI ──────────────────────────────────────────────────────────────

update_cli() {
  local install_path="/usr/local/bin/mimir"
  local version_input=""

  # Parse --version=X.Y.Z or --version X.Y.Z
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version=*) version_input="${1#--version=}"; shift ;;
      --version)   version_input="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done

  echo ""
  echo -e "${BLUE}${BOLD}  Updating Mimir CLI...${RESET}" >&2
  echo ""

  local version_tag
  if [[ -n "$version_input" ]]; then
    version_tag=$(normalise_version "$version_input")
    info "Installing Mimir ${version_tag}..."
  else
    info "Fetching latest Mimir release..."
    version_tag=$(latest_release_tag)
    info "Latest release: ${version_tag}"
  fi

  local script_url="https://raw.githubusercontent.com/${MIMIR_REPO}/${version_tag}/setup.sh"
  local tmp
  tmp=$(mktemp)
  info "Downloading ${script_url}..."
  curl -fsSL "$script_url" -o "$tmp" \
    || error "Failed to download Mimir ${version_tag}. Check the version exists: https://github.com/${MIMIR_REPO}/releases"
  chmod +x "$tmp"
  info "Installing to ${install_path} (may prompt for your password)..."
  sudo mv "$tmp" "$install_path"
  sudo chmod +x "$install_path"
  success "Mimir updated to ${version_tag}"
  echo ""
  exit 0
}

# ─── Version ─────────────────────────────────────────────────────────────────

cmd_version() {
  echo "  Mimir v${MIMIR_VERSION}"
  exit 0
}

# ─── Usage ───────────────────────────────────────────────────────────────────

usage() {
  cat << USAGE

  Mimir v${MIMIR_VERSION} — GAIN WordPress Project Setup

  Usage:
    mimir                                Run the interactive setup wizard
    mimir --theme-version=3.1.0          Use a specific Erebus version
    mimir version                        Print the installed Mimir version
    mimir update-cli                     Update to the latest Mimir release
    mimir update-cli --version=4.2.0     Update to a specific Mimir version
    mimir --help                         Show this help text

  Default Erebus version: ${EREBUS_VERSION}

  Prerequisites:
    - WP-CLI  (https://wp-cli.org)
    - Git
    - PHP 8.2+
    - A local MySQL/MariaDB database accessible to the current environment

  Run this script from an empty directory that will become your project root.

USAGE
  exit 0
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  case "${1:-}" in
    --help|-h)   usage ;;
    version)     cmd_version ;;
    update-cli)  update_cli "${@:2}" ;;
  esac

  # Parse setup flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --theme-version=*) THEME_VERSION_OVERRIDE="${1#--theme-version=}"; shift ;;
      --theme-version)   THEME_VERSION_OVERRIDE="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done

  banner
  check_requirements
  setup_core
  setup_themes
  setup_deploy
  setup_plugins
  setup_config
  setup_build
  setup_git
  print_summary
}

main "$@"
