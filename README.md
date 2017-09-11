# Config

**Config** is a basic checklist I follow to set up a new Mac's development environment.

## Contents

| File | Description |
| --- | --- |
| `.bash-profile` | Customizes the Terminal.app prompt and echoes the currently checked out Git branch. |
| `.gitconfig` | Global Git configuration to specify my name and email, shortcuts, colors, and more. |
| `.inputrc` | Makes tab autocompletion case insensitive. |

## Checklist

### 1. Prep macOS

- Download and install latest version of Xcode from the Mac App Store.
- Download and install Xcode Command Line Tools from <https://developer.apple.com/downloads>.

### 2. Prep Terminal.app

- Load [`.bash_profile`](/.bash_profile)
- Load [`.gitconfig`](/.gitconfig) contents into the global `~/.gitconfig`
- Load [`.inputrc`](/.inputrc)
- Load up the Ocean theme from <https://github.com/mdo/ocean-terminal>

### 3. Secure Git(Hub) access

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

```
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.4/install.sh | bash
nvm install 8.4.0
nvm alias default 8.4.0
```

### 6. Setup rbenv, Ruby and Rails
See <https://gorails.com/setup/osx/10.12-sierra>

- [ ] Install [rbenv](https://github.com/rbenv/rbenv) via Homebrew
- [ ] Download a version of Ruby via rbenv
- [ ] Make it the global version of Ruby
- [ ] Check Ruby version

```
brew install rbenv ruby-build
rbenv install 2.4.1
rbenv global 2.4.1
ruby -v
```

### 7. Additional dependencies

- [ ] Override Git from macOS
- [ ] Install bash-completion
- [ ] Install [Sass](http://sass-lang.com)

```
brew install git
brew install bash-completion
gem install sass
```

### 8. Setup Hyper

- Install Hyper: [Hyper](https://hyper.is/)
- Set theme and plugins:
```javascript
plugins: [
  'hyperline',
  'hypercwd',
  'hyperterm-alternatescroll',
  'hyper-sierra-vibrancy',
  'hyperterm-paste',
  'hyperlinks',
  'hyper-search',
  'hyper-confirm',
  'hyper-john',
],
```

### 9. Setup Atom

- Install Atom: [Atom](https://atom.io)
- Set theme: [One Dark](https://github.com/atom/one-dark-ui)
- Install favorite packages
  - [file-icons](https://atom.io/packages/file-icons)
  - [highlight-selected](https://atom.io/packages/highlight-selected)
  - [merge-conflicts](https://atom.io/packages/merge-conflicts)
  - [pigments](https://atom.io/packages/pigments)
  - [atom-wrap-in-tag](https://atom.io/packages/atom-wrap-in-tag)
  - [editorconfig](https://atom.io/packages/editorconfig)
  - [tablr](https://atom.io/packages/tablr)

### 10. Install apps

- [1Password](https://1password.com/downloads)
- [Alfred](https://www.alfredapp.com)
- [Arq](https://www.arqbackup.com)
- [Blackmagic Disk Speed Test](https://itunes.apple.com/us/app/blackmagic-disk-speed-test/id425264550)
- [Boom 3D](http://www.globaldelight.com/boom)
- [Caffeine](http://lightheadsw.com/caffeine)
- [CleanMyMac](http://cleanmymac.com)
- [coconutBattery](http://www.coconut-flavour.com/coconutbattery)
- [DaisyDisk](https://daisydiskapp.com)
- [Dropbox](https://www.dropbox.com)
- [Google Chrome](https://www.google.com/chrome/browser/desktop)
- [Firefox](https://www.mozilla.org/pt-BR/firefox)
- [iBoostUp](https://itunes.apple.com/us/app/iboostup/id484829041)
- [iStat Menus](https://bjango.com/mac/istatmenus)
- [Little Snitch](https://www.obdev.at/products/littlesnitch)
- [Malwarebytes Anti-Malware](https://www.malwarebytes.com)
- [Moom](https://manytricks.com/moom)
- [OverSight](https://objective-see.com/products/oversight.html)
- [Popcorn Time](https://popcorntime.sh)
- [Postgres.app](https://postgresapp.com)
- [Postman](https://www.getpostman.com)
- [Sequel Pro](https://www.sequelpro.com)
- [Slack](https://slack.com)
- [Spotify](https://www.spotify.com)
- [Telegram](https://macos.telegram.org)
- [Transmit](https://panic.com/transmit)
- [VLC](http://www.videolan.org/vlc)
- [The Unarchiver](https://theunarchiver.com)
- [Steam](http://store.steampowered.com/about)
- VPN App
- [WhatsApp](https://www.whatsapp.com/download)
- [qBittorrent](https://www.qbittorrent.org)

## 11. Fira Code
Install [Fira Code](https://github.com/tonsky/FiraCode) font and set to use it on Atom.

## Use it yourself

Fork this repo, or just copy-paste things you need, and make it your own. **Please be sure to change your `.gitconfig` name and email address though!**

## Works on my machine

Yup, it does. Hopefully it does on yours as well, but please don't hate me if it doesn't.

<3
