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
VERBOSE=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
  [[ "$arg" == "--verbose" ]] && VERBOSE=true
done

# nvm version — update manually when a new stable release is available
NVM_VERSION="v0.40.4"

# ASCII art
printf "${CYAN}${BOLD}"
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
WARNINGS=()

# Per-section summaries
SUM_XCODE=""
SUM_DOTFILES=""
SUM_HOMEBREW=""
SUM_SSH=""
SUM_SHELL=""
SUM_NODE=""
SUM_VSCODE=""
SUM_APPS=""
SUM_TERMINAL=""
SUM_MACOS=""
SUM_PERIPHERALS=""

# Brew counters (shared across brew_formula/brew_cask calls)
BREW_OK=0
BREW_UPDATED=0
BREW_INSTALLED=0

step()      { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
installed() { echo -e "${GREEN}✔ installed $1${RESET}"; INSTALLED+=("$1"); }
ok()        { $VERBOSE && echo -e "${CYAN}✔ $1${RESET}"; }
updated()   { echo -e "${BLUE}↑ Updated $1${RESET}"; UPDATED+=("$1"); }
warn()      { echo -e "${YELLOW}⚠ $1${RESET}"; WARNINGS+=("$1"); }
would()     { echo -e "  ${BOLD}→${RESET} $1"; }

join_arr() {
  local sep=$1; shift
  local result="" first=true
  for item in "$@"; do
    $first && result="$item" || result="$result$sep$item"
    first=false
  done
  echo "$result"
}

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
      would "brew upgrade $pkg (if outdated)"
    else
      if brew outdated --formula | grep -q "^$pkg$"; then
        read -r -p "  Upgrade $pkg? [Y/n] " r
        if [[ ! "$r" =~ ^[nN] ]]; then
          if brew upgrade "$pkg" &>/dev/null; then
            updated "$pkg"
            BREW_UPDATED=$((BREW_UPDATED+1))
          else
            warn "Failed to upgrade $pkg"
            return 1
          fi
        else
          ok "$pkg upgrade skipped"
          BREW_OK=$((BREW_OK+1))
        fi
      else
        ok "$pkg already up to date"
        BREW_OK=$((BREW_OK+1))
      fi
    fi
  else
    if $DRY_RUN; then
      would "brew install $pkg"
    else
      if brew install "$pkg" &>/dev/null; then
        installed "$pkg"
        BREW_INSTALLED=$((BREW_INSTALLED+1))
      else
        warn "Failed to install $pkg"
        return 1
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
      would "brew upgrade --cask $cask (if outdated)"
    else
      if brew outdated --cask | grep -q "^$cask$"; then
        read -r -p "  Upgrade $cask? [Y/n] " r
        if [[ ! "$r" =~ ^[nN] ]]; then
          if brew upgrade --cask "$cask" &>/dev/null; then
            updated "$cask"
            BREW_UPDATED=$((BREW_UPDATED+1))
          else
            warn "Failed to upgrade $cask"
            return 1
          fi
        else
          ok "$cask upgrade skipped"
          BREW_OK=$((BREW_OK+1))
        fi
      else
        ok "$cask already up to date"
        BREW_OK=$((BREW_OK+1))
      fi
    fi
  elif [ -n "$cmd" ] && command -v "$cmd" &>/dev/null; then
    warn "$cask is installed outside Homebrew, skipping"
  else
    if $DRY_RUN; then
      would "brew install --cask $cask"
    else
      if brew install --cask "$cask" &>/dev/null; then
        installed "$cask"
        BREW_INSTALLED=$((BREW_INSTALLED+1))
      else
        warn "Failed to install $cask"
        return 1
      fi
    fi
  fi
}

# -------------------------------------------------------
# 0. Xcode Command Line Tools
# -------------------------------------------------------
step "Checking Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
  ok "Xcode CLT already installed"
  SUM_XCODE="${GREEN}✔${RESET} installed"
else
  if $DRY_RUN; then
    would "xcode-select --install"
  else
    xcode-select --install 2>/dev/null || true
    warn "Xcode CLT installation started — complete the installer, then re-run this script"
    exit 1
  fi
fi

# -------------------------------------------------------
# 1. Config files
# -------------------------------------------------------
step "Loading config files"

CF_OK=()
for file in .bash_profile .gitconfig .inputrc; do
  if [ -f "$DOTFILES_DIR/$file" ]; then
    if $DRY_RUN; then
      would "cp $file to $HOME/$file"
    else
      if [ -f "$HOME/$file" ]; then
        if diff -q "$HOME/$file" "$DOTFILES_DIR/$file" &>/dev/null; then
          ok "$file already up to date"
          CF_OK+=("$file")
          continue
        fi
        echo "  Diff for $file:"
        diff --color=always "$HOME/$file" "$DOTFILES_DIR/$file"
        read -r -p "  $file already exists. Overwrite? [Y/n] " r
        if [[ "$r" =~ ^[nN] ]]; then
          ok "$file unchanged"
          CF_OK+=("$file")
          continue
        fi
      fi
      cp "$DOTFILES_DIR/$file" "$HOME/$file"
      installed "$file"
      CF_OK+=("$file")
    fi
  else
    warn "$file not found, skipping"
  fi
done
# SSH config (deploys to ~/.ssh/config, not $HOME directly)
if [ -f "$DOTFILES_DIR/ssh_config" ]; then
  if $DRY_RUN; then
    would "cp ssh_config to ~/.ssh/config"
  else
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if [ -f "$HOME/.ssh/config" ]; then
      if diff -q "$HOME/.ssh/config" "$DOTFILES_DIR/ssh_config" &>/dev/null; then
        ok "~/.ssh/config already up to date"
        CF_OK+=("ssh_config")
      else
        echo "  Diff for ~/.ssh/config:"
        diff --color=always "$HOME/.ssh/config" "$DOTFILES_DIR/ssh_config"
        read -r -p "  ~/.ssh/config already exists. Overwrite? [Y/n] " r
        if [[ ! "$r" =~ ^[nN] ]]; then
          cp "$DOTFILES_DIR/ssh_config" "$HOME/.ssh/config"
          chmod 600 "$HOME/.ssh/config"
          installed "~/.ssh/config"
        else
          ok "~/.ssh/config unchanged"
        fi
        CF_OK+=("ssh_config")
      fi
    else
      cp "$DOTFILES_DIR/ssh_config" "$HOME/.ssh/config"
      chmod 600 "$HOME/.ssh/config"
      installed "~/.ssh/config"
      CF_OK+=("ssh_config")
    fi
  fi
else
  warn "ssh_config not found, skipping"
fi

[ ${#CF_OK[@]} -gt 0 ] && SUM_DOTFILES="${GREEN}✔${RESET} $(join_arr ' · ' "${CF_OK[@]}")"

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

for pkg in bash git bash-completion@2 yarn gh dockutil; do
  brew_formula "$pkg"
done

# VS Code: check app bundle first since 'code' CLI may not be in PATH
if [ -d "/Applications/Visual Studio Code.app" ]; then
  if command -v brew &>/dev/null && brew list --cask visual-studio-code &>/dev/null; then
    brew_cask "visual-studio-code"
  else
    ok "VS Code installed outside Homebrew, skipping"
  fi
else
  brew_cask "visual-studio-code"
fi

brew_cask "claude-code" "claude"
brew_cask "font-fira-code"

HB_PARTS=()
[ $BREW_INSTALLED -gt 0 ] && HB_PARTS+=("${BREW_INSTALLED} installed")
[ $BREW_UPDATED -gt 0 ]   && HB_PARTS+=("${BREW_UPDATED} updated")
[ $BREW_OK -gt 0 ]        && HB_PARTS+=("${BREW_OK} up to date")
[ ${#HB_PARTS[@]} -gt 0 ] && SUM_HOMEBREW="${GREEN}✔${RESET} $(join_arr ' · ' "${HB_PARTS[@]}")"

# -------------------------------------------------------
# 3. SSH keys
# -------------------------------------------------------
step "SSH keys"

SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

if [ -f "$SSH_KEY_PATH" ] || [ -f "$HOME/.ssh/id_rsa" ]; then
  ok "SSH keys already exist"
  SUM_SSH="${GREEN}✔${RESET} keys exist"
else
  if $DRY_RUN; then
    would "generate SSH key, add to GitHub with title $(hostname | sed 's/\.local$//')"
  else
    SSH_KEY_TITLE="$(hostname)"
    SSH_KEY_TITLE="${SSH_KEY_TITLE%.local}"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if ssh-keygen -t ed25519 -f "$SSH_KEY_PATH"; then
      chmod 600 "$SSH_KEY_PATH"
      chmod 600 "${SSH_KEY_PATH}.pub"
      installed "SSH key (~/.ssh/id_ed25519)"
      ssh-add --apple-use-keychain "$SSH_KEY_PATH" 2>/dev/null && ok "SSH key added to keychain agent"
      SUM_SSH="${GREEN}✔${RESET} key generated"
      if gh auth status &>/dev/null 2>&1; then
        if gh ssh-key add "${SSH_KEY_PATH}.pub" --title "$SSH_KEY_TITLE"; then
          installed "SSH key on GitHub"
          SUM_SSH="${GREEN}✔${RESET} key generated · added to GitHub"
        else
          warn "Failed to add SSH key to GitHub — run manually: gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
        fi
      else
        read -r -p "  Not authenticated with GitHub. Run gh auth login now? [Y/n] " r
        if [[ ! "$r" =~ ^[nN] ]]; then
          gh auth login
          if gh auth status &>/dev/null 2>&1; then
            if gh ssh-key add "${SSH_KEY_PATH}.pub" --title "$SSH_KEY_TITLE"; then
              installed "SSH key on GitHub"
              SUM_SSH="${GREEN}✔${RESET} key generated · added to GitHub"
            else
              warn "Failed to add SSH key to GitHub — run manually: gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
            fi
          else
            warn "Still not authenticated — run manually: gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
          fi
        else
          warn "Skipped GitHub login — run manually: gh auth login && gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
        fi
      fi
    else
      warn "Failed to generate SSH key"
    fi
  fi
fi

# -------------------------------------------------------
# 4. Switch to Homebrew bash
# -------------------------------------------------------
step "Setting Homebrew bash as default shell"

HOMEBREW_BASH="/opt/homebrew/bin/bash"

if ! $DRY_RUN && [ ! -f "$HOMEBREW_BASH" ]; then
  warn "Homebrew bash not found at $HOMEBREW_BASH — was 'brew install bash' successful? Skipping shell switch"
  SUM_SHELL="${YELLOW}⚠${RESET} Homebrew bash not found"
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
    SUM_SHELL="${GREEN}✔${RESET} Homebrew bash active"
  else
    if $DRY_RUN; then
      would "chsh -s $HOMEBREW_BASH"
    else
      read -r -p "  Switch default shell to Homebrew bash? [Y/n] " r
      if [[ ! "$r" =~ ^[nN] ]]; then
        if chsh -s "$HOMEBREW_BASH"; then
          installed "default shell → $HOMEBREW_BASH"
          SUM_SHELL="${GREEN}✔${RESET} switched to Homebrew bash"
        else
          warn "Failed to set default shell — try manually: chsh -s $HOMEBREW_BASH"
          SUM_SHELL="${YELLOW}⚠${RESET} switch failed"
        fi
      else
        ok "Shell unchanged"
        SUM_SHELL="${CYAN}✔${RESET} unchanged"
      fi
    fi
  fi
fi

# -------------------------------------------------------
# 5. Node.js via nvm
# -------------------------------------------------------
step "Installing Node.js"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if [ -d "$HOME/.nvm" ]; then
  current_nvm=$(nvm --version 2>/dev/null)
  if [ "$current_nvm" = "${NVM_VERSION#v}" ]; then
    ok "nvm $NVM_VERSION"
  else
    if $DRY_RUN; then
      would "update nvm $current_nvm → $NVM_VERSION"
    else
      read -r -p "  Upgrade nvm $current_nvm → $NVM_VERSION? [Y/n] " r
      if [[ ! "$r" =~ ^[nN] ]]; then
        if curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash &>/dev/null; then
          [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
          updated "nvm $current_nvm → $NVM_VERSION"
        else
          warn "Failed to update nvm"
        fi
      else
        ok "nvm upgrade skipped"
      fi
    fi
  fi
else
  if $DRY_RUN; then
    would "install nvm $NVM_VERSION"
  else
    if curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash &>/dev/null; then
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      installed "nvm $NVM_VERSION"
    else
      warn "Failed to install nvm"
    fi
  fi
fi

if $DRY_RUN; then
  would "nvm install --lts && nvm alias default node"
else
  prev_node=$(node --version 2>/dev/null || echo "none")
  latest_lts=$(nvm version-remote --lts 2>/dev/null)
  if [ "$prev_node" = "$latest_lts" ]; then
    ok "Node.js LTS ($prev_node)"
    SUM_NODE="${GREEN}✔${RESET} $prev_node"
  elif [ -n "$latest_lts" ] && [ "$prev_node" != "none" ]; then
    read -r -p "  Upgrade Node.js $prev_node → $latest_lts? [Y/n] " r
    if [[ ! "$r" =~ ^[nN] ]]; then
      if nvm install "$latest_lts" >/dev/null 2>&1 && nvm alias default node >/dev/null 2>&1; then
        updated "Node.js LTS $prev_node → $latest_lts"
        SUM_NODE="${BLUE}↑${RESET} $latest_lts"
      else
        warn "Failed to upgrade Node.js LTS"
        SUM_NODE="${YELLOW}⚠${RESET} upgrade failed"
      fi
    else
      ok "Node.js upgrade skipped"
      SUM_NODE="${GREEN}✔${RESET} $prev_node"
    fi
  else
    if nvm install --lts >/dev/null 2>&1 && nvm alias default node >/dev/null 2>&1; then
      NODE_VERSION=$(node --version 2>/dev/null || echo 'unknown')
      installed "Node.js LTS ($NODE_VERSION)"
      SUM_NODE="${GREEN}✔${RESET} $NODE_VERSION"
    else
      warn "Failed to install Node.js LTS"
      SUM_NODE="${YELLOW}⚠${RESET} install failed"
    fi
  fi
fi

# -------------------------------------------------------
# 6. VS Code extensions and settings
# -------------------------------------------------------
step "Setting up VS Code"

if ! command -v code &>/dev/null; then
  warn "VS Code CLI not found — in VS Code, open the Command Palette and run: Shell Command: Install 'code' command in PATH"
  SUM_VSCODE="${YELLOW}⚠${RESET} CLI not found"
else
  extensions=(
    anthropic.claude-code
    bradlc.vscode-tailwindcss
    christian-kohler.npm-intellisense
    christian-kohler.path-intellisense
    dbaeumer.vscode-eslint
    eamodio.gitlens
    esbenp.prettier-vscode
    formulahendry.auto-close-tag
    github.github-vscode-theme
    kamikillerto.vscode-colorize
    tyriar.sort-lines
    wix.vscode-import-cost
    yummygum.city-lights-icon-vsc
  )

  VSCODE_EXT_OK=0
  VSCODE_EXT_NEW=0
  $DRY_RUN || installed_exts=$(code --list-extensions 2>/dev/null)

  for ext in "${extensions[@]}"; do
    if $DRY_RUN; then
      would "code --install-extension $ext"
    else
      if echo "$installed_exts" | grep -qix "$ext"; then
        ok "$ext"
        VSCODE_EXT_OK=$((VSCODE_EXT_OK+1))
      elif code --install-extension "$ext" &>/dev/null; then
        installed "$ext"
        VSCODE_EXT_NEW=$((VSCODE_EXT_NEW+1))
      else
        warn "Failed to install extension $ext"
      fi
    fi
  done

  VSCODE_DIR="$HOME/Library/Application Support/Code/User"
  VSCODE_SETTINGS_OK=()
  VSCODE_SETTINGS_NEW=()

  if $DRY_RUN; then
    would "cp settings.json and keybindings.json to VS Code"
  else
    mkdir -p "$VSCODE_DIR"
    for config_file in settings.json keybindings.json; do
      if [ -f "$VSCODE_DIR/$config_file" ]; then
        if diff -q "$VSCODE_DIR/$config_file" "$DOTFILES_DIR/$config_file" &>/dev/null; then
          ok "$config_file already up to date"
          VSCODE_SETTINGS_OK+=("$config_file")
          continue
        fi
        echo "  Diff for $config_file:"
        diff --color=always "$VSCODE_DIR/$config_file" "$DOTFILES_DIR/$config_file"
        read -r -p "  $config_file already exists. Overwrite? [Y/n] " r
        if [[ "$r" =~ ^[nN] ]]; then
          ok "$config_file unchanged"
          VSCODE_SETTINGS_OK+=("$config_file")
          continue
        fi
      fi
      cp "$DOTFILES_DIR/$config_file" "$VSCODE_DIR/$config_file" && installed "$config_file"
      VSCODE_SETTINGS_NEW+=("$config_file")
    done
  fi

  # Build VS Code summary
  EXT_SUMMARY=""
  if [ $VSCODE_EXT_NEW -gt 0 ] && [ $VSCODE_EXT_OK -gt 0 ]; then
    EXT_SUMMARY="${VSCODE_EXT_NEW} installed · ${VSCODE_EXT_OK} up to date"
  elif [ $VSCODE_EXT_NEW -gt 0 ]; then
    EXT_SUMMARY="${VSCODE_EXT_NEW} installed"
  elif [ $VSCODE_EXT_OK -gt 0 ]; then
    EXT_SUMMARY="${VSCODE_EXT_OK} extensions"
  fi

  VSCODE_PARTS=()
  [ -n "$EXT_SUMMARY" ] && VSCODE_PARTS+=("$EXT_SUMMARY")
  SETTINGS_OK_STR=$(join_arr ' · ' "${VSCODE_SETTINGS_OK[@]}")
  SETTINGS_NEW_STR=$(join_arr ' · ' "${VSCODE_SETTINGS_NEW[@]}")
  [ -n "$SETTINGS_OK_STR" ] && VSCODE_PARTS+=("$SETTINGS_OK_STR")
  [ -n "$SETTINGS_NEW_STR" ] && VSCODE_PARTS+=("↑ $SETTINGS_NEW_STR")
  [ ${#VSCODE_PARTS[@]} -gt 0 ] && SUM_VSCODE="${GREEN}✔${RESET} $(join_arr ' · ' "${VSCODE_PARTS[@]}")"
fi

# -------------------------------------------------------
# 7. Apps
# -------------------------------------------------------
step "Installing apps"

APP_OK=()

install_app() {
  local name=$1 cask=$2 app=$3
  if $DRY_RUN; then
    would "brew install --cask $cask (or upgrade if outdated)"
  elif brew list --cask "$cask" &>/dev/null; then
    brew_cask "$cask"
    APP_OK+=("$name")
  elif [ -d "$app" ]; then
    ok "$name already installed (not Homebrew-managed)"
    APP_OK+=("$name")
  else
    read -r -p "  Install $name? [Y/n] " r
    if [[ ! "$r" =~ ^[nN] ]]; then
      if brew_cask "$cask"; then
        APP_OK+=("$name")
      fi
    fi
  fi
}

install_app "Google Chrome" "google-chrome" "/Applications/Google Chrome.app"
install_app "Spotify"       "spotify"       "/Applications/Spotify.app"
install_app "1Password"     "1password"     "/Applications/1Password.app"
install_app "iStat Menus"   "istat-menus"   "/Applications/iStat Menus.app"

# Deploy iStat Menus settings (merges preference keys, preserves license and device data)
ISTATMENUS_PLIST="$HOME/Library/Preferences/com.bjango.istatmenus.menubar.7.plist"
istatmenus_settings_current() {
  [ -f "$ISTATMENUS_PLIST" ] && python3 - <<PYEOF
import plistlib, sys
with open("$DOTFILES_DIR/istatmenus.menubar.plist", "rb") as f: src = plistlib.load(f)
with open("$ISTATMENUS_PLIST", "rb") as f: dst = plistlib.load(f)
sys.exit(0 if all(dst.get(k) == v for k, v in src.items()) else 1)
PYEOF
}
istatmenus_settings_apply() {
  python3 - <<PYEOF
import plistlib
with open("$DOTFILES_DIR/istatmenus.menubar.plist", "rb") as f: src = plistlib.load(f)
dst = {}
try:
  with open("$ISTATMENUS_PLIST", "rb") as f: dst = plistlib.load(f)
except FileNotFoundError: pass
dst.update(src)
with open("$ISTATMENUS_PLIST", "wb") as f: plistlib.dump(dst, f)
PYEOF
}
if $DRY_RUN; then
  would "merge istatmenus.menubar.plist into $ISTATMENUS_PLIST"
elif [ ! -f "/Applications/iStat Menus.app/Contents/Info.plist" ]; then
  : # app not installed, skip
elif istatmenus_settings_current; then
  ok "iStat Menus settings already up to date"
  APP_OK+=("iStat Menus settings")
else
  read -r -p "  Apply iStat Menus settings? [Y/n] " r
  if [[ ! "$r" =~ ^[nN] ]]; then
    istatmenus_settings_apply
    ok "iStat Menus settings applied (restart iStat Menus to take effect)"
    APP_OK+=("iStat Menus settings")
  fi
fi

[ ${#APP_OK[@]} -gt 0 ] && SUM_APPS="${GREEN}✔${RESET} $(join_arr ' · ' "${APP_OK[@]}")"

# -------------------------------------------------------
# 8. Terminal
# -------------------------------------------------------
step "Setting up Terminal"

TERM_PLIST="$HOME/Library/Preferences/com.apple.Terminal.plist"
TERM_PROFILE="Pedro's Default"

terminal_current() {
  [ -f "$TERM_PLIST" ] &&
  [ "$(defaults read com.apple.Terminal 'Default Window Settings' 2>/dev/null)" = "$TERM_PROFILE" ] &&
  /usr/libexec/PlistBuddy -c "Print ':Window Settings:Pedro'\''s Default:name'" "$TERM_PLIST" &>/dev/null
}

if $DRY_RUN; then
  would "create Terminal profile '$TERM_PROFILE' with SF Mono 14pt, black background, and title bar settings"
elif [ ! -f "$TERM_PLIST" ]; then
  warn "Terminal preferences not found — open Terminal.app first, then re-run"
  SUM_TERMINAL="${YELLOW}⚠${RESET} plist not found"
elif terminal_current; then
  ok "Terminal profile '$TERM_PROFILE' already configured"
  SUM_TERMINAL="${GREEN}✔${RESET} Pedro's Default profile"
else
  # Create the profile by duplicating Basic, then rename it
  /usr/libexec/PlistBuddy -c "Copy :Window Settings:Basic ':Window Settings:Pedro'\''s Default'" "$TERM_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add ':Window Settings:Pedro'\''s Default' dict" "$TERM_PLIST" 2>/dev/null
  /usr/libexec/PlistBuddy -c "Set ':Window Settings:Pedro'\''s Default:name' 'Pedro'\''s Default'" "$TERM_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add ':Window Settings:Pedro'\''s Default:name' string 'Pedro'\''s Default'" "$TERM_PLIST" 2>/dev/null

  # Font and background via AppleScript
  osascript &>/dev/null <<'APPLESCRIPT'
tell application "Terminal"
  set font name of settings set "Pedro's Default" to "SFMonoTerminal-Regular"
  set font size of settings set "Pedro's Default" to 14
  set background color of settings set "Pedro's Default" to {0, 0, 0}
end tell
APPLESCRIPT

  # Profile settings via PlistBuddy
  pb_set() {
    /usr/libexec/PlistBuddy -c "Set ':Window Settings:Pedro'\''s Default:$1' $2" "$TERM_PLIST" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Add ':Window Settings:Pedro'\''s Default:$1' $3 $2" "$TERM_PLIST" 2>/dev/null
  }
  pb_set BackgroundBlur                    0.5   real
  pb_set shellExitAction                   0     integer
  pb_set ShowActiveProcessInTitle          false bool
  pb_set ShowDimensionsInTitle             false bool
  pb_set ShowShellCommandInTitle           false bool
  pb_set ShowWindowSettingsNameInTitle     false bool
  pb_set ShowRepresentedURLInTitle         true  bool
  pb_set ShowRepresentedURLPathInTitle     false bool
  unset -f pb_set

  # Set as default profile
  defaults write com.apple.Terminal "Default Window Settings" -string "$TERM_PROFILE"
  defaults write com.apple.Terminal "Startup Window Settings" -string "$TERM_PROFILE"
  defaults write com.apple.Terminal NewWindowWorkingDirectoryBehavior -int 2
  defaults write com.apple.Terminal NewTabWorkingDirectoryBehavior -int 2

  ok "Terminal profile '$TERM_PROFILE' configured"
  SUM_TERMINAL="${GREEN}✔${RESET} Pedro's Default profile"
fi

# -------------------------------------------------------
# 9. macOS Preferences
# -------------------------------------------------------
step "Applying macOS preferences"

# Per-group state (computed once, used for both idempotency check and change reporting)
dock_current=true
{ [ "$(defaults read com.apple.dock orientation 2>/dev/null)"              = "left" ] &&
  [ "$(defaults read com.apple.dock tilesize 2>/dev/null)"                 = "40"   ] &&
  [ "$(defaults read com.apple.dock size-immutable 2>/dev/null)"           = "1"    ] &&
  [ "$(defaults read com.apple.dock minimize-to-application 2>/dev/null)"  = "1"    ] &&
  [ "$(defaults read com.apple.dock show-recents 2>/dev/null)"             = "0"    ] &&
  [ "$(defaults read com.apple.dock wvous-tl-corner 2>/dev/null)"          = "1"    ] &&
  [ "$(defaults read com.apple.dock wvous-tr-corner 2>/dev/null)"          = "1"    ] &&
  [ "$(defaults read com.apple.dock wvous-bl-corner 2>/dev/null)"          = "1"    ] &&
  [ "$(defaults read com.apple.dock wvous-br-corner 2>/dev/null)"          = "1"    ]; } || dock_current=false

finder_current=true
{ [ "$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null)"                  = "true" ] &&
  [ "$(defaults read com.apple.finder ShowPathbar 2>/dev/null)"                        = "1"    ] &&
  [ "$(defaults read com.apple.finder ShowRecentTags 2>/dev/null)"                     = "0"    ] &&
  [ "$(defaults read com.apple.finder FXPreferredViewStyle 2>/dev/null)"               = "icnv" ] &&
  [ "$(defaults read com.apple.finder NewWindowTarget 2>/dev/null)"                    = "PfHm" ] &&
  [ "$(defaults read com.apple.finder FXDefaultSearchScope 2>/dev/null)"               = "SCcf" ] &&
  [ "$(defaults read com.apple.finder ShowExternalHardDrivesOnDesktop 2>/dev/null)"    = "1"    ] &&
  [ "$(defaults read com.apple.finder ShowHardDrivesOnDesktop 2>/dev/null)"            = "1"    ] &&
  [ "$(defaults read com.apple.desktopservices DSDontWriteNetworkStores 2>/dev/null)"  = "1"    ] &&
  [ "$(defaults read com.apple.finder FXEnableExtensionChangeWarning 2>/dev/null)"     = "0"    ]; } || finder_current=false

system_current=true
{ [ "$(defaults read com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking 2>/dev/null)" = "1"        ] &&
  [ "$(defaults read NSGlobalDomain NSAutomaticSpellingCorrectionEnabled 2>/dev/null)"          = "0"        ] &&
  [ "$(defaults read NSGlobalDomain NSAutomaticCapitalizationEnabled 2>/dev/null)"              = "0"        ] &&
  [ "$(defaults read NSGlobalDomain NSAutomaticDashSubstitutionEnabled 2>/dev/null)"            = "0"        ] &&
  [ "$(defaults read NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled 2>/dev/null)"          = "0"        ] &&
  [ "$(defaults read NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled 2>/dev/null)"           = "0"        ] &&
  [ "$(defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null)"                        = "1"        ] &&
  [ "$(defaults read NSGlobalDomain AppleInterfaceStyle 2>/dev/null)"                           = "Dark"     ] &&
[ "$(defaults read NSGlobalDomain AppleActionOnDoubleClick 2>/dev/null)"                      = "Minimize" ] &&
  [ "$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null)"                                     = "5"        ] &&
  [ "$(defaults read NSGlobalDomain InitialKeyRepeat 2>/dev/null)"                              = "25"       ] &&
  [ "$(defaults read NSGlobalDomain com.apple.sound.beep.feedback 2>/dev/null)"                 = "0"        ] &&
  [ "$(defaults read NSGlobalDomain AppleEnableMenuBarTransparency 2>/dev/null)"                = "0"        ] &&
  [ "$(defaults read -g EnableTilingByEdgeDrag 2>/dev/null)"                                    = "0"        ] &&
  [ "$(defaults read -g EnableTilingByMenuBar 2>/dev/null)"                                     = "0"        ]; } || system_current=false

screenshot_current=true
_sc_loc=$(defaults read com.apple.screencapture location 2>/dev/null)
{ [ "$_sc_loc" = "$HOME/Desktop" ] &&
  [ "$(defaults read com.apple.screencapture show-thumbnail 2>/dev/null)"  = "0" ]; } || screenshot_current=false
unset _sc_loc

menubar_current=true
{ [ "$(defaults read com.apple.controlcenter "NSStatusItem Visible BentoBox" 2>/dev/null)"       = "1" ] &&
  [ "$(defaults read com.apple.controlcenter "NSStatusItem Visible FaceTime" 2>/dev/null)"        = "0" ] &&
  [ "$(defaults read com.apple.controlcenter "NSStatusItem Visible NowPlaying" 2>/dev/null)"      = "0" ] &&
  [ "$(defaults read com.apple.controlcenter "NSStatusItem Visible ScreenMirroring" 2>/dev/null)" = "0" ] &&
  [ "$(defaults read com.apple.controlcenter "NSStatusItem VisibleCC Bluetooth" 2>/dev/null)"     = "1" ] &&
  [ "$(defaults read com.apple.controlcenter "NSStatusItem VisibleCC Clock" 2>/dev/null)"         = "1" ] &&
  [ "$(defaults read com.apple.controlcenter "NSStatusItem VisibleCC Sound" 2>/dev/null)"         = "1" ] &&
  [ "$(defaults read com.apple.controlcenter "NSStatusItem VisibleCC WiFi" 2>/dev/null)"          = "1" ] &&
  [ "$(defaults read com.apple.menuextra.clock IsAnalog 2>/dev/null)"                             = "0" ] &&
  [ "$(defaults read com.apple.menuextra.clock ShowAMPM 2>/dev/null)"                             = "1" ] &&
  [ "$(defaults read com.apple.menuextra.clock ShowDate 2>/dev/null)"                             = "0" ] &&
  [ "$(defaults read com.apple.menuextra.clock ShowDayOfWeek 2>/dev/null)"                        = "1" ]; } || menubar_current=false

macos_prefs_current() {
  $dock_current && $finder_current && $system_current && $screenshot_current && $menubar_current
}

if $DRY_RUN; then
  would "configure Dock, Finder, System Settings, and menu bar"
  would "reset Dock to: Finder, Google Chrome, VS Code, Terminal, 1Password, Spotify, Trash"
elif macos_prefs_current; then
  ok "macOS preferences already configured"
  SUM_MACOS="${GREEN}✔${RESET} already configured"
else
  read -r -p "  Apply macOS preferences? [Y/n] " r
  if [[ "$r" =~ ^[nN] ]]; then
    ok "macOS preferences unchanged"
    SUM_MACOS="${CYAN}✔${RESET} unchanged"
  else

  # Dock
  defaults write com.apple.dock orientation left
  defaults write com.apple.dock tilesize -integer 40
  defaults write com.apple.dock size-immutable -bool true
  defaults write com.apple.dock minimize-to-application -bool true
  defaults write com.apple.dock show-recents -bool false
  if $dock_current; then ok "Dock already configured"; else updated "Dock"; fi

  # Dock app layout
  if command -v dockutil &>/dev/null; then
    dockutil --remove all --no-restart &>/dev/null
    [[ -d "/Applications/Google Chrome.app" ]]             && dockutil --add "/Applications/Google Chrome.app" --no-restart &>/dev/null
    [[ -d "/Applications/Visual Studio Code.app" ]]        && dockutil --add "/Applications/Visual Studio Code.app" --no-restart &>/dev/null
    [[ -d "/System/Applications/Utilities/Terminal.app" ]] && dockutil --add "/System/Applications/Utilities/Terminal.app" --no-restart &>/dev/null
    [[ -d "/Applications/1Password.app" ]]                 && dockutil --add "/Applications/1Password.app" --no-restart &>/dev/null
    [[ -d "/Applications/Spotify.app" ]]                   && dockutil --add "/Applications/Spotify.app" --no-restart &>/dev/null
    ok "Dock apps set: Finder, Google Chrome, VS Code, Terminal, 1Password, Spotify, Trash"
  fi

  # Hot corners (disabled)
  defaults write com.apple.dock wvous-tl-corner -int 1
  defaults write com.apple.dock wvous-tr-corner -int 1
  defaults write com.apple.dock wvous-bl-corner -int 1
  defaults write com.apple.dock wvous-br-corner -int 1

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
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  if $finder_current; then ok "Finder already configured"; else updated "Finder"; fi

  # System Settings
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write NSGlobalDomain AppleInterfaceStyle Dark
defaults write NSGlobalDomain AppleActionOnDoubleClick Minimize
  defaults write NSGlobalDomain KeyRepeat -int 5
  defaults write NSGlobalDomain InitialKeyRepeat -int 25
  defaults write NSGlobalDomain com.apple.sound.beep.feedback -int 0
  defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool false
  defaults write -g EnableTilingByEdgeDrag -bool false
  defaults write -g EnableTilingByMenuBar -bool false
  if $system_current; then ok "System settings already configured"; else updated "System settings"; fi

  # Screenshots
  defaults write com.apple.screencapture location -string "$HOME/Desktop"
  defaults write com.apple.screencapture show-thumbnail -bool false
  if $screenshot_current; then ok "Screenshots already configured"; else updated "Screenshots"; fi

  # Menu bar — visible items
  defaults write com.apple.controlcenter "NSStatusItem Visible BentoBox" -bool true
  defaults write com.apple.controlcenter "NSStatusItem Visible FaceTime" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible NowPlaying" -bool false
  defaults write com.apple.controlcenter "NSStatusItem Visible ScreenMirroring" -bool false
  # Menu bar — Control Center items
  defaults write com.apple.controlcenter "NSStatusItem VisibleCC Bluetooth" -bool true
  defaults write com.apple.controlcenter "NSStatusItem VisibleCC Clock" -bool true
  defaults write com.apple.controlcenter "NSStatusItem VisibleCC Sound" -bool true
  defaults write com.apple.controlcenter "NSStatusItem VisibleCC WiFi" -bool true
  # Menu bar — clock format (digital, day of week + AM/PM, no date)
  defaults write com.apple.menuextra.clock IsAnalog -bool false
  defaults write com.apple.menuextra.clock ShowAMPM -bool true
  defaults write com.apple.menuextra.clock ShowDate -bool false
  defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
  if $menubar_current; then ok "Menu bar already configured"; else updated "Menu bar"; fi

  # Restart Finder, Dock, and menu bar
  killall Finder
  killall Dock
  killall SystemUIServer
  ok "Finder, Dock, and menu bar restarted"

  MACOS_UPDATED=()
  $dock_current       || MACOS_UPDATED+=("Dock")
  $finder_current     || MACOS_UPDATED+=("Finder")
  $system_current     || MACOS_UPDATED+=("System settings")
  $screenshot_current || MACOS_UPDATED+=("Screenshots")
  $menubar_current    || MACOS_UPDATED+=("Menu bar")
  if [ ${#MACOS_UPDATED[@]} -gt 0 ]; then
    SUM_MACOS="${BLUE}↑${RESET} $(join_arr ' · ' "${MACOS_UPDATED[@]}")"
  else
    SUM_MACOS="${GREEN}✔${RESET} already configured"
  fi

  fi # end apply macOS preferences
fi # end macOS preferences section

# -------------------------------------------------------
# 10. External Peripherals (Windows keyboard/mouse on Mac)
# -------------------------------------------------------
step "External peripherals"
echo -e "  ${YELLOW}Only needed when using a Windows keyboard or mouse on a Mac.${RESET}"

PERIPH_OK=()

deploy_peripheral_config() {
  local src="$DOTFILES_DIR/$1" dst="$2" name="$3"
  $DRY_RUN && { would "deploy $1 to $dst"; return 0; }
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ]; then
    if diff -q "$dst" "$src" &>/dev/null; then
      ok "$name config already up to date"
      return 0
    fi
    echo "  Diff for $name config:"
    diff --color=always "$dst" "$src"
    read -r -p "  $name config already exists. Overwrite? [y/N] " r
    if [[ ! "$r" =~ ^[yY] ]]; then
      ok "$name config unchanged"
      return 0
    fi
  fi
  if cp "$src" "$dst"; then
    ok "$name config deployed"
  else
    warn "Failed to deploy $name config"
    return 1
  fi
}

setup_peripheral() {
  local name=$1 cask=$2 app=$3 config_src=$4 config_dst=$5
  if $DRY_RUN; then
    would "brew install --cask $cask && deploy $config_src to $config_dst"
    return
  fi
  if brew list --cask "$cask" &>/dev/null && [ -d "$app" ]; then
    ok "$name already installed"
  elif brew list --cask "$cask" &>/dev/null && [ ! -d "$app" ]; then
    warn "$name registered with Homebrew but app missing, reinstalling..."
    if brew reinstall --cask "$cask" &>/dev/null && [ -d "$app" ]; then
      installed "$name"
      echo -e "  ${YELLOW}⚠ Launch $name, then grant permissions in System Settings → Privacy & Security.${RESET}"
    else
      warn "Failed to reinstall $name"
      return 1
    fi
  else
    read -r -p "  Set up $name? [y/N] " r
    if [[ ! "$r" =~ ^[yY] ]]; then
      return
    fi
    if brew install --cask "$cask" &>/dev/null && [ -d "$app" ]; then
      installed "$name"
      echo -e "  ${YELLOW}⚠ Launch $name, then grant permissions in System Settings → Privacy & Security.${RESET}"
    else
      warn "Failed to install $name"
      return 1
    fi
  fi
  if deploy_peripheral_config "$config_src" "$config_dst" "$name"; then
    PERIPH_OK+=("$name")
  fi
}

setup_peripheral \
  "Karabiner-Elements" \
  "karabiner-elements" \
  "/Applications/Karabiner-Elements.app" \
  "karabiner.json" \
  "$HOME/.config/karabiner/karabiner.json"

# Mouse settings
if $DRY_RUN; then
  would "set mouse tracking speed and scroll speed"
else
  if [ "$(defaults read .GlobalPreferences com.apple.mouse.scaling 2>/dev/null)" = "0.5" ] &&
     [ "$(defaults read .GlobalPreferences com.apple.scrollwheel.scaling 2>/dev/null)" = "0.5" ]; then
    ok "Mouse settings already configured"
    PERIPH_OK+=("Mouse")
  else
    read -r -p "  Apply mouse settings (tracking speed 0.5, scroll speed 0.5)? [y/N] " r
    if [[ "$r" =~ ^[yY] ]]; then
      defaults write .GlobalPreferences com.apple.mouse.scaling 0.5
      defaults write .GlobalPreferences com.apple.scrollwheel.scaling 0.5
      ok "Mouse: tracking speed set to 0.5, scroll speed set to 0.5"
      PERIPH_OK+=("Mouse")
    fi
  fi
fi

[ ${#PERIPH_OK[@]} -gt 0 ] && SUM_PERIPHERALS="${GREEN}✔${RESET} $(join_arr ' · ' "${PERIPH_OK[@]}")"

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo -e "${BOLD}-----------------------------------${RESET}"
echo -e "${BOLD}Summary${RESET}"
echo -e "${BOLD}-----------------------------------${RESET}"
[ ${#INSTALLED[@]} -gt 0 ] && echo -e "${GREEN}✔ Installed (${#INSTALLED[@]}):${RESET}  $(printf '%s, ' "${INSTALLED[@]}" | sed 's/, $//')"
[ ${#UPDATED[@]} -gt 0 ]   && echo -e "${BLUE}↑ Updated (${#UPDATED[@]}):${RESET}    $(printf '%s, ' "${UPDATED[@]}" | sed 's/, $//')"
[ ${#WARNINGS[@]} -gt 0 ]  && echo -e "${YELLOW}⚠ Warnings (${#WARNINGS[@]}):${RESET}   $(printf '%s, ' "${WARNINGS[@]}" | sed 's/, $//')"

section_line() {
  local label=$1 value=$2 pad
  pad=$(( 16 - ${#label} )); [ $pad -lt 1 ] && pad=1
  [ -n "$value" ] && echo -e "${BOLD}${label}${RESET}$(printf '%*s' $pad '')${value}"
}

echo ""
section_line "Xcode CLT"     "$SUM_XCODE"
section_line "Config files"  "$SUM_DOTFILES"
section_line "Homebrew"      "$SUM_HOMEBREW"
section_line "SSH"           "$SUM_SSH"
section_line "Shell"         "$SUM_SHELL"
section_line "Node.js"       "$SUM_NODE"
section_line "VS Code"       "$SUM_VSCODE"
section_line "Apps"          "$SUM_APPS"
section_line "Terminal"      "$SUM_TERMINAL"
section_line "macOS"         "$SUM_MACOS"
section_line "Peripherals"   "$SUM_PERIPHERALS"
echo ""
$DRY_RUN || echo -e "${GREEN}${BOLD}All done! Restart your terminal to apply all changes.${RESET}"
echo ""
