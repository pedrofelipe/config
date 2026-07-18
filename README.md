# Config

My personal setup for a new Mac. Run the script or follow the checklist below.

```bash
git clone https://github.com/pedrofelipe/config.git && cd config && ./setup.sh
```

Pass `--dry-run` to preview what the script would do without making any changes.

```bash
./setup.sh --dry-run
```

<video src="https://github.com/user-attachments/assets/86e67cd3-ade5-46e7-a4b6-b244670a7590" autoplay loop muted playsinline></video>

## Contents

| File                              | Description                                                                   |
| --------------------------------- | ----------------------------------------------------------------------------- |
| `.bash_profile`                   | Customizes the terminal prompt and shows the currently checked-out Git branch |
| `.gitconfig`                      | Global Git configuration with my name, email, aliases, colors, and more       |
| `.inputrc`                        | Makes tab completion case-insensitive                                         |
| `ssh_config`                      | SSH client config. Persists keys in the macOS keychain agent across reboots   |
| `settings.json`                   | Custom settings for Visual Studio Code                                        |
| `keybindings.json`                | Custom set of key bindings for Visual Studio Code                             |
| `setup.sh`                        | Automated setup script for a fresh macOS install                              |
| `karabiner.json`                  | Karabiner-Elements config. Remaps Ctrl↔Cmd and Alt+Tab on external keyboards  |
| `istatmenus.menubar.plist`        | iStat Menus display preferences. Which modules show in the menubar and menu   |
| `.claude/settings.json`           | Global Claude Code settings. Permissions, plugins, environment                |
| `.config/ghostty/config`          | Ghostty terminal settings. Theme, font, shell integration                     |
| `.config/ghostty/themes/`         | Custom Ghostty themes                                                         |
| `.config/opencode/opencode.jsonc` | OpenCode settings. Model, MCP servers, permissions, autoupdate                |
| `.config/opencode/agents/`        | OpenCode agents                                                               |
| `.config/opencode/skills/`        | OpenCode skills                                                               |
| `scripts/`                        | Permission rule source of truth and generator for the agent configs          |

## Checklist

### 0. Install Xcode Command Line Tools

Required by Homebrew and Git. If not already installed, macOS will prompt you automatically when you run the setup script. To install manually:

```bash
xcode-select --install
```

### 1. Load config files

- [ ] Load [`.bash_profile`](/.bash_profile)
- [ ] Load [`.gitconfig`](/.gitconfig)
- [ ] Load [`.inputrc`](/.inputrc)

### 2. Set up Homebrew and install packages

- [ ] Install [Homebrew](http://brew.sh)
- [ ] Install the latest Bash, Git, and other packages

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install bash
brew install git
brew install bash-completion@2
brew install pnpm
brew install gh
brew install dockutil

brew install --cask font-fira-code
```

### 3. Copy or create SSH keys

- [ ] Load [`ssh_config`](/ssh_config) to `~/.ssh/config` so keys persist in the keychain across reboots

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cp ssh_config ~/.ssh/config && chmod 600 ~/.ssh/config
```

- [ ] Copy existing SSH keys to `~/.ssh`, or let the setup script generate new ones

If no key exists, `setup.sh` generates `~/.ssh/id_ed25519`, adds it to the macOS keychain agent, and uploads it to GitHub via `gh ssh-key add` (prompting for `gh auth login` if needed). Confirm at [github.com/settings/keys](https://github.com/settings/keys).

### 4. Switch from Zsh to Bash

- [ ] Set Homebrew Bash as the default shell

```bash
echo "/opt/homebrew/bin/bash" | sudo tee -a /etc/shells
chsh -s "/opt/homebrew/bin/bash"
```

### 5. Set up Node.js

- [ ] Install [nvm](https://github.com/nvm-sh/nvm)
- [ ] Install the latest [Node.js](https://nodejs.org/en) LTS version
- [ ] Set as the default Node.js version

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
nvm install --lts
nvm alias default node
```

### 6. Set up VS Code

- [ ] Install [Visual Studio Code](https://code.visualstudio.com) via Homebrew

```bash
brew install --cask visual-studio-code
```

- [ ] Install the `code` CLI: open VS Code, open the Command Palette (`Cmd+Shift+P`), and run `Shell Command: Install 'code' command in PATH`
- [ ] Install extensions
  - [ ] [Auto Close Tag](https://marketplace.visualstudio.com/items?itemName=formulahendry.auto-close-tag)
  - [ ] [City Lights Icon](https://marketplace.visualstudio.com/items?itemName=yummygum.city-lights-icon-vsc)
  - [ ] [Claude Code](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code)
  - [ ] [GitHub Theme](https://marketplace.visualstudio.com/items?itemName=github.github-vscode-theme)
  - [ ] [GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens)
  - [ ] [Import Cost](https://marketplace.visualstudio.com/items?itemName=wix.vscode-import-cost)
  - [ ] [npm Intellisense](https://marketplace.visualstudio.com/items?itemName=christian-kohler.npm-intellisense)
  - [ ] [Oxc](https://marketplace.visualstudio.com/items?itemName=oxc.oxc-vscode)
  - [ ] [Path Intellisense](https://marketplace.visualstudio.com/items?itemName=christian-kohler.path-intellisense)
  - [ ] [Sort Lines](https://marketplace.visualstudio.com/items?itemName=tyriar.sort-lines)
  - [ ] [Tailwind CSS IntelliSense](https://marketplace.visualstudio.com/items?itemName=bradlc.vscode-tailwindcss)
- [ ] Apply [`settings.json`](/settings.json)
- [ ] Apply [`keybindings.json`](/keybindings.json)

### 7. Install apps

```bash
brew install --cask google-chrome
brew install --cask spotify
brew install --cask 1password
brew install --cask little-snitch
brew install --cask istat-menus
```

After installing iStat Menus, `setup.sh` merges [`istatmenus.menubar.plist`](/istatmenus.menubar.plist) into the app's preferences using Python. It updates only the display settings while preserving any existing license and device data.

### 8. Set up AI tools

#### Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

- [ ] Copy [`.claude/settings.json`](/.claude/settings.json) to `~/.claude`

#### OpenCode

```bash
brew tap anomalyco/tap
brew trust anomalyco/tap
brew install anomalyco/tap/opencode
```

`brew trust anomalyco/tap` lets Homebrew install and upgrade OpenCode from the trusted tap when tap trust is required.

- [ ] Copy [`.config/opencode/opencode.jsonc`](/.config/opencode/opencode.jsonc) to `~/.config/opencode`
- [ ] Copy [`.config/opencode/agents`](/.config/opencode/agents) to `~/.config/opencode/agents` as the Copilot agent
- [ ] Copy [`.config/opencode/skills`](/.config/opencode/skills) to `~/.config/opencode/skills`
- [ ] Install the other skills to `~/.agents/skills` using the commands below

```bash
npx -y skills add https://github.com/vercel-labs/agent-skills \
  --skill vercel-react-best-practices \
  --skill vercel-composition-patterns \
  --global \
  --agent opencode \
  --yes

npx -y skills add https://github.com/emilkowalski/skill \
  --skill emil-design-eng \
  --global \
  --agent opencode \
  --yes

npx -y skills add https://github.com/ibelick/ui-skills \
  --skill baseline-ui \
  --skill fixing-accessibility \
  --skill fixing-motion-performance \
  --global \
  --agent opencode \
  --yes

npx -y skills add https://github.com/addyosmani/web-quality-skills \
  --skill web-quality-audit \
  --skill performance \
  --skill core-web-vitals \
  --skill accessibility \
  --skill seo \
  --skill best-practices \
  --global \
  --agent opencode \
  --yes

npx -y skills add https://github.com/addyosmani/agent-skills \
  --skill code-simplification \
  --global \
  --agent opencode \
  --yes

npx -y skills add https://github.com/millionco/react-doctor \
  --skill react-doctor \
  --global \
  --agent opencode \
  --yes

npx -y skills add https://github.com/shadcn/improve \
  --skill improve \
  --global \
  --agent opencode \
  --yes
```

**Agents**

| Agent                      | Description                                                                |
| -------------------------- | -------------------------------------------------------------------------- |
| `@copilot`                 | Orchestrates the development workflow from description to pull request     |
| &nbsp;&nbsp;↳ `@planner`   | Creates an implementation plan from a description                          |
| &nbsp;&nbsp;↳ `@developer` | Implements code for a single todo item                                     |
| &nbsp;&nbsp;↳ `@reviewer`  | Reviews code changes against todo requirements                             |
| &nbsp;&nbsp;↳ `@publisher` | Handles branch setup, Git commits, and GitHub/GitLab pull request creation |
| &nbsp;&nbsp;↳ `@tester`    | Generates manual QA test plans for code changes                            |
| &nbsp;&nbsp;↳ `@learner`   | Reflects on completed work and proposes updates to AGENTS.md files         |

**Skills**

| Skill                                       | Description                                                                                    |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| **Copilot agent**                           |                                                                                                |
| &nbsp;&nbsp;↳ `branch`                      | Set up a Git branch from a work description                                                    |
| &nbsp;&nbsp;↳ `commit`                      | Create a Git commit following conventional commit format                                       |
| &nbsp;&nbsp;↳ `pr`                          | Create a GitHub or GitLab pull request for the current branch                                  |
| &nbsp;&nbsp;↳ `aaa-testing`                 | Write clear Arrange-Act-Assert unit tests                                                      |
| &nbsp;&nbsp;↳ `unit-test`                   | Generate comprehensive tests for React components, utility functions, and hooks                |
| &nbsp;&nbsp;↳ `manual-qa`                   | Generate manual QA test steps for a code change                                                |
| **Standalone repo-local**                   |                                                                                                |
| `simplify`                                  | Review changed code for reuse, quality, efficiency, and clarity, then fix issues               |
| **addyosmani**                              |                                                                                                |
| `web-quality-audit`                         | Audit performance, accessibility, SEO, and best practices                                      |
| `performance`                               | Optimize web performance for faster loading and better user experience                         |
| `core-web-vitals`                           | Optimize Core Web Vitals for better page experience                                            |
| `accessibility`                             | Audit and improve web accessibility against WCAG guidelines                                    |
| `seo`                                       | Optimize search engine visibility, metadata, and structured data                               |
| `best-practices`                            | Apply web security, compatibility, and code quality best practices                             |
| `code-simplification`                       | Simplify code while preserving behavior and reducing complexity                                |
| **vercel-labs**                             |                                                                                                |
| `vercel-composition-patterns`               | Composition patterns for building flexible, maintainable React components                      |
| `vercel-react-best-practices`               | React performance optimization guidelines for components, data fetching, and bundle efficiency |
| **ibelick**                                 |                                                                                                |
| `baseline-ui`                               | Validate UI for animation durations, typography scale, accessibility, and layout anti-patterns |
| `fixing-accessibility`                      | Find and fix common accessibility issues in interfaces                                         |
| `fixing-motion-performance`                 | Improve animation smoothness and avoid expensive motion patterns                               |
| **emilkowalski**                            |                                                                                                |
| `emil-design-eng`                           | Design engineering principles and polished UI guidelines                                       |
| **millionco**                               |                                                                                                |
| `react-doctor`                              | Diagnose React performance, correctness, and architecture issues                               |
| **shadcn**                                  |                                                                                                |
| `improve`                                   | Audit codebases and propose prioritized implementation plans                                   |

### 9. Set up Ghostty

```bash
brew install --cask ghostty
```

- [ ] Copy [`.config/ghostty/config`](/.config/ghostty/config) to `~/.config/ghostty`
- [ ] Copy [`.config/ghostty/themes`](/.config/ghostty/themes) to `~/.config/ghostty/themes`

```bash
mkdir -p ~/.config/ghostty/themes
cp .config/ghostty/config ~/.config/ghostty/config
cp .config/ghostty/themes/* ~/.config/ghostty/themes
```

### 10. macOS Preferences

```bash
  # Dock
  # Move to left side
  defaults write com.apple.dock orientation -string left

  # Set icon size
  defaults write com.apple.dock tilesize -integer 40

  # Lock icon size
  defaults write com.apple.dock size-immutable -bool true

  # Minimize to app icon
  defaults write com.apple.dock minimize-to-application -bool true

  # Hide recent apps
  defaults write com.apple.dock show-recents -bool false

  # Set Dock app layout (requires dockutil)
  dockutil --remove all --no-restart
  dockutil --add "/Applications/Google Chrome.app" --no-restart
  dockutil --add "/Applications/Visual Studio Code.app" --no-restart
  dockutil --add "/Applications/Ghostty.app" --no-restart
  dockutil --add "/Applications/1Password.app" --no-restart
  dockutil --add "/Applications/Spotify.app" --no-restart

  # Disable top-left corner
  defaults write com.apple.dock wvous-tl-corner -int 1
  # Disable top-right corner
  defaults write com.apple.dock wvous-tr-corner -int 1
  # Disable bottom-left corner
  defaults write com.apple.dock wvous-bl-corner -int 1
  # Disable bottom-right corner
  defaults write com.apple.dock wvous-br-corner -int 1

  # Finder
  # Show hidden files
  defaults write com.apple.finder AppleShowAllFiles -bool true

  # Show path bar
  defaults write com.apple.finder ShowPathbar -bool true

  # Hide recent tags
  defaults write com.apple.finder ShowRecentTags -bool false

  # Open windows to home
  defaults write com.apple.finder NewWindowTarget -string "PfHm"

  # Search current folder
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

  # Prevent .DS_Store on network
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

  # Disable extension warning
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

  # System Settings
  # Enable tap to click
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

  # Disable autocorrect
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

  # Disable autocapitalize
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

  # Disable smart dashes
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

  # Disable smart periods
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

  # Disable smart quotes
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

  # Show all file extensions
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  # Enable dark mode
  defaults write NSGlobalDomain AppleInterfaceStyle -string Dark

  # Double-click to minimize
  defaults write NSGlobalDomain AppleActionOnDoubleClick -string Minimize

  # Increase key repeat speed
  defaults write NSGlobalDomain KeyRepeat -int 5
  # Reduce initial key repeat
  defaults write NSGlobalDomain InitialKeyRepeat -int 25

  # Mute volume feedback sound
  defaults write NSGlobalDomain com.apple.sound.beep.feedback -int 0

  # Disable translucent menu bar
  defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool false

  # Disable tiling on edge drag
  defaults write -g EnableTilingByEdgeDrag -bool false

  # Disable tiling on menu bar
  defaults write -g EnableTilingByMenuBar -bool false

  # Screenshots
  # Disable thumbnail preview
  defaults write com.apple.screencapture show-thumbnail -bool false

  # Pin Weather to menu bar
  defaults -currentHost write com.apple.controlcenter Weather -int 18

  # Restart Finder, Dock, and menu bar
  killall Finder
  killall Dock
  killall SystemUIServer
  killall ControlCenter
```

### 11. External peripherals

> Only needed when using a Windows keyboard or mouse on a Mac.

#### Karabiner-Elements (keyboard remapping)

Remaps modifier keys on external keyboards only (built-in keyboard unaffected):

- Left Ctrl → Command; Left Windows key → Control (global, including the terminal)
- Alt+Tab → Cmd+Tab (app switcher)

```bash
brew install --cask karabiner-elements
mkdir -p ~/.config/karabiner
cp karabiner.json ~/.config/karabiner/karabiner.json
```

#### Mouse settings

Sets pointer tracking speed and disables scroll acceleration on external mice (trackpad unaffected):

```bash
defaults write .GlobalPreferences com.apple.mouse.scaling 0.5
defaults write .GlobalPreferences com.apple.scrollwheel.scaling -1
```

## Use it yourself

Fork this repo, or just copy-paste things you need, and make it your own. **Please be sure to change your `.gitconfig` name and email address though!**
