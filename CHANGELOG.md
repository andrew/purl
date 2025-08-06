# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.2] - 2025-08-06

### Fixed
- CLI executable runs unconditionally to ensure proper execution when installed as gem

## [1.5.1] - 2025-08-06

### Fixed
- CLI executable not running when installed as gem due to file comparison issue

## [1.5.0] - 2025-08-06

### Added
- `versionless` convenience method to create a PackageURL without version component
- `lookup` command to CLI for fetching package information from ecosyste.ms API with version-specific details
- `Purl::Lookup` class for programmatic package information lookup
- `lookup` instance method on `PackageURL` for convenient package information retrieval
- `Purl::LookupFormatter` class for customizable lookup result formatting
- Package maintainer information display in lookup results

## [1.4.0] - 2025-01-06

### Added
- Command-line interface with parse, validate, convert, url, generate, and info commands plus JSON output support

## [1.3.1] - 2025-08-04

### Fixed
- Remove arbitrary business logic validation, follow PURL spec for namespace requirements

## [1.3.0] - 2025-07-29

### Added
- RFC 6570 URI templates for registry URL generation
- Advanced URL templating capabilities for dynamic registry URL construction

### Enhanced
- Registry URL generation now supports more flexible URL patterns
- Improved templating system for custom registry configurations

## [1.2.0] - 2025-07-27

### Added
- Default registry URLs for 10 additional package types:
  - `golang`: https://pkg.go.dev (Go package discovery site)
  - `luarocks`: https://luarocks.org (Lua package repository)
  - `clojars`: https://clojars.org (Clojure package repository)
  - `elm`: https://package.elm-lang.org (Elm package catalog)
  - `deno`: https://deno.land (Deno module registry)
  - `homebrew`: https://formulae.brew.sh (Homebrew package browser)
  - `bioconductor`: https://bioconductor.org (R bioinformatics packages)
  - `huggingface`: https://huggingface.co (Machine learning models)
  - `swift`: https://swiftpackageindex.com (Swift package index)
  - `conan`: https://conan.io/center (C/C++ package center)

### Enhanced
- Registry configuration support for newly added package types
- Updated test suite to validate all new default registries
- Improved package type coverage with comprehensive registry URL mapping

### Configuration
- Updated `purl-types.json` to version 1.2.0 with enhanced registry configurations
- Added specialized registry handling for Go's unique import path structure

## [1.1.2] - 2025-07-25

### Added
- Comprehensive benchmarking rake tasks for performance analysis
  - `rake benchmark:parse` - PURL parsing performance benchmarks
  - `rake benchmark:types` - Package type parsing comparison
  - `rake benchmark:registry` - Registry URL generation benchmarks
  - `rake benchmark:all` - Run all benchmarks

### Improved
- **26% improvement in parsing throughput** (~175K PURLs/second)
- **8% improvement in string conversion performance** (~315K conversions/second)
- **7% improvement in object creation** (~280K objects/second)
- Optimized string operations in parse method with conditional regex application
- Reduced string allocations in `to_s` method using array joining
- Cached compiled regexes with `.freeze` for better performance
- Lower memory allocation pressure in high-throughput scenarios

## [1.1.1] - 2025-07-25

### Added
- Comprehensive RDoc documentation for all classes and methods
- RDoc task in Rakefile with proper configuration
- API documentation link in README

### Fixed
- Add bigdecimal gem dependency to resolve potential loading issues
- Improve JSON schema loading error handling

## [1.1.0] - 2025-07-25

### Added
- JSON schema validation for configuration files (`purl-types.json` and `test-suite-data.json`)
- New rake tasks: `spec:validate_schemas` and `spec:validate_examples`
- Examples for all package types in configuration
- Default registry URLs for package types
- Enhanced reverse parsing support for additional package types
- `with` method for creating modified PURL objects (immutable pattern)
- FUNDING.yml for project sponsorship support

### Enhanced
- Improved README documentation with custom registry examples
- Enhanced test coverage for new functionality
- Better compliance test output formatting
- Comprehensive package type examples and validation

### Documentation
- Updated documentation to remove emoji and enhance readability
- Added comprehensive examples for custom registry usage
- Enhanced API documentation throughout

## [1.0.0] - 2025-01-24

### Added
- 🎯 Comprehensive PURL parsing and validation with all 32 official package types
- 🔥 Namespaced error handling with contextual information (`InvalidSchemeError`, `InvalidTypeError`, `ValidationError`, etc.)
- 🔄 Bidirectional registry URL conversion - generate registry URLs from PURLs and parse PURLs from registry URLs
- 🌐 Registry URL generation for 13+ package ecosystems (npm, gem, maven, pypi, cargo, golang, etc.)
- 🎨 Rails-style route patterns for registry URL templates
- 📋 Type-specific validation for conan, cran, and swift packages
- 🤝 Cross-language compatibility with JSON-based configuration in `purl-types.json`
- 📊 69.5% compliance with official PURL specification test suite (41/59 tests passing)
- 🛠️ Comprehensive rake tasks for spec compliance testing and type management
- 📚 Full documentation and usage examples

### Features
- Parse PURL strings with full component extraction (type, namespace, name, version, qualifiers, subpath)
- Create PURL objects programmatically with validation
- Generate registry URLs for supported package types
- Reverse parse registry URLs back to PURL objects
- Query package type information and capabilities
- Validate PURLs according to type-specific rules
- Support for all official PURL types from the specification

### Supported Package Types
- **Registry URL Generation (13 types):** cargo, cocoapods, composer, conda, gem, golang, hex, maven, npm, nuget, pub, pypi, swift
- **Reverse Parsing (6 types):** cargo, gem, golang, maven, npm, pypi
- **All 32 Official Types:** alpm, apk, bitbucket, bitnami, cargo, cocoapods, composer, conan, conda, cpan, cran, deb, docker, gem, generic, github, golang, hackage, hex, huggingface, luarocks, maven, mlflow, npm, nuget, oci, pub, pypi, qpkg, rpm, swid, swift

### Development Tools
- `rake spec:update` - Fetch latest test cases from official PURL spec repository
- `rake spec:compliance` - Run compliance tests against official test suite
- `rake spec:types` - Show information about all PURL types and their support
- `rake spec:verify_types` - Verify types list against official specification
- `rake spec:debug` - Show detailed info about failing test cases

### Major Release - Production Ready
This marks the first major release of the Purl gem, indicating API stability and production readiness. The library provides comprehensive PURL parsing with better error handling and more features than existing PURL libraries for Ruby, including bidirectional registry URL conversion and cross-language JSON configuration compatibility.
