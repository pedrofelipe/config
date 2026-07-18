#!/bin/bash
#
# Bootstraps a macOS workstation from this dotfiles repo.
# Most writes are prompted so local config is not overwritten silently.
# Use --dry-run to preview prompts and commands without changing the machine.

GREEN='\033[38;2;78;186;101m'
YELLOW='\033[38;2;255;193;7m'
RED='\033[38;2;255;107;128m'
BLUE='\033[38;2;87;105;247m'
PURPLE='\033[38;2;175;135;255m'
GREY='\033[38;2;102;102;102m'
BOLD='\033[1m'
RESET='\033[0m'

DRY_RUN=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

# Pin the nvm installer so repeat runs stay predictable.
# Update manually when a new stable release is worth adopting.
NVM_VERSION="v0.40.5"

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
$DRY_RUN && echo -e "\n${YELLOW}${BOLD}Dry run. No changes will be made${RESET}"
echo ""

# System Settings can race defaults writes, so close it before applying changes.
if ! $DRY_RUN; then
  osascript -e 'tell application "System Preferences" to quit' 2>/dev/null
  osascript -e 'tell application "System Settings" to quit' 2>/dev/null
fi

# Prompt for sudo once and keep it alive so the script does not pause halfway through.
if ! $DRY_RUN; then
  sudo -v || exit 1
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

INSTALLED=()
UPDATED=()
WARNINGS=()

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

# Homebrew helpers update shared counters for the final summary.
BREW_OK=0
BREW_UPDATED=0
BREW_INSTALLED=0
BREW_SKIPPED=0

# Tool config is deployed only after the matching installer is present or accepted.
OPENCODE_AVAILABLE=false
OPENCODE_INSTALL_DECLINED=false
CLAUDE_CODE_AVAILABLE=false
CLAUDE_CODE_INSTALL_DECLINED=false
GIT_COMMIT_AUTHOR_IDENTITY_CONFIGURE=false

step()      { echo -e "\n${BLUE}${BOLD}▶ $1${RESET}"; }
installed() { echo -e "${GREEN}✔ Installed $1${RESET}"; INSTALLED+=("$1"); }
ok()        { echo -e "${GREY}✔ $1${RESET}"; }
updated()   { echo -e "${BLUE}↑ Updated $1${RESET}"; UPDATED+=("$1"); }
warn()      { echo -e "${YELLOW}⚠ $1${RESET}"; WARNINGS+=("$1"); }
would()     { echo -e "  ${BOLD}→${RESET} $1"; }

# Prompts for a yes/no decision and returns success when the choice accepts it.
install_consent() {
  local prompt=$1 default=${2:-n} r suffix

  case "$default" in
    y|Y) suffix="[Y/n]" ;;
    *) suffix="[y/N]" ;;
  esac

  if ! read -r -p "  $prompt $suffix " r; then
    echo ""
    return 1
  fi
  if [[ "$default" =~ ^[yY] ]]; then
    [[ ! "$r" =~ ^[nN] ]]
  else
    [[ "$r" =~ ^[yY] ]]
  fi
}

mark_installer_detected() {
  local target=$1

  case "$target" in
    opencode)
      OPENCODE_AVAILABLE=true
      ;;
    claude_code)
      CLAUDE_CODE_AVAILABLE=true
      ;;
  esac
}

mark_installer_installed() {
  mark_installer_detected "$1"
}

mark_installer_declined() {
  case "$1" in
    opencode) OPENCODE_INSTALL_DECLINED=true ;;
    claude_code) CLAUDE_CODE_INSTALL_DECLINED=true ;;
  esac
}

installer_available() {
  case "$1" in
    opencode) $OPENCODE_AVAILABLE ;;
    claude_code) $CLAUDE_CODE_AVAILABLE ;;
    *) return 1 ;;
  esac
}

installer_declined() {
  case "$1" in
    opencode) $OPENCODE_INSTALL_DECLINED ;;
    claude_code) $CLAUDE_CODE_INSTALL_DECLINED ;;
    *) return 1 ;;
  esac
}

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
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"

# OpenCode install manifests. README.md is documentation and is intentionally
# excluded from agent install manifests.
OPENCODE_WORKFLOW_AGENTS=(
  copilot
  planner
  developer
  reviewer
  publisher
  tester
  learner
  copilot-lite
  planner-lite
  developer-lite
  reviewer-lite
  publisher-lite
  tester-lite
  learner-lite
)
# Both workflows share these local skills, so deploy each directory once.
OPENCODE_WORKFLOW_LOCAL_SKILLS=(
  branch
  commit
  pr
  aaa-testing
  unit-test
  manual-qa
)
OPENCODE_STANDALONE_LOCAL_SKILLS=(
  simplify
)
OPENCODE_EXTERNAL_SKILL_COMMON_ARGS=(
  --global
  --agent opencode
  --yes
)
OPENCODE_EXTERNAL_SKILL_SPECS=(
  "https://github.com/vercel-labs/agent-skills|vercel-react-best-practices vercel-composition-patterns"
  "https://github.com/emilkowalski/skill|emil-design-eng"
  "https://github.com/ibelick/ui-skills|baseline-ui fixing-accessibility fixing-motion-performance"
  "https://github.com/addyosmani/web-quality-skills|web-quality-audit performance core-web-vitals accessibility seo best-practices"
  "https://github.com/addyosmani/agent-skills|code-simplification"
  "https://github.com/millionco/react-doctor|react-doctor"
  "https://github.com/shadcn/improve|improve"
)

# Resolves apps installed system-wide or in the user's Applications folder.
app_bundle_path() {
  local app=$1 user_app
  if [ -d "$app" ]; then
    echo "$app"
    return 0
  fi

  case "$app" in
    /Applications/*)
      user_app="$HOME/Applications/${app#/Applications/}"
      if [ -d "$user_app" ]; then
        echo "$user_app"
        return 0
      fi
      ;;
  esac

  return 1
}

app_bundle_exists() {
  app_bundle_path "$1" >/dev/null
}

brew_available() {
  command -v brew &>/dev/null
}

brew_cask_registered() {
  brew_available && brew list --cask "$1" &>/dev/null
}

brew_upgrade_formula_command_run() {
  local pkg=$1 display=$2 non_interactive=${3:-false} help

  if ! $non_interactive; then
    brew upgrade "$pkg" &>/dev/null
    return $?
  fi

  help="$(brew upgrade --help 2>/dev/null || true)"
  if [[ "$help" == *"--no-ask"* ]]; then
    HOMEBREW_NO_ASK=1 brew upgrade --no-ask "$pkg" &>/dev/null
  elif [[ "$help" == *"HOMEBREW_NO_ASK"* ]]; then
    HOMEBREW_NO_ASK=1 brew upgrade "$pkg" &>/dev/null
  else
    warn "Homebrew upgrade does not support non-interactive confirmation. Skipping $display upgrade"
    return 1
  fi
}

brew_trust_tap() {
  local tap=$1

  if $DRY_RUN; then
    would "Would trust package source $tap"
    return 0
  fi

  if ! brew trust --help &>/dev/null; then
    warn "Homebrew brew trust is unavailable. Continuing without trusting $tap"
    return 0
  fi

  if brew trust "$tap" &>/dev/null; then
    ok "Trusted Homebrew tap $tap"
    return 0
  fi

  warn "Failed to trust Homebrew tap $tap. Continuing anyway"
  return 0
}

prepare_opencode_homebrew_tap() {
  local tap=$1

  if $DRY_RUN; then
    would "Would prepare package source $tap"
    brew_trust_tap "$tap"
    return 0
  fi

  if ! brew tap "$tap" &>/dev/null; then
    warn "Failed to tap $tap"
    return 1
  fi

  brew_trust_tap "$tap"
}

# Deploys one file without hiding local changes.
# Sets _deploy_result so callers can distinguish installed, unchanged, and dry-run paths.
deploy_prompted_file() {
  local src=$1 dst=$2 display=$3 prompt_label=$4 dry_run_message=$5
  local dest_dir=${6:-} dir_mode=${7:-} file_mode=${8:-} overwrite_default=${9:-y}
  _deploy_result=""

  if $DRY_RUN; then
    if [ -n "$dest_dir" ] && [ -e "$dest_dir" ] && [ ! -d "$dest_dir" ]; then
      warn "$display destination directory exists and is not a directory: $dest_dir"
      _deploy_result="blocked"
      return 1
    fi

    if [ -e "$dst" ] && [ ! -f "$dst" ]; then
      warn "$display destination exists and is not a file: $dst"
      _deploy_result="blocked"
      return 1
    fi

    if [ -f "$dst" ]; then
      if diff -q "$dst" "$src" &>/dev/null; then
        ok "$display already up to date"
      else
        would "Ask to overwrite $prompt_label at $dst"
      fi
    else
      would "$dry_run_message"
    fi
    _deploy_result="dry-run"
    return 0
  fi

  if [ -n "$dest_dir" ]; then
    if ! mkdir -p "$dest_dir"; then
      warn "Failed to create directory for $display: $dest_dir"
      _deploy_result="failed"
      return 1
    fi
    if [ -n "$dir_mode" ] && ! chmod "$dir_mode" "$dest_dir"; then
      warn "Failed to set permissions on $display directory: $dest_dir"
      _deploy_result="failed"
      return 1
    fi
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
    if ! install_consent "$prompt_label already exists. Overwrite?" "$overwrite_default"; then
      ok "$display unchanged"
      _deploy_result="unchanged"
      return 0
    fi
  fi

  if ! cp "$src" "$dst"; then
    warn "Failed to copy $display to $dst"
    _deploy_result="failed"
    return 1
  fi
  if [ -n "$file_mode" ] && ! chmod "$file_mode" "$dst"; then
    warn "Failed to set permissions on $display: $dst"
    _deploy_result="failed"
    return 1
  fi
  installed "$display"
  _deploy_result="installed"
  return 0
}

deploy_diff_safe_paths_match() {
  local path_type=$1 src=$2 dst=$3

  case "$path_type" in
    file) diff -q "$dst" "$src" &>/dev/null ;;
    dir) diff -rq "$dst" "$src" &>/dev/null ;;
    *) return 1 ;;
  esac
}

deploy_diff_safe_show_diff() {
  local src=$1 dst=$2

  git --no-pager diff --no-index --color "$dst" "$src" || true
}

deploy_diff_safe_copy_path() {
  local path_type=$1 src=$2 dst=$3 display=$4 file_mode=${5:-}

  if [ "$path_type" = "dir" ] && { [ -e "$dst" ] || [ -L "$dst" ]; }; then
    if ! rm -rf "$dst"; then
      warn "Failed to replace $display at $dst"
      return 1
    fi
  fi

  if [ "$path_type" = "dir" ]; then
    if ! cp -R "$src" "$dst"; then
      warn "Failed to copy $display to $dst"
      return 1
    fi
  elif ! cp "$src" "$dst"; then
    warn "Failed to copy $display to $dst"
    return 1
  fi

  if [ "$path_type" = "file" ] && [ -n "$file_mode" ] && ! chmod "$file_mode" "$dst"; then
    warn "Failed to set permissions on $display: $dst"
    return 1
  fi

  return 0
}

# Installs local files or directories after showing diffs and asking first.
# Agent and skill installs use this because those files are likely to have local edits.
deploy_diff_safe_path() {
  local src=$1 dst=$2 display=$3 prompt_label=$4 path_type=$5
  local dest_dir=${6:-} dir_mode=${7:-} file_mode=${8:-}
  local install_consent_granted=${9:-false}
  local install_parent
  _deploy_result=""

  if [ "$path_type" != "file" ] && [ "$path_type" != "dir" ]; then
    warn "Unsupported install type for $display: $path_type"
    _deploy_result="failed"
    return 1
  fi

  if [ "$path_type" = "file" ] && [ ! -f "$src" ]; then
    if $DRY_RUN; then
      would "Would skip $display: source not found at $src"
      _deploy_result="dry-run"
      return 0
    fi
    warn "$display source is not a file: $src"
    _deploy_result="failed"
    return 1
  fi
  if [ "$path_type" = "dir" ] && [ ! -d "$src" ]; then
    if $DRY_RUN; then
      would "Would skip $display: source not found at $src"
      _deploy_result="dry-run"
      return 0
    fi
    warn "$display source is not a directory: $src"
    _deploy_result="failed"
    return 1
  fi

  install_parent=${dest_dir:-$(dirname "$dst")}

  if [ -e "$install_parent" ] && [ ! -d "$install_parent" ]; then
    warn "$display parent destination exists and is not a directory: $install_parent"
    _deploy_result="blocked"
    return 1
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if { [ "$path_type" = "file" ] && [ ! -f "$dst" ]; } || { [ "$path_type" = "dir" ] && [ ! -d "$dst" ]; }; then
      if $DRY_RUN; then
        would "Skip $display: destination exists but is not a $path_type: $dst"
        _deploy_result="dry-run"
        return 0
      fi
      warn "$display destination type does not match $path_type: $dst"
      _deploy_result="blocked"
      return 1
    fi

    if deploy_diff_safe_paths_match "$path_type" "$src" "$dst"; then
      ok "$display already up to date"
      if $DRY_RUN; then
        _deploy_result="dry-run"
      else
        _deploy_result="ok"
      fi
      return 0
    fi

    if $DRY_RUN; then
      would "Diff needed for $display at $dst. Would ask to overwrite"
      _deploy_result="dry-run"
      return 0
    fi

    deploy_diff_safe_show_diff "$src" "$dst"
    if ! install_consent "$prompt_label already exists. Overwrite?" y; then
      ok "$display unchanged"
      _deploy_result="unchanged"
      return 0
    fi
  else
    if $DRY_RUN; then
      would "Install $display to $dst"
      _deploy_result="dry-run"
      return 0
    fi

    if ! $install_consent_granted && ! install_consent "Install $prompt_label to $dst?" y; then
      ok "$display skipped"
      _deploy_result="unchanged"
      return 0
    fi
  fi

  if ! mkdir -p "$install_parent"; then
    warn "Failed to create directory for $display: $install_parent"
    _deploy_result="failed"
    return 1
  fi
  if [ -n "$dir_mode" ] && ! chmod "$dir_mode" "$install_parent"; then
    warn "Failed to set permissions on $display directory: $install_parent"
    _deploy_result="failed"
    return 1
  fi

  if ! deploy_diff_safe_copy_path "$path_type" "$src" "$dst" "$display" "$file_mode"; then
    _deploy_result="failed"
    return 1
  fi

  installed "$display"
  _deploy_result="installed"
  return 0
}

deploy_diff_safe_file() {
  local src=$1 dst=$2 display=$3 prompt_label=$4
  local dest_dir=${5:-} dir_mode=${6:-} file_mode=${7:-}
  local install_consent_granted=${8:-false}

  deploy_diff_safe_path "$src" "$dst" "$display" "$prompt_label" file "$dest_dir" "$dir_mode" "$file_mode" "$install_consent_granted"
}

deploy_diff_safe_dir() {
  local src=$1 dst=$2 display=$3 prompt_label=$4
  local dest_dir=${5:-} dir_mode=${6:-}
  local install_consent_granted=${7:-false}

  deploy_diff_safe_path "$src" "$dst" "$display" "$prompt_label" dir "$dest_dir" "$dir_mode" "" "$install_consent_granted"
}

# Installs or upgrades a Homebrew formula.
# Pass --install-consent-granted when the caller already asked about first-time install.
brew_formula() {
  local pkg=$1 display=$1 install_consent_granted=false upgrade_no_ask=false arg
  shift || true

  case "$pkg" in
    opencode|anomalyco/tap/opencode) display="OpenCode" ;;
  esac

  for arg in "$@"; do
    case "$arg" in
      --install-consent-granted) install_consent_granted=true ;;
      --upgrade-no-ask) upgrade_no_ask=true ;;
      *) warn "Ignoring unknown brew_formula option: $arg" ;;
    esac
  done

  if brew_available && brew list --formula "$pkg" &>/dev/null; then
    if $DRY_RUN; then
      would "Would update $display if outdated"
    else
      if brew outdated --formula "$pkg" | grep -q .; then
        if ! install_consent "Upgrade $display?" y; then
          ok "$display upgrade skipped"
          BREW_SKIPPED=$((BREW_SKIPPED+1))
        else
          if brew_upgrade_formula_command_run "$pkg" "$display" "$upgrade_no_ask"; then
            updated "$display"
            BREW_UPDATED=$((BREW_UPDATED+1))
          else
            warn "Failed to upgrade $display"
            return 1
          fi
        fi
      else
        ok "$display already up to date"
        BREW_OK=$((BREW_OK+1))
      fi
    fi
  elif ! brew_available; then
    if $DRY_RUN; then
      would "Would ask to install $display"
      return 0
    fi
    warn "Homebrew not found, skipping $display"
    return 1
  else
    if $DRY_RUN; then
      if $install_consent_granted; then
        would "Would install $display"
      else
        would "Would ask to install $display"
      fi
    else
      if ! $install_consent_granted && ! install_consent "Install $display?" y; then
        ok "$display skipped"
        return 2
      fi
      if brew install "$pkg" &>/dev/null; then
        installed "$display"
        BREW_INSTALLED=$((BREW_INSTALLED+1))
      else
        warn "Failed to install $display"
        return 1
      fi
    fi
  fi
}

# Installs or upgrades a Homebrew cask.
# Pass --install-consent-granted when the caller already asked about first-time install.
brew_cask() {
  local cask=$1
  local install_consent_granted=false arg
  shift || true

  for arg in "$@"; do
    case "$arg" in
      --install-consent-granted) install_consent_granted=true ;;
      *) warn "Ignoring unknown brew_cask option: $arg" ;;
    esac
  done

  if brew_available && brew list --cask "$cask" &>/dev/null; then
    if $DRY_RUN; then
      would "Would update $cask if outdated"
    else
      if brew outdated --cask | grep -Fxq "$cask"; then
        if ! install_consent "Upgrade $cask?" y; then
          ok "$cask upgrade skipped"
          BREW_SKIPPED=$((BREW_SKIPPED+1))
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
  elif ! brew_available; then
    if $DRY_RUN; then
      would "Would ask to install $cask"
      return 0
    fi
    warn "Homebrew not found, skipping $cask"
    return 1
  else
    if $DRY_RUN; then
      if $install_consent_granted; then
        would "Would install $cask"
      else
        would "Would ask to install $cask"
      fi
    else
      if ! $install_consent_granted && ! install_consent "Install $cask?" y; then
        ok "$cask skipped"
        return 2
      fi
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

install_opencode() {
  local pkg="opencode" tap="anomalyco/tap" formula="anomalyco/tap/opencode" cmd_path
  cmd_path="$(command -v "$pkg" 2>/dev/null || true)"

  if command -v brew &>/dev/null && brew list --formula "$formula" &>/dev/null; then
    mark_installer_detected opencode
    if ! prepare_opencode_homebrew_tap "$tap"; then
      return 1
    fi
    brew_formula "$formula" --upgrade-no-ask
    return $?
  fi

  if [ -n "$cmd_path" ]; then
    mark_installer_detected opencode
    ok "OpenCode found at $cmd_path, skipping installation"
    return 0
  fi

  if $DRY_RUN; then
    would "Would ask to install OpenCode. Deploy config only if accepted and completed"
    return 0
  fi

  if ! command -v brew &>/dev/null; then
    warn "Homebrew not found, skipping OpenCode"
    return 1
  fi

  if ! install_consent "Install OpenCode?" n; then
    mark_installer_declined opencode
    ok "OpenCode skipped"
    return 0
  fi

  if ! prepare_opencode_homebrew_tap "$tap"; then
    return 1
  fi

  if brew_formula "$formula" --install-consent-granted; then
    mark_installer_installed opencode
    return 0
  fi

  return 1
}

# Prepends a directory to PATH if absent and refreshes the command hash so a freshly installed binary resolves in this session.
ensure_dir_on_path() {
  local dir=$1
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir:$PATH" ;;
  esac
  hash -r 2>/dev/null || true
}

canonical_path() {
  local path=$1 dir base

  dir="$(dirname "$path")"
  base="$(basename "$path")"
  dir="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s\n' "$dir" "$base"
}

resolve_symlink_chain() {
  local path=$1 target dir depth=0

  path="$(canonical_path "$path")" || return 1
  while [ -L "$path" ]; do
    [ $depth -lt 20 ] || return 1
    target="$(readlink "$path")" || return 1
    case "$target" in
      /*) path="$target" ;;
      *)
        dir="$(dirname "$path")"
        path="$dir/$target"
        ;;
    esac
    path="$(canonical_path "$path")" || return 1
    depth=$((depth+1))
  done

  printf '%s\n' "$path"
}

claude_code_homebrew_managed() {
  local cmd_path=$1 canonical_cmd_path real_cmd_path list_kind package brew_file real_brew_file

  [ -n "$cmd_path" ] || return 1
  brew_available || return 1

  canonical_cmd_path="$(canonical_path "$cmd_path" 2>/dev/null || printf '%s\n' "$cmd_path")"
  real_cmd_path="$(resolve_symlink_chain "$cmd_path" 2>/dev/null || true)"

  if brew which-formula "$canonical_cmd_path" >/dev/null 2>&1; then
    return 0
  fi
  if [ -n "$real_cmd_path" ] && brew which-formula "$real_cmd_path" >/dev/null 2>&1; then
    return 0
  fi

  for list_kind in --formula --cask; do
    for package in claude-code claude; do
      while IFS= read -r brew_file; do
        [ -n "$brew_file" ] || continue

        brew_file="$(canonical_path "$brew_file" 2>/dev/null || printf '%s\n' "$brew_file")"
        if [ "$brew_file" = "$canonical_cmd_path" ] || { [ -n "$real_cmd_path" ] && [ "$brew_file" = "$real_cmd_path" ]; }; then
          return 0
        fi

        real_brew_file="$(resolve_symlink_chain "$brew_file" 2>/dev/null || true)"
        if [ -n "$real_brew_file" ] && { [ "$real_brew_file" = "$canonical_cmd_path" ] || [ "$real_brew_file" = "$real_cmd_path" ]; }; then
          return 0
        fi
      done <<EOF
$(brew list "$list_kind" "$package" 2>/dev/null)
EOF
    done
  done

  return 1
}

update_claude_code() {
  local cmd_path=$1

  if $DRY_RUN; then
    would "Would ask to update Claude Code with claude update"
    return 0
  fi

  if ! install_consent "Upgrade Claude Code?" y; then
    ok "Claude Code update skipped"
    return 0
  fi

  if "$cmd_path" update &>/dev/null; then
    updated "Claude Code"
    return 0
  fi

  warn "Failed to update Claude Code"
  return 1
}

install_claude_code() {
  local cmd="claude" install_dir="$HOME/.local/bin" direct_cmd cmd_path
  direct_cmd="$install_dir/$cmd"
  cmd_path="$(type -P "$cmd" 2>/dev/null || true)"

  if [ -z "$cmd_path" ] && [ -x "$direct_cmd" ]; then
    ensure_dir_on_path "$install_dir"
    cmd_path="$(type -P "$cmd" 2>/dev/null || true)"
  fi

  if [ -n "$cmd_path" ]; then
    mark_installer_detected claude_code
    ok "Claude Code found at $cmd_path, skipping installation"
    if claude_code_homebrew_managed "$cmd_path"; then
      ok "Claude Code updates managed by Homebrew"
      return 0
    fi
    update_claude_code "$cmd_path"
    return $?
  fi

  if $DRY_RUN; then
    would "Would ask to install Claude Code. Deploy settings only if accepted and completed"
    return 0
  fi

  if ! install_consent "Install Claude Code?" y; then
    mark_installer_declined claude_code
    ok "Claude Code skipped"
    return 0
  fi

  if (set -o pipefail; curl -fsSL --connect-timeout 10 --max-time 300 https://claude.ai/install.sh | bash); then
    ensure_dir_on_path "$install_dir"
    cmd_path="$(type -P "$cmd" 2>/dev/null || true)"
    if [ -z "$cmd_path" ]; then
      warn "Claude Code installer finished, but claude was not found on PATH after adding $install_dir"
      return 1
    fi

    mark_installer_installed claude_code
    installed "Claude Code"
    return 0
  fi

  warn "Failed to install Claude Code"
  return 1
}

refresh_dotfiles_summary() {
  [ ${#CF_OK[@]} -gt 0 ] && SUM_DOTFILES="${GREEN}✔${RESET} $(join_arr ' · ' "${CF_OK[@]}")"
}

skip_installer_setup() {
  local target=$1 display=$2 scope=$3

  if installer_declined "$target"; then
    ok "$display $scope skipped (install declined)"
  elif $DRY_RUN; then
    ok "$display $scope skipped (install was not completed)"
  else
    ok "$display $scope skipped (not installed)"
  fi
}

deploy_claude_code_config() {
  local _claude_settings_src _claude_settings_dest

  if ! installer_available claude_code; then
    skip_installer_setup claude_code "Claude Code" "settings"
    return 0
  fi

  _claude_settings_src="$DOTFILES_DIR/.claude/settings.json"
  _claude_settings_dest="$HOME/.claude/settings.json"
  if [ -f "$_claude_settings_src" ]; then
    if deploy_prompted_file "$_claude_settings_src" "$_claude_settings_dest" "Claude Code/settings.json" "claude/settings.json" "cp claude/settings.json to $_claude_settings_dest" "$HOME/.claude"; then
      [ "$_deploy_result" != "dry-run" ] && CF_OK+=("Claude Code/settings.json")
    fi
  fi
}

deploy_opencode_config() {
  local _oc_file _oc_src _oc_dest

  if ! installer_available opencode; then
    skip_installer_setup opencode "OpenCode" "config"
    return 0
  fi

  step "Deploying OpenCode config"

  _oc_file="opencode.jsonc"
  _oc_src="$DOTFILES_DIR/.config/opencode/$_oc_file"
  _oc_dest="$OPENCODE_CONFIG_DIR/$_oc_file"
  if [ -f "$_oc_src" ]; then
    if deploy_prompted_file "$_oc_src" "$_oc_dest" "OpenCode/$_oc_file" "OpenCode/$_oc_file" "cp .config/opencode/$_oc_file to $_oc_dest" "$OPENCODE_CONFIG_DIR"; then
      [ "$_deploy_result" != "dry-run" ] && CF_OK+=("OpenCode/$_oc_file")
    fi
  fi
}

install_opencode_agent_file() {
  local agent=$1 install_consent_granted=${2:-false} src dest

  if ! installer_available opencode && ! $DRY_RUN; then
    skip_installer_setup opencode "Agent $agent" "setup"
    return 0
  fi

  src="$DOTFILES_DIR/.config/opencode/agents/$agent.md"
  dest="$OPENCODE_CONFIG_DIR/agents/$agent.md"
  deploy_diff_safe_file "$src" "$dest" "Agent $agent" "Agent $agent" "$OPENCODE_CONFIG_DIR/agents" "" "" "$install_consent_granted"
  [[ "$_deploy_result" = "failed" || "$_deploy_result" = "blocked" ]] && return 1
  return 0
}

install_opencode_local_skill() {
  local skill=$1 install_consent_granted=${2:-false} src dest

  if ! installer_available opencode && ! $DRY_RUN; then
    skip_installer_setup opencode "Skill $skill" "setup"
    return 0
  fi

  src="$DOTFILES_DIR/.config/opencode/skills/$skill"
  dest="$OPENCODE_CONFIG_DIR/skills/$skill"
  deploy_diff_safe_dir "$src" "$dest" "Skill $skill" "Skill $skill" "$OPENCODE_CONFIG_DIR/skills" "" "$install_consent_granted"
  [[ "$_deploy_result" = "failed" || "$_deploy_result" = "blocked" ]] && return 1
  return 0
}

# Classifies a target without installing it so workflow prompts can group missing and changed files.
# Missing targets return nonzero but still set _opencode_target_status for callers that expect that state.
opencode_install_target_status() {
  local path_type=$1 src=$2 dst=$3 display=$4 dest_dir=${5:-}
  local install_parent
  _opencode_target_status=""

  if [ "$path_type" != "file" ] && [ "$path_type" != "dir" ]; then
    warn "Unsupported install type for $display: $path_type"
    _opencode_target_status="failed"
    return 1
  fi

  if [ "$path_type" = "file" ] && [ ! -f "$src" ]; then
    warn "$display source is not a file: $src"
    _opencode_target_status="failed"
    return 1
  fi
  if [ "$path_type" = "dir" ] && [ ! -d "$src" ]; then
    warn "$display source is not a directory: $src"
    _opencode_target_status="failed"
    return 1
  fi

  install_parent=${dest_dir:-$(dirname "$dst")}
  if [ -e "$install_parent" ] && [ ! -d "$install_parent" ]; then
    warn "$display parent destination exists and is not a directory: $install_parent"
    _opencode_target_status="blocked"
    return 1
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if { [ "$path_type" = "file" ] && [ ! -f "$dst" ]; } || { [ "$path_type" = "dir" ] && [ ! -d "$dst" ]; }; then
      warn "$display destination type does not match $path_type: $dst"
      _opencode_target_status="blocked"
      return 1
    fi

    if deploy_diff_safe_paths_match "$path_type" "$src" "$dst"; then
      _opencode_target_status="match"
    else
      _opencode_target_status="changed"
    fi
  else
    _opencode_target_status="missing"
    return 1
  fi
}

# Classifies one workflow target, records its status in _workflow_target_status,
# and folds it into the shared counters. match is the no-op case (no counter).
_count_workflow_target_status() {
  opencode_install_target_status "$@" || true
  _workflow_target_status=$_opencode_target_status
  case "$_workflow_target_status" in
    match) ;;
    missing) _workflow_missing_count=$((_workflow_missing_count+1)) ;;
    changed) _workflow_changed_count=$((_workflow_changed_count+1)) ;;
    blocked) _workflow_blocked_count=$((_workflow_blocked_count+1)) ;;
    *) _workflow_failed_count=$((_workflow_failed_count+1)) ;;
  esac
}

opencode_workflow_status_counts() {
  local agent skill src dest
  _workflow_missing_count=0
  _workflow_changed_count=0
  _workflow_blocked_count=0
  _workflow_failed_count=0
  _workflow_file_statuses=()
  _workflow_skill_statuses=()

  for agent in "${OPENCODE_WORKFLOW_AGENTS[@]}"; do
    src="$DOTFILES_DIR/.config/opencode/agents/$agent.md"
    dest="$OPENCODE_CONFIG_DIR/agents/$agent.md"
    _count_workflow_target_status file "$src" "$dest" "Agent $agent" "$OPENCODE_CONFIG_DIR/agents"
    _workflow_file_statuses+=("$_workflow_target_status")
  done

  for skill in "${OPENCODE_WORKFLOW_LOCAL_SKILLS[@]}"; do
    src="$DOTFILES_DIR/.config/opencode/skills/$skill"
    dest="$OPENCODE_CONFIG_DIR/skills/$skill"
    _count_workflow_target_status dir "$src" "$dest" "Skill $skill" "$OPENCODE_CONFIG_DIR/skills"
    _workflow_skill_statuses+=("$_workflow_target_status")
  done
}

install_opencode_workflow_targets_with_status() {
  local desired_status=$1 install_consent_granted=${2:-false}
  local _i agent skill

  for _i in "${!OPENCODE_WORKFLOW_AGENTS[@]}"; do
    agent="${OPENCODE_WORKFLOW_AGENTS[$_i]}"
    [ "${_workflow_file_statuses[$_i]:-}" = "$desired_status" ] || continue
    install_opencode_agent_file "$agent" "$install_consent_granted" || _workflow_targets_had_failures=true
  done

  for _i in "${!OPENCODE_WORKFLOW_LOCAL_SKILLS[@]}"; do
    skill="${OPENCODE_WORKFLOW_LOCAL_SKILLS[$_i]}"
    [ "${_workflow_skill_statuses[$_i]:-}" = "$desired_status" ] || continue
    install_opencode_local_skill "$skill" "$install_consent_granted" || _workflow_targets_had_failures=true
  done
}

install_opencode_workflow_files() {
  local agent skill

  for agent in "${OPENCODE_WORKFLOW_AGENTS[@]}"; do
    install_opencode_agent_file "$agent"
  done

  for skill in "${OPENCODE_WORKFLOW_LOCAL_SKILLS[@]}"; do
    install_opencode_local_skill "$skill"
  done
}

opencode_local_skill_in_workflows() {
  local skill=$1 workflow_skill

  for workflow_skill in "${OPENCODE_WORKFLOW_LOCAL_SKILLS[@]}"; do
    [ "$skill" = "$workflow_skill" ] && return 0
  done

  return 1
}

setup_opencode_standalone_local_skill_installs() {
  local skill src dest
  _standalone_skills_had_failures=false

  if ! installer_available opencode; then
    if $DRY_RUN; then
      ok "OpenCode install not completed. Showing standalone skill plan anyway"
    else
      skip_installer_setup opencode "Standalone skills" "setup"
      return 0
    fi
  fi

  step "Installing standalone skills"

  for skill in "${OPENCODE_STANDALONE_LOCAL_SKILLS[@]}"; do
    if opencode_local_skill_in_workflows "$skill"; then
      ok "Skill $skill is shared by the OpenCode workflows. Standalone prompt skipped"
      continue
    fi

    src="$DOTFILES_DIR/.config/opencode/skills/$skill"
    dest="$OPENCODE_CONFIG_DIR/skills/$skill"
    opencode_install_target_status dir "$src" "$dest" "Skill $skill" "$OPENCODE_CONFIG_DIR/skills" || true

    case "$_opencode_target_status" in
      match)
        ok "Skill $skill already up to date. Standalone install skipped"
        ;;
      missing)
        if $DRY_RUN; then
          would "Would ask to install standalone skill $skill to $dest"
        else
          install_opencode_local_skill "$skill" || _standalone_skills_had_failures=true
        fi
        ;;
      changed)
        if $DRY_RUN; then
          would "Diff needed for standalone skill $skill at $dest. Would show diff and ask before replacing"
        else
          install_opencode_local_skill "$skill" || _standalone_skills_had_failures=true
        fi
        ;;
      blocked)
        ok "Skill $skill skipped"
        _standalone_skills_had_failures=true
        ;;
      *)
        warn "Skill $skill skipped because its source could not be validated"
        _standalone_skills_had_failures=true
        ;;
    esac
  done
}

setup_opencode_workflow_installs() {
  if ! installer_available opencode; then
    if $DRY_RUN; then
      ok "OpenCode install not completed. Showing workflow file plan anyway"
    else
      skip_installer_setup opencode "OpenCode workflows" "setup"
      return 0
    fi
  fi

  step "Installing OpenCode workflows"

  if $DRY_RUN; then
    install_opencode_workflow_files
    setup_opencode_standalone_local_skill_installs
    return 0
  fi

  local _cf_ok=true
  opencode_workflow_status_counts

  if [ $_workflow_missing_count -eq 0 ] && [ $_workflow_changed_count -eq 0 ] && [ $_workflow_blocked_count -eq 0 ] && [ $_workflow_failed_count -eq 0 ]; then
    ok "OpenCode workflows already up to date"
  else
    if [ $_workflow_missing_count -gt 0 ]; then
      if install_consent "Install OpenCode workflows ($_workflow_missing_count missing item(s))?" y; then
        _workflow_targets_had_failures=false
        install_opencode_workflow_targets_with_status missing true
        $_workflow_targets_had_failures && _cf_ok=false
      else
        ok "OpenCode workflow missing items skipped"
        _cf_ok=false
      fi
    fi

    if [ $_workflow_changed_count -gt 0 ]; then
      _workflow_targets_had_failures=false
      install_opencode_workflow_targets_with_status changed false
      $_workflow_targets_had_failures && _cf_ok=false
    fi

    if [ $_workflow_blocked_count -gt 0 ] || [ $_workflow_failed_count -gt 0 ]; then
      warn "OpenCode workflows have $_workflow_blocked_count blocked and $_workflow_failed_count failed target(s)"
      _cf_ok=false
    fi
  fi

  _standalone_skills_had_failures=false
  setup_opencode_standalone_local_skill_installs
  $_standalone_skills_had_failures && _cf_ok=false

  if $_cf_ok; then
    CF_OK+=("OpenCode/agents")
    CF_OK+=("OpenCode/skills")
  fi
}

install_external_opencode_skills() {
  local _entry _skill _source _skills_str _status _path
  local _external_had_failures=false
  local _opencode_external_skill_status _opencode_external_skill_path
  local -a _skill_roots _cmd _stale_skills _missing_skills _missing_skill_args

  if ! installer_available opencode; then
    skip_installer_setup opencode "Skills" "setup"
    return 0
  fi

  step "Installing skills"

  # The skills CLI writes global skills to ~/.agents/skills.
  # Keep the legacy OpenCode/Claude roots so existing installs still count.
  _skill_roots=(
    "$HOME/.agents/skills"
    "$OPENCODE_CONFIG_DIR/skills"
    "$HOME/.claude/skills"
  )
  _stale_skills=(
    "react-best-practices:vercel-react-best-practices"
    "composition-patterns:vercel-composition-patterns"
  )

  opencode_external_skill_status() {
    local skill=$1 skill_root skill_dir skill_file first_collision=""

    _opencode_external_skill_path=""

    for skill_root in "${_skill_roots[@]}"; do
      skill_dir="$skill_root/$skill"
      skill_file="$skill_dir/SKILL.md"

      if [ -f "$skill_file" ]; then
        if grep -Eq "^[[:space:]]*name:[[:space:]]*[\"']?${skill}[\"']?[[:space:]]*$" "$skill_file"; then
          _opencode_external_skill_path=$skill_file
          _opencode_external_skill_status=installed
          return 0
        fi
        [ -z "$first_collision" ] && first_collision=$skill_file
        continue
      fi

      if [ -e "$skill_dir" ] || [ -L "$skill_dir" ]; then
        [ -z "$first_collision" ] && first_collision=$skill_dir
      fi
    done

    if [ -n "$first_collision" ]; then
      _opencode_external_skill_path=$first_collision
      _opencode_external_skill_status=collision
      return 0
    fi

    _opencode_external_skill_status=missing
    return 1
  }

  opencode_stale_external_skill_matches() {
    local stale_path=$1 replacement_skill=$2

    [ -f "$stale_path/SKILL.md" ] && grep -Eq "^[[:space:]]*name:[[:space:]]*[\"']?${replacement_skill}[\"']?[[:space:]]*$" "$stale_path/SKILL.md"
  }

  cleanup_stale_external_opencode_skills() {
    local stale_entry stale_dir replacement_skill stale_path replacement_status replacement_path

    for stale_entry in "${_stale_skills[@]}"; do
      stale_dir=${stale_entry%%:*}
      replacement_skill=${stale_entry#*:}
      stale_path="$OPENCODE_CONFIG_DIR/skills/$stale_dir"

      if ! opencode_stale_external_skill_matches "$stale_path" "$replacement_skill"; then
        if $DRY_RUN; then
          if [ -e "$stale_path" ] || [ -L "$stale_path" ]; then
            would "Skip stale skill cleanup for $stale_dir. $stale_path does not identify as $replacement_skill"
          else
            ok "No stale skill $stale_dir found at $stale_path"
          fi
        fi
        continue
      fi

      opencode_external_skill_status "$replacement_skill" || true
      replacement_status=$_opencode_external_skill_status
      replacement_path=$_opencode_external_skill_path

      case "$replacement_status" in
        installed)
          if $DRY_RUN; then
            would "Would ask to remove stale skill $stale_dir at $stale_path (replaced by $replacement_skill at $replacement_path)"
          else
            if ! install_consent "Remove stale skill $stale_dir?" y; then
              ok "Stale skill $stale_dir unchanged"
            else
              rm -rf "$stale_path"
              ok "Removed stale skill $stale_dir"
            fi
          fi
          ;;
        collision)
          if $DRY_RUN; then
            would "Skip stale skill cleanup for $stale_dir. Replacement $replacement_skill has collision at $replacement_path"
          else
            warn "Stale skill $stale_dir unchanged. Replacement $replacement_skill has collision at $replacement_path"
          fi
          ;;
        missing)
          if $DRY_RUN; then
            would "Would consider removing stale skill $stale_dir at $stale_path after $replacement_skill is installed"
          else
            ok "Stale skill $stale_dir unchanged. Replacement $replacement_skill is not installed"
          fi
          ;;
      esac
    done
  }

  # Each spec groups all skills from the same source repo so they install in one npx call.
  for _entry in "${OPENCODE_EXTERNAL_SKILL_SPECS[@]}"; do
    _source=${_entry%%|*}
    _skills_str=${_entry#*|}

    _missing_skills=()
    _missing_skill_args=()

    for _skill in $_skills_str; do
      opencode_external_skill_status "$_skill" || true
      _status=$_opencode_external_skill_status
      _path=$_opencode_external_skill_path

      case "$_status" in
        installed)
          if $DRY_RUN; then
            would "Skip skill $_skill. Already installed at $_path"
          else
            ok "Skill $_skill already installed at $_path. Skipped"
          fi
          ;;
        collision)
          if $DRY_RUN; then
            would "Skip skill $_skill. Collision at $_path (expected name: $_skill)"
          else
            warn "Skill $_skill skipped. Target exists at $_path but does not identify as $_skill"
          fi
          ;;
        missing)
          _missing_skills+=("$_skill")
          _missing_skill_args+=(--skill "$_skill")
          ;;
      esac
    done

    [ ${#_missing_skills[@]} -eq 0 ] && continue

    _cmd=(npx -y skills add "$_source" "${_missing_skill_args[@]}" "${OPENCODE_EXTERNAL_SKILL_COMMON_ARGS[@]}")

    if $DRY_RUN; then
      would "Would ask to install skill(s): ${_missing_skills[*]}"
      would "${_cmd[*]}"
    elif ! command -v npx &>/dev/null; then
      warn "npx not found, skipping skill(s): ${_missing_skills[*]}"
      _external_had_failures=true
    elif install_consent "Install skill(s): $(join_arr ', ' "${_missing_skills[@]}")?" y; then
      if "${_cmd[@]}" &>/dev/null; then
        installed "$(join_arr ', ' "${_missing_skills[@]}") skill(s)"
      else
        warn "Failed to install $(join_arr ', ' "${_missing_skills[@]}") skill(s)"
        _external_had_failures=true
      fi
    else
      ok "Skill(s) $(join_arr ', ' "${_missing_skills[@]}") skipped"
      _external_had_failures=true
    fi
  done

  cleanup_stale_external_opencode_skills

  $_external_had_failures || $DRY_RUN || CF_OK+=("skills")

  unset -f opencode_external_skill_status opencode_stale_external_skill_matches cleanup_stale_external_opencode_skills
}

reinstall_missing_cask_app() {
  local name=$1 cask=$2 app=$3

  warn "$name Homebrew cask is registered, but $app is missing"
  if $DRY_RUN; then
    would "Would ask to reinstall $name"
    return 0
  fi

  if ! install_consent "Reinstall $name?" y; then
    ok "$name reinstall skipped"
    return 2
  fi

  if brew reinstall --cask "$cask" &>/dev/null && app_bundle_exists "$app"; then
    installed "$name"
    return 0
  fi

  warn "Failed to reinstall $name"
  return 1
}

collect_git_commit_author_identity() {
  step "Setting Git commit author identity"

  if $DRY_RUN; then
    would "ask whether to configure Git commit author identity"
    would "collect Git commit author name (default: Pedro Menezes) and required Git commit author email if accepted"
    would "use the collected Git commit author identity for global Git config if accepted"
    echo "  Git uses this identity for commit authorship."
    echo "  GitHub uses the email to associate commits with your account."
    echo "  .gitconfig deployment is independent of Git commit author identity."
    return 0
  fi

  echo "  Git uses this identity for commit authorship."
  echo "  GitHub uses the email to associate commits with your account."

  if ! install_consent "Configure Git commit author identity?" y; then
    ok "Git commit author identity skipped"
    return 0
  fi

  GIT_COMMIT_AUTHOR_IDENTITY_CONFIGURE=true

  read -r -p "  Git commit author name [Pedro Menezes]: " GIT_COMMIT_AUTHOR_NAME
  GIT_COMMIT_AUTHOR_NAME="${GIT_COMMIT_AUTHOR_NAME:-Pedro Menezes}"

  while true; do
    if ! read -r -p "  Git commit author email: " GIT_COMMIT_AUTHOR_EMAIL; then
      warn "No input for Git commit author email. Skipping identity configuration"
      GIT_COMMIT_AUTHOR_IDENTITY_CONFIGURE=false
      break
    fi
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
    would "Would start Xcode CLT installation"
  else
    xcode-select --install 2>/dev/null || true
    warn "Xcode CLT installation started. Complete the installer, then re-run this script"
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
# Keep template deployment separate from author identity so local name/email are not overwritten silently.
if [ -f "$DOTFILES_DIR/.gitconfig" ]; then
  if $DRY_RUN; then
    would "cp .gitconfig to ~/.gitconfig (independent of Git commit author identity)"
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
        if ! install_consent ".gitconfig already exists. Overwrite?" y; then
          _gitconfig_needs_copy=false
        fi
      fi
    fi
    if $_gitconfig_needs_copy; then
      cp "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
      installed ".gitconfig"
    else
      ok ".gitconfig template unchanged"
    fi
    if $GIT_COMMIT_AUTHOR_IDENTITY_CONFIGURE; then
      if git config --global user.name "$GIT_COMMIT_AUTHOR_NAME" && git config --global user.email "$GIT_COMMIT_AUTHOR_EMAIL"; then
        ok "Git commit author identity configured ($GIT_COMMIT_AUTHOR_NAME <$GIT_COMMIT_AUTHOR_EMAIL>)"
      else
        warn "Failed to configure Git commit author identity"
      fi
    else
      if [ "$(git config --global user.email 2>/dev/null)" = "email_here" ]; then
        warn "Git user.email is the placeholder 'email_here'. Set it: git config --global user.email you@example.com"
      fi
      ok "Git commit author identity skipped"
    fi
    CF_OK+=(".gitconfig")
    unset _gitconfig_needs_copy _current_email _files_match
    unset -f _strip_identity
  fi
fi
# The repo stores ssh_config flat, but OpenSSH reads it from ~/.ssh/config.
if [ -f "$DOTFILES_DIR/ssh_config" ]; then
  if deploy_prompted_file "$DOTFILES_DIR/ssh_config" "$HOME/.ssh/config" "$HOME/.ssh/config" \~/.ssh/config "cp ssh_config to ~/.ssh/config" "$HOME/.ssh" 700 600; then
    [ "$_deploy_result" != "dry-run" ] && CF_OK+=("ssh_config")
  fi
else
  warn "ssh_config not found, skipping"
fi
refresh_dotfiles_summary

# 2. Homebrew
step "Installing Homebrew and packages"

if ! command -v brew &>/dev/null; then
  if $DRY_RUN; then
    would "Would ask to install Homebrew"
  else
    if ! install_consent "Install Homebrew?" y; then
      ok "Homebrew skipped"
    else
      _brew_install_script=$(mktemp) || { warn "Failed to create temporary Homebrew installer file"; _brew_install_script=""; }
      if [ -n "$_brew_install_script" ] && curl -fsSL --connect-timeout 10 --max-time 300 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$_brew_install_script" && /bin/bash "$_brew_install_script"; then
        if [ -x /opt/homebrew/bin/brew ]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
          eval "$(/usr/local/bin/brew shellenv)"
        fi

        if command -v brew &>/dev/null; then
          installed "Homebrew"
          warn "Homebrew was added to this session's PATH. Restart your terminal to make it permanent"
        else
          warn "Homebrew installed, but brew is not available on PATH"
        fi
      else
        warn "Failed to install Homebrew"
      fi
      [ -n "$_brew_install_script" ] && rm -f "$_brew_install_script"
      unset _brew_install_script
    fi
  fi
else
  if $DRY_RUN; then
    would "Would update Homebrew"
  else
    brew update &>/dev/null && ok "Homebrew up to date"
  fi
fi

for pkg in bash git bash-completion@2 pnpm gh dockutil; do
  brew_formula "$pkg"
done

install_opencode

# VS Code: check app bundle first since 'code' CLI may not be in PATH
if app_bundle_exists "/Applications/Visual Studio Code.app"; then
  if brew_cask_registered visual-studio-code; then
    brew_cask "visual-studio-code" --install-consent-granted
  else
    ok "VS Code already installed, skipping installation"
  fi
elif brew_cask_registered visual-studio-code; then
  reinstall_missing_cask_app "VS Code" "visual-studio-code" "/Applications/Visual Studio Code.app"
elif $DRY_RUN; then
  would "Would ask to install VS Code"
elif ! brew_available; then
  warn "Homebrew not found, skipping VS Code"
else
  if ! install_consent "Install VS Code?" y; then
    ok "VS Code skipped"
  else
    brew_cask "visual-studio-code" --install-consent-granted
  fi
fi

install_claude_code
brew_cask "font-fira-code"

deploy_claude_code_config
setup_opencode_workflow_installs
deploy_opencode_config
refresh_dotfiles_summary

HB_PARTS=()
[ $BREW_INSTALLED -gt 0 ] && HB_PARTS+=("${BREW_INSTALLED} installed")
[ $BREW_UPDATED -gt 0 ]   && HB_PARTS+=("${BREW_UPDATED} updated")
[ $BREW_SKIPPED -gt 0 ]   && HB_PARTS+=("${BREW_SKIPPED} upgrade(s) skipped")
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
    if ! install_consent "Generate SSH key (~/.ssh/id_ed25519)?" y; then
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
            warn "Failed to add SSH key to GitHub. Run manually: gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
          fi
        else
          if ! install_consent "Not authenticated with GitHub. Run gh auth login now?" y; then
            warn "Skipped GitHub login. Run manually: gh auth login && gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
          else
            gh auth login
            if gh auth status &>/dev/null 2>&1; then
              if gh ssh-key add "${SSH_KEY_PATH}.pub" --title "$SSH_KEY_TITLE"; then
                installed "SSH key on GitHub"
                SUM_SSH="${GREEN}✔${RESET} key generated · added to GitHub"
              else
                warn "Failed to add SSH key to GitHub. Run manually: gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
              fi
            else
              warn "Still not authenticated. Run manually: gh ssh-key add ~/.ssh/id_ed25519.pub --title \"$SSH_KEY_TITLE\""
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

resolve_homebrew_bash() {
  local brew_prefix bash_prefix candidate arch

  if command -v brew &>/dev/null; then
    if bash_prefix=$(brew --prefix bash 2>/dev/null) && [ -n "$bash_prefix" ]; then
      candidate="$bash_prefix/bin/bash"
      if $DRY_RUN || [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi

    if brew_prefix=$(brew --prefix 2>/dev/null) && [ -n "$brew_prefix" ]; then
      candidate="$brew_prefix/bin/bash"
      if $DRY_RUN || [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  fi

  arch=$(uname -m 2>/dev/null || true)
  case "$arch" in
    arm64) set -- /opt/homebrew/bin/bash /usr/local/bin/bash ;;
    *) set -- /usr/local/bin/bash /opt/homebrew/bin/bash ;;
  esac

  for candidate in "$@"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if $DRY_RUN; then
    printf '%s\n' "$1"
    return 0
  fi

  return 1
}

HOMEBREW_BASH=$(resolve_homebrew_bash || true)

if [ -z "$HOMEBREW_BASH" ]; then
  warn "Homebrew bash not found. Was 'brew install bash' successful? Skipping shell switch"
  SUM_SHELL="${YELLOW}⚠${RESET} Homebrew bash not found"
else
  if grep -Fxq "$HOMEBREW_BASH" /etc/shells; then
    ok "$HOMEBREW_BASH already in /etc/shells"
  else
    if $DRY_RUN; then
      if [ -x "$HOMEBREW_BASH" ]; then
        would "echo $HOMEBREW_BASH | sudo tee -a /etc/shells"
      else
        would "echo $HOMEBREW_BASH | sudo tee -a /etc/shells (if Homebrew bash exists after install)"
      fi
    else
      if echo "$HOMEBREW_BASH" | sudo tee -a /etc/shells >/dev/null; then
        installed "$HOMEBREW_BASH in /etc/shells"
      else
        warn "Failed to add $HOMEBREW_BASH to /etc/shells. Try manually: echo \"$HOMEBREW_BASH\" | sudo tee -a /etc/shells"
      fi
    fi
  fi

  if [ "$SHELL" = "$HOMEBREW_BASH" ]; then
    ok "Already using Homebrew bash"
    SUM_SHELL="${GREEN}✔${RESET} Homebrew bash active"
  else
    if $DRY_RUN; then
      if [ -x "$HOMEBREW_BASH" ]; then
        would "chsh -s $HOMEBREW_BASH"
      else
        would "chsh -s $HOMEBREW_BASH (if Homebrew bash exists after install)"
      fi
    else
      if ! install_consent "Switch default shell to Homebrew bash?" y; then
        ok "Shell unchanged"
        SUM_SHELL="${GREEN}✔${RESET} unchanged"
      else
        if chsh -s "$HOMEBREW_BASH"; then
          installed "default shell → $HOMEBREW_BASH"
          SUM_SHELL="${GREEN}✔${RESET} switched to Homebrew bash"
        else
          warn "Failed to set default shell. Try manually: chsh -s $HOMEBREW_BASH"
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
      if ! install_consent "Upgrade nvm $current_nvm → $NVM_VERSION?" y; then
        ok "nvm upgrade skipped"
      else
        if (set -o pipefail; curl -fsSL --connect-timeout 10 --max-time 300 "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash) &>/dev/null; then
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
    would "Would ask to install nvm $NVM_VERSION"
  else
    if ! install_consent "Install nvm $NVM_VERSION?" y; then
      ok "nvm install skipped"
    else
      if (set -o pipefail; curl -fsSL --connect-timeout 10 --max-time 300 "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash) &>/dev/null; then
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        installed "nvm $NVM_VERSION"
      else
        warn "Failed to install nvm"
      fi
    fi
  fi
fi

if $DRY_RUN; then
  would "Would install Node.js LTS and set it as default"
elif ! command -v nvm &>/dev/null; then
  warn "nvm not available, skipping Node.js"
  SUM_NODE="${YELLOW}⚠${RESET} nvm unavailable"
else
  prev_node=$(node --version 2>/dev/null || echo "none")
  latest_lts=$(nvm version-remote --lts 2>/dev/null)
  if [ "$latest_lts" = "N/A" ]; then
    latest_lts=
  fi
  if [ "$prev_node" = "$latest_lts" ]; then
    ok "Node.js LTS ($prev_node)"
    SUM_NODE="${GREEN}✔${RESET} $prev_node"
  elif [ -z "$latest_lts" ] && [ "$prev_node" != "none" ]; then
    warn "Could not determine the latest Node.js LTS (offline?). Keeping $prev_node"
    SUM_NODE="${GREEN}✔${RESET} $prev_node"
  elif [ -n "$latest_lts" ] && [ "$prev_node" != "none" ]; then
    if ! install_consent "Set Node.js LTS ($latest_lts) as default?" y; then
      ok "Node.js unchanged"
      SUM_NODE="${GREEN}✔${RESET} $prev_node"
    else
      if nvm install "$latest_lts" >/dev/null 2>&1 && nvm alias default "$latest_lts" >/dev/null 2>&1; then
        updated "Node.js LTS default → $latest_lts"
        SUM_NODE="${BLUE}↑${RESET} $latest_lts"
      else
        warn "Failed to set Node.js LTS default"
        SUM_NODE="${YELLOW}⚠${RESET} failed"
      fi
    fi
  else
    if ! install_consent "Install Node.js LTS?" y; then
      ok "Node.js install skipped"
      SUM_NODE="${GREEN}✔${RESET} skipped"
    else
      if nvm install --lts >/dev/null 2>&1; then
        NODE_VERSION=$(node --version 2>/dev/null || echo 'unknown')
        if nvm alias default "$NODE_VERSION" >/dev/null 2>&1; then
          installed "Node.js LTS ($NODE_VERSION)"
          SUM_NODE="${GREEN}✔${RESET} $NODE_VERSION"
        else
          warn "Failed to set Node.js LTS default"
          SUM_NODE="${YELLOW}⚠${RESET} default alias failed"
        fi
      else
        warn "Failed to install Node.js LTS"
        SUM_NODE="${YELLOW}⚠${RESET} install failed"
      fi
    fi
  fi
fi

# Skills installed with npx run after Node is available.
install_external_opencode_skills
refresh_dotfiles_summary

# 6. VS Code extensions and settings
step "Setting up VS Code"

if ! command -v code &>/dev/null; then
  warn "VS Code CLI not found. In VS Code, open the Command Palette and run: Shell Command: Install 'code' command in PATH"
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
  installed_exts=$(code --list-extensions 2>/dev/null || true)
  exts_missing=()
  for ext in "${extensions[@]}"; do
    echo "$installed_exts" | grep -Fqix "$ext" || exts_missing+=("$ext")
  done
  VSCODE_EXT_OK=$(( ${#extensions[@]} - ${#exts_missing[@]} ))

  if $DRY_RUN; then
    if [ ${#exts_missing[@]} -eq 0 ]; then
      ok "All ${#extensions[@]} extensions already installed"
    else
      would "Would ask to install ${#exts_missing[@]} VS Code extension(s)"
    fi
    for ext in "${exts_missing[@]}"; do
      would "code --install-extension $ext"
    done
  else
    if [ ${#exts_missing[@]} -eq 0 ]; then
      ok "All ${#extensions[@]} extensions already installed"
    else
      if ! install_consent "Install ${#exts_missing[@]} VS Code extension(s)?" y; then
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
    for config_file in settings.json keybindings.json; do
      if [ -f "$VSCODE_DIR/$config_file" ] && diff -q "$VSCODE_DIR/$config_file" "$DOTFILES_DIR/$config_file" &>/dev/null; then
        ok "$config_file already up to date"
        VSCODE_SETTINGS_OK+=("$config_file")
      elif [ -f "$VSCODE_DIR/$config_file" ]; then
        would "Ask to overwrite VS Code $config_file"
      else
        would "cp $config_file to VS Code"
      fi
    done
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
        if ! install_consent "$config_file already exists. Overwrite?" y; then
          ok "$config_file unchanged"
          VSCODE_SETTINGS_OK+=("$config_file")
          continue
        fi
      fi
      if cp "$DOTFILES_DIR/$config_file" "$VSCODE_DIR/$config_file"; then
        installed "$config_file"
        VSCODE_SETTINGS_NEW+=("$config_file")
      else
        warn "Failed to copy $config_file to $VSCODE_DIR"
      fi
    done
  fi

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
  local name=$1 cask=$2 app=$3
  if $DRY_RUN; then
    if brew_cask_registered "$cask"; then
      if app_bundle_exists "$app"; then
        brew_cask "$cask" --install-consent-granted
      else
        reinstall_missing_cask_app "$name" "$cask" "$app"
      fi
    elif app_bundle_exists "$app"; then
      ok "$name already installed, skipping installation"
      APP_OK+=("$name")
    else
      would "Would ask to install $name"
    fi
  elif brew_cask_registered "$cask"; then
    if app_bundle_exists "$app"; then
      if brew_cask "$cask" --install-consent-granted; then
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
  elif app_bundle_exists "$app"; then
    ok "$name already installed, skipping installation"
    APP_OK+=("$name")
  elif ! brew_available; then
    warn "Homebrew not found, skipping $name"
    return 1
  else
    if ! install_consent "Install $name?" y; then
      ok "$name skipped"
    else
      if brew_cask "$cask" --install-consent-granted; then
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

# Merge only managed iStat Menus keys so licenses and device-specific data survive setup runs.
ISTATMENUS_PLIST="$HOME/Library/Preferences/com.bjango.istatmenus.menubar.7.plist"
istatmenus_settings_current() {
  [ -f "$ISTATMENUS_PLIST" ] && DOTFILES_DIR="$DOTFILES_DIR" ISTATMENUS_PLIST="$ISTATMENUS_PLIST" python3 - <<'PYEOF'
import os, plistlib, sys
with open(os.path.join(os.environ["DOTFILES_DIR"], "istatmenus.menubar.plist"), "rb") as f: src = plistlib.load(f)
with open(os.environ["ISTATMENUS_PLIST"], "rb") as f: dst = plistlib.load(f)
sys.exit(0 if all(dst.get(k) == v for k, v in src.items()) else 1)
PYEOF
}
istatmenus_state_check_available() {
  command -v python3 >/dev/null && xcode-select -p >/dev/null 2>&1
}
istatmenus_settings_apply() {
  # cfprefsd can overwrite direct plist writes with a cached copy of this domain.
  killall cfprefsd 2>/dev/null || true
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
if ! app_bundle_exists "/Applications/iStat Menus.app"; then
  ok "iStat Menus settings skipped (app not installed)"
elif $DRY_RUN; then
  if ! istatmenus_state_check_available; then
    would "Ask to apply iStat Menus settings (skipped state check: python3 or Xcode CLT unavailable)"
  elif istatmenus_settings_current; then
    ok "iStat Menus settings already up to date"
    APP_OK+=("iStat Menus settings")
  else
    would "Ask to apply iStat Menus settings (merge istatmenus.menubar.plist into $ISTATMENUS_PLIST)"
  fi
elif istatmenus_settings_current; then
  ok "iStat Menus settings already up to date"
  APP_OK+=("iStat Menus settings")
else
  if ! install_consent "Apply iStat Menus settings?" y; then
    ok "iStat Menus settings skipped"
  else
    if istatmenus_settings_apply; then
      ok "iStat Menus settings applied (restart iStat Menus to take effect)"
      APP_OK+=("iStat Menus settings")
    else
      warn "Failed to apply iStat Menus settings"
    fi
  fi
fi

[ ${#APP_OK[@]} -gt 0 ] && SUM_APPS="${GREEN}✔${RESET} $(join_arr ' · ' "${APP_OK[@]}")"

# 8. Ghostty
step "Setting up Ghostty"

if app_bundle_exists "/Applications/Ghostty.app"; then
  if brew_cask_registered ghostty; then
    brew_cask "ghostty" --install-consent-granted
  else
    ok "Ghostty already installed, skipping installation"
  fi
  SUM_GHOSTTY="${GREEN}✔${RESET} installed"
elif brew_cask_registered ghostty; then
  reinstall_missing_cask_app "Ghostty" "ghostty" "/Applications/Ghostty.app"
  _ghostty_reinstall_status=$?
  if ! $DRY_RUN; then
    case $_ghostty_reinstall_status in
      0) SUM_GHOSTTY="${GREEN}✔${RESET} installed" ;;
      1|2) ;;
    esac
  fi
  unset _ghostty_reinstall_status
elif $DRY_RUN; then
  would "Would ask to install Ghostty"
elif ! brew_available; then
  warn "Homebrew not found, skipping Ghostty"
else
  if ! install_consent "Install Ghostty?" y; then
    ok "Ghostty skipped"
  else
    brew_cask "ghostty" --install-consent-granted && SUM_GHOSTTY="${GREEN}✔${RESET} installed"
  fi
fi
# Deploy Ghostty config even when the app was already installed outside this script.
_ghostty_src="$DOTFILES_DIR/.config/ghostty/config"
_ghostty_dest="$HOME/.config/ghostty/config"
if [ -f "$_ghostty_src" ]; then
  deploy_prompted_file "$_ghostty_src" "$_ghostty_dest" "ghostty/config" "ghostty/config" "cp .config/ghostty/config to $_ghostty_dest" "$HOME/.config/ghostty"
fi
unset _ghostty_src _ghostty_dest

# Themes are copied one-by-one so local theme changes still get a per-file diff prompt.
if [ -d "$DOTFILES_DIR/.config/ghostty/themes" ]; then
  for _ghostty_theme_src in "$DOTFILES_DIR/.config/ghostty/themes"/*; do
    [ -f "$_ghostty_theme_src" ] || continue
    _ghostty_theme_name=$(basename "$_ghostty_theme_src")
    _ghostty_theme_dest="$HOME/.config/ghostty/themes/$_ghostty_theme_name"
    deploy_prompted_file "$_ghostty_theme_src" "$_ghostty_theme_dest" "ghostty/themes/$_ghostty_theme_name" "ghostty/themes/$_ghostty_theme_name" "cp .config/ghostty/themes/$_ghostty_theme_name to $_ghostty_theme_dest" "$HOME/.config/ghostty/themes"
  done
fi
unset _ghostty_theme_src _ghostty_theme_name _ghostty_theme_dest

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

# defaults may read booleans back as 1/0 even when we write true/false.
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

# Compute each group once so the prompt and diff output describe the same state.
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
  _pref_matches NSGlobalDomain EnableTilingByEdgeDrag false &&
  _pref_matches NSGlobalDomain EnableTilingByMenuBar false; } || system_current=false

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
    if ! install_consent "Apply Dock settings?" y; then
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
      _dock_rebuild_failed=false
      if command -v dockutil &>/dev/null; then
        _dock_fail=0
        if ! dockutil --remove all --no-restart &>/dev/null; then
          warn "Failed to clear Dock before rebuilding"
          _dock_fail=1
        fi
        _dock_add_app() {
          local name=$1 app=$2 resolved_app
          if resolved_app=$(app_bundle_path "$app"); then
            if ! dockutil --add "$resolved_app" --no-restart &>/dev/null; then
              warn "Failed to add $name to Dock"
              _dock_fail=1
            fi
          else
            ok "$name not found, skipping Dock item"
          fi
        }
        _dock_add_app "Google Chrome" "/Applications/Google Chrome.app"
        _dock_add_app "Visual Studio Code" "/Applications/Visual Studio Code.app"
        _dock_add_app "Ghostty" "/Applications/Ghostty.app"
        _dock_add_app "1Password" "/Applications/1Password.app"
        _dock_add_app "Spotify" "/Applications/Spotify.app"
        unset -f _dock_add_app
        if [ "$_dock_fail" -eq 0 ]; then
          ok "Dock apps set: Finder, Google Chrome, VS Code, Ghostty, 1Password, Spotify, Trash"
        else
          warn "Dock rebuild had failures; check the Dock manually"
          _dock_rebuild_failed=true
        fi
        unset _dock_fail
      fi
      if $_dock_rebuild_failed; then
        updated "Dock preferences"
        MACOS_UPDATED+=("Dock preferences")
      else
        updated "Dock"
        MACOS_UPDATED+=("Dock")
      fi
      NEEDS_RESTART=true
      unset _dock_rebuild_failed
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
    if ! install_consent "Apply Finder settings?" y; then
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
    _pref_diff "Disable tiling on edge drag" NSGlobalDomain EnableTilingByEdgeDrag              false
    _pref_diff "Disable tiling on menu bar" NSGlobalDomain EnableTilingByMenuBar               false
    if ! install_consent "Apply System settings?" y; then
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
      _pref_write NSGlobalDomain EnableTilingByEdgeDrag -bool false
      _pref_write NSGlobalDomain EnableTilingByMenuBar -bool false
      updated "System settings"; MACOS_UPDATED+=("System settings"); NEEDS_RESTART=true
    fi
  fi

  # Screenshots
  if $screenshot_current; then
    ok "Screenshots already configured"
  else
    _pref_diff "Disable thumbnail preview"  com.apple.screencapture show-thumbnail false
    if ! install_consent "Apply Screenshots settings?" y; then
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
    if ! install_consent "Apply menu bar settings?" y; then
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

setup_peripheral() {
  local name=$1 cask=$2 app=$3 config_src=$4 config_dst=$5
  if $DRY_RUN; then
    if brew_cask_registered "$cask"; then
      if app_bundle_exists "$app"; then
        ok "$name already installed"
        deploy_prompted_file "$DOTFILES_DIR/$config_src" "$config_dst" "$name config" "$name config" \
          "deploy $config_src to $config_dst" "$(dirname "$config_dst")" "" "" n && PERIPH_OK+=("$name")
      else
        reinstall_missing_cask_app "$name" "$cask" "$app"
        would "deploy $config_src to $config_dst if $name is reinstalled"
      fi
    elif app_bundle_exists "$app"; then
      ok "$name already installed, skipping installation"
      deploy_prompted_file "$DOTFILES_DIR/$config_src" "$config_dst" "$name config" "$name config" \
        "deploy $config_src to $config_dst" "$(dirname "$config_dst")" "" "" n && PERIPH_OK+=("$name")
    elif ! brew_available; then
      warn "Homebrew not found, skipping $name"
    else
      would "Ask to set up $name"
      would "deploy $config_src to $config_dst if $name is installed"
    fi
    return
  fi
  if brew_cask_registered "$cask"; then
    if app_bundle_exists "$app"; then
      ok "$name already installed"
    else
      reinstall_missing_cask_app "$name" "$cask" "$app"
      case $? in
        0) echo -e "  ${YELLOW}⚠ Launch $name, then grant permissions in System Settings → Privacy & Security.${RESET}" ;;
        1) return 1 ;;
        2) return 0 ;;
      esac
    fi
  elif app_bundle_exists "$app"; then
    ok "$name already installed, skipping installation"
  elif ! brew_available; then
    warn "Homebrew not found, skipping $name"
    return 1
  else
    if ! install_consent "Set up $name?" n; then
      return
    fi
    if brew install --cask "$cask" &>/dev/null && app_bundle_exists "$app"; then
      installed "$name"
      echo -e "  ${YELLOW}⚠ Launch $name, then grant permissions in System Settings → Privacy & Security.${RESET}"
    else
      warn "Failed to install $name"
      return 1
    fi
  fi
  if deploy_prompted_file "$DOTFILES_DIR/$config_src" "$config_dst" "$name config" "$name config" \
    "deploy $config_src to $config_dst" "$(dirname "$config_dst")" "" "" n; then
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
mouse_settings_current() {
  [ "$(defaults read .GlobalPreferences com.apple.mouse.scaling 2>/dev/null)" = "0.5" ] &&
    [ "$(defaults read .GlobalPreferences com.apple.scrollwheel.scaling 2>/dev/null)" = "-1" ]
}

if $DRY_RUN; then
  if mouse_settings_current; then
    ok "Mouse settings already configured"
    PERIPH_OK+=("Mouse")
  else
    would "Ask to apply mouse settings (tracking speed 0.5, scroll linear/no acceleration)"
  fi
else
  if mouse_settings_current; then
    ok "Mouse settings already configured"
    PERIPH_OK+=("Mouse")
  else
    if install_consent "Apply mouse settings (tracking speed 0.5, scroll linear/no acceleration)?" n; then
      defaults write .GlobalPreferences com.apple.mouse.scaling 0.5
      defaults write .GlobalPreferences com.apple.scrollwheel.scaling -1
      ok "Mouse: tracking speed set to 0.5, scroll acceleration disabled"
      PERIPH_OK+=("Mouse")
    fi
  fi
fi
unset -f mouse_settings_current

[ ${#PERIPH_OK[@]} -gt 0 ] && SUM_PERIPHERALS="${GREEN}✔${RESET} $(join_arr ' · ' "${PERIPH_OK[@]}")"

# Summary
echo ""
echo -e "${BOLD}Summary${RESET}"
[ ${#INSTALLED[@]} -gt 0 ] && echo -e "${GREEN}✔ Installed (${#INSTALLED[@]}):${RESET}  $(join_arr ', ' "${INSTALLED[@]}")"
[ ${#UPDATED[@]} -gt 0 ]   && echo -e "${BLUE}↑ Updated (${#UPDATED[@]}):${RESET}    $(join_arr ', ' "${UPDATED[@]}")"
[ ${#WARNINGS[@]} -gt 0 ]  && echo -e "${YELLOW}⚠ Warnings (${#WARNINGS[@]}):${RESET}   $(join_arr ', ' "${WARNINGS[@]}")"

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
