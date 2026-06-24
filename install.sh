#!/usr/bin/env bash

# ─── Mimir — Global installer ────────────────────────────────────────────────
# Installs the `mimir` command to /usr/local/bin so it can be run from
# any directory. Requires sudo.
#
# Usage: curl -fsSL https://raw.githubusercontent.com/thisisgain/Mimir/main/install.sh | bash

set -eo pipefail

INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="${INSTALL_DIR}/mimir"
SCRIPT_URL="https://raw.githubusercontent.com/thisisgain/Mimir/main/setup.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "  ${BLUE}→ $1${RESET}"; }
success() { echo -e "  ${GREEN}✓ $1${RESET}"; }
error()   { echo -e "\n  ${RED}${BOLD}✗ $1${RESET}" >&2; exit 1; }

echo ""
echo -e "${BLUE}${BOLD}  Installing Mimir...${RESET}"
echo ""

# Download the setup script
info "Downloading setup script..."
TMP=$(mktemp)
curl -fsSL "$SCRIPT_URL" -o "$TMP" || error "Failed to download setup script from ${SCRIPT_URL}"

chmod +x "$TMP"

# Install to /usr/local/bin (requires sudo)
info "Installing to ${INSTALL_PATH} (may prompt for your password)..."
sudo mv "$TMP" "$INSTALL_PATH"
sudo chmod +x "$INSTALL_PATH"

success "mimir installed to ${INSTALL_PATH}"
echo ""
echo -e "  Run ${BOLD}mimir${RESET} from any new empty project directory to get started."
echo ""
