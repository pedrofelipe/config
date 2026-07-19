---
name: aaa-testing
description: Write clear Arrange-Act-Assert (AAA) unit tests
---

## What I do

- Turn vague test ideas into clean AAA tests
- Push tests toward behavioral assertions (outputs, effects)
- Reduce noise by extracting helpers/page models
- Keep tests readable without extensive comments

## When to use me

Use this when writing or reviewing unit tests in Vitest (or similar). Ask clarifying questions if the expected behavior is unclear.

## Core rules (firm)

- Tests must read like a spec: setup, do the thing, check the outcome.
- Express setup, action, and assertions through proximity and blank lines: setup first, one action after a blank line, then assertions after another blank line.
- Prefer observable behavior over implementation details.
- Avoid "comment-driven" tests. If it needs lots of comments, the test is too complex—extract helpers.
- Do not add routine `// Arrange`, `// Act`, or `// Assert` labels. Comments are only for non-obvious rationale, I/O, validation, or edge cases.

## AAA template

```ts
it('does X when Y', async () => {
  // Arrange
  // minimal data + mocks

  // Act
  // one action

  // Assert
  // verify outcome
});
```

## Arrange

- Create only what the test needs.
- Use factories/builders for data (`makeUser()`, `createMockData()`), not inline blobs.
- Set up mocks/spies here.

## Act

- Perform one action (one function call, one user action, one event).
- If the Act section is multiple steps, your test scope is too broad—split it.

## Assert

- Assert on outputs and effects:
  - returned values
  - thrown errors
  - emitted events
  - calls to boundary dependencies (network/db/fs adapters)
  - rendered presence/absence of meaningful UI elements (if applicable)
- Don't assert on internal state, private methods, or incidental details.

## Prefer behavior over implementation

Bad (implementation detail; brittle):
```ts
it('applies hover class', () => {
  render(<Table />);
  const row = screen.getByTestId('row-0');
  expect(row.className).toContain('hover:bg-');
});
```

Good (behavior; stable):
```ts
it('shows column controls when hovering the header', async () => {
  const table = new TablePageModel();
  render(<Table enableColumnControls />);

  await table.hoverHeader('name');

  expect(table.areHeaderControlsVisible('name')).toBe(true);
  expect(table.dragHandle('name')).toBeInTheDocument();
  expect(table.removeButton('name')).toBeInTheDocument();
});
```

## Extract complexity (helpers/page models)

If a test needs lots of DOM traversal, setup boilerplate, or explanatory comments:

- Move setup into factories/builders.
- Move interaction + queries into a helper class (often called a "page model").

Example shape:
```ts
class TablePageModel {
  hoverHeader(columnId: string) { /* ... */ }
  areHeaderControlsVisible(columnId: string) { /* ... */ }
  dragHandle(columnId: string) { /* ... */ }
}
```

## Anti-patterns

- Asserting CSS classes, DOM structure, or internal state.
- "Works correctly" tests with vague names.
- Multi-scenario tests (multiple Acts).
- Tests that verify mock setup instead of behavior.
- Excessive comments that explain what the code should already communicate.
