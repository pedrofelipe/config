---
name: unit-test
description: Generate comprehensive unit tests for source files with 100% coverage target. Use when writing tests for React components, utility functions, and hooks. Utilize Jest and React Testing Library for best results.
---

# Unit Test Generation Skill
Generate comprehensive unit tests for any provided React component

## When to Use
This skill activates when:

- User asks for unit tests for a file or component
- User mentions "test", "jest"
- After writing new code that needs testing

## Supported File Types
- React components (.tsx, .jsx)
- Utility functions (.ts, .js)
- Custom hooks (use*.ts, use*.tsx)

## Test Generation Process
Analyze the source file:

- Identify exported functions, components, hooks
- Map conditional branches and logic paths
- Note dependencies and imports

Generate test cases for:

- Happy path scenarios
- Edge cases (empty, null, boundary)
- Error handling paths
- All branches and conditions

Write test code following patterns:

- Use React Testing Library for components
- Mock external dependencies
- Use descriptive test names
- Group setup, action, and assertions by proximity and blank lines instead of routine `// Arrange`, `// Act`, or `// Assert` labels; reserve comments for non-obvious rationale, I/O, validation, or edge cases
- Group with describe blocks
- Use translation IDs over translated text to make the tests resilient to copy changes
- Prioritize using getByRole and getByText
- Avoid using getByTestId

## Test File Templates

### Test file using mocks and render from @testing-library/react
```tsx
import { render, screen } from '@testing-library/react';
import { MetricCardError } from '../MetricCardError';

const mockError = { message: 'Test error' };

describe('MetricCardError', () => {
  it('renders the label', () => {
    render(<MetricCardError label="WAF Blocks" error={mockError} />);
    expect(screen.getByText('WAF Blocks')).toBeInTheDocument();
  });

  it('renders the warning icon', () => {
    const { container } = render(
      <MetricCardError label="WAF Blocks" error={mockError} />
    );
    const warningIcon = container.querySelector('[aria-hidden="true"]');
    expect(warningIcon).toBeInTheDocument();
  });

  it('renders the API Failure text', () => {
    render(<MetricCardError label="WAF Blocks" error={mockError} />);
    expect(screen.getByText('API Failure')).toBeInTheDocument();
  });

  it('has correct accessibility attributes', () => {
    render(<MetricCardError label="WAF Blocks" error={mockError} />);
    const statusElement = screen.getByRole('status');
    expect(statusElement).toHaveAttribute('aria-label', 'API Failure');
  });
});
```

### Test file with mocked hooks
```tsx
import { render, screen } from '@testing-library/react';
import { AnalyticsWidget } from '../AnalyticsWidget';
import * as analyticsHook from '../hooks/useAnalytics';
import * as permissionHook from '../hooks/usePermissions';
import * as orgHook from '../hooks/useFetchOrganizationData';

jest.mock('../hooks/usePermissions', () => ({
  usePermissions: jest.fn()
}));

jest.mock('../hooks/useFetchOrganizationData', () => ({
  useFetchOrganizationData: jest.fn()
}));

const createMockAnalytics = (overrides = {}) => ({
  seatCount: { used: 0, total: 0 },
  totalApps: 0,
  isLoading: false,
  error: null,
  ...overrides
});

const createMockOrganization = (overrides = {}) => ({
  organization: { id: 'test-org-id', name: 'Test Organization' },
  isLoading: false,
  error: null,
  ...overrides
});

describe('AnalyticsWidget permissions', () => {
  beforeEach(() => {
    jest.spyOn(analyticsHook, 'useAnalytics').mockReturnValue(createMockAnalytics());
    (orgHook.useFetchOrganizationData as jest.Mock).mockReturnValue(createMockOrganization());
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  it("shows no permission message when user cannot read", () => {
    (permissionHook.usePermissions as jest.Mock).mockReturnValue({
      canRead: false,
      canEdit: false,
      isLoading: false
    });

    render(<AnalyticsWidget />);
    expect(
      screen.getByText(/You don't have permission to view this section/)
    ).toBeInTheDocument();
  });

  it('does not show permission message when user can read', () => {
    (permissionHook.usePermissions as jest.Mock).mockReturnValue({
      canRead: true,
      canEdit: true,
      isLoading: false
    });

    render(<AnalyticsWidget />);
    expect(
      screen.queryByText(/You don't have permission to view this section/)
    ).not.toBeInTheDocument();
  });
});

describe('AnalyticsWidget content', () => {
  beforeEach(() => {
    (permissionHook.usePermissions as jest.Mock).mockReturnValue({
      canRead: true,
      canEdit: true,
      isLoading: false
    });
    (orgHook.useFetchOrganizationData as jest.Mock).mockReturnValue(createMockOrganization());
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('displays the widget title', () => {
    jest.spyOn(analyticsHook, 'useAnalytics').mockReturnValue(
      createMockAnalytics({ seatCount: { used: 5, total: 10 } })
    );
    render(<AnalyticsWidget />);
    expect(screen.getByText('Analytics')).toBeInTheDocument();
  });

  it('displays metrics', () => {
    jest.spyOn(analyticsHook, 'useAnalytics').mockReturnValue(
      createMockAnalytics({ seatCount: { used: 5, total: 10 }, totalApps: 3 })
    );
    render(<AnalyticsWidget />);
    expect(screen.getByText('Seats')).toBeInTheDocument();
    expect(screen.getByText('Applications')).toBeInTheDocument();
  });

  it('shows empty state when no data', () => {
    jest.spyOn(analyticsHook, 'useAnalytics').mockReturnValue(createMockAnalytics());
    (orgHook.useFetchOrganizationData as jest.Mock).mockReturnValue(
      createMockOrganization({ organization: null })
    );
    render(<AnalyticsWidget />);
    expect(screen.queryByRole('list')).not.toBeInTheDocument();
  });
});
```

### Best Practices
- Test behavior, not implementation
- Use meaningful test descriptions
- Keep tests independent and isolated
- Mock external services and APIs
- Test accessibility where applicable
- Load `skill({ name: "aaa-testing" })` for more best practices to follow
