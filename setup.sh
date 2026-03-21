#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ASCII art
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
 _     _   _                  _               _
| |__ | |_| |_ _ __   ___  __| |_ __ ___   __| | _____   __
| '_ \| __| __| '_ \ / _ \/ _` | '__/ _ \ / _` |/ _ \ \ / /
| | | | |_| |_| |_) |  __/ (_| | | | (_) | (_| |  __/\ V /
|_| |_|\__|\__| .__/ \___|\__,_|_|  \___(_)__,_|\___| \_/
              |_|
EOF
echo -e "${RESET}"
echo -e "${BOLD}macOS Setup Script${RESET}"
echo "-----------------------------------"
echo ""

step()    { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
ok()      { echo -e "${GREEN}✔ $1${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $1${RESET}"; }
updated() { echo -e "${CYAN}↑ $1${RESET}"; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install or upgrade a Homebrew formula
brew_formula() {
  local pkg=$1
  if brew list --formula "$pkg" &>/dev/null; then
    brew upgrade "$pkg" &>/dev/null && updated "$pkg upgraded" || ok "$pkg already up to date"
  else
    brew install "$pkg" && ok "Installed $pkg"
  fi
}

# Install or upgrade a Homebrew cask
# Pass a second argument to check if it's already installed via a CLI command
brew_cask() {
  local cask=$1
  local cmd=$2
  if brew list --cask "$cask" &>/dev/null; then
    brew upgrade --cask "$cask" &>/dev/null && updated "$cask upgraded" || ok "$cask already up to date"
  elif [ -n "$cmd" ] && command -v "$cmd" &>/dev/null; then
    warn "$cask is installed outside Homebrew, skipping"
  else
    brew install --cask "$cask" && ok "Installed $cask"
  fi
}

# -------------------------------------------------------
# 1. Config files
# -------------------------------------------------------
step "Loading config files"

for file in .bash_profile .gitconfig .inputrc; do
  if [ -f "$DOTFILES_DIR/$file" ]; then
    cp "$DOTFILES_DIR/$file" "$HOME/$file"
    ok "Copied $file"
  else
    warn "$file not found, skipping"
  fi
done

# -------------------------------------------------------
# 2. SSH keys
# -------------------------------------------------------
step "SSH keys"
if [ -f "$HOME/.ssh/id_rsa" ]; then
  ok "SSH keys already exist"
else
  warn "No SSH keys found — generate them manually or copy existing ones to ~/.ssh"
fi

# -------------------------------------------------------
# 3. Homebrew
# -------------------------------------------------------
step "Installing Homebrew and packages"

if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  ok "Homebrew installed"
  warn "Homebrew was added to this session's PATH only — your shell will need a restart to pick it up permanently"
else
  brew update &>/dev/null && ok "Homebrew updated"
fi

for pkg in bash git bash-completion@2 yarn gh; do
  brew_formula "$pkg"
done

# VS Code: check for app first, then CLI
if [ -d "/Applications/Visual Studio Code.app" ]; then
  if brew list --cask visual-studio-code &>/dev/null; then
    brew upgrade --cask visual-studio-code &>/dev/null && updated "visual-studio-code upgraded" || ok "visual-studio-code already up to date"
  else
    ok "VS Code installed outside Homebrew, skipping"
  fi
  if ! command -v code &>/dev/null; then
    warn "VS Code CLI not found — open VS Code and run: Shell Command: Install 'code' command in PATH"
  fi
else
  brew install --cask visual-studio-code && ok "Installed visual-studio-code"
fi

brew_cask "claude-code" "claude"
brew_cask "font-fira-code"

# -------------------------------------------------------
# 4. Switch to Homebrew bash
# -------------------------------------------------------
step "Setting Homebrew bash as default shell"

HOMEBREW_BASH="/opt/homebrew/bin/bash"

if grep -q "$HOMEBREW_BASH" /etc/shells; then
  ok "$HOMEBREW_BASH already in /etc/shells"
else
  echo "$HOMEBREW_BASH" | sudo tee -a /etc/shells
  ok "Added $HOMEBREW_BASH to /etc/shells"
fi

if [ "$SHELL" = "$HOMEBREW_BASH" ]; then
  ok "Already using Homebrew bash"
else
  chsh -s "$HOMEBREW_BASH"
  ok "Default shell set to $HOMEBREW_BASH"
fi

# -------------------------------------------------------
# 5. Node.js via nvm
# -------------------------------------------------------
step "Installing nvm and Node.js"

if [ -d "$HOME/.nvm" ]; then
  # Reinstalling nvm upgrades it in place
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash &>/dev/null
  ok "nvm up to date"
else
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
  ok "nvm installed"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Always install latest LTS — nvm skips if already on latest
nvm install --lts &>/dev/null && nvm alias default node
ok "Node.js LTS up to date ($(node --version))"

# -------------------------------------------------------
# 6. VS Code extensions and settings
# -------------------------------------------------------
step "Setting up VS Code"

if ! command -v code &>/dev/null; then
  warn "VS Code CLI not found — open VS Code and run: Shell Command: Install 'code' command in PATH"
else
  extensions=(
    anthropic.claude-code
    bradlc.vscode-tailwindcss
    christian-kohler.npm-intellisense
    christian-kohler.path-intellisense
    dbaeumer.vscode-eslint
    eamodio.gitlens
    editorconfig.editorconfig
    esbenp.prettier-vscode
    github.github-vscode-theme
    kamikillerto.vscode-colorize
    tyriar.sort-lines
    wix.vscode-import-cost
    yummygum.city-lights-icon-vsc
  )

  for ext in "${extensions[@]}"; do
    code --install-extension "$ext" --force &>/dev/null && ok "Installed/updated $ext"
  done

  VSCODE_DIR="$HOME/Library/Application Support/Code/User"
  mkdir -p "$VSCODE_DIR"

  cp "$DOTFILES_DIR/settings.json" "$VSCODE_DIR/settings.json" && ok "Copied settings.json"
  cp "$DOTFILES_DIR/keybindings.json" "$VSCODE_DIR/keybindings.json" && ok "Copied keybindings.json"
fi

# -------------------------------------------------------
# 7. macOS Preferences
# -------------------------------------------------------
step "Applying macOS preferences"

# Dock
defaults write com.apple.dock orientation left
defaults write com.apple.dock tilesize -integer 40
defaults write com.apple.dock size-immutable -bool true
defaults delete com.apple.dock persistent-apps 2>/dev/null
defaults delete com.apple.dock persistent-others 2>/dev/null
defaults write com.apple.dock show-recents -bool false
ok "Dock configured"

# Hot corners (disabled)
defaults write com.apple.dock wvous-tl-corner -int 1
defaults write com.apple.dock wvous-tr-corner -int 1
defaults write com.apple.dock wvous-bl-corner -int 1
defaults write com.apple.dock wvous-br-corner -int 1
ok "Hot corners disabled"

# Finder
defaults write com.apple.finder AppleShowAllFiles true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
ok "Finder configured"

# System Settings
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
ok "System settings configured"

# Restart Finder and Dock
killall Finder
killall Dock
ok "Finder and Dock restarted"

# -------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}All done! Restart your terminal to apply all changes.${RESET}"
echo ""
