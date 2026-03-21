#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Parse flags
DRY_RUN=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

# nvm version — update manually when a new stable release is available
NVM_VERSION="v0.40.4"

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
$DRY_RUN && echo -e "\n${YELLOW}${BOLD}Dry run — no changes will be made${RESET}"
echo "-----------------------------------"
echo ""

# Close System Preferences/Settings to prevent it from overriding defaults
osascript -e 'tell application "System Preferences" to quit' 2>/dev/null
osascript -e 'tell application "System Settings" to quit' 2>/dev/null

# Ask for sudo password upfront and keep it alive for the duration of the script
if ! $DRY_RUN; then
  sudo -v
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

# Summary tracking
INSTALLED=()
UPDATED=()
SKIPPED=()
WARNINGS=()

step()      { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
installed() { echo -e "${GREEN}✔ installed $1${RESET}"; INSTALLED+=("$1"); }
ok()        { echo -e "${GREEN}✔ $1${RESET}"; SKIPPED+=("$1"); }
updated()   { echo -e "${BLUE}↑ updated $1${RESET}"; UPDATED+=("$1"); }
warn()      { echo -e "${YELLOW}⚠ $1${RESET}"; WARNINGS+=("$1"); }
would()     { echo -e "  ${BOLD}→${RESET} $1"; }
confirm()   { $DRY_RUN && return 0; read -r -p "  Install $1? [Y/n] " r; [[ "$r" =~ ^[nN] ]] && return 1 || return 0; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install or upgrade a Homebrew formula
brew_formula() {
  local pkg=$1
  if ! command -v brew &>/dev/null; then
    $DRY_RUN && would "brew install $pkg"
    return
  fi
  if brew list --formula "$pkg" &>/dev/null; then
    if $DRY_RUN; then
      would "brew upgrade $pkg"
    else
      if brew upgrade "$pkg" &>/dev/null; then
        updated "$pkg"
      else
        ok "$pkg already up to date"
      fi
    fi
  else
    if $DRY_RUN; then
      would "brew install $pkg"
    else
      if brew install "$pkg" >/dev/null; then
        installed "$pkg"
      else
        warn "Failed to install $pkg"
      fi
    fi
  fi
}

# Install or upgrade a Homebrew cask
# Pass a second argument (CLI command name) to detect installs outside Homebrew
brew_cask() {
  local cask=$1
  local cmd=$2
  if ! command -v brew &>/dev/null; then
    $DRY_RUN && would "brew install --cask $cask"
    return
  fi
  if brew list --cask "$cask" &>/dev/null; then
    if $DRY_RUN; then
      would "brew upgrade --cask $cask"
    else
      if brew upgrade --cask "$cask" &>/dev/null; then
        updated "$cask"
      else
        ok "$cask already up to date"
      fi
    fi
  elif [ -n "$cmd" ] && command -v "$cmd" &>/dev/null; then
    warn "$cask is installed outside Homebrew, skipping"
  else
    if $DRY_RUN; then
      would "brew install --cask $cask"
    else
      if brew install --cask "$cask" >/dev/null; then
        installed "$cask"
      else
        warn "Failed to install $cask"
      fi
    fi
  fi
}

# -------------------------------------------------------
# 1. Config files
# -------------------------------------------------------
step "Loading config files"

for file in .bash_profile .gitconfig .inputrc; do
  if [ -f "$DOTFILES_DIR/$file" ]; then
    if $DRY_RUN; then
      would "cp $file to $HOME/$file"
    else
      cp "$DOTFILES_DIR/$file" "$HOME/$file"
      installed "$file"
    fi
  else
    warn "$file not found, skipping"
  fi
done

# -------------------------------------------------------
# 2. Homebrew
# -------------------------------------------------------
step "Installing Homebrew and packages"

if ! command -v brew &>/dev/null; then
  if $DRY_RUN; then
    would "install Homebrew"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    installed "Homebrew"
    warn "Homebrew was added to this session's PATH — restart your terminal to make it permanent"
  fi
else
  if $DRY_RUN; then
    would "brew update"
  else
    brew update &>/dev/null && ok "Homebrew up to date"
  fi
fi

for pkg in bash git bash-completion@2 yarn gh; do
  brew_formula "$pkg"
done

# -------------------------------------------------------
# 3. SSH keys
# -------------------------------------------------------
step "SSH keys"

SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

if [ -f "$SSH_KEY_PATH" ] || [ -f "$HOME/.ssh/id_rsa" ]; then
  ok "SSH keys already exist"
else
  if $DRY_RUN; then
    would "prompt for key name, generate SSH key, add to GitHub"
  else
    read -r -p "  Name for this SSH key on GitHub [Pedro's Mac]: " SSH_KEY_TITLE
    SSH_KEY_TITLE="${SSH_KEY_TITLE:-Pedro's Mac}"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -C "$SSH_KEY_TITLE"; then
      chmod 600 "$SSH_KEY_PATH"
      chmod 600 "${SSH_KEY_PATH}.pub"
      installed "SSH key (~/.ssh/id_ed25519)"
      if gh auth status &>/dev/null 2>&1; then
        if gh ssh-key add "${SSH_KEY_PATH}.pub" --title "$SSH_KEY_TITLE"; then
          installed "SSH key on GitHub"
        else
          warn "Failed to add SSH key to GitHub — run manually: gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
        fi
      else
        warn "Not authenticated with GitHub — run 'gh auth login' then: gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
      fi
    else
      warn "Failed to generate SSH key"
    fi
  fi
fi

# VS Code: check for app first, then CLI
if [ -d "/Applications/Visual Studio Code.app" ]; then
  if command -v brew &>/dev/null && brew list --cask visual-studio-code &>/dev/null; then
    if $DRY_RUN; then
      would "brew upgrade --cask visual-studio-code"
    else
      if brew upgrade --cask visual-studio-code &>/dev/null; then
        updated "visual-studio-code"
      else
        ok "visual-studio-code already up to date"
      fi
    fi
  else
    ok "VS Code installed outside Homebrew, skipping"
  fi
  if ! command -v code &>/dev/null; then
    warn "VS Code CLI not found — in VS Code, open the Command Palette and run: Shell Command: Install 'code' command in PATH"
  fi
else
  if $DRY_RUN; then
    would "brew install --cask visual-studio-code"
  else
    if brew install --cask visual-studio-code >/dev/null; then
      installed "visual-studio-code"
    else
      warn "Failed to install visual-studio-code"
    fi
  fi
fi

brew_cask "claude-code" "claude"
brew_cask "font-fira-code"

# -------------------------------------------------------
# 4. Switch to Homebrew bash
# -------------------------------------------------------
step "Setting Homebrew bash as default shell"

HOMEBREW_BASH="/opt/homebrew/bin/bash"

if ! $DRY_RUN && [ ! -f "$HOMEBREW_BASH" ]; then
  warn "Homebrew bash not found at $HOMEBREW_BASH — was 'brew install bash' successful? Skipping shell switch"
else
  if grep -q "$HOMEBREW_BASH" /etc/shells; then
    ok "$HOMEBREW_BASH already in /etc/shells"
  else
    if $DRY_RUN; then
      would "echo $HOMEBREW_BASH | sudo tee -a /etc/shells"
    else
      if echo "$HOMEBREW_BASH" | sudo tee -a /etc/shells >/dev/null; then
        installed "$HOMEBREW_BASH in /etc/shells"
      else
        warn "Failed to add $HOMEBREW_BASH to /etc/shells — try manually: echo \"$HOMEBREW_BASH\" | sudo tee -a /etc/shells"
      fi
    fi
  fi

  if [ "$SHELL" = "$HOMEBREW_BASH" ]; then
    ok "Already using Homebrew bash"
  else
    if $DRY_RUN; then
      would "chsh -s $HOMEBREW_BASH"
    else
      if chsh -s "$HOMEBREW_BASH"; then
        installed "default shell → $HOMEBREW_BASH"
      else
        warn "Failed to set default shell — try manually: chsh -s $HOMEBREW_BASH"
      fi
    fi
  fi
fi

# -------------------------------------------------------
# 5. Node.js via nvm
# -------------------------------------------------------
step "Installing Node.js"

if [ -d "$HOME/.nvm" ]; then
  ok "nvm already installed"
else
  if $DRY_RUN; then
    would "install nvm $NVM_VERSION"
  else
    if curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash; then
      installed "nvm $NVM_VERSION"
    else
      warn "Failed to install nvm"
    fi
  fi
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if $DRY_RUN; then
  would "nvm install --lts && nvm alias default node"
else
  if nvm install --lts >/dev/null 2>&1 && nvm alias default node >/dev/null 2>&1; then
    ok "Node.js LTS up to date ($(node --version))"
  else
    warn "Failed to install Node.js LTS"
  fi
fi

# -------------------------------------------------------
# 6. VS Code extensions and settings
# -------------------------------------------------------
step "Setting up VS Code"

if ! command -v code &>/dev/null; then
  warn "VS Code CLI not found — in VS Code, open the Command Palette and run: Shell Command: Install 'code' command in PATH"
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
    if $DRY_RUN; then
      would "code --install-extension $ext"
    else
      if code --install-extension "$ext" --force &>/dev/null; then
        installed "$ext"
      else
        warn "Failed to install extension $ext"
      fi
    fi
  done

  VSCODE_DIR="$HOME/Library/Application Support/Code/User"

  if $DRY_RUN; then
    would "cp settings.json and keybindings.json to VS Code"
  else
    mkdir -p "$VSCODE_DIR"
    cp "$DOTFILES_DIR/settings.json" "$VSCODE_DIR/settings.json" && installed "settings.json"
    cp "$DOTFILES_DIR/keybindings.json" "$VSCODE_DIR/keybindings.json" && installed "keybindings.json"
  fi
fi

# -------------------------------------------------------
# 7. Apps
# -------------------------------------------------------
step "Installing apps"

confirm "google-chrome" && brew_cask "google-chrome"
confirm "spotify"       && brew_cask "spotify"
confirm "1password"     && brew_cask "1password"

# -------------------------------------------------------
# 8. macOS Preferences
# -------------------------------------------------------
step "Applying macOS preferences"

if $DRY_RUN; then
  would "configure Dock, Finder, and System Settings"
else
  # Dock
  defaults write com.apple.dock orientation left
  defaults write com.apple.dock tilesize -integer 40
  defaults write com.apple.dock size-immutable -bool true
  defaults write com.apple.dock minimize-to-application -bool true
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
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder ShowRecentTags -bool false
  defaults write com.apple.finder FXPreferredViewStyle -string "icnv"
  defaults write com.apple.finder NewWindowTarget -string "PfHm"
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  ok "Finder configured"

  # System Settings
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write NSGlobalDomain AppleInterfaceStyle Dark
  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  defaults write NSGlobalDomain AppleActionOnDoubleClick Minimize
  defaults write NSGlobalDomain KeyRepeat -int 5
  defaults write NSGlobalDomain InitialKeyRepeat -int 25
  defaults write NSGlobalDomain com.apple.sound.beep.feedback -int 0
  ok "System settings configured"

  # Restart Finder and Dock
  killall Finder
  killall Dock
  ok "Finder and Dock restarted"
fi

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo -e "${BOLD}-----------------------------------${RESET}"
echo -e "${BOLD}Summary${RESET}"
echo -e "${BOLD}-----------------------------------${RESET}"
[ ${#INSTALLED[@]} -gt 0 ] && echo -e "${GREEN}✔ Installed (${#INSTALLED[@]}):${RESET} $(printf '%s, ' "${INSTALLED[@]}" | sed 's/, $//')"
[ ${#UPDATED[@]} -gt 0 ]   && echo -e "${BLUE}↑ Updated (${#UPDATED[@]}):${RESET} $(printf '%s, ' "${UPDATED[@]}" | sed 's/, $//')"
[ ${#SKIPPED[@]} -gt 0 ]   && echo -e "  Skipped (${#SKIPPED[@]}): $(printf '%s, ' "${SKIPPED[@]}" | sed 's/, $//')"
[ ${#WARNINGS[@]} -gt 0 ]  && echo -e "${YELLOW}⚠ Warnings (${#WARNINGS[@]}):${RESET} $(printf '%s, ' "${WARNINGS[@]}" | sed 's/, $//')"
echo ""
$DRY_RUN || echo -e "${GREEN}${BOLD}All done! Restart your terminal to apply all changes.${RESET}"
echo ""
