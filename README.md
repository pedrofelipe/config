# Config

**Config** is a basic checklist I follow to set up a new Mac development environment.

## Contents

| File | Description |
| --- | --- |
| `.bash-profile` | Customizes the Terminal.app prompt and echoes the currently checked out Git branch. |
| `.gitconfig` | Global Git configuration to specify my name and email, shortcuts, colors, and more. |
| `.inputrc` | Makes tab autocompletion case insensitive. |
| `.hyper.js` | Customizes Hyper.app terminal |

## Checklist

### 1. Prepare macOS

- Download and install Xcode Command Line Tools from <https://developer.apple.com/downloads>.

### 2. Prepare Terminal.app

- Load [`.bash_profile`](/.bash_profile)
- Load [`.gitconfig`](/.gitconfig)
- Load [`.inputrc`](/.inputrc)

### 3. Secure GitHub access

- [Generate new SSH key](https://help.github.com/articles/generating-ssh-keys)

### 4. Setup Homebrew

- Install [Homebrew](http://brew.sh):
```
/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 5. Setup nvm, Node.js and npm
- [ ] Install [nvm](https://github.com/creationix/nvm)
- [ ] Install latest [Node.js](https://nodejs.org/en) LTS via nvm
- [ ] Make it global version of Node.js
- [ ] Upgrade npm

```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
nvm install 14.15.3
nvm alias default 14.15.3
nvm install-latest-npm
```

### 6. Additional dependencies

- [ ] Override Git from macOS
- [ ] Install bash-completion

```
brew install git
brew install bash-completion
```

### 8. Setup Hyper

- Install [Hyper](https://hyper.is)
- Load [`.hyper.js`](/.hyper.js) config file

## 9. Install Fira Code font
Install [Fira Code](https://github.com/tonsky/FiraCode) font.

### 10. Setup code editor

- Install [Visual Studio Code](https://code.visualstudio.com)
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
- Load [`settings.json`](/settings.json) config file

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
- VPN App

## Use it yourself

Fork this repo, or just copy-paste things you need, and make it your own. **Please be sure to change your `.gitconfig` name and email address though!**
