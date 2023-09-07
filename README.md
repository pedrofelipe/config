# Config
**Config** is a basic checklist I follow to set up macOS development environment.

## Contents
| File | Description |
| --- | --- |
| `.bash_profile` | Customizes the Terminal.app prompt and echoes the currently checked out Git branch |
| `.gitconfig` | Global Git configuration to specify my name and email, shortcuts, colors, and more |
| `.inputrc` | Makes tab autocompletion case insensitive |
| `.hyper.js` | Custom settings for Hyper terminal |
| `settings.js` | Custom settings for Visual Studio Code |
| `settings.js` | Custom set of key bindings for Visual Studio Code |

## Checklist

### 1. Switch zsh for bash
- [ ] Set bash the default shell on macOS

```bash
chsh -s /bin/bash
```

### 2. Enable hidden files
- [ ] Make hidden files visible on Finder

```bash
defaults write com.apple.finder AppleShowAllFiles true
killall Finder
```

### 3. Load config files
- [ ] Load [`.bash_profile`](/.bash_profile)
- [ ] Load [`.gitconfig`](/.gitconfig)
- [ ] Load [`.inputrc`](/.inputrc)

### 4. Copy or create SSH keys
- [ ] Copy existing `id_rsa` and `id_rsa.pub` keys to `~/.ssh` folder
- [ ] Or [generate a new SSH key](https://help.github.com/articles/generating-ssh-keys)
- [ ] Fix keys permissions

```bash
chmod 600 ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa.pub
```

### 5. Setup Homebrew and install packages
- [ ] Install [Homebrew](http://brew.sh)
- [ ] Update bash to latest version
- [ ] Update Git to latest version
- [ ] Install bash-completion
- [ ] Install Yarn

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install bash
brew install git
brew install bash-completion
brew install yarn
```

### 6. Setup Node.js and npm
- [ ] Install [nvm](https://github.com/creationix/nvm)
- [ ] Install latest [Node.js](https://nodejs.org/en) LTS version
- [ ] Set as global version of Node.js
- [ ] Upgrade npm to latest version

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
nvm install 18.17.1
nvm alias default 18.17.1
nvm install-latest-npm
```

### 7. Setup Hyper terminal
- [ ] Install [Hyper](https://hyper.is)
- [ ] Load [`.hyper.js`](/.hyper.js) config file on user folder

```bash
brew install --cask hyper
```

### 8. Install Fira Code font
- [ ] Download and install [Fira Code](https://github.com/tonsky/FiraCode/wiki/Installing) font files

```bash
brew tap homebrew/cask-fonts
brew install --cask font-fira-code
```

### 9. Setup code editor
- [ ] Install [Visual Studio Code](https://code.visualstudio.com)
- [ ] [Enable launch from command line](https://code.visualstudio.com/docs/setup/mac#_launching-from-the-command-line)
- [ ] Install extensions
  - [ ] [City Lights Icon](https://marketplace.visualstudio.com/items?itemName=Yummygum.city-lights-icon-vsc)
  - [ ] [ESLint](https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint)
  - [ ] [EditorConfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig)
  - [ ] [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot)
  - [ ] [GitHub Theme](https://marketplace.visualstudio.com/items?itemName=GitHub.github-vscode-theme)
  - [ ] [GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens)
  - [ ] [Import Cost](https://marketplace.visualstudio.com/items?itemName=wix.vscode-import-cost)
  - [ ] [Path Intellisense](https://marketplace.visualstudio.com/items?itemName=christian-kohler.path-intellisense)
  - [ ] [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
  - [ ] [Sort lines](https://marketplace.visualstudio.com/items?itemName=Tyriar.sort-lines)
  - [ ] [colorize](https://marketplace.visualstudio.com/items?itemName=kamikillerto.vscode-colorize)
  - [ ] [npm Intellisense](https://marketplace.visualstudio.com/items?itemName=christian-kohler.npm-intellisense)
  - [ ] [Stylelint](https://marketplace.visualstudio.com/items?itemName=stylelint.vscode-stylelint)
- [ ] Load [`settings.json`](/settings.json) config file
- [ ] Load [`keybindings.json`](/keybindings.json) file

### 10. Adjust Dock preferences
- [ ] Set Dock icon size
- [ ] Lock Dock from being resized

```
defaults write com.apple.dock tilesize -integer 40
defaults write com.apple.dock size-immutable -bool true
killall Dock
```

## Use it yourself
Fork this repo, or just copy-paste things you need, and make it your own. **Please be sure to change your `.gitconfig` name and email address though!**
