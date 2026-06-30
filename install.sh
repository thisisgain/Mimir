#!/usr/bin/env bash

# ─── Mimir — Global installer ────────────────────────────────────────────────
# Installs the `mimir` command to /usr/local/bin so it can be run from
# any directory. Requires sudo.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/thisisgain/Mimir/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/thisisgain/Mimir/main/install.sh | bash -s -- --version=4.0.0

set -eo pipefail

MIMIR_REPO="thisisgain/Mimir"
INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="${INSTALL_DIR}/mimir"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "  ${BLUE}→ $1${RESET}"; }
success() { echo -e "  ${GREEN}✓ $1${RESET}"; }
error()   { echo -e "\n  ${RED}${BOLD}✗ $1${RESET}" >&2; exit 1; }

# Parse --version=X.Y.Z or --version X.Y.Z
VERSION_INPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version=*) VERSION_INPUT="${1#--version=}"; shift ;;
    --version)   VERSION_INPUT="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

echo ""
echo -e "${BLUE}${BOLD}  Installing Mimir...${RESET}"
echo ""

# Resolve version tag
if [[ -n "$VERSION_INPUT" ]]; then
  # Normalise: strip leading 'v', then re-add
  VERSION_TAG="v${VERSION_INPUT#v}"
  info "Installing Mimir ${VERSION_TAG}..."
else
  info "Fetching latest Mimir release..."
  VERSION_TAG=$(curl -fsSL "https://api.github.com/repos/${MIMIR_REPO}/releases/latest" \
    | grep '"tag_name"' \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/') \
    || error "Could not reach GitHub — check your internet connection."
  [[ -z "$VERSION_TAG" ]] && error "Could not determine the latest Mimir release."
  info "Latest release: ${VERSION_TAG}"
fi

SCRIPT_URL="https://raw.githubusercontent.com/${MIMIR_REPO}/${VERSION_TAG}/setup.sh"

# Download
info "Downloading setup script..."
TMP=$(mktemp)
curl -fsSL "$SCRIPT_URL" -o "$TMP" \
  || error "Failed to download Mimir ${VERSION_TAG}. Check the version exists: https://github.com/${MIMIR_REPO}/releases"

chmod +x "$TMP"

# Install to /usr/local/bin (requires sudo)
info "Installing to ${INSTALL_PATH} (may prompt for your password)..."
sudo mv "$TMP" "$INSTALL_PATH"
sudo chmod +x "$INSTALL_PATH"

success "Mimir ${VERSION_TAG} installed to ${INSTALL_PATH}"
echo ""
echo -e "  Run ${BOLD}mimir${RESET} from any new empty project directory to get started."
echo -e "  Run ${BOLD}mimir version${RESET} to confirm the installed version."
echo ""
