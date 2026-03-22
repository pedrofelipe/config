# Locale — set first to prevent bash startup warnings from Terminal.app
# injecting LC_CTYPE=UTF-8 with empty remaining LC_* variables
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# History
shopt -s histappend
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups

# Shell behavior
shopt -s cdspell        # autocorrect minor cd typos
shopt -s globstar       # ** matches nested dirs in globs
shopt -s checkwinsize   # update LINES/COLUMNS after each command

# Get the Git branch
function parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Quicker navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

### Prompt Colors
# Modified version of @gf3’s Sexy Bash Prompt
# (https://github.com/gf3/dotfiles)
if [[ $COLORTERM = gnome-* && $TERM = xterm ]] && infocmp gnome-256color >/dev/null 2>&1; then
	export TERM=gnome-256color
elif infocmp xterm-256color >/dev/null 2>&1; then
	export TERM=xterm-256color
fi

if tput setaf 1 &> /dev/null; then
	tput sgr0
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

# Tell Terminal.app the current directory so new tabs open in the same folder
update_terminal_cwd() {
    local url_path='' i ch hexch LC_CTYPE=C
    for ((i = 0; i < ${#PWD}; ++i)); do
        ch="${PWD:i:1}"
        if [[ "$ch" =~ [/._~A-Za-z0-9-] ]]; then
            url_path+="$ch"
        else
            printf -v hexch "%02X" "'$ch"
            url_path+="%${hexch}"
        fi
    done
    printf '\e]7;%s\a' "file://$HOSTNAME$url_path"
}

# Only show the current directory's name in the tab; also track directory for new tabs
export PROMPT_COMMAND='echo -ne "\033]0;${PWD##*/}\007"; update_terminal_cwd'

# bash-completion
[[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Hides the following macOS message from Terminal:
# The default interactive shell is now zsh.
# To update your account to use zsh, please run `chsh -s /bin/zsh`.
# For more details, please visit https://support.apple.com/kb/HT208050.
export BASH_SILENCE_DEPRECATION_WARNING=1

