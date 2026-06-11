# Locale — set explicitly to prevent bash warnings from Terminal.app's partial LC_* injection
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# History — append on exit, keep 1k entries (default: 500), skip duplicates and space-prefixed lines
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=1000
HISTCONTROL=ignoreboth:erasedups

# Shell behavior
shopt -s cdspell # autocorrect minor cd typos
shopt -s globstar 2>/dev/null || true # ** matches nested dirs in Bash 4+
shopt -s checkwinsize # update LINES/COLUMNS after each command

# Get the Git branch
function parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

### Prompt Colors
# Modified version of @gf3’s Sexy Bash Prompt
# (https://github.com/gf3/dotfiles)

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
symbol="⚡ "

# Older profile versions exported prompt variables; clear inherited export flags.
prompt_command_was_exported=false
case $(export -p 2>/dev/null) in
    *" PROMPT_COMMAND="*) prompt_command_was_exported=true ;;
esac
export -n PS1 PS2 PROMPT_COMMAND 2>/dev/null || true
if $prompt_command_was_exported; then
    PROMPT_COMMAND=
fi
PS1="\[${BOLD}${MAGENTA}\]\u \[$WHITE\]in \[$GREEN\]\w\[$WHITE\]\$(type parse_git_branch >/dev/null 2>&1 && [[ -n \$(git branch 2> /dev/null) ]] && echo \" on\")\[$PURPLE\]\$(type parse_git_branch >/dev/null 2>&1 && parse_git_branch)\[$WHITE\]\n$symbol\[$RESET\]"
PS2="\[$ORANGE\]→ \[$RESET\]"

# Only show the current directory's name in Terminal.app tabs; Ghostty owns title integration.
prompt_terminal_context() {
    if [[ -z ${GHOSTTY_RESOURCES_DIR:-} && -z ${GHOSTTY_BIN_DIR:-} && ${TERM_PROGRAM:-} != ghostty ]]; then
        printf '\033]0;%s\007' "${PWD##*/}"
    fi
}

if [[ -n ${PROMPT_COMMAND:-} ]]; then
    PROMPT_COMMAND="prompt_terminal_context; $PROMPT_COMMAND"
else
    PROMPT_COMMAND='prompt_terminal_context'
fi

# bash-completion
[[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
