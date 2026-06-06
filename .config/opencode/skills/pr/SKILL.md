---
name: pr
description: Create a PR for the current branch on GitHub or GitLab, following project conventions for title format, description template, and reviewer selection.
---

Create a PR for the current branch.

## Host

Detect the host from `git remote get-url origin`.

- GitHub origin: use `gh pr ...`
- GitLab origin: use `glab mr ...`, but call it a PR in user-facing text
- Ambiguous or unsupported origin: ask the user whether to use `gh pr` or `glab mr`

Example detection:

```bash
origin_url=$(git remote get-url origin 2>/dev/null || true)
case "$origin_url" in
  *github.com*|git@github.com:*) echo "github" ;;
  *gitlab.com*|git@gitlab.com:*|*gitlab*) echo "gitlab" ;;
  *) echo "unknown" ;;
esac
```

## Current Branch

Check `git branch --show-current` for the current branch name.

## Base Branch

Check `git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null || echo "origin/main"` for the base branch.
Strip the `origin/` prefix and use that branch name consistently below.

## Unpushed Commits

Check `git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null || echo "Branch not yet pushed to remote"` for unpushed commits.

## Commits on This Branch

Check `git log origin/<base-branch>..HEAD --oneline` for commits on this branch.

## Detailed Changes

Check `git log origin/<base-branch>..HEAD --format="%h %s%n%n%b" --no-merges` for detailed commit information.

## Diff Summary

Check `git diff origin/<base-branch>...HEAD --stat` for a summary of changes.

## Instructions

First, check if the current branch is the detected base branch or any other protected branch. If so, warn the user that they should not create a PR from a protected branch and stop.

Next, check if there are commits on this branch. If there are no commits ahead of the base branch, inform the user and stop.

Also check if a PR already exists for this branch. If it does, provide the URL and ask if they want to update it instead.

GitHub existing PR check:
```bash
gh pr view "$(git branch --show-current)" --json url --jq .url
```

GitLab existing PR check:
```bash
glab mr list --source-branch "$(git branch --show-current)"
```

Using the commit history and changes above, create a PR following these steps:

### 1. Verify Commits Are Pushed

Verify all commits are pushed. If there are unpushed commits (e.g., from manual local commits), push them before proceeding.

Check for unpushed commits using:
```bash
git rev-list --count origin/$(git branch --show-current)..HEAD 2>/dev/null || echo "not-pushed"
```

- If the output is `0`, all commits are already pushed — proceed to the next step
- If the branch doesn't exist on the remote, push it using `git push -u origin HEAD`
- If the branch exists but has unpushed commits, push them using `git push`
- **Do NOT proceed to the next step until all commits are pushed**

Use the same push behavior for GitHub and GitLab.

### 2. Check for an Issue Key

Look at the branch name and commit messages to find an issue key (e.g., `PROJ-1234`) if one is already present.

If no issue key can be found, proceed without one. Do not ask the user for a ticket ID and do not use placeholders like `NO-TICKET`.

### 3. Generate the Title

Create a title in this exact format:
```
ISSUE-KEY Brief description of the change
```

Examples:
- `PROJ-2691 Fix overlapping error text`
- `PROJ-2692 Fix verify button colors`
- `PROJ-2686 Allow multiple disclosures open at once`
- `Add keyboard shortcuts to command palette`

The description should be:
- Concise (under 50 characters ideally)
- Written in imperative mood ("Fix", "Add", "Update", not "Fixed", "Added", "Updated")
- Descriptive of what the PR accomplishes

### 4. Generate the Description

Use this template structure for the PR description:

```markdown
<!-- Summarize what this PR does based on the commits -->
<!-- Describe how to test the changes -->

# Screenshots & Videos
<!-- Include screenshots or video demonstrating the new feature, if applicable. -->
```

PR descriptions should be concise, direct, and not verbose. Fill in the summary and testing guidance based on the commit messages and changed code.

### 5. Find Reviewers (if none specified)

If no reviewers were provided, use git blame to find who recently modified the changed files:

```bash
git log --follow -n 5 --pretty=format:"%an" -- <changed-file>
```

Suggest 1-2 reviewers based on recent activity and ask the user to confirm before adding them to the PR. Do not auto-assign reviewers without user confirmation.

### 6. Create the PR

Use the detected CLI to create the PR with:
- **Source branch**: The current branch name
- **Target branch**: The detected base branch
- **Title**: The generated title from step 3
- **Description**: The generated description from step 4
- **Draft**: If requested, add `--draft` flag
- **Reviewers**: If reviewers are specified or confirmed, add one reviewer flag per user

GitHub creation:
```bash
gh pr create \
  --head "branch-name" \
  --base "base-branch" \
  --title "Add keyboard shortcuts to command palette" \
  --body "..." \
  --draft \
  --reviewer "username1" \
  --reviewer "username2"
```

GitHub view/open:
```bash
gh pr view --web
```

GitLab creation:
```bash
glab mr create \
  --source-branch "branch-name" \
  --target-branch "base-branch" \
  --title "Add keyboard shortcuts to command palette" \
  --description "..." \
  --draft \
  --reviewer "username1" \
  --reviewer "username2"
```

GitLab view/open:
```bash
glab mr view --web
```

After creating the PR, provide the URL to the user and open it in the browser unless `no-open` was requested.

## Options

The user may specify:
- An issue key or URL, if provided - reference it in the title/body
- `draft` - create the PR as a draft
- Reviewers with `@username` - assign them as reviewers
- `no-open` - skip opening the PR in the browser (browser opens by default)
