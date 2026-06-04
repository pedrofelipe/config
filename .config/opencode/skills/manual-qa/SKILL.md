---
name: manual-qa
description: Generate tailored manual QA test steps for a code change
---

Generate manual QA test steps by deeply understanding what changed and thinking about how a human would verify it works. The output is a set of focused test scenarios, each with its own heading and numbered steps — not a checklist template.

## Step-by-Step Process

### 1. Understand the Change

Read every file that was modified. For each file, understand:

- What feature was added, what behavior changed, what bug was fixed, what configuration was updated
- How the change affects the user — what would a user see, do, or experience differently after this change?
- What could go wrong — what are the failure modes, edge cases, and regression risks?

Do not skim. Read the actual diffs. Understand the before and after. If a component was modified, understand what it renders and how the change affects its output. If a hook was changed, understand what consumes it and how downstream behavior shifts. If a config file was updated, understand what system it configures and what the observable effect is.

### 2. Write Test Steps from Scratch

Based on your understanding of the change, write specific manual test steps that verify:

- **The happy path works as intended** — The primary thing the change does actually works when you try it.
- **Edge cases are handled** — Empty states, error states, boundary conditions, missing data, long strings, special characters.
- **Nothing that worked before is now broken** — Regression. If a component was refactored, the old behavior still works. If a route was moved, the old URL still resolves or redirects.
- **The change works in the contexts it's expected to** — Different browsers, screen sizes, user roles, feature flag states, account types — but only the ones relevant to this specific change.

Every changeset has test steps. Examples:

- Documentation change: "Open the docs page at X and verify the new section renders correctly, links work, and code blocks are formatted"
- Agent/config change: "Run the workflow with input Y and verify the new behavior Z"
- CI change: "Push a commit and verify the pipeline job X runs and produces output Y"
- Translation change: "Switch the app language to German and verify the new strings render without overflow or truncation"

Think like a QA engineer who just read the PR description and the diff. What would you actually test?

### 3. Output Format

Return a `## Manual QA Test Plan` section containing test scenarios ordered by importance (most critical first). Each scenario gets a `###` heading that describes what is being verified, followed by numbered steps. Each step describes:

- **What to do** — the action to take
- **Where to do it** — the URL, page, command, or context
- **What you should see** — the expected result

```markdown
## Manual QA Test Plan

### Verify new Domains tab appears when gate is enabled
1. Navigate to the service detail page
2. Enable the feature gate
3. Verify a "Domains" tab appears in the tab bar between "Observability" and "Settings"
4. Click the "Domains" tab and verify the domain list loads without console errors

### Verify domains section is removed from Settings when gate is enabled
1. With the gate still enabled, click the "Settings" tab
2. Scroll to where the domains section previously appeared
3. Verify it is no longer present (no duplication)

### Verify fallback behavior when gate is disabled
1. Disable the feature gate and reload
2. Verify the "Domains" tab is hidden from the tab bar
3. Navigate to the "Settings" tab and verify domain management appears there instead
```

Each scenario heading describes a specific thing being verified that traces back to the change — NOT a checklist category from the reference. Keep the number of scenarios tight. A small change might only need one or two scenarios.

## Rules

- **Do not organize output by checklist categories.** Scenario headings describe specific things being verified (derived from the change), not categories copied from the reference checklist.
- **Do not include generic checklist items that aren't specific to this change.** Every test step must trace back to something in the diff.
- **Do not skip changes because they're "just docs" or "just config."** Every change is testable. Find the test.
- **Do not run commands or modify files.** This skill produces text output only.
- **Be specific.** "Navigate to the Workers page and verify the Domains tab appears" — not "Test the new feature." Reference real routes, real component names, real UI elements from the code you read.
- **Be concise.** Five precise test steps beat twenty vague ones. If a change touches one component in one route, you don't need fifteen steps.
