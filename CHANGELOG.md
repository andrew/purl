# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
