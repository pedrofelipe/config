---
name: simplify
description: Review changed code for reuse, quality, efficiency, and clarity, then fix any issues found
---

# Simplify: Code Review and Cleanup

Review all changed files for reuse, quality, efficiency, and clarity. Fix any issues found.

## Phase 1: Identify Changes

Run `git diff` (or `git diff HEAD` if there are staged changes) to see what changed. If there are no git changes, review the most recently modified files that the user mentioned or that you edited earlier in this conversation.

## Phase 2: Review Across Four Dimensions

Review the changes across all four dimensions below. For each dimension, examine the full diff carefully and note any findings.

### Dimension 1: Code Reuse

For each change:

1. **Search for existing utilities and helpers** that could replace newly written code. Look for similar patterns elsewhere in the codebase — common locations are utility directories, shared modules, and files adjacent to the changed ones.
2. **Flag any new function that duplicates existing functionality.** Suggest the existing function to use instead.
3. **Flag any inline logic that could use an existing utility** — hand-rolled string manipulation, manual path handling, custom environment checks, ad-hoc type guards, and similar patterns are common candidates.

### Dimension 2: Code Quality

Review for hacky patterns:

1. **Redundant state**: state that duplicates existing state, cached values that could be derived, observers/effects that could be direct calls
2. **Parameter sprawl**: adding new parameters to a function instead of generalizing or restructuring existing ones
3. **Copy-paste with slight variation**: near-duplicate code blocks that should be unified with a shared abstraction
4. **Leaky abstractions**: exposing internal details that should be encapsulated, or breaking existing abstraction boundaries
5. **Stringly-typed code**: using raw strings where constants, enums (string unions), or branded types already exist in the codebase
6. **Unnecessary JSX nesting**: wrapper Boxes/elements that add no layout value — check if inner component props (flexShrink, alignItems, etc.) already provide the needed behavior
7. **Unnecessary comments**: comments explaining WHAT the code does (well-named identifiers already do that), narrating the change, or referencing the task/caller — delete; keep only non-obvious WHY (hidden constraints, subtle invariants, workarounds)

### Dimension 3: Efficiency

Review for efficiency:

1. **Unnecessary work**: redundant computations, repeated file reads, duplicate network/API calls, N+1 patterns
2. **Missed concurrency**: independent operations run sequentially when they could run in parallel
3. **Hot-path bloat**: new blocking work added to startup or per-request/per-render hot paths
4. **Recurring no-op updates**: state/store updates inside polling loops, intervals, or event handlers that fire unconditionally — add a change-detection guard so downstream consumers aren't notified when nothing changed. Also: if a wrapper function takes an updater/reducer callback, verify it honors same-reference returns (or whatever the "no change" signal is) — otherwise callers' early-return no-ops are silently defeated
5. **Unnecessary existence checks**: pre-checking file/resource existence before operating (TOCTOU anti-pattern) — operate directly and handle the error
6. **Memory**: unbounded data structures, missing cleanup, event listener leaks
7. **Overly broad operations**: reading entire files when only a portion is needed, loading all items when filtering for one

### Dimension 4: Clarity and Standards

Review for clarity and project consistency:

1. **Unnecessary complexity**: deeply nested conditionals, overly clever one-liners, dense ternary chains — prefer switch statements or if/else for multiple conditions. Choose clarity over brevity.
2. **Naming**: unclear variable or function names that don't convey intent. Names should make the code self-documenting.
3. **Structure**: related logic scattered across the function, concerns mixed together that should be separated, or over-separated code that should be consolidated.
4. **Redundant abstractions**: unnecessary wrapper functions, premature generalizations, or abstractions that add indirection without value.
5. **Project conventions**: follow established patterns in the codebase — import ordering, function style, type annotations, component patterns, error handling idioms. Match what's already there.
6. **Over-simplification guard**: do NOT make code harder to debug or extend. Don't combine too many concerns into one function. Don't remove helpful abstractions that improve organization. Don't prioritize fewer lines over readability.

## Phase 3: Fix Issues

After reviewing all four dimensions, fix each issue directly. If a finding is a false positive or not worth addressing, note it and move on — do not argue with the finding, just skip it.

When done, briefly summarize what was fixed (or confirm the code was already clean).

## Additional Focus

If the user specified a particular area to focus on, prioritize reviewing those aspects above others. Apply the same four dimensions but weight your attention toward the user's stated focus.
