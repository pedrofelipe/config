# Config
**Config** is a basic checklist I follow to set up a new Mac development environment.

## Contents
| File | Description |
| --- | --- |
| `.bash_profile` | Customizes the Terminal.app prompt and echoes the currently checked out Git branch. |
| `.gitconfig` | Global Git configuration to specify my name and email, shortcuts, colors, and more. |
| `.inputrc` | Makes tab autocompletion case insensitive. |
| `.hyper.js` | Custom settings for Hyper.app terminal |
| `settings.js` | Custom settings for Visual Studio Code |

## Checklist

### 1. Switch zsh for bash
- Set bash the default shell on macOS

```
chsh -s /bin/bash
```

### 2. Hidden files
- Make hidden files visible on Finder

```
defaults write com.apple.finder AppleShowAllFiles true
killall Finder
```

### 3. Prepare Terminal
- Load [`.bash_profile`](/.bash_profile)
- Load [`.gitconfig`](/.gitconfig)
- Load [`.inputrc`](/.inputrc)

### 4. Copy or create SSH keys
- [] Copy existing `id_rsa` and `id_rsa.pub` keys to `~/.ssh` folder
- [] Or [generate a new SSH key](https://help.github.com/articles/generating-ssh-keys)
- [] Fix keys permissions

```
chmod 600 ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa.pub
```

### 5. Setup Homebrew and install packages
- [ ] Install [Homebrew](http://brew.sh)
- [ ] Update bash to latest version
- [ ] Update Git to latest version
- [ ] Install bash-completion
- [ ] Install Yarn

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install bash
brew install git
brew install bash-completion
brew install yarn
```

### 6. Setup Node.js and npm
- [ ] Install [nvm](https://github.com/creationix/nvm)
- [ ] Install latest [Node.js](https://nodejs.org/en) LTS via nvm
- [ ] Set as global version of Node.js
- [ ] Upgrade npm to latest version

```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
nvm install 14.15.3
nvm alias default 14.15.3
nvm install-latest-npm
```

### 8. Setup Hyper terminal
- Install [Hyper](https://hyper.is)
- Load [`.hyper.js`](/.hyper.js) config file on user folder

```
brew install --cask hyper
```

## 9. Install Fira Code font
Install [Fira Code](https://github.com/tonsky/FiraCode/wiki/Installing) font

### 10. Setup code editor
- Install [Visual Studio Code](https://code.visualstudio.com)
- [Enable launch from command line](https://code.visualstudio.com/docs/setup/mac#_launching-from-the-command-line)
- Install extensions
  - [Atom Keymap](https://marketplace.visualstudio.com/items?itemName=ms-vscode.atom-keybindings)
  - [Atom One Dark Theme](https://marketplace.visualstudio.com/items?itemName=akamud.vscode-theme-onedark)
  - [Auto Close Tag](https://marketplace.visualstudio.com/items?itemName=formulahendry.auto-close-tag)
  - [Bracket Pair Colorizer](https://marketplace.visualstudio.com/items?itemName=CoenraadS.bracket-pair-colorizer)
  - [City Lights Icon](https://marketplace.visualstudio.com/items?itemName=Yummygum.city-lights-icon-vsc)
  - [City Lights theme](https://marketplace.visualstudio.com/items?itemName=Yummygum.city-lights-theme)
  - [EditorConfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig)
  - [ESLint](https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint)
  - [Import Cost](https://marketplace.visualstudio.com/items?itemName=wix.vscode-import-cost)
  - [npm Intellisense](https://marketplace.visualstudio.com/items?itemName=christian-kohler.npm-intellisense)
  - [Path Intellisense](https://marketplace.visualstudio.com/items?itemName=christian-kohler.path-intellisense)
  - [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
  - [Sort lines](https://marketplace.visualstudio.com/items?itemName=Tyriar.sort-lines)
  - [stylelint](https://marketplace.visualstudio.com/items?itemName=stylelint.vscode-stylelint)
  - [vscode-pigments](https://marketplace.visualstudio.com/items?itemName=jaspernorth.vscode-pigments)
- Load [`settings.json`](/settings.json) config file on user folder

### 10. Install apps
- [1Blocker](https://apps.apple.com/us/app/1blocker-for-safari/id1107421413)
- [1Password](https://1password.com/downloads)
- [AirBuddy](https://v2.airbuddy.app)
- [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704)
- [Boom 3D](http://globaldelight.com/boom)
- [CleanMyMac](http://cleanmymac.com)
- [coconutBattery](http://coconut-flavour.com/coconutbattery)
- [DaisyDisk](https://daisydiskapp.com)
- [Discord](https://discord.com)
- [Dropbox](https://dropbox.com)
- [Firefox](https://mozilla.org/firefox)
- [Google Chrome](https://google.com/chrome/browser/desktop)
- [iStat Menus](https://bjango.com/mac/istatmenus)
- [Little Snitch](https://obdev.at/products/littlesnitch)
- [Malwarebytes Anti-Malware](https://malwarebytes.com)
- [Micro Snitch](https://www.obdev.at/products/microsnitch)
- [Moom](https://manytricks.com/moom)
- [Sketch](https://sketch.com)
- [Slack](https://slack.com)
- [Spotify](https://spotify.com)
- [Steam](http://store.steampowered.com/about)
- [Stremio](https://stremio.com)
- [WhatsApp](https://whatsapp.com/download)
- [Zeplin](https://zpl.io/download-mac)
- VPN App

## Use it yourself
Fork this repo, or just copy-paste things you need, and make it your own. **Please be sure to change your `.gitconfig` name and email address though!**
