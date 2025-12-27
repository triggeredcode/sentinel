# Contributing to Sentinel

First off, thanks for considering contributing to Sentinel!

## Development Setup

```bash
git clone https://github.com/triggeredcode/sentinel.git
cd sentinel
swift build
swift test
```

## Pull Request Process

1. Fork the repo and create your branch from `main`
2. If you've added code, add tests
3. Ensure the test suite passes
4. Update documentation if needed
5. Submit your PR

## Code Style

- Swift 5.9+ features welcome
- Use `@MainActor` for UI code
- Prefer `async/await` over callbacks
- Keep functions focused and small

## Reporting Bugs

Open an issue with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Console logs if relevant

## Feature Requests

Open an issue describing:
- The problem you're trying to solve
- Your proposed solution
- Alternatives you've considered

## Questions?

Open a discussion or reach out via issues.
