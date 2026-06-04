---
name: commit
description: Create a git commit following conventional commit format with type and imperative description.
---

Create a git commit for the staged changes following the conventional commit format.

## Unstaged Changes

Check `git status --short` for unstaged changes.

If there are unstaged changes, stage all files using `git add -A` before proceeding.

## Staged Changes

Check `git diff --staged` for the actual changes to commit.

## Formatting

If the project has a format command that auto-fixes files (e.g. `format:write`, `format:fix`), run it on staged files before committing:

```bash
git diff --staged --name-only --diff-filter=ACMR | xargs <format-write-command>
```

Then re-stage any files that were modified:

```bash
git add -u
```

This ensures all committed code passes the format check in CI.

## Commit Format

The commit message MUST follow this exact format:

```
<type>: <description>

[optional body]

[optional BREAKING CHANGE: description]
```

### Type (required)

Choose ONE of these types based on the nature of the change:
- `feat` - A new feature
- `fix` - A bug fix
- `docs` - Documentation only changes
- `style` - Code style changes (formatting, semicolons, etc)
- `refactor` - Code change that neither fixes a bug nor adds a feature
- `perf` - Performance improvement
- `test` - Adding or correcting tests
- `build` - Changes to build system or dependencies
- `ci` - Changes to CI configuration
- `chore` - Other changes that don't modify src or test files
- `revert` - Reverts a previous commit

### Description (required)

Write a short, imperative tense description of the change (e.g., "Add dark mode toggle", not "Added dark mode toggle" or "Adds dark mode toggle").

### Body (optional)

A longer description explaining the what and why of the change.

### Breaking Changes (optional)

If there are breaking changes, add a footer: `BREAKING CHANGE: description`

## Rules

1. Line 1 (the header) must be <= 72 characters
2. Body lines should wrap at 100 characters
3. Use imperative mood in the description ("Add feature" not "Added feature")
4. Do not end the description with a period

## Examples

```
feat: Convert phone number country code to Combobox
```

```
fix: Resolve focus ring not showing on keyboard nav
```

Commit with body text:

```
feat: Add analytics tracking to settings page

This adds click tracking for the new settings panel components
to help understand user engagement.
```

Commit with BREAKING CHANGE footer:

```
chore: Update dependencies

BREAKING CHANGE: Minimum Node version is now 18
```

## Instructions

1. If there are no staged or unstaged changes, inform the user there is nothing to commit and stop
2. If there are unstaged changes, stage all files using `git add -A`
3. Run the project's auto-fix format command on staged files and re-stage
4. Analyze the staged changes
5. Determine the appropriate type
6. Write a clear, concise description in imperative mood
7. Create the commit
8. Push the commit to the remote using `git push`
