#!/bin/bash
# Anylytical Technologies - developer Mac setup
# ------------------------------------------------
# Installs Homebrew (if needed), then everything in the shared Brewfile, links Java,
# and checks the result. Safe to run again: it skips anything already installed.
#
# FIRST-TIME SETUP (admin rights needed - turn on Privileges first, if the Mac has it):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/v94553839-hue/Test-Brewfile/main/setup-mac.sh)"
#
# UPDATING LATER (no admin needed):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/v94553839-hue/Test-Brewfile/main/setup-mac.sh)" -- --update

set -euo pipefail

# >>> Change this to the Raw link of your Brewfile <<<
BREWFILE_URL="https://raw.githubusercontent.com/v94553839-hue/Test-Brewfile/main/Brewfile"

BREWFILE="$HOME/Brewfile"
BREW="/opt/homebrew/bin/brew"
JAVA_FORMULA="openjdk@25"
JAVA_LINK="/Library/Java/JavaVirtualMachines/openjdk-25.jdk"
UPDATE_ONLY=false
[[ "${1:-}" == "--update" ]] && UPDATE_ONLY=true

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✖ %s\033[0m\n' "$*"; exit 1; }

# --- Basic checks -----------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || fail "This script is for macOS."
[[ "$(uname -m)" == "arm64" ]]  || fail "This Mac doesn't have an Apple chip (Apple silicon)."
[[ "$EUID" -ne 0 ]]             || fail "Run this as yourself, not with sudo."

# --- Admin rights (first-time setup only) -----------------------------------
if [[ "$UPDATE_ONLY" == false ]]; then
  if ! groups | grep -qw admin; then
    fail "Your account isn't an admin right now. Turn on admin rights in Privileges, then run this again."
  fi
  say "Enter your Mac password once (nothing shows as you type - that's normal)"
  sudo -v
  # Keep the password valid until the script finishes
  while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
  SUDO_KEEPALIVE=$!
  trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT
fi

# --- 1. Homebrew --------------------------------------------------------------
if [[ -x "$BREW" ]]; then
  ok "Homebrew is already installed"
else
  [[ "$UPDATE_ONLY" == true ]] && fail "Homebrew isn't installed yet. Run the first-time setup command instead."
  say "Installing Homebrew (and Apple's developer tools) - this can take 10 minutes"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make Homebrew available now and in every future Terminal window
eval "$("$BREW" shellenv)"
if ! grep -qs 'brew shellenv' "$HOME/.zprofile"; then
  { echo; echo "eval \"\$($BREW shellenv)\""; } >> "$HOME/.zprofile"
  ok "Added Homebrew to ~/.zprofile"
fi

# --- 2. Brewfile --------------------------------------------------------------
say "Downloading the latest Brewfile"
curl -fsSL "$BREWFILE_URL" -o "$BREWFILE" || fail "Couldn't download the Brewfile. Check BREWFILE_URL at the top of this script."
ok "Saved to $BREWFILE"

say "Installing apps and tools from the Brewfile - this can take 10 to 20 minutes"
brew update || warn "Couldn't refresh Homebrew's app list - carrying on"
brew bundle --file="$BREWFILE" || warn "Some items had problems - the check at the end will list them"
if [[ "$UPDATE_ONLY" == true ]]; then
  say "Updating everything already installed"
  brew upgrade || warn "Some updates had problems - run this command again later"
fi

# --- 3. Java link (first-time setup only) ---------------------------------
if [[ "$UPDATE_ONLY" == false ]] && brew list --versions "$JAVA_FORMULA" >/dev/null 2>&1; then
  if [[ ! -e "$JAVA_LINK" ]]; then
    say "Linking Java so other tools can find it"
    sudo ln -sfn "$(brew --prefix)/opt/$JAVA_FORMULA/libexec/openjdk.jdk" "$JAVA_LINK"
  fi
  ok "Java is linked"
fi

# --- 4. Check -----------------------------------------------------------------
say "Checking everything installed"
if brew bundle check --file="$BREWFILE"; then
  ok "All done."
else
  warn "Some items didn't install. Run this command again - it picks up where it stopped."
  exit 1
fi

if [[ "$UPDATE_ONLY" == false ]]; then
  cat <<'NEXT'

Last steps (a few minutes):
  1. Open Docker Desktop and Parallels Desktop once from Applications, and accept their setup prompts.
  2. Open JetBrains Toolbox from your own Applications folder (your home folder > Applications),
     sign in, and install IntelliJ IDEA.
  3. Admin rights can now switch off.
NEXT
fi

