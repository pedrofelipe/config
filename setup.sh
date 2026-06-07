#!/bin/bash

# Colors
GREEN='\033[38;2;78;186;101m'
YELLOW='\033[38;2;255;193;7m'
RED='\033[38;2;255;107;128m'
BLUE='\033[38;2;87;105;247m'
PURPLE='\033[38;2;175;135;255m'
GREY='\033[38;2;102;102;102m'
BOLD='\033[1m'
RESET='\033[0m'

# Parse flags
DRY_RUN=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

# nvm version — update manually when a new stable release is available
NVM_VERSION="v0.40.5"

# ASCII art
printf '%b' "${PURPLE}${BOLD}"
cat << 'EOF'
 _     _   _                  _               _
| |__ | |_| |_ _ __   ___  __| |_ __ ___   __| | _____   __
| '_ \| __| __| '_ \ / _ \/ _` | '__/ _ \ / _` |/ _ \ \ / /
| | | | |_| |_| |_) |  __/ (_| | | | (_) | (_| |  __/\ V /
|_| |_|\__|\__| .__/ \___|\__,_|_|  \___(_)__,_|\___| \_/
              |_|
EOF
echo -e "${RESET}"
echo -e "${BOLD}macOS Setup${RESET}"
$DRY_RUN && echo -e "\n${YELLOW}${BOLD}Dry run — no changes will be made${RESET}"
echo ""

# Close System Preferences/Settings to prevent it from overriding defaults
if ! $DRY_RUN; then
  osascript -e 'tell application "System Preferences" to quit' 2>/dev/null
  osascript -e 'tell application "System Settings" to quit' 2>/dev/null
fi

# Ask for sudo password upfront and keep it alive for the duration of the script
if ! $DRY_RUN; then
  sudo -v || exit 1
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
SUM_GHOSTTY=""
SUM_MACOS=""
SUM_PERIPHERALS=""

# Brew counters (shared across brew_formula/brew_cask calls)
BREW_OK=0
BREW_UPDATED=0
BREW_INSTALLED=0

step()      { echo -e "\n${BLUE}${BOLD}▶ $1${RESET}"; }
installed() { echo -e "${GREEN}✔ Installed $1${RESET}"; INSTALLED+=("$1"); }
ok()        { echo -e "${GREY}✔ $1${RESET}"; }
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

deploy_prompted_file() {
  local src=$1 dst=$2 display=$3 prompt_label=$4 dry_run_message=$5
  local dest_dir=${6:-} dir_mode=${7:-} file_mode=${8:-} r
  _deploy_result=""

  if $DRY_RUN; then
    would "$dry_run_message"
    _deploy_result="dry-run"
    return 0
  fi

  if [ -n "$dest_dir" ]; then
    mkdir -p "$dest_dir"
    [ -n "$dir_mode" ] && chmod "$dir_mode" "$dest_dir"
  fi

  if [ -e "$dst" ] && [ ! -f "$dst" ]; then
    warn "$display destination exists and is not a file: $dst"
    _deploy_result="blocked"
    return 1
  fi

  if [ -f "$dst" ]; then
    if diff -q "$dst" "$src" &>/dev/null; then
      ok "$display already up to date"
      _deploy_result="ok"
      return 0
    fi
    git --no-pager diff --no-index --color "$dst" "$src"
    read -r -p "  $prompt_label already exists. Overwrite? [Y/n] " r
    if [[ "$r" =~ ^[nN] ]]; then
      ok "$display unchanged"
      _deploy_result="unchanged"
      return 0
    fi
  fi

  cp "$src" "$dst"
  [ -n "$file_mode" ] && chmod "$file_mode" "$dst"
  installed "$display"
  _deploy_result="installed"
}

# Install or upgrade a Homebrew formula
brew_formula() {
  local pkg=$1 r
  if ! command -v brew &>/dev/null; then
    if $DRY_RUN; then
      would "brew install $pkg"
      return 0
    fi
    warn "Homebrew not found, skipping $pkg"
    return 1
  fi
  if brew list --formula "$pkg" &>/dev/null; then
    if $DRY_RUN; then
      would "brew upgrade $pkg (if outdated)"
    else
      if brew outdated --formula | grep -Fxq "$pkg"; then
        read -r -p "  Upgrade $pkg? [Y/n] " r
        if [[ "$r" =~ ^[nN] ]]; then
          ok "$pkg upgrade skipped"
          BREW_OK=$((BREW_OK+1))
        else
          if brew upgrade "$pkg" &>/dev/null; then
            updated "$pkg"
            BREW_UPDATED=$((BREW_UPDATED+1))
          else
            warn "Failed to upgrade $pkg"
            return 1
          fi
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
  local cmd=$2 r
  if ! command -v brew &>/dev/null; then
    if $DRY_RUN; then
      would "brew install --cask $cask"
      return 0
    fi
    warn "Homebrew not found, skipping $cask"
    return 1
  fi
  if brew list --cask "$cask" &>/dev/null; then
    if $DRY_RUN; then
      would "brew upgrade --cask $cask (if outdated)"
    else
      if brew outdated --cask | grep -Fxq "$cask"; then
        read -r -p "  Upgrade $cask? [Y/n] " r
        if [[ "$r" =~ ^[nN] ]]; then
          ok "$cask upgrade skipped"
          BREW_OK=$((BREW_OK+1))
        else
          if brew upgrade --cask "$cask" &>/dev/null; then
            updated "$cask"
            BREW_UPDATED=$((BREW_UPDATED+1))
          else
            warn "Failed to upgrade $cask"
            return 1
          fi
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

reinstall_missing_cask_app() {
  local name=$1 cask=$2 app=$3 r

  warn "$name Homebrew cask is registered, but $app is missing"
  read -r -p "  Reinstall $name via Homebrew? [Y/n] " r
  if [[ "$r" =~ ^[nN] ]]; then
    ok "$name reinstall skipped"
    return 2
  fi

  if brew reinstall --cask "$cask" &>/dev/null && [ -d "$app" ]; then
    installed "$name"
    return 0
  fi

  warn "Failed to reinstall $name"
  return 1
}

collect_git_commit_author_identity() {
  step "Setting Git commit author identity"

  if $DRY_RUN; then
    would "collect Git commit author name (default: Pedro Menezes) and required Git commit author email"
    would "use the collected Git commit author identity for global Git config"
    echo "  Git uses this identity for commit authorship."
    echo "  GitHub uses the email to associate commits with your account."
    return 0
  fi

  echo "  Git uses this identity for commit authorship."
  echo "  GitHub uses the email to associate commits with your account."

  read -r -p "  Git commit author name [Pedro Menezes]: " GIT_COMMIT_AUTHOR_NAME
  GIT_COMMIT_AUTHOR_NAME="${GIT_COMMIT_AUTHOR_NAME:-Pedro Menezes}"

  while true; do
    read -r -p "  Git commit author email: " GIT_COMMIT_AUTHOR_EMAIL
    [ -n "$GIT_COMMIT_AUTHOR_EMAIL" ] && break
    echo "  Git commit author email cannot be empty."
  done
}

# 0. Xcode Command Line Tools
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

# Git commit author identity
collect_git_commit_author_identity

# 1. Config files
step "Loading config files"

CF_OK=()
_deploy_result=""
for file in .bash_profile .inputrc; do
  if [ -f "$DOTFILES_DIR/$file" ]; then
    if deploy_prompted_file "$DOTFILES_DIR/$file" "$HOME/$file" "$file" "$file" "cp $file to $HOME/$file"; then
      [ "$_deploy_result" != "dry-run" ] && CF_OK+=("$file")
    fi
  else
    warn "$file not found, skipping"
  fi
done
# Git config (identity collected upfront so dry runs stay non-interactive)
if [ -f "$DOTFILES_DIR/.gitconfig" ]; then
  if $DRY_RUN; then
    would "cp .gitconfig to ~/.gitconfig and apply Git commit author identity to global Git config"
  else
    _gitconfig_needs_copy=true
    _current_email=$(git config --global user.email 2>/dev/null)
    if [ -f "$HOME/.gitconfig" ]; then
      _files_match=false
      _strip_identity() { grep -vE '^[[:space:]]*(name|email)[[:space:]]*=' "$1"; }
      diff -q <(_strip_identity "$HOME/.gitconfig") <(_strip_identity "$DOTFILES_DIR/.gitconfig") &>/dev/null && _files_match=true
      if $_files_match && [ -n "$_current_email" ] && [[ "$_current_email" != *"YOUR_"* && "$_current_email" != "email_here" ]]; then
        _gitconfig_needs_copy=false
      elif ! $_files_match; then
        _diff_dir=$(mktemp -d) || { warn "Failed to create temporary gitconfig diff directory"; _diff_dir=""; }
        if [ -n "$_diff_dir" ]; then
          _strip_identity "$HOME/.gitconfig" > "$_diff_dir/.gitconfig"
          _strip_identity "$DOTFILES_DIR/.gitconfig" > "$_diff_dir/.gitconfig.incoming"
          git --no-pager diff --no-index --color "$_diff_dir/.gitconfig" "$_diff_dir/.gitconfig.incoming"
          rm -rf "$_diff_dir"
        fi
        unset _diff_dir
        read -r -p "  .gitconfig already exists. Overwrite? [Y/n] " r
        [[ "$r" =~ ^[nN] ]] && _gitconfig_needs_copy=false
      fi
    fi
    if $_gitconfig_needs_copy; then
      cp "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
      installed ".gitconfig"
    else
      ok ".gitconfig template unchanged"
    fi
    git config --global user.name "$GIT_COMMIT_AUTHOR_NAME"
    git config --global user.email "$GIT_COMMIT_AUTHOR_EMAIL"
    ok "Git commit author identity configured ($GIT_COMMIT_AUTHOR_NAME <$GIT_COMMIT_AUTHOR_EMAIL>)"
    CF_OK+=(".gitconfig")
    unset _gitconfig_needs_copy _current_email _files_match
    unset -f _strip_identity
  fi
fi
# SSH config (deploys to ~/.ssh/config, not $HOME directly)
if [ -f "$DOTFILES_DIR/ssh_config" ]; then
  if deploy_prompted_file "$DOTFILES_DIR/ssh_config" "$HOME/.ssh/config" "$HOME/.ssh/config" \~/.ssh/config "cp ssh_config to ~/.ssh/config" "$HOME/.ssh" 700 600; then
    [ "$_deploy_result" != "dry-run" ] && CF_OK+=("ssh_config")
  fi
else
  warn "ssh_config not found, skipping"
fi
# Copy Claude Code settings.json
_claude_settings_src="$DOTFILES_DIR/.claude/settings.json"
_claude_settings_dest="$HOME/.claude/settings.json"
if [ -f "$_claude_settings_src" ]; then
  if deploy_prompted_file "$_claude_settings_src" "$_claude_settings_dest" "Claude Code/settings.json" "claude/settings.json" "cp claude/settings.json to $_claude_settings_dest" "$HOME/.claude"; then
    [ "$_deploy_result" != "dry-run" ] && CF_OK+=("Claude Code/settings.json")
  fi
fi
unset _claude_settings_src _claude_settings_dest
# OpenCode (opencode.jsonc, agents, skills)
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
_oc_file="opencode.jsonc"
_oc_src="$DOTFILES_DIR/.config/opencode/$_oc_file"
_oc_dest="$OPENCODE_CONFIG_DIR/$_oc_file"
if [ -f "$_oc_src" ]; then
  if deploy_prompted_file "$_oc_src" "$_oc_dest" "OpenCode/$_oc_file" "opencode/$_oc_file" "cp opencode/$_oc_file to $_oc_dest" "$OPENCODE_CONFIG_DIR"; then
    [ "$_deploy_result" != "dry-run" ] && CF_OK+=("OpenCode/$_oc_file")
  fi
fi
unset _oc_file _oc_src _oc_dest
if [ -d "$DOTFILES_DIR/.config/opencode/agents" ]; then
  if $DRY_RUN; then
    would "sync opencode/agents to $OPENCODE_CONFIG_DIR/agents/"
  else
    mkdir -p "$OPENCODE_CONFIG_DIR/agents"
    _changed=()
    for f in "$DOTFILES_DIR/.config/opencode/agents"/*.md; do
      [ -f "$f" ] || continue
      dest="$OPENCODE_CONFIG_DIR/agents/$(basename "$f")"
      { [ ! -f "$dest" ] || ! diff -q "$dest" "$f" &>/dev/null; } && _changed+=("$(basename "$f")")
    done
    for d in "$DOTFILES_DIR/.config/opencode/agents"/*/; do
      [ -d "$d" ] || continue
      dest="$OPENCODE_CONFIG_DIR/agents/$(basename "$d")"
      { [ ! -d "$dest" ] || ! diff -rq "$dest" "$d" &>/dev/null; } && _changed+=("$(basename "$d")/")
    done
    if [ ${#_changed[@]} -eq 0 ]; then
      ok "OpenCode agents already up to date"
      CF_OK+=("OpenCode/agents")
    else
      for _name in "${_changed[@]}"; do
        if [[ "$_name" == */ ]]; then
          _dname="${_name%/}"
          _src_dir="$DOTFILES_DIR/.config/opencode/agents/$_dname"
          _dest_dir="$OPENCODE_CONFIG_DIR/agents/$_dname"
          for _f in "$_src_dir"/*.md; do
            [ -f "$_f" ] || continue
            _dest_f="$_dest_dir/$(basename "$_f")"
            if [ -f "$_dest_f" ]; then git --no-pager diff --no-index --color "$_dest_f" "$_f"; else git --no-pager diff --no-index --color /dev/null "$_f"; fi
          done
        else
          _src="$DOTFILES_DIR/.config/opencode/agents/$_name"
          _dest="$OPENCODE_CONFIG_DIR/agents/$_name"
          if [ -f "$_dest" ]; then git --no-pager diff --no-index --color "$_dest" "$_src"; else git --no-pager diff --no-index --color /dev/null "$_src"; fi
        fi
      done
      read -r -p "  Sync ${#_changed[@]} opencode agent(s)? [Y/n] " r
      if [[ ! "$r" =~ ^[nN] ]]; then
        for _f in "$DOTFILES_DIR/.config/opencode/agents"/*.md; do
          [ -f "$_f" ] && cp "$_f" "$OPENCODE_CONFIG_DIR/agents/"
        done
        for d in "$DOTFILES_DIR/.config/opencode/agents"/*/; do
          [ -d "$d" ] && cp -r "$d" "$OPENCODE_CONFIG_DIR/agents/"
        done
        installed "OpenCode agents (${#_changed[@]})"
        CF_OK+=("OpenCode/agents")
      else
        ok "OpenCode agents unchanged"
      fi
    fi
    unset _changed
  fi
fi
if [ -d "$DOTFILES_DIR/.config/opencode/skills" ]; then
  if $DRY_RUN; then
    would "sync opencode/skills to $OPENCODE_CONFIG_DIR/skills/"
  else
    mkdir -p "$OPENCODE_CONFIG_DIR/skills"
    _any_changed=false
    for item in "$DOTFILES_DIR/.config/opencode/skills"/*; do
      [ -e "$item" ] || continue
      name=$(basename "$item")
      dest="$OPENCODE_CONFIG_DIR/skills/$name"
      if [ -d "$item" ]; then
        ! diff -rq "$item" "$dest" &>/dev/null && _any_changed=true && break
      elif [ -f "$item" ]; then
        { [ ! -f "$dest" ] || ! diff -q "$dest" "$item" &>/dev/null; } && _any_changed=true && break
      fi
    done
    if ! $_any_changed; then
      ok "OpenCode skills already up to date"
      CF_OK+=("OpenCode/skills")
    else
      read -r -p "  Sync opencode skills? [Y/n] " r
      if [[ ! "$r" =~ ^[nN] ]]; then
        cp -r "$DOTFILES_DIR/.config/opencode/skills/." "$OPENCODE_CONFIG_DIR/skills/"
        installed "OpenCode skills"
        CF_OK+=("OpenCode/skills")
      else
        ok "OpenCode skills unchanged"
      fi
    fi
    unset _any_changed
  fi
fi
[ ${#CF_OK[@]} -gt 0 ] && SUM_DOTFILES="${GREEN}✔${RESET} $(join_arr ' · ' "${CF_OK[@]}")"

# 2. Homebrew
step "Installing Homebrew and packages"

if ! command -v brew &>/dev/null; then
  if $DRY_RUN; then
    would "install Homebrew"
  else
    _brew_install_script=$(mktemp) || { warn "Failed to create temporary Homebrew installer file"; _brew_install_script=""; }
    if [ -n "$_brew_install_script" ] && curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$_brew_install_script" && /bin/bash "$_brew_install_script"; then
      if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi

      if command -v brew &>/dev/null; then
        installed "Homebrew"
        warn "Homebrew was added to this session's PATH — restart your terminal to make it permanent"
      else
        warn "Homebrew installed, but brew is not available on PATH"
      fi
    else
      warn "Failed to install Homebrew"
    fi
    [ -n "$_brew_install_script" ] && rm -f "$_brew_install_script"
    unset _brew_install_script
  fi
else
  if $DRY_RUN; then
    would "brew update"
  else
    brew update &>/dev/null && ok "Homebrew up to date"
  fi
fi

for pkg in bash git bash-completion@2 pnpm gh dockutil; do
  brew_formula "$pkg"
done

! $DRY_RUN && command -v brew &>/dev/null && brew tap anomalyco/tap &>/dev/null || true
brew_formula "opencode"

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

# 3. SSH keys
step "SSH keys"

SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

if [ -f "$SSH_KEY_PATH" ] || [ -f "$HOME/.ssh/id_rsa" ]; then
  ok "SSH keys already exist"
  SUM_SSH="${GREEN}✔${RESET} keys exist"
else
  if $DRY_RUN; then
    would "generate SSH key, add to GitHub with title $(hostname | sed 's/\.local$//')"
  else
    read -r -p "  Generate SSH key (~/.ssh/id_ed25519)? [Y/n] " r
    if [[ "$r" =~ ^[nN] ]]; then
      ok "SSH key generation skipped"
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
          if [[ "$r" =~ ^[nN] ]]; then
            warn "Skipped GitHub login — run manually: gh auth login && gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
          else
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
          fi
        fi
      else
        warn "Failed to generate SSH key"
      fi
    fi
  fi
fi

# 4. Switch to Homebrew bash
step "Setting Homebrew bash as default shell"

HOMEBREW_BASH="/opt/homebrew/bin/bash"

if ! $DRY_RUN && [ ! -f "$HOMEBREW_BASH" ]; then
  warn "Homebrew bash not found at $HOMEBREW_BASH — was 'brew install bash' successful? Skipping shell switch"
  SUM_SHELL="${YELLOW}⚠${RESET} Homebrew bash not found"
else
  if grep -Fxq "$HOMEBREW_BASH" /etc/shells; then
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
      if [[ "$r" =~ ^[nN] ]]; then
        ok "Shell unchanged"
        SUM_SHELL="${GREEN}✔${RESET} unchanged"
      else
        if chsh -s "$HOMEBREW_BASH"; then
          installed "default shell → $HOMEBREW_BASH"
          SUM_SHELL="${GREEN}✔${RESET} switched to Homebrew bash"
        else
          warn "Failed to set default shell — try manually: chsh -s $HOMEBREW_BASH"
          SUM_SHELL="${YELLOW}⚠${RESET} switch failed"
        fi
      fi
    fi
  fi
fi

# 5. Node.js via nvm
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
      if [[ "$r" =~ ^[nN] ]]; then
        ok "nvm upgrade skipped"
      else
        if (set -o pipefail; curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash) &>/dev/null; then
          [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
          updated "nvm $current_nvm → $NVM_VERSION"
        else
          warn "Failed to update nvm"
        fi
      fi
    fi
  fi
else
  if $DRY_RUN; then
    would "install nvm $NVM_VERSION"
  else
    if (set -o pipefail; curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash) &>/dev/null; then
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
    if [[ "$r" =~ ^[nN] ]]; then
      ok "Node.js upgrade skipped"
      SUM_NODE="${GREEN}✔${RESET} $prev_node"
    else
      if nvm install "$latest_lts" >/dev/null 2>&1 && nvm alias default node >/dev/null 2>&1; then
        updated "Node.js LTS $prev_node → $latest_lts"
        SUM_NODE="${BLUE}↑${RESET} $latest_lts"
      else
        warn "Failed to upgrade Node.js LTS"
        SUM_NODE="${YELLOW}⚠${RESET} upgrade failed"
      fi
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

# External OpenCode skills
_OPENCODE_SKILL_CMD_VERCEL=(
  npx -y skills add https://github.com/vercel-labs/agent-skills
  --skill vercel-react-best-practices
  --skill vercel-composition-patterns
  --global
  --agent opencode
  --yes
)
_OPENCODE_SKILL_CMD_EMIL=(
  npx -y skills add https://github.com/emilkowalski/skill
  --skill emil-design-eng
  --global
  --agent opencode
  --yes
)
if $DRY_RUN; then
  would "${_OPENCODE_SKILL_CMD_VERCEL[*]}"
  would "${_OPENCODE_SKILL_CMD_EMIL[*]}"
  would "remove stale ~/.config/opencode/skills/react-best-practices if it is the Vercel React skill"
  would "remove stale ~/.config/opencode/skills/composition-patterns if it is the Vercel composition skill"
elif command -v npx &>/dev/null; then
  read -r -p "  Install external skills (Vercel + emil-design-eng)? [Y/n] " r
  if [[ "$r" =~ ^[nN] ]]; then
    ok "External skills skipped"
  else
    if "${_OPENCODE_SKILL_CMD_VERCEL[@]}" &>/dev/null; then
      installed "vercel-react-best-practices and vercel-composition-patterns skills"
    else
      warn "Failed to install vercel-react-best-practices and vercel-composition-patterns skills"
    fi

    if "${_OPENCODE_SKILL_CMD_EMIL[@]}" &>/dev/null; then
      installed "emil-design-eng"
    else
      warn "Failed to install emil-design-eng skill"
    fi
  fi

  _stale_skills=(
    "react-best-practices:vercel-react-best-practices"
    "composition-patterns:vercel-composition-patterns"
  )
  for _entry in "${_stale_skills[@]}"; do
    _dir="${_entry%%:*}"
    _skill="${_entry#*:}"
    _path="$HOME/.config/opencode/skills/$_dir"
    if [ -f "$_path/SKILL.md" ] && grep -Fxq "name: $_skill" "$_path/SKILL.md"; then
      read -r -p "  Remove stale OpenCode skill $_dir? [Y/n] " r
      if [[ "$r" =~ ^[nN] ]]; then
        ok "Stale OpenCode skill $_dir unchanged"
      else
        rm -rf "$_path"
        ok "Removed stale OpenCode skill $_dir"
      fi
    fi
  done
  unset _stale_skills _entry _dir _skill _path
else
  warn "npx not found, skipping external skills"
fi
unset _OPENCODE_SKILL_CMD_VERCEL _OPENCODE_SKILL_CMD_EMIL

# 6. VS Code extensions and settings
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
    eamodio.gitlens
    formulahendry.auto-close-tag
    github.github-vscode-theme
    oxc.oxc-vscode
    tyriar.sort-lines
    wix.vscode-import-cost
    yummygum.city-lights-icon-vsc
  )

  VSCODE_EXT_OK=0
  VSCODE_EXT_NEW=0

  if $DRY_RUN; then
    for ext in "${extensions[@]}"; do
      would "code --install-extension $ext"
    done
  else
    installed_exts=$(code --list-extensions 2>/dev/null)
    exts_missing=()
    for ext in "${extensions[@]}"; do
      echo "$installed_exts" | grep -Fqix "$ext" || exts_missing+=("$ext")
    done
    VSCODE_EXT_OK=$(( ${#extensions[@]} - ${#exts_missing[@]} ))

    if [ ${#exts_missing[@]} -eq 0 ]; then
      ok "All ${#extensions[@]} extensions already installed"
    else
      read -r -p "  Install ${#exts_missing[@]} VS Code extension(s)? [Y/n] " r
      if [[ "$r" =~ ^[nN] ]]; then
        ok "Extensions unchanged"
      else
        for ext in "${extensions[@]}"; do
          if echo "$installed_exts" | grep -Fqix "$ext"; then
            ok "$ext"
          elif code --install-extension "$ext" &>/dev/null; then
            installed "$ext"
            VSCODE_EXT_NEW=$((VSCODE_EXT_NEW+1))
          else
            warn "Failed to install extension $ext"
          fi
        done
      fi
    fi
  fi

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
        git --no-pager diff --no-index --color "$VSCODE_DIR/$config_file" "$DOTFILES_DIR/$config_file"
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

# 7. Apps
step "Installing apps"

APP_OK=()

install_app() {
  local name=$1 cask=$2 app=$3 r
  if $DRY_RUN; then
    would "brew install --cask $cask (or upgrade if outdated)"
  elif command -v brew &>/dev/null && brew list --cask "$cask" &>/dev/null; then
    if [ -d "$app" ]; then
      if brew_cask "$cask"; then
        APP_OK+=("$name")
      else
        return 1
      fi
    else
      reinstall_missing_cask_app "$name" "$cask" "$app"
      case $? in
        0) APP_OK+=("$name") ;;
        1) return 1 ;;
        2) ;;
      esac
    fi
  elif [ -d "$app" ]; then
    ok "$name already installed (not Homebrew-managed)"
    APP_OK+=("$name")
  elif ! command -v brew &>/dev/null; then
    warn "Homebrew not found, skipping $name"
    return 1
  else
    read -r -p "  Install $name? [Y/n] " r
    if [[ "$r" =~ ^[nN] ]]; then
      ok "$name skipped"
    else
      if brew_cask "$cask"; then
        APP_OK+=("$name")
      else
        return 1
      fi
    fi
  fi
}

install_app "Google Chrome" "google-chrome" "/Applications/Google Chrome.app"
install_app "Spotify"       "spotify"       "/Applications/Spotify.app"
install_app "1Password"     "1password"     "/Applications/1Password.app"
install_app "Little Snitch" "little-snitch" "/Applications/Little Snitch.app"
install_app "iStat Menus"   "istat-menus"   "/Applications/iStat Menus.app"

# Deploy iStat Menus settings (merges preference keys, preserves license and device data)
ISTATMENUS_PLIST="$HOME/Library/Preferences/com.bjango.istatmenus.menubar.7.plist"
istatmenus_settings_current() {
  [ -f "$ISTATMENUS_PLIST" ] && DOTFILES_DIR="$DOTFILES_DIR" ISTATMENUS_PLIST="$ISTATMENUS_PLIST" python3 - <<'PYEOF'
import os, plistlib, sys
with open(os.path.join(os.environ["DOTFILES_DIR"], "istatmenus.menubar.plist"), "rb") as f: src = plistlib.load(f)
with open(os.environ["ISTATMENUS_PLIST"], "rb") as f: dst = plistlib.load(f)
sys.exit(0 if all(dst.get(k) == v for k, v in src.items()) else 1)
PYEOF
}
istatmenus_settings_apply() {
  DOTFILES_DIR="$DOTFILES_DIR" ISTATMENUS_PLIST="$ISTATMENUS_PLIST" python3 - <<'PYEOF'
import os, plistlib
with open(os.path.join(os.environ["DOTFILES_DIR"], "istatmenus.menubar.plist"), "rb") as f: src = plistlib.load(f)
dst = {}
try:
  with open(os.environ["ISTATMENUS_PLIST"], "rb") as f: dst = plistlib.load(f)
except FileNotFoundError: pass
dst.update(src)
with open(os.environ["ISTATMENUS_PLIST"], "wb") as f: plistlib.dump(dst, f)
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
  if [[ "$r" =~ ^[nN] ]]; then
    ok "iStat Menus settings skipped"
  else
    istatmenus_settings_apply
    ok "iStat Menus settings applied (restart iStat Menus to take effect)"
    APP_OK+=("iStat Menus settings")
  fi
fi

[ ${#APP_OK[@]} -gt 0 ] && SUM_APPS="${GREEN}✔${RESET} $(join_arr ' · ' "${APP_OK[@]}")"

# 8. Ghostty
step "Setting up Ghostty"

if [ -d "/Applications/Ghostty.app" ]; then
  if command -v brew &>/dev/null && brew list --cask ghostty &>/dev/null; then
    brew_cask "ghostty" && SUM_GHOSTTY="${GREEN}✔${RESET} installed"
  else
    ok "Ghostty installed outside Homebrew, skipping"
    SUM_GHOSTTY="${GREEN}✔${RESET} installed"
  fi
elif $DRY_RUN; then
  would "brew install --cask ghostty"
elif command -v brew &>/dev/null && brew list --cask ghostty &>/dev/null; then
  reinstall_missing_cask_app "Ghostty" "ghostty" "/Applications/Ghostty.app"
  case $? in
    0) SUM_GHOSTTY="${GREEN}✔${RESET} installed" ;;
    1|2) ;;
  esac
else
  read -r -p "  Install Ghostty? [Y/n] " r
  if [[ "$r" =~ ^[nN] ]]; then
    ok "Ghostty skipped"
  else
    brew_cask "ghostty" && SUM_GHOSTTY="${GREEN}✔${RESET} installed"
  fi
fi
# Ghostty config
_ghostty_src="$DOTFILES_DIR/.config/ghostty/config"
_ghostty_dest="$HOME/.config/ghostty/config"
if [ -f "$_ghostty_src" ]; then
  deploy_prompted_file "$_ghostty_src" "$_ghostty_dest" "ghostty/config" "ghostty/config" "cp .config/ghostty/config to $_ghostty_dest" "$HOME/.config/ghostty"
fi
unset _ghostty_src _ghostty_dest

# 9. macOS Preferences
step "Applying macOS preferences"

_pref_read() {
  local domain="$1" key="$2" host="${3:-}"
  if [ -n "$host" ]; then
    defaults -currentHost read "$domain" "$key" 2>/dev/null
  else
    defaults read "$domain" "$key" 2>/dev/null
  fi
}

_pref_values_match() {
  local actual="$1" expected="$2"

  case "$expected" in
    true|false)
      case "$actual" in
        1) actual=true ;;
        0) actual=false ;;
      esac
      ;;
  esac

  [ "$actual" = "$expected" ]
}

_pref_matches() {
  local domain="$1" key="$2" expected="$3" host="${4:-}"
  _pref_values_match "$(_pref_read "$domain" "$key" "$host")" "$expected"
}

_pref_write() {
  local domain="$1" key="$2" type="$3" value="$4" host="${5:-}"
  if [ -n "$host" ]; then
    defaults -currentHost write "$domain" "$key" "$type" "$value"
  else
    defaults write "$domain" "$key" "$type" "$value"
  fi
}

_pref_diff() {
  local label="$1" domain="$2" key="$3" expected="$4" host="${5:-}"
  local actual pad
  actual=$(_pref_read "$domain" "$key" "$host")
  if ! _pref_values_match "$actual" "$expected"; then
    pad=$(( 28 - ${#label} )); [ $pad -lt 1 ] && pad=1
    printf "    %s%*s${RED}%s${RESET} → ${GREEN}%s${RESET}\n" "$label" $pad "" "${actual:-<unset>}" "$expected"
  fi
}

# Per-group state (computed once, used for both idempotency check and change reporting)
dock_current=true
{ _pref_matches com.apple.dock orientation left &&
  _pref_matches com.apple.dock tilesize 40 &&
  _pref_matches com.apple.dock size-immutable true &&
  _pref_matches com.apple.dock minimize-to-application true &&
  _pref_matches com.apple.dock show-recents false &&
  _pref_matches com.apple.dock wvous-tl-corner 1 &&
  _pref_matches com.apple.dock wvous-tr-corner 1 &&
  _pref_matches com.apple.dock wvous-bl-corner 1 &&
  _pref_matches com.apple.dock wvous-br-corner 1; } || dock_current=false
if $dock_current && command -v dockutil &>/dev/null; then
  _dock_list=$(dockutil --list 2>/dev/null | awk -F'\t' '{print $1}')
  for _app in "Google Chrome" "Visual Studio Code" "Ghostty" "1Password" "Spotify"; do
    echo "$_dock_list" | grep -Fxq "$_app" || { dock_current=false; break; }
  done
  unset _dock_list _app
fi

finder_current=true
{ _pref_matches com.apple.finder AppleShowAllFiles true &&
  _pref_matches com.apple.finder ShowPathbar true &&
  _pref_matches com.apple.finder ShowRecentTags false &&
  _pref_matches com.apple.finder NewWindowTarget PfHm &&
  _pref_matches com.apple.finder FXDefaultSearchScope SCcf &&
  _pref_matches com.apple.desktopservices DSDontWriteNetworkStores true &&
  _pref_matches com.apple.finder FXEnableExtensionChangeWarning false; } || finder_current=false

system_current=true
{ _pref_matches com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking true &&
  _pref_matches NSGlobalDomain NSAutomaticSpellingCorrectionEnabled false &&
  _pref_matches NSGlobalDomain NSAutomaticCapitalizationEnabled false &&
  _pref_matches NSGlobalDomain NSAutomaticDashSubstitutionEnabled false &&
  _pref_matches NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled false &&
  _pref_matches NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled false &&
  _pref_matches NSGlobalDomain AppleShowAllExtensions true &&
  _pref_matches NSGlobalDomain AppleInterfaceStyle Dark &&
  _pref_matches NSGlobalDomain AppleActionOnDoubleClick Minimize &&
  _pref_matches NSGlobalDomain KeyRepeat 5 &&
  _pref_matches NSGlobalDomain InitialKeyRepeat 25 &&
  _pref_matches NSGlobalDomain com.apple.sound.beep.feedback 0 &&
  _pref_matches NSGlobalDomain AppleEnableMenuBarTransparency false &&
  _pref_matches -g EnableTilingByEdgeDrag false &&
  _pref_matches -g EnableTilingByMenuBar false; } || system_current=false

screenshot_current=true
{ _pref_matches com.apple.screencapture show-thumbnail false; } || screenshot_current=false

menubar_current=true
{ _pref_matches com.apple.controlcenter Weather 18 host; } || menubar_current=false

if $DRY_RUN; then
  would "configure Dock, Finder, System Settings, Screenshots, and menu bar"
  would "reset Dock to: Finder, Google Chrome, VS Code, Ghostty, 1Password, Spotify, Trash"
else
  MACOS_UPDATED=()
  NEEDS_RESTART=false

  # Dock
  if $dock_current; then
    ok "Dock already configured"
  else
    if command -v dockutil &>/dev/null; then
      _dock_list=$(dockutil --list 2>/dev/null | awk -F'\t' '{print $1}')
      _missing=()
      for _app in "Google Chrome" "Visual Studio Code" "Ghostty" "1Password" "Spotify"; do
        echo "$_dock_list" | grep -Fxq "$_app" || _missing+=("$_app")
      done
      [ ${#_missing[@]} -gt 0 ] && echo "  Missing from Dock: $(IFS=', '; echo "${_missing[*]}")"
      unset _dock_list _app _missing
    fi
    _pref_diff "Move to left side"       com.apple.dock orientation             left
    _pref_diff "Set icon size"           com.apple.dock tilesize                40
    _pref_diff "Lock icon size"          com.apple.dock size-immutable          true
    _pref_diff "Minimize to app icon"    com.apple.dock minimize-to-application true
    _pref_diff "Hide recent apps"        com.apple.dock show-recents            false
    _pref_diff "Disable top-left corner"    com.apple.dock wvous-tl-corner      1
    _pref_diff "Disable top-right corner"   com.apple.dock wvous-tr-corner      1
    _pref_diff "Disable bottom-left corner" com.apple.dock wvous-bl-corner      1
    _pref_diff "Disable bottom-right corner" com.apple.dock wvous-br-corner     1
    read -r -p "  Apply Dock settings? [Y/n] " r
    if [[ "$r" =~ ^[nN] ]]; then
      ok "Dock unchanged"
    else
      _pref_write com.apple.dock orientation -string left
      _pref_write com.apple.dock tilesize -integer 40
      _pref_write com.apple.dock size-immutable -bool true
      _pref_write com.apple.dock minimize-to-application -bool true
      _pref_write com.apple.dock show-recents -bool false
      _pref_write com.apple.dock wvous-tl-corner -int 1
      _pref_write com.apple.dock wvous-tr-corner -int 1
      _pref_write com.apple.dock wvous-bl-corner -int 1
      _pref_write com.apple.dock wvous-br-corner -int 1
      if command -v dockutil &>/dev/null; then
        dockutil --remove all --no-restart &>/dev/null
        [[ -d "/Applications/Google Chrome.app" ]]             && dockutil --add "/Applications/Google Chrome.app" --no-restart &>/dev/null
        [[ -d "/Applications/Visual Studio Code.app" ]]        && dockutil --add "/Applications/Visual Studio Code.app" --no-restart &>/dev/null
        [[ -d "/Applications/Ghostty.app" ]]                   && dockutil --add "/Applications/Ghostty.app" --no-restart &>/dev/null
        [[ -d "/Applications/1Password.app" ]]                 && dockutil --add "/Applications/1Password.app" --no-restart &>/dev/null
        [[ -d "/Applications/Spotify.app" ]]                   && dockutil --add "/Applications/Spotify.app" --no-restart &>/dev/null
        ok "Dock apps set: Finder, Google Chrome, VS Code, Ghostty, 1Password, Spotify, Trash"
      fi
      updated "Dock"; MACOS_UPDATED+=("Dock"); NEEDS_RESTART=true
    fi
  fi

  # Finder
  if $finder_current; then
    ok "Finder already configured"
  else
    _pref_diff "Show hidden files"          com.apple.finder AppleShowAllFiles              true
    _pref_diff "Show path bar"             com.apple.finder ShowPathbar                    true
    _pref_diff "Hide recent tags"          com.apple.finder ShowRecentTags                 false
    _pref_diff "Open windows to home"      com.apple.finder NewWindowTarget                PfHm
    _pref_diff "Search current folder"     com.apple.finder FXDefaultSearchScope           SCcf
    _pref_diff "Prevent .DS_Store on network" com.apple.desktopservices DSDontWriteNetworkStores true
    _pref_diff "Disable extension warning" com.apple.finder FXEnableExtensionChangeWarning false
    read -r -p "  Apply Finder settings? [Y/n] " r
    if [[ "$r" =~ ^[nN] ]]; then
      ok "Finder unchanged"
    else
      _pref_write com.apple.finder AppleShowAllFiles -bool true
      _pref_write com.apple.finder ShowPathbar -bool true
      _pref_write com.apple.finder ShowRecentTags -bool false
      _pref_write com.apple.finder NewWindowTarget -string PfHm
      _pref_write com.apple.finder FXDefaultSearchScope -string SCcf
      _pref_write com.apple.desktopservices DSDontWriteNetworkStores -bool true
      _pref_write com.apple.finder FXEnableExtensionChangeWarning -bool false
      updated "Finder"; MACOS_UPDATED+=("Finder"); NEEDS_RESTART=true
    fi
  fi

  # System Settings
  if $system_current; then
    ok "System settings already configured"
  else
    _pref_diff "Enable tap to click"       com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking true
    _pref_diff "Disable autocorrect"       NSGlobalDomain NSAutomaticSpellingCorrectionEnabled  false
    _pref_diff "Disable autocapitalize"    NSGlobalDomain NSAutomaticCapitalizationEnabled      false
    _pref_diff "Disable smart dashes"      NSGlobalDomain NSAutomaticDashSubstitutionEnabled    false
    _pref_diff "Disable smart periods"     NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled  false
    _pref_diff "Disable smart quotes"      NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled   false
    _pref_diff "Show all file extensions"  NSGlobalDomain AppleShowAllExtensions                true
    _pref_diff "Enable dark mode"          NSGlobalDomain AppleInterfaceStyle                  Dark
    _pref_diff "Double-click to minimize"  NSGlobalDomain AppleActionOnDoubleClick             Minimize
    _pref_diff "Increase key repeat speed" NSGlobalDomain KeyRepeat                            5
    _pref_diff "Reduce initial key repeat" NSGlobalDomain InitialKeyRepeat                     25
    _pref_diff "Mute volume feedback sound" NSGlobalDomain com.apple.sound.beep.feedback       0
    _pref_diff "Disable translucent menu bar" NSGlobalDomain AppleEnableMenuBarTransparency    false
    _pref_diff "Disable tiling on edge drag" -g EnableTilingByEdgeDrag                         false
    _pref_diff "Disable tiling on menu bar" -g EnableTilingByMenuBar                           false
    read -r -p "  Apply System settings? [Y/n] " r
    if [[ "$r" =~ ^[nN] ]]; then
      ok "System settings unchanged"
    else
      _pref_write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
      _pref_write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
      _pref_write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
      _pref_write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
      _pref_write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
      _pref_write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
      _pref_write NSGlobalDomain AppleShowAllExtensions -bool true
      _pref_write NSGlobalDomain AppleInterfaceStyle -string Dark
      _pref_write NSGlobalDomain AppleActionOnDoubleClick -string Minimize
      _pref_write NSGlobalDomain KeyRepeat -int 5
      _pref_write NSGlobalDomain InitialKeyRepeat -int 25
      _pref_write NSGlobalDomain com.apple.sound.beep.feedback -int 0
      _pref_write NSGlobalDomain AppleEnableMenuBarTransparency -bool false
      _pref_write -g EnableTilingByEdgeDrag -bool false
      _pref_write -g EnableTilingByMenuBar -bool false
      updated "System settings"; MACOS_UPDATED+=("System settings"); NEEDS_RESTART=true
    fi
  fi

  # Screenshots
  if $screenshot_current; then
    ok "Screenshots already configured"
  else
    _pref_diff "Disable thumbnail preview"  com.apple.screencapture show-thumbnail false
    read -r -p "  Apply Screenshots settings? [Y/n] " r
    if [[ "$r" =~ ^[nN] ]]; then
      ok "Screenshots unchanged"
    else
      _pref_write com.apple.screencapture show-thumbnail -bool false
      updated "Screenshots"; MACOS_UPDATED+=("Screenshots")
    fi
  fi

  # Menu bar
  if $menubar_current; then
    ok "Menu bar already configured"
  else
    _pref_diff "Pin Weather to menu bar"  com.apple.controlcenter Weather                             18 host
    read -r -p "  Apply menu bar settings? [Y/n] " r
    if [[ "$r" =~ ^[nN] ]]; then
      ok "Menu bar unchanged"
    else
      _pref_write com.apple.controlcenter Weather -int 18 host
      updated "Menu bar"; MACOS_UPDATED+=("Menu bar"); NEEDS_RESTART=true
    fi
  fi

  # Restart affected services
  if $NEEDS_RESTART; then
    killall Finder 2>/dev/null; killall Dock 2>/dev/null; killall SystemUIServer 2>/dev/null; killall ControlCenter 2>/dev/null
    ok "Finder, Dock, and menu bar restarted"
  fi

  if [ ${#MACOS_UPDATED[@]} -gt 0 ]; then
    SUM_MACOS="${BLUE}↑${RESET} $(join_arr ' · ' "${MACOS_UPDATED[@]}")"
  else
    SUM_MACOS="${GREEN}✔${RESET} already configured"
  fi
fi # end macOS preferences section
unset -f _pref_read _pref_values_match _pref_matches _pref_write _pref_diff

# 10. External Peripherals (Windows keyboard/mouse on Mac)
step "External peripherals"
echo -e "  ${GREY}Only needed when using a Windows keyboard or mouse on a Mac.${RESET}"

PERIPH_OK=()

deploy_peripheral_config() {
  local src="$DOTFILES_DIR/$1" dst="$2" name="$3" r
  $DRY_RUN && { would "deploy $1 to $dst"; return 0; }
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -f "$dst" ]; then
    warn "$name config destination exists and is not a file: $dst"
    return 1
  fi
  if [ -f "$dst" ]; then
    if diff -q "$dst" "$src" &>/dev/null; then
      ok "$name config already up to date"
      return 0
    fi
    git --no-pager diff --no-index --color "$dst" "$src"
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
  local name=$1 cask=$2 app=$3 config_src=$4 config_dst=$5 r
  if $DRY_RUN; then
    would "brew install --cask $cask && deploy $config_src to $config_dst"
    return
  fi
  if ! command -v brew &>/dev/null; then
    warn "Homebrew not found, skipping $name"
    return 1
  fi
  if brew list --cask "$cask" &>/dev/null; then
    if [ -d "$app" ]; then
      ok "$name already installed"
    else
      warn "$name registered with Homebrew but app missing, reinstalling..."
      if brew reinstall --cask "$cask" &>/dev/null && [ -d "$app" ]; then
        installed "$name"
        echo -e "  ${YELLOW}⚠ Launch $name, then grant permissions in System Settings → Privacy & Security.${RESET}"
      else
        warn "Failed to reinstall $name"
        return 1
      fi
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
  would "set mouse tracking speed 0.5, disable scroll acceleration"
else
  if [ "$(defaults read .GlobalPreferences com.apple.mouse.scaling 2>/dev/null)" = "0.5" ] &&
     [ "$(defaults read .GlobalPreferences com.apple.scrollwheel.scaling 2>/dev/null)" = "-1" ]; then
    ok "Mouse settings already configured"
    PERIPH_OK+=("Mouse")
  else
    read -r -p "  Apply mouse settings (tracking speed 0.5, scroll linear/no acceleration)? [y/N] " r
    if [[ "$r" =~ ^[yY] ]]; then
      defaults write .GlobalPreferences com.apple.mouse.scaling 0.5
      defaults write .GlobalPreferences com.apple.scrollwheel.scaling -1
      ok "Mouse: tracking speed set to 0.5, scroll acceleration disabled"
      PERIPH_OK+=("Mouse")
    fi
  fi
fi

[ ${#PERIPH_OK[@]} -gt 0 ] && SUM_PERIPHERALS="${GREEN}✔${RESET} $(join_arr ' · ' "${PERIPH_OK[@]}")"

# Summary
echo ""
echo -e "${BOLD}Summary${RESET}"
[ ${#INSTALLED[@]} -gt 0 ] && echo -e "${GREEN}✔ Installed (${#INSTALLED[@]}):${RESET}  $(printf '%s, ' "${INSTALLED[@]}" | sed 's/, $//')"
[ ${#UPDATED[@]} -gt 0 ]   && echo -e "${BLUE}↑ Updated (${#UPDATED[@]}):${RESET}    $(printf '%s, ' "${UPDATED[@]}" | sed 's/, $//')"
[ ${#WARNINGS[@]} -gt 0 ]  && echo -e "${YELLOW}⚠ Warnings (${#WARNINGS[@]}):${RESET}   $(printf '%s, ' "${WARNINGS[@]}" | sed 's/, $//')"

section_line() {
  local label=$1 value=$2 pad
  pad=$(( 16 - ${#label} )); [ $pad -lt 1 ] && pad=1
  [ -n "$value" ] && echo -e "${GREY}${label}${RESET}$(printf '%*s' $pad '')${value}"
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
section_line "Ghostty"       "$SUM_GHOSTTY"
section_line "macOS"         "$SUM_MACOS"
section_line "Peripherals"   "$SUM_PERIPHERALS"
echo ""
$DRY_RUN || echo -e "${GREEN}${BOLD}All done! Restart your terminal to apply all changes.${RESET}"
echo ""
