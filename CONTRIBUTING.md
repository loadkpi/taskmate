# Contributing to Taskmate

Thank you for your interest in contributing!

## Prerequisites

- Ruby >= 3.3 (use `rbenv` or `asdf` to manage versions)
- Bundler (`gem install bundler`)

## Development setup

```bash
git clone https://github.com/taskmate-dev/taskmate
cd taskmate
bundle install
```

Run the full verification (same as CI):

```bash
bundle exec rspec
bundle exec rubocop
```

## Guidelines

- Follow the existing code style (RuboCop enforces it)
- Every new feature needs tests
- Keep commits focused — one logical change per commit
- Write a clear commit message explaining *why*, not just *what*
- Do not bump `lib/taskmate/version.rb` — maintainers handle releases

## Architecture

The project follows a strict layered architecture. Before making changes, read `.ai/architecture.md`.
Key rule: CLI commands are thin wrappers; business logic lives in `lib/taskmate/core/`.

Tests live in `spec/unit/` (isolated) and `spec/integration/` (multi-component workflows).

## Submitting a pull request

1. Fork the repository
2. Create a feature branch (`git checkout -b my-feature`)
3. Make your changes with tests
4. Ensure `bundle exec rspec` and `bundle exec rubocop` both pass
5. Update CHANGELOG.md under `[Unreleased]` if the change is user-visible
6. Open a pull request against `main`

## Reporting issues

Please open a GitHub issue with steps to reproduce, expected behavior, and actual behavior.

## Security vulnerabilities

Do **not** open a public issue for security vulnerabilities. Instead, email security@taskmate.dev with details.
