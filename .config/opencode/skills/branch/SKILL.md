---
name: branch
description: Instructions for setting up a git branch from a work description
---

## Purpose

Set up the correct git branch for a work description. Ensures you are on a branch named `<username>/<slug>`, creating it if necessary.

## Input

You receive a short work description.

## Instructions

1. **Derive the username** from the git config:
   ```bash
   git config user.email
   ```
   Extract the username by taking everything before the `@` sign (e.g., `pedro@example.com` → `pedro`).

2. **Construct the branch name**: `<username>/<slug>` where `<slug>` is a short kebab-case summary of the work description. Example: `pedro/fix-login-redirect`.

3. **Check the current branch**:
   ```bash
   git branch --show-current
   ```
   If already on the correct branch, skip to step 8.

4. **Check for uncommitted changes**:
   ```bash
   git status --porcelain
   ```
   If there is output, **STOP and report back** that there are uncommitted changes. Include the output of `git status --porcelain` in your response. Do NOT proceed with branch switching — let Copilot ask the user how to handle it.

5. **Detect the default branch**:
   ```bash
   git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null || echo "origin/main"
   ```
   Strip the `origin/` prefix to get the branch name (e.g., `origin/main` → `main`). Use this as the base for new branches.

6. **Fetch from remote and check if the branch exists**:
   ```bash
   git fetch origin
   git branch --list "<username>/<slug>"
   git ls-remote --heads origin "refs/heads/<username>/<slug>"
   ```

7. **Switch or create the branch**:
   - If the branch exists (locally or on the remote):
     ```bash
     git checkout <username>/<slug>
     ```
   - If the branch does not exist anywhere:
     ```bash
     git checkout -b <username>/<slug> origin/<default-branch>
     git push -u origin <username>/<slug>
     ```

8. **Report back** the branch name that is now active.

## Output

Return the result as:
```json
{
  "branch": "<branch-name>",
  "created": true/false,
  "switched": true/false
}
```

If there are uncommitted changes and you cannot proceed:
```json
{
  "error": "uncommitted_changes",
  "details": "<git status output>"
}
```
