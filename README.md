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
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.4/install.sh | bash
nvm install 6.3.1
nvm alias default 6.3.1
```

### 6. Setup rbenv, Ruby and Rails
See <https://gorails.com/setup/osx/10.11-el-capitan>

- [ ] Install [rbenv](https://github.com/rbenv/rbenv) via Homebrew
- [ ] Download a version of Ruby via rbenv
- [ ] Make it the global version of Ruby
- [ ] Check Ruby version

```
brew install rbenv ruby-build
rbenv install 2.3.1
rbenv global 2.3.1
ruby -v
```

### 7. Additional dependencies

- [ ] Override Git from macOS
- [ ] Install MySQL
- [ ] Install PostgreSQL
- [ ] Install bash-completion
- [ ] Install [Gulp](http://gulpjs.com)
- [ ] Install [Sass](http://sass-lang.com)

```
brew install git
brew install mysql
brew install postgresql
brew install bash-completion
npm install -g gulp
gem install sass
```

### 8. Setup Atom

- Set theme: [One Dark](https://github.com/atom/one-dark-ui)
- Install favorite packages
  - [file-icons](https://atom.io/packages/file-icons)
  - [highlight-selected](https://atom.io/packages/highlight-selected)
  - [merge-conflicts](https://atom.io/packages/merge-conflicts)
  - [pigments](https://atom.io/packages/pigments)
  - [atom-wrap-in-tag](https://atom.io/packages/atom-wrap-in-tag)
  - [editorconfig](https://atom.io/packages/editorconfig)

### 9. Install apps

- [Google Chrome](https://www.google.com/chrome/browser/desktop)
- [Slack](https://slack.com/downloads)
- [Spotify](https://www.spotify.com/download/mac)
- [1Password](https://1password.com)
- [Dropbox](https://www.dropbox.com)
- [Little Snitch](https://www.obdev.at/products/littlesnitch)
- [iStat Menus](https://bjango.com/mac/istatmenus)
- [Tweetbot](http://tapbots.com/tweetbot/mac)
- [Alfred](https://www.alfredapp.com)
- [Boom](http://www.globaldelight.com/boom)
- [Moom](https://manytricks.com/moom)
- [CleanMyMac](http://cleanmymac.com)
- [DaisyDisk](https://daisydiskapp.com)
- [Arq](https://www.arqbackup.com)
- [OverSight](https://objective-see.com/products/oversight.html)
- [WhatsApp](https://www.whatsapp.com/download)
- [Telegram](https://macos.telegram.org)
- VPN App

## Use it yourself

Fork this repo, or just copy-paste things you need, and make it your own. **Please be sure to change your `.gitconfig` name and email address though!**

## Works on my machine

Yup, it does. Hopefully it does on yours as well, but please don't hate me if it doesn't.

<3
