# Contributing to Koch Trainer

Thank you for your interest in contributing to Koch Trainer! This document provides guidelines and information for contributors.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Install dependencies:

   ```bash
   brew install xcodegen swiftformat swiftlint
   ```

   `make build` runs SwiftFormat and SwiftLint, and `make build`/`make test`/`make run`
   use `python3` (already on macOS) to resolve the simulator UDID.

4. Generate the Xcode project:

   ```bash
   make generate
   ```

5. Open `KochTrainer.xcodeproj` in Xcode

### Secrets and `.envrc` (optional)

This repo ships an `.envrc` (direnv) that loads secrets — API keys and a GitHub
token — from the punt-labs Proton Pass `dev` vault. It is only needed for tasks
that use those secrets; **building and testing the app do not require it**, and
without the tools below `.envrc` prints a one-line reason per missing secret and
continues.

To enable it:

```bash
brew install jq
# Proton Pass CLI:
curl -fsSL https://proton.me/download/pass-cli/install.sh | bash
# Log in once to the punt-labs account:
PROTON_PASS_SESSION_DIR=~/.punt-labs/pass-sessions/puntlabs pass-cli login
```

- Set `PUNTLABS_GIT_IDENTITY=<handle>` to load that identity's GitHub token.
- Set `PROTON_PASS_KEY_PROVIDER=fs` on a host with no usable keyring.

## Development Workflow

### Building

```bash
make build    # Build the app
make test     # Run all tests
make clean    # Clean build artifacts
```

### Code Style

This project uses SwiftLint and SwiftFormat for consistent code style:

- **SwiftLint** — Enforces Swift style and conventions
- **SwiftFormat** — Automatic code formatting

Configuration files are in the repository root (`.swiftlint.yml`, `.swiftformat`).

Before submitting a PR, ensure your code passes linting:

```bash
swiftlint lint
swiftformat . --lint
```

### Project Structure

```text
KochTrainer/
├── App/           # App entry point and main views
├── Models/        # Data models
├── ViewModels/    # View models (MVVM)
├── Views/         # SwiftUI views
├── Services/      # Business logic and utilities
├── Design/        # Theme, typography, components
└── Resources/     # Assets and resources

KochTrainerTests/  # Unit tests
```

### Adding New Features

1. Create a feature branch from `main`:

   ```bash
   git checkout -b feature/my-feature-name
   ```

2. Implement your feature with tests
3. Run `make build` to format, lint, and compile
4. Run `make test` to verify all tests pass
5. Update CHANGELOG.md under `[Unreleased]`
6. Submit a pull request

### Updating the Changelog

All user-facing changes must be documented in `CHANGELOG.md`. Add entries under the `[Unreleased]` section using these categories:

- **Added** — New features
- **Changed** — Changes to existing functionality
- **Deprecated** — Features that will be removed
- **Removed** — Features that were removed
- **Fixed** — Bug fixes
- **Security** — Security-related changes

Write descriptions from the user's perspective, not technical implementation details.

## Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Write clear commit messages following conventional commits (`feat:`, `fix:`, `docs:`, etc.)
- Include tests for new functionality
- Update CHANGELOG.md for user-facing changes
- Update the README if adding user-facing features
- Ensure all tests pass and linting is clean before submitting

## Reporting Issues

When reporting bugs, please include:

- iOS version
- Device or simulator model
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
