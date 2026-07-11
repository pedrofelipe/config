# Locale: set explicitly to prevent bash warnings from Terminal.app's partial LC_* injection
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# History: append on exit, keep 1k entries (default: 500), skip duplicates and space-prefixed lines
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=1000
HISTCONTROL=ignoreboth:erasedups

# Shell behavior
shopt -s cdspell        # autocorrect minor cd typos
shopt -s globstar 2>/dev/null || true # ** matches nested dirs (bash 4+; ignored on 3.2)
shopt -s checkwinsize   # update LINES/COLUMNS after each command

# Get the Git branch
function parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Custom prompt colors
if tput setaf 1 &> /dev/null; then
	tput sgr0 >/dev/null
	if [[ $(tput colors) -ge 256 ]] 2>/dev/null; then
		BLACK=$(tput setaf 0)
		WHITE=$(tput setaf 7)
		MAGENTA=$(tput setaf 9)
		ORANGE=$(tput setaf 172)
		GREEN=$(tput setaf 190)
		PURPLE=$(tput setaf 141)
	else
		BLACK=$(tput setaf 0)
		WHITE=$(tput setaf 7)
		MAGENTA=$(tput setaf 5)
		ORANGE=$(tput setaf 4)
		GREEN=$(tput setaf 2)
		PURPLE=$(tput setaf 1)
	fi
	BOLD=$(tput bold)
	RESET=$(tput sgr0)
else
	BLACK="\033[0;30m"
	WHITE="\033[0;37m"
	MAGENTA="\033[1;31m"
	ORANGE="\033[1;33m"
	GREEN="\033[1;32m"
	PURPLE="\033[1;35m"
	BOLD=""
	RESET="\033[m"
fi

export BLACK
export MAGENTA
export ORANGE
export GREEN
export PURPLE
export WHITE
export BOLD
export RESET

# Change this symbol to something sweet.
# (http://en.wikipedia.org/wiki/Unicode_symbols)
symbol="⚡ "

export PS1="\[${BOLD}${MAGENTA}\]\u \[$WHITE\]in \[$GREEN\]\w\[$WHITE\]\$([[ -n \$(git branch 2> /dev/null) ]] && echo \" on\")\[$PURPLE\]\$(parse_git_branch)\[$WHITE\]\n$symbol\[$RESET\]"
export PS2="\[$ORANGE\]→ \[$RESET\]"

# Homebrew (https://brew.sh)
eval "$(/opt/homebrew/bin/brew shellenv)"

# bash-completion (line from `brew info bash-completion@2` caveats)
[[ -r "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh" ]] && . "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Claude Code
export PATH="$HOME/.local/bin:$PATH"
