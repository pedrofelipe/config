# 🛩️  Copilot

## Overview

A human-in-the-loop agent workflow for automating software development from description to pull request. The workflow is orchestrated by `@copilot`, which coordinates subagents for planning, development, review, and publishing.

```
@copilot Add keyboard shortcuts to the command palette
```

## Agents

| Agent        | Responsibility                                                                     |
| ------------ | ---------------------------------------------------------------------------------- |
| `@copilot`  | Orchestrates workflow, manages human checkpoints                                   |
| `@planner`   | Explores codebase and creates todo list from the description                       |
| `@developer` | Implements code for a single todo item                                             |
| `@reviewer`  | Reviews code for correctness, quality, and adherence to requirements              |
| `@publisher` | Sets up branches, creates git commits and pull requests                            |
| `@tester`    | Generates manual QA test plans for code changes                                    |
| `@learner`   | Reflects on completed work and proposes AGENTS.md updates for future sessions      |

## Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                             Copilot                             │
│                                                                 │
│   ┌───────────────────┐                                         │
│   │ Publisher: branch │                                         │
│   └────┬──────────────┘                                         │
│        │                                                        │
│        ▼                                                        │
│   ┌─────────┐                                                   │
│   │ Planner │◀────────────────┐                                 │
│   └────┬────┘                 │                                 │
│        │                      │                                 │
│        ▼                      │                                 │
│   ┌──────────────────┐        ▲                                 │
│   │ ⏸ User approves? ├── No ──┘                                 │
│   └────┬─────────────┘                                          │
│        │                                                        │
│        │ Yes                                                    │
│        ▼                                                        │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                      For each todo                      │   │
│   │                                                         │   │
│   │   ┌───────────┐                                         │   │
│   │   │ Developer │◀─────────────────────────────┐          │   │
│   │   └─────┬─────┘                              │          │   │
│   │         │                                    │          │   │
│   │         ▼                                    │          │   │
│   │   ┌──────────┐                               ▲          │   │
│   │   │ Reviewer ├── Reject ─────────────────────┘          │   │
│   │   └─────┬────┘                               │          │   │
│   │         │ Approve                            │          │   │
│   │         ▼                                    │          │   │
│   │   ┌──────────────────┐                       ▲          │   │
│   │   │ ⏸ User approves? ├── No ─────────────────┘          │   │
│   │   └─────┬────────────┘                       │          │   │
│   │         │ Yes                                │          │   │
│   │         ▼                                    │          │   │
│   │   ┌──────────────────────────┐               │          │   │
│   │   │ Publisher: commit + push │               │          │   │
│   │   └─────┬────────────────────┘               │          │   │
│   │         │                                    ▲          │   │
│   │         └── Next todo ───────────────────────┘          │   │
│   │                                              │          │   │
│   └────┬─────────────────────────────────────────┼──────────┘   │
│        │                                         │              │
│        ▼                                         │              │
│   ┌──────────────────┐                           ▲              │
│   │ ⏸ User approves? ├── No ─────────────────────┘              │
│   └────┬─────────────┘                                          │
│        │ Yes                                                    │
│        ▼                                                        │
│   ┌───────────────┐                                             │
│   │ Publisher: pr │                                             │
│   └────┬──────────┘                                             │
│        │                                                        │
│        ▼                                                        │
│   ┌────────┐                                                    │
│   │ Tester │                                                    │
│   └────┬───┘                                                    │
│        │                                                        │
│        ▼                                                        │
│   ┌─────────┐                                                   │
│   │ Learner │                                                   │
│   └────┬────┘                                                   │
│        │                                                        │
│        ▼                                                        │
│   ┌───────────┐                                                 │
│   │ Developer │                                                 │
│   └────┬──────┘                                                 │
│        │                                                        │
│        ▼                                                        │
│   ┌──────────────────┐                                          │
│   │ ⏸ User approves? ├── No ──┐                                 │
│   └────┬─────────────┘        ▼                                 │
│        │ Yes                  │                                 │
│        ▼                      │                                 │
│   ┌───────────────────┐       │                                 │
│   │ Publisher: commit │       │                                 │
│   └────┬──────────────┘       │                                 │
│        │                      │                                 │
│        ├──────────────────────┘                                 │
│        │                                                        │
└────────┼────────────────────────────────────────────────────────┘
         │
         ▼
     Complete
```

## Agent Details

### Copilot

Orchestrates the entire workflow from description to PR. Does not implement, review, or commit code itself—only invokes subagents and manages human checkpoints. Nothing is committed or published without explicit user approval.

**Input**

- Description

**Output**

- Pull request URL

**Tools**

- `question`
- `todowrite`
- `todoread`

---

### Planner

Gathers requirements from the description, explores the codebase to understand the existing architecture, and breaks down the work into discrete, implementable todos ordered by dependency.

**Input**

- Description

**Output**

- Numbered list of todos with titles, descriptions, and affected files

**Tools**

- `bash`
- `question`
- `todoread`

---

### Developer

Implements code changes for a single todo item.

**Input**

- Single todo item
- Context about the overall plan
- Feedback from a previous review (optional)

**Output**

- Summary of changes made (files created/modified, descriptions, notes for reviewer)

**Tools**

- `write`
- `edit`
- `bash`
- `skill`
- `question`
- `todoread`

---

### Reviewer

Reviews code like a senior engineer during code review. Evaluates correctness, readability, performance, security, and adherence to codebase patterns.

**Input**

- Code changes made by Developer
- Todo item that was implemented
- Context about the overall plan

**Output**

- Approved, or list of issues with specific feedback

**Tools**

- `bash`
- `skill`
- `question`
- `todoread`

---

### Publisher

Sets up branches, creates git commits, and creates pull requests using the `branch`, `commit`, and `pr` skills.

**Input (branches)**

- Original description

**Output (branches)**

```json
{
  "branch": "<branch-name>",
  "created": true/false,
  "switched": true/false
}
```

**Input (commits)**

- Changes to commit
- Todo item that was completed
- Context for commit message

**Output (commits)**

```json
{
  "sha": "<sha>",
  "message": "<message>",
  "files": ["<files>"]
}
```

**Input (pull requests)**

- All commits that were made
- Original description
- Context about the overall work

**Output (pull requests)**

```json
{
  "url": "<url>"
}
```

**Tools**

- `bash`
  - `git *`
  - `gh *`
- `skill`
  - `branch`
  - `commit`
  - `pr`
- `question`
- `todoread`

---

### Tester

Generates a structured manual QA test plan based on the code changes. Runs after the PR is created so the developer can verify locally while CI runs. Read-only — does not modify any files.

**Input**

- List of files changed
- Summary of what was implemented

**Output**

- Structured markdown test plan with scenario headings and numbered test steps

**Tools**

- `list`
- `read`
- `glob`
- `grep`
- `skill`
  - `manual-qa`
- `question`
- `todoread`

---

### Learner

Analysis-only agent that reflects on completed work and proposes updates to `AGENTS.md` files across the codebase. The learn phase is non-blocking and runs after the PR is created.

**Input**

- The original description
- The full todo list that was executed
- A summary of all files and directories that were changed
- Reviewer feedback — what was flagged, especially rejections that led to rework
- Rework details — which todos required multiple iterations, what went wrong initially vs. the final approach
- Patterns or conventions discovered during implementation that weren't already documented

**Output**

- Structured proposal of `AGENTS.md` updates with file paths, sections, content, and rationale

**Permissions**

- Read-only: `read`, `glob`, `grep`, `bash` (for git history)
- No `write` or `edit` — `@developer` applies approved changes

**Tools**

- `read`
- `glob`
- `grep`
- `bash`
  - `git log`
  - `git diff`
  - `git show`
- `question`
- `todoread`

---

## Reference

Run the full workflow with a description.

```
@copilot Add keyboard shortcuts to the command palette
```

Run the full workflow with a description.

```
@copilot Add a dark mode toggle to the settings page
```

Create a plan from a description.

```
@planner Add keyboard shortcuts to the command palette
```

Implement a specific task.

```
@developer write a test for the auth service
```

Review the current changes.

```
@reviewer does this look good
```

Create a commit.

```
@publisher commit
```

Create a pull request.

```
@publisher pr
```

Create a pull request with a reviewer.

```
@publisher pr <github-username>
```

Generate a manual QA test plan for the current changes.

```
@tester
```

Reflect on completed work and propose AGENTS.md updates.

```
@learner
```
