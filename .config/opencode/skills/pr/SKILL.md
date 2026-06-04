---
name: pr
description: Create a GitHub pull request for the current branch, following project conventions for title format, description template, and reviewer selection.
---

Create a GitHub pull request for the current branch.

## Current Branch

Check `git branch --show-current` for the current branch name.

## Base Branch

Check `git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null || echo "origin/main"` for the base branch.

## Unpushed Commits

Check `git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null || echo "Branch not yet pushed to remote"` for unpushed commits.

## Commits on This Branch

Check `git log origin/main..HEAD --oneline` for commits on this branch.

## Detailed Changes

Check `git log origin/main..HEAD --format="%h %s%n%n%b" --no-merges` for detailed commit information.

## Diff Summary

Check `git diff origin/main...HEAD --stat` for a summary of changes.

## Instructions

First, check if the current branch is `main` or any other protected branch. If so, warn the user that they should not create a pull request from a protected branch and stop.

Next, check if there are commits on this branch. If there are no commits ahead of main, inform the user and stop.

Also check if a pull request already exists for this branch. If it does, provide the URL and ask if they want to update it instead.

Using the commit history and changes above, create a GitHub pull request following these steps:

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

Use this template structure for the pull request description:

```markdown
# Description
<!-- Summarize what this PR does based on the commits -->

# Context
<!-- Explain the rationale. Reference an issue only if one is already available. -->

# How to test the code
<!-- Describe how to test the changes -->

# Screenshots & Videos
<!-- Include screenshots or video demonstrating the new feature, if applicable. -->
```

Fill in the Description and Context sections based on the commit messages. For "How to test the code", provide reasonable testing instructions based on what changed.

### 5. Find Reviewers (if none specified)

If no reviewers were provided, use git blame to find who recently modified the changed files:

```bash
git log --follow -n 5 --pretty=format:"%an" -- <changed-file>
```

Suggest 1-2 reviewers based on recent activity and ask the user to confirm before adding them to the PR. Do not auto-assign reviewers without user confirmation.

### 6. Create the Pull Request

Use the `gh` CLI to create the pull request with:
- **Source branch**: The current branch name
- **Target branch**: `main`
- **Title**: The generated title from step 3
- **Description**: The generated description from step 4
- **Draft**: If requested, add `--draft` flag
- **Reviewers**: If reviewers are specified or confirmed, add `--reviewer "username"` for each

Example command:
```bash
gh pr create \
  --head "branch-name" \
  --base "main" \
  --title "Add keyboard shortcuts to command palette" \
  --body "..." \
  --draft \
  --reviewer "username1" \
  --reviewer "username2"
```

After creating the pull request, provide the URL to the user and open it in the browser:
```bash
gh pr view --web
```

## Options

The user may specify:
- An issue key or URL, if provided - reference it in the title/body
- `draft` - create the PR as a draft
- Reviewers with `@username` - assign them as reviewers
- `no-open` - skip opening the PR in the browser (browser opens by default)
