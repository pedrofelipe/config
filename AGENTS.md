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
- As an explicit exception, route overwrite prompts through
  `overwrite_consent`; they default to No.
- Keep the README checklist in sync with `setup.sh`: Homebrew packages, VS Code
  extensions, and macOS `defaults` commands must match.
- Never edit deployed copies (`~/.claude/settings.json`,
  `~/.config/opencode/**`, `~/.ssh/config`, …); change the repo copy instead.

## Permission policy

- Bash defaults to allow (`*`): exploratory and routine commands run without
  prompts in both Claude Code and OpenCode.
- Destructive operations stay ask-gated: file deletion (`rm`,
  `find -delete/-exec`, `rsync --del`), in-place bulk edits (`sed -i`,
  `xargs`), git operations that discard work or rewrite history
  (`checkout`, `reset`, `clean`, `rebase`, `--amend`, `restore`,
  `stash drop/clear`, branch/tag deletion), every `git push` (including
  `git -C` forms and alias creation), interpreter one-liners (`bash -c`,
  `node -e`, `python3 -c`, `osascript`), dependency changes (every
  `pnpm`/`npm`/`yarn`/`pip`/`gem` install/add/remove/update,
  `dlx`/`npx`), remote state (PR/MR create/edit/comment/merge/close, CI
  runs, `gh api` mutations, repo/release delete), Homebrew
  install/upgrade/tap/uninstall, and system-level commands (`sudo`,
  `dd`, `diskutil`, `shutdown`, `crontab`, `security delete`).
- Do not tighten this policy without the operator asking.
