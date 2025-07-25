# Contributing to Purl

Thank you for your interest in contributing to the Purl Ruby library! This document provides guidelines and information for contributors.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How to Contribute

### Reporting Issues

Before creating an issue, please:
1. Search existing issues to avoid duplicates
2. Use the latest version of the gem
3. Provide a clear, descriptive title
4. Include steps to reproduce the issue
5. Share relevant code examples or error messages

### Suggesting Enhancements

Enhancement suggestions are welcome! Please:
1. Check if the enhancement is already requested
2. Explain the use case and expected behavior
3. Consider if it fits the project's scope
4. Be willing to help implement if accepted

### Pull Requests

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b my-new-feature`)
3. **Make** your changes following our coding standards
4. **Add** tests for your changes
5. **Ensure** all tests pass (`rake test`)
6. **Run** the full test suite including compliance tests
7. **Commit** your changes with clear, descriptive messages
8. **Push** to your branch (`git push origin my-new-feature`)
9. **Create** a Pull Request with a clear description

## Development Setup

### Prerequisites

- Ruby 3.1 or higher
- Bundler gem

### Setup

```bash
git clone https://github.com/package-url/purl-ruby.git
cd purl-ruby
bundle install
```

### Running Tests

```bash
# Run all tests
rake test

# Run PURL specification compliance tests
rake spec:compliance

# Validate JSON schemas
rake spec:validate_schemas

# Validate PURL examples
rake spec:validate_examples

# Show all available tasks
rake -T
```

### Coding Standards

- Follow Ruby best practices and conventions
- Use meaningful variable and method names
- Add documentation for public methods
- Keep methods focused and concise
- Follow the existing code style

### Testing Requirements

All contributions must include appropriate tests:

- **Unit tests** for new functionality
- **Integration tests** for feature interactions
- **Compliance tests** must continue to pass
- **Example validation** for any new PURL examples

### Documentation

- Update the README.md if adding new features
- Add inline documentation for complex methods
- Update CHANGELOG.md following the format
- Include examples in documentation

## Project Structure

```
├── lib/
│   ├── purl.rb              # Main module
│   └── purl/
│       ├── errors.rb        # Error classes
│       ├── package_url.rb   # Core PURL parsing
│       └── registry_url.rb  # Registry URL handling
├── test/                    # Test files
├── schemas/                 # JSON schemas
├── purl-types.json         # Package types configuration
└── test-suite-data.json    # Official test cases
```

## Adding New Package Types

To add support for a new package type:

1. **Add type definition** to `purl-types.json`
2. **Include examples** from the official specification
3. **Add registry configuration** if applicable
4. **Update tests** to verify the new type
5. **Run validation** to ensure compliance

## JSON Schema Updates

When modifying JSON files:

1. **Validate** against schemas: `rake spec:validate_schemas`
2. **Update schemas** if structure changes
3. **Test examples** are valid: `rake spec:validate_examples`

## PURL Specification Compliance

This library maintains 100% compliance with the official PURL specification:

- All changes must maintain compliance
- Run `rake spec:compliance` before submitting
- New features should align with the spec
- Report spec issues upstream when discovered

## Release Process

Releases are handled by maintainers:

1. Update version in `lib/purl/version.rb`
2. Update `CHANGELOG.md` with changes
3. Run full test suite
4. Create release tag
5. Publish to RubyGems

## Getting Help

- **Issues**: Use GitHub issues for bugs and feature requests
- **Discussions**: Use GitHub discussions for questions
- **Security**: Follow our [Security Policy](SECURITY.md)

## Recognition

Contributors will be recognized in:
- Git commit history
- CHANGELOG.md for significant contributions
- Project documentation where appropriate

## License

By contributing to Purl, you agree that your contributions will be licensed under the [MIT License](LICENSE).

Thank you for contributing to make Purl better for everyone!