# Config

**Config** is a basic checklist I follow to set up a new Mac development environment.

## Contents

| File | Description |
| --- | --- |
| `.bash-profile` | Customizes the Terminal.app prompt and echoes the currently checked out Git branch. |
| `.gitconfig` | Global Git configuration to specify my name and email, shortcuts, colors, and more. |
| `.inputrc` | Makes tab autocompletion case insensitive. |

## Checklist

### 1. Prepare macOS

- Download and install latest version of Xcode from the Mac App Store.
- Download and install Xcode Command Line Tools from <https://developer.apple.com/downloads>.

### 2. Prepare Terminal.app

- Load [`.bash_profile`](/.bash_profile)
- Load [`.gitconfig`](/.gitconfig) contents into the global `~/.gitconfig`
- Load [`.inputrc`](/.inputrc)

### 3. Secure GitHub access

- [Generate new SSH key](https://help.github.com/articles/generating-ssh-keys)

### 4. Setup Homebrew

- Install [Homebrew](http://brew.sh):
```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

### 5. Setup nvm, Node.js and npm
- [ ] Install [nvm](https://github.com/creationix/nvm)
- [ ] Install [Node.js](https://nodejs.org/en) via nvm
- [ ] Make it global version of Node.js
- [ ] Upgrade npm

```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.0/install.sh | bash
nvm install 12.11.1
nvm alias default 12.11.1
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

- Install Hyper: [Hyper](https://hyper.is)
- Set theme and plugins:
```javascript
plugins: [
  'hypercwd',
  'hyperterm-alternatescroll',
  'hyper-sierra-vibrancy',
  'hyperterm-paste',
  'hyperlinks',
  'hyper-search',
  'hyper-confirm',
  'hyper-tab-icons',
],
```

### 9. Setup code editor

- Install Atom: [Atom](https://atom.io)
- Set UI Theme: [City Lights](http://citylights.xyz)
- Set Syntax Theme: One Dark
- Install favorite packages
  - [atom-wrap-in-tag](https://atom.io/packages/atom-wrap-in-tag)
  - [city-lights-icons](https://atom.io/packages/city-lights-icons)
  - [editorconfig](https://atom.io/packages/editorconfig)
  - [file-icons](https://atom.io/packages/file-icons)
  - [highlight-selected](https://atom.io/packages/highlight-selected)
  - [language-javascript-jsx](https://atom.io/packages/language-javascript-jsx)
  - [linter-ui-default](https://atom.io/packages/linter-ui-default)
  - [linter](https://atom.io/packages/linter)
  - [linter-eslint](https://atom.io/packages/linter-eslint)
  - [linter-stylelint](https://atom.io/packages/linter-stylelint)
  - [merge-conflicts](https://atom.io/packages/merge-conflicts)
  - [pigments](https://atom.io/packages/pigments)
  - [prettier-atom](https://atom.io/packages/prettier-atom)
  - [sort-selected-elements](https://atom.io/packages/sort-selected-elements)
  - [tree-view-copy-relative-path](https://atom.io/packages/tree-view-copy-relative-path)

### 10. Install apps

- [1Password](https://1password.com/downloads)
- [Alfred](https://alfredapp.com)
- [Boom 3D](http://globaldelight.com/boom)
- [Caffeine](http://lightheadsw.com/caffeine)
- [CleanMyMac](http://cleanmymac.com)
- [coconutBattery](http://coconut-flavour.com/coconutbattery)
- [DaisyDisk](https://daisydiskapp.com)
- [Dropbox](https://dropbox.com)
- [Firefox](https://mozilla.org/firefox)
- [Google Chrome](https://google.com/chrome/browser/desktop)
- [iStat Menus](https://bjango.com/mac/istatmenus)
- [Little Snitch](https://obdev.at/products/littlesnitch)
- [Malwarebytes Anti-Malware](https://malwarebytes.com)
- [Moom](https://manytricks.com/moom)
- [OverSight](https://objective-see.com/products/oversight.html)
- [Sequel Pro](https://sequelpro.com)
- [Sketch](https://sketch.com)
- [Slack](https://slack.com)
- [Spotify](https://spotify.com)
- [Steam](http://store.steampowered.com/about)
- [Stremio](https://stremio.com)
- [Visual Studio Code](https://code.visualstudio.com)
- [WhatsApp](https://whatsapp.com/download)
- VPN App

## 11. Install Fira Code font
Install [Fira Code](https://github.com/tonsky/FiraCode) font and set to use it on code editor.

## Use it yourself

Fork this repo, or just copy-paste things you need, and make it your own. **Please be sure to change your `.gitconfig` name and email address though!**
