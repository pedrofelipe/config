# AGENTS.md

Personal macOS dotfiles. `setup.sh` deploys repo files into `$HOME` with
per-file prompts and diffs. This repo is the source of truth.

## Verify changes

| Check | Command |
| --- | --- |
| All checks | `scripts/check.sh` |
| ShellCheck | `shellcheck setup.sh` |
| Bash syntax | `bash -n setup.sh` |
| Dry run | `./setup.sh --dry-run` |
| JSON/JSONC | `jq empty settings.json keybindings.json karabiner.json .claude/settings.json && npx -y json5 .config/opencode/opencode.jsonc > /dev/null` |
| plist | `plutil -lint istatmenus.menubar.plist` |
| Permissions | `node scripts/generate-permissions.mjs --check` |

## Constraints

- `setup.sh` must run on stock macOS Bash 3.2; keep `#!/bin/bash` and avoid
  `declare -A`, `mapfile`/`readarray`, `${var,,}`, and `${var^^}`.
- `./setup.sh --dry-run` must stay non-interactive and side-effect-free.
- `scripts/permissions.json` is the source for Bash permission rules; run
  `node scripts/generate-permissions.mjs` after edits.
- Do not hand-edit generated permission blocks in `.claude/settings.json` or
  `.config/opencode/opencode.jsonc`.

## Conventions

- Route yes/no prompts in `setup.sh` through `install_consent`; preserve
  existing prompt defaults when converting or adding prompts.
- Keep the README checklist in sync with `setup.sh`: Homebrew packages, VS Code
  extensions, and macOS `defaults` commands must match.
- Never edit deployed copies (`~/.claude/settings.json`,
  `~/.config/opencode/**`, `~/.ssh/config`, …); change the repo copy instead.

## Permission policy

- Broad read-only and exploratory Bash rules are intentionally allowed,
  including `find`, `grep`, `git`, `node`, `make`, `awk`, `curl`/`wget`, and
  `cp`/`mv`/`tee`.
- Keep destructive patterns ask-gated, including `rm`, force-push,
  `find -delete`, `sed -i`, `xargs`, and risky package-manager operations.
- Do not tighten this policy without the operator asking.
