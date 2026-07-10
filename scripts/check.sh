#!/bin/bash
#
# Runs every verification gate from the AGENTS.md "Verify changes" table.
# Exits nonzero if any check fails; all checks run regardless.

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

FAILURES=0

check() {
  local label=$1
  shift

  if "$@" >/dev/null 2>&1; then
    printf '✔ %s\n' "$label"
  else
    printf '✘ %s: %s\n' "$label" "$*"
    FAILURES=$((FAILURES+1))
  fi
}

check "ShellCheck (setup.sh)" shellcheck setup.sh
check "ShellCheck (check.sh)" shellcheck scripts/check.sh
check "Bash syntax" bash -n setup.sh
check "Dry run" ./setup.sh --dry-run
check "JSON" jq empty settings.json keybindings.json karabiner.json .claude/settings.json
check "JSONC" npx -y json5 .config/opencode/opencode.jsonc
check "plist" plutil -lint istatmenus.menubar.plist
check "Permissions" node scripts/generate-permissions.mjs --check

if [ "$FAILURES" -gt 0 ]; then
  printf '\n%d check(s) failed\n' "$FAILURES"
  exit 1
fi

printf '\nAll checks passed\n'
