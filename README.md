# Purl - Package URL Parser for Ruby

A Ruby library for parsing, validating, and generating Package URLs (PURLs) as defined by the [PURL specification](https://github.com/package-url/purl-spec).

This library features comprehensive error handling with namespaced error types, bidirectional registry URL conversion, and JSON-based configuration for cross-language compatibility.

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.1-red.svg)](https://www.ruby-lang.org/)
[![Gem Version](https://badge.fury.io/rb/purl.svg)](https://rubygems.org/gems/purl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[Available on RubyGems](https://rubygems.org/gems/purl)** | **[API Documentation](https://rdoc.info/github/andrew/purl)**

## Related Libraries

- **[Vers](https://github.com/andrew/vers)** - A Ruby library for working with version ranges that supports the VERS specification

## Features

- **Command-line interface** with parse, validate, convert, generate, info, lookup, and advisories commands plus JSON output
- **Comprehensive PURL parsing and validation** with 37 package types (32 official + 5 additional ecosystems)
- **Better error handling** with namespaced error classes and contextual information
- **Bidirectional registry URL conversion** - generate registry URLs from PURLs and parse PURLs from registry URLs
- **Security advisory lookup** - query security advisories from advisories.ecosyste.ms
- **Package information lookup** - query package metadata from ecosyste.ms
- **Type-specific validation** for conan, cran, and swift packages
- **Registry URL generation** for 20 package ecosystems (npm, gem, maven, pypi, etc.)
- **Rails-style route patterns** for registry URL templates
- **100% compliance** with official PURL specification test suite (59/59 tests passing)
- **Cross-language compatibility** with JSON-based configuration
- **Comprehensive documentation** and examples

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'purl'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install purl
```

## Command Line Interface

The purl gem includes a command-line interface that provides convenient access to all parsing, validation, conversion, and generation functionality.

### Installation

The CLI is automatically available after installing the gem:

```bash
gem install purl
purl --help
```

### Available Commands

```bash
purl parse <purl-string>              # Parse and display PURL components
purl validate <purl-string>           # Validate a PURL (exit code indicates success)
purl convert <registry-url>           # Convert registry URL to PURL
purl url <purl-string>                # Convert PURL to registry URL
purl generate [options]               # Generate PURL from components
purl info [type]                      # Show information about PURL types
purl lookup <purl-string>             # Look up package information from ecosyste.ms
purl advisories <purl-string>         # Look up security advisories from advisories.ecosyste.ms
```

### JSON Output

All commands support JSON output with the `--json` flag:

```bash
purl --json parse "pkg:gem/rails@7.0.0"
purl --json info gem
purl --json lookup "pkg:cargo/rand"
purl --json advisories "pkg:npm/lodash@4.17.19"
```

### Command Examples

#### Parse a PURL
```bash
$ purl parse "pkg:gem/rails@7.0.0"
Valid PURL: pkg:gem/rails@7.0.0
Components:
  Type:       gem
  Namespace:  (none)
  Name:       rails
  Version:    7.0.0
  Qualifiers: (none)
  Subpath:    (none)

$ purl --json parse "pkg:npm/@babel/core@7.0.0"
{
  "success": true,
  "purl": "pkg:npm/%40babel/core@7.0.0",
  "components": {
    "type": "npm",
    "namespace": "@babel",
    "name": "core",
    "version": "7.0.0",
    "qualifiers": {},
    "subpath": null
  }
}
```

#### Validate a PURL
```bash
$ purl validate "pkg:gem/rails@7.0.0"
Valid PURL

$ purl validate "invalid-purl"
Invalid PURL: PURL must start with 'pkg:'
```

#### Convert Registry URL to PURL
```bash
$ purl convert "https://rubygems.org/gems/rails"
pkg:gem/rails

$ purl convert "https://www.npmjs.com/package/@babel/core"
pkg:npm/@babel/core
```

#### Convert PURL to Registry URL
```bash
$ purl url "pkg:gem/rails@7.0.0"
https://rubygems.org/gems/rails

$ purl url "pkg:npm/@babel/core@7.0.0"
https://www.npmjs.com/package/@babel/core

$ purl --json url "pkg:gem/rails@7.0.0"
{
  "success": true,
  "purl": "pkg:gem/rails@7.0.0",
  "registry_url": "https://rubygems.org/gems/rails",
  "type": "gem"
}
```

#### Generate a PURL
```bash
$ purl generate --type gem --name rails --version 7.0.0
pkg:gem/rails@7.0.0

$ purl generate --type npm --namespace @babel --name core --version 7.0.0 --qualifiers "arch=x64,os=linux"
pkg:npm/%40babel/core@7.0.0?arch=x64&os=linux
```

#### Show Type Information
```bash
$ purl info gem
Type: gem
Known: Yes
Description: RubyGems
Default registry: https://rubygems.org
Registry URL generation: Yes
Reverse parsing: Yes
Examples:
  pkg:gem/ruby-advisory-db-check@0.12.4
  pkg:gem/rails@7.0.4
  pkg:gem/bundler@2.3.26
Registry URL patterns:
  https://rubygems.org/gems/:name
  https://rubygems.org/gems/:name/versions/:version

$ purl info  # Shows all types
Known PURL types:

  alpm
    Description: Arch Linux packages
    Registry support: No
    Reverse parsing: No
  ...
Total types: 37
Registry supported: 20
```

#### Look Up Package Information
```bash
$ purl lookup "pkg:cargo/rand"
Package: rand (cargo)
Description: Random number generators and other randomness functionality.
Homepage: https://rust-random.github.io/book
Repository: https://github.com/rust-random/rand
License: MIT OR Apache-2.0
Downloads: 145,678,901
Latest Version: 0.8.5
Published: 2023-01-13T17:47:01.870Z

$ purl --json lookup "pkg:cargo/rand@0.8.5"
{
  "success": true,
  "purl": "pkg:cargo/rand@0.8.5",
  "package": {
    "name": "rand",
    "ecosystem": "cargo",
    "description": "Random number generators and other randomness functionality.",
    "homepage": "https://rust-random.github.io/book",
    "repository_url": "https://github.com/rust-random/rand",
    "registry_url": "https://crates.io/crates/rand",
    "licenses": "MIT OR Apache-2.0",
    "latest_version": "0.8.5",
    "latest_version_published_at": "2023-01-13T17:47:01.870Z",
    "versions_count": 89,
    "maintainers": [
      {
        "login": "dhardy",
        "name": "Diggory Hardy"
      }
    ]
  },
  "version": {
    "number": "0.8.5",
    "published_at": "2023-01-13T17:47:01.870Z",
    "registry_url": "https://crates.io/crates/rand/0.8.5",
    "downloads": 5678901,
    "size": 102400
  }
}
```

#### Look Up Security Advisories
```bash
$ purl advisories "pkg:npm/lodash@4.17.19"
Security Advisories for pkg:npm/lodash@4.17.19
================================================================================

Advisory #1: Regular Expression Denial of Service (ReDoS) in lodash
Identifiers: GHSA-x5rq-j2xg-h7qm, CVE-2019-1010266
Severity: MODERATE

Description:
  lodash prior to 4.7.11 is affected by: CWE-400: Uncontrolled Resource
  Consumption. The impact is: Denial of service. The component is: Date
  handler. The attack vector is: Attacker provides very long strings, which
  the library attempts to match using a regular expression. The fixed version
  is: 4.7.11.

Affected Packages:
  Package: npm/lodash
  Vulnerable: >= 4.7.0, < 4.17.11
  Patched: 4.17.11

Source: github | Origin: UNSPECIFIED | Published: 2019-07-19T16:13:07.000Z
Advisory URL: https://github.com/advisories/GHSA-x5rq-j2xg-h7qm

Total advisories found: 3

$ purl --json advisories "pkg:npm/lodash@4.17.19"
{
  "success": true,
  "purl": "pkg:npm/lodash@4.17.19",
  "advisories": [
    {
      "id": "MDE2OlNlY3VyaXR5QWR2aXNvcnlHSFNBLXg1cnEtajJ4Zy1oN3Ft",
      "title": "Regular Expression Denial of Service (ReDoS) in lodash",
      "description": "lodash prior to 4.7.11 is affected by...",
      "severity": "MODERATE",
      "url": "https://github.com/advisories/GHSA-x5rq-j2xg-h7qm",
      "published_at": "2019-07-19T16:13:07.000Z",
      "affected_packages": [
        {
          "ecosystem": "npm",
          "name": "lodash",
          "vulnerable_version_range": ">= 4.7.0, < 4.17.11",
          "first_patched_version": "4.17.11"
        }
      ],
      "identifiers": ["GHSA-x5rq-j2xg-h7qm", "CVE-2019-1010266"]
    }
  ],
  "count": 3
}
```

### Generate Options

The `generate` command supports all PURL components:

```bash
purl generate --help
Usage: purl generate [options]
    --type TYPE                      Package type (required)
    --name NAME                      Package name (required)
    --namespace NAMESPACE            Package namespace
    --version VERSION                Package version
    --qualifiers QUALIFIERS          Qualifiers as key=value,key2=value2
    --subpath SUBPATH                Package subpath
    -h, --help                       Show this help
```

### Exit Codes

The CLI uses standard exit codes:
- `0` - Success
- `1` - Error (invalid PURL, unsupported operation, etc.)

This makes the CLI suitable for use in scripts and CI/CD pipelines:

```bash
if purl validate "pkg:gem/rails@7.0.0"; then
  echo "Valid PURL"
else
  echo "Invalid PURL"
  exit 1
fi
```

## Library Usage

### Basic PURL Parsing

```ruby
require 'purl'

# Parse a PURL string
purl = Purl.parse("pkg:gem/rails@7.0.0")
puts purl.type        # => "gem"
puts purl.name        # => "rails"
puts purl.version     # => "7.0.0"
puts purl.namespace   # => nil

# Parse with namespace and qualifiers
purl = Purl.parse("pkg:npm/@babel/core@7.0.0?arch=x86_64")
puts purl.type        # => "npm"
puts purl.namespace   # => "@babel"
puts purl.name        # => "core"
puts purl.version     # => "7.0.0"
puts purl.qualifiers  # => {"arch" => "x86_64"}
```

### Creating PURLs

```ruby
# Create a PURL object
purl = Purl::PackageURL.new(
  type: "maven",
  namespace: "org.apache.commons",
  name: "commons-lang3",
  version: "3.12.0"
)

puts purl.to_s  # => "pkg:maven/org.apache.commons/commons-lang3@3.12.0"
```

### Modifying PURL Objects

PURL objects are immutable by design, but you can create new objects with modified attributes using the `with` method:

```ruby
# Create original PURL
original = Purl::PackageURL.new(
  type: "npm",
  namespace: "@babel", 
  name: "core",
  version: "7.20.0",
  qualifiers: { "arch" => "x64" }
)

# Create new PURL with updated version
updated = original.with(version: "7.21.0")
puts updated.to_s  # => "pkg:npm/@babel/core@7.21.0?arch=x64"

# Update qualifiers
with_new_qualifiers = original.with(
  qualifiers: { "arch" => "arm64", "os" => "linux" }
)
puts with_new_qualifiers.to_s  # => "pkg:npm/@babel/core@7.20.0?arch=arm64&os=linux"

# Update multiple attributes at once
fully_updated = original.with(
  version: "8.0.0",
  qualifiers: { "dev" => "true" },
  subpath: "lib/index.js"
)
puts fully_updated.to_s  # => "pkg:npm/@babel/core@8.0.0#lib/index.js?dev=true"

# Original remains unchanged
puts original.to_s  # => "pkg:npm/@babel/core@7.20.0?arch=x64"
```

### Registry URL Generation

```ruby
# Generate registry URLs from PURLs
purl = Purl.parse("pkg:gem/rails@7.0.0")
puts purl.registry_url                # => "https://rubygems.org/gems/rails"
puts purl.registry_url_with_version   # => "https://rubygems.org/gems/rails/versions/7.0.0"

# Check if registry URL generation is supported
puts purl.supports_registry_url?      # => true

# NPM with scoped packages
purl = Purl.parse("pkg:npm/@babel/core@7.0.0")
puts purl.registry_url                # => "https://www.npmjs.com/package/@babel/core"
```

### Reverse Parsing: Registry URLs to PURLs

```ruby
# Parse registry URLs back to PURLs
purl = Purl.from_registry_url("https://rubygems.org/gems/rails/versions/7.0.0")
puts purl.to_s  # => "pkg:gem/rails@7.0.0"

# Works with various registries
purl = Purl.from_registry_url("https://www.npmjs.com/package/@babel/core")
puts purl.to_s  # => "pkg:npm/@babel/core"

purl = Purl.from_registry_url("https://pypi.org/project/django/4.0.0/")
puts purl.to_s  # => "pkg:pypi/django@4.0.0"
```

### Custom Registry Domains

You can parse registry URLs from custom domains or generate URLs for private registries:

```ruby
# Parse from custom domain (specify type to help with parsing)
purl = Purl.from_registry_url("https://npm.company.com/package/@babel/core", type: "npm")
puts purl.to_s  # => "pkg:npm/@babel/core"

# Generate URLs for custom registries
purl = Purl.parse("pkg:gem/rails@7.0.0")
custom_url = purl.registry_url(base_url: "https://gems.internal.com/gems")
puts custom_url  # => "https://gems.internal.com/gems/rails"

# With version-specific URLs
with_version = purl.registry_url_with_version(base_url: "https://gems.internal.com/gems")
puts with_version  # => "https://gems.internal.com/gems/rails/versions/7.0.0"

# Works with all supported package types
composer_purl = Purl.parse("pkg:composer/symfony/console@5.4.0")
private_composer = composer_purl.registry_url(base_url: "https://packagist.company.com/packages")
puts private_composer  # => "https://packagist.company.com/packages/symfony/console"
```

### Route Patterns

```ruby
# Get route patterns for a package type (Rails-style)
patterns = Purl::RegistryURL.route_patterns_for("gem")
# => ["https://rubygems.org/gems/:name", "https://rubygems.org/gems/:name/versions/:version"]

# Get all route patterns
all_patterns = Purl::RegistryURL.all_route_patterns
puts all_patterns["npm"]
# => ["https://www.npmjs.com/package/:namespace/:name", "https://www.npmjs.com/package/:name", ...]
```

### Working with Qualifiers

Qualifiers are key-value pairs that provide additional metadata about packages:

```ruby
# Create PURL with qualifiers
purl = Purl::PackageURL.new(
  type: "apk",
  name: "curl",
  version: "7.83.0-r0",
  qualifiers: {
    "distro" => "alpine-3.16",
    "arch" => "x86_64",
    "repository_url" => "https://dl-cdn.alpinelinux.org"
  }
)
puts purl.to_s  # => "pkg:apk/curl@7.83.0-r0?arch=x86_64&distro=alpine-3.16&repository_url=https://dl-cdn.alpinelinux.org"

# Access qualifiers
puts purl.qualifiers["distro"]  # => "alpine-3.16"
puts purl.qualifiers["arch"]    # => "x86_64"

# Parse PURL with qualifiers
parsed = Purl.parse("pkg:rpm/httpd@2.4.53?distro=fedora-36&arch=x86_64")
puts parsed.qualifiers  # => {"distro" => "fedora-36", "arch" => "x86_64"}

# Add qualifiers to existing PURL
with_qualifiers = purl.with(qualifiers: purl.qualifiers.merge("signed" => "true"))
```

### Package Type Information

```ruby
# Get all known PURL types
puts Purl.known_types.length          # => 37
puts Purl.known_types.include?("gem") # => true

# Check type support
puts Purl.known_type?("gem")                    # => true
puts Purl.registry_supported_types              # => ["cargo", "gem", "maven", "npm", ...]
puts Purl.reverse_parsing_supported_types       # => ["bioconductor", "cargo", "clojars", ...]

# Get default registry for a type
puts Purl.default_registry("gem")               # => "https://rubygems.org"
puts Purl.default_registry("npm")               # => "https://registry.npmjs.org"
puts Purl.default_registry("golang")             # => nil (no default)

# Get official examples for a type
puts Purl.type_examples("gem")                  # => ["pkg:gem/rails@7.0.4", "pkg:gem/bundler@2.3.26", ...]
puts Purl.type_examples("npm")                  # => ["pkg:npm/lodash@4.17.21", "pkg:npm/@babel/core@7.20.0", ...]
puts Purl.type_examples("unknown")              # => []

# Get detailed type information
info = Purl.type_info("gem")
puts info[:known]                     # => true
puts info[:description]               # => "RubyGems"
puts info[:default_registry]          # => "https://rubygems.org"
puts info[:examples]                  # => ["pkg:gem/rails@7.0.4", ...]
puts info[:registry_url_generation]   # => true
puts info[:reverse_parsing]           # => true
puts info[:route_patterns]            # => ["https://rubygems.org/gems/:name", ...]
```

### Security Advisory Lookup

Look up security advisories for packages using the advisories.ecosyste.ms API:

```ruby
# Look up advisories for a package
purl = Purl.parse("pkg:npm/lodash@4.17.19")
advisories = purl.advisories

# Display advisory information
advisories.each do |advisory|
  puts "Title: #{advisory[:title]}"
  puts "Severity: #{advisory[:severity]}"
  puts "Description: #{advisory[:description]}"
  puts "URL: #{advisory[:url]}"

  # Show affected packages
  advisory[:affected_packages].each do |pkg|
    puts "  Package: #{pkg[:ecosystem]}/#{pkg[:name]}"
    puts "  Vulnerable: #{pkg[:vulnerable_version_range]}"
    puts "  Patched: #{pkg[:first_patched_version]}" if pkg[:first_patched_version]
  end

  # Show identifiers (CVE, GHSA, etc.)
  puts "Identifiers: #{advisory[:identifiers].join(', ')}"
  puts
end

# Look up advisories for any version of a package
purl = Purl.parse("pkg:npm/lodash")
all_advisories = purl.advisories

# Use custom user agent and timeout
advisories = purl.advisories(user_agent: "my-app/1.0", timeout: 5)
```

### Error Handling

```ruby
# Detailed error types with context
begin
  Purl.parse("invalid-purl")
rescue Purl::InvalidSchemeError => e
  puts "Scheme error: #{e.message}"
rescue Purl::ParseError => e
  puts "Parse error: #{e.message}"
  puts "Component: #{e.component}"
  puts "Value: #{e.value}"
end

# Type-specific validation errors
begin
  Purl::PackageURL.new(type: "swift", name: "Alamofire")  # Swift requires namespace
rescue Purl::ValidationError => e
  puts e.message  # => "Swift PURLs require a namespace to be unambiguous"
end
```

### Supported Package Types

The library supports 37 package types (32 official + 5 additional ecosystems):

**Registry URL Generation (20 types):**
- `bioconductor` (R/Bioconductor) - bioconductor.org
- `cargo` (Rust) - crates.io
- `clojars` (Clojure) - clojars.org
- `cocoapods` (iOS) - cocoapods.org
- `composer` (PHP) - packagist.org
- `conda` (Python) - anaconda.org
- `cpan` (Perl) - metacpan.org
- `deno` (Deno) - deno.land/x
- `elm` (Elm) - package.elm-lang.org
- `gem` (Ruby) - rubygems.org  
- `golang` (Go) - pkg.go.dev
- `hackage` (Haskell) - hackage.haskell.org
- `hex` (Elixir) - hex.pm
- `homebrew` (macOS) - formulae.brew.sh
- `maven` (Java) - mvnrepository.com
- `npm` (Node.js) - npmjs.com
- `nuget` (.NET) - nuget.org
- `pub` (Dart) - pub.dev
- `pypi` (Python) - pypi.org
- `swift` (Swift) - swiftpackageindex.com

**Reverse Parsing (20 types):**
- `bioconductor`, `cargo`, `clojars`, `cocoapods`, `composer`, `conda`, `cpan`, `deno`, `elm`, `gem`, `golang`, `hackage`, `hex`, `homebrew`, `maven`, `npm`, `nuget`, `pub`, `pypi`, `swift`

**All 37 Supported Types:**
`alpm`, `apk`, `bioconductor`, `bitbucket`, `bitnami`, `cargo`, `clojars`, `cocoapods`, `composer`, `conan`, `conda`, `cpan`, `cran`, `deb`, `deno`, `docker`, `elm`, `gem`, `generic`, `github`, `golang`, `hackage`, `hex`, `homebrew`, `huggingface`, `luarocks`, `maven`, `mlflow`, `npm`, `nuget`, `oci`, `pub`, `pypi`, `qpkg`, `rpm`, `swid`, `swift`

## Specification Compliance

- **100% compliance** with the official PURL specification test suite (59/59 tests passing)
- **All 32 official package types** plus 5 additional ecosystem types supported
- **Type-specific validation** for conan, cran, swift, cpan, and mlflow packages
- **Proper error handling** for invalid PURLs that should be rejected

## JSON Configuration

Package types and registry patterns are stored in `purl-types.json` for easy contribution and cross-language compatibility:

```json
{
  "version": "1.0.0",
  "description": "PURL types and registry URL patterns for package ecosystems",
  "source": "https://github.com/package-url/purl-spec/blob/main/PURL-TYPES.rst",
  "last_updated": "2025-07-24",
  "types": {
    "gem": {
      "description": "RubyGems",
      "default_registry": "https://rubygems.org",
      "registry_config": {
        "path_template": "/gems/:name",
        "version_path_template": "/gems/:name/versions/:version",
        "reverse_regex": "/gems/([^/?#]+)(?:/versions/([^/?#]+))?",
        "components": {
          "namespace": false,
          "version_in_url": true,
          "version_path": "/versions/"
        }
      }
    }
  }
}
```

**Key Configuration Improvements:**
- **Domain-agnostic patterns**: `path_template` without hardcoded domains enables custom registries
- **Flexible URL generation**: Combine `default_registry` + `path_template` for any domain
- **Cleaner JSON**: Reduced duplication and easier maintenance
- **Cross-registry compatibility**: Same URL structure works with public and private registries

## JSON Schema Validation

The library includes JSON schemas for validation and documentation:

- **`schemas/purl-types.schema.json`** - Schema for the PURL types configuration file
- **`schemas/test-suite-data.schema.json`** - Schema for the official test suite data

These schemas provide:
- **Structure validation** - Ensure JSON files conform to expected format
- **Documentation** - Self-documenting configuration with descriptions
- **IDE support** - Enable autocomplete and validation in editors
- **CI/CD integration** - Validate configuration in automated pipelines

Validate JSON files against their schemas:
```bash
rake spec:validate_schemas
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then:

```bash
# Run tests
rake test

# Run specification compliance tests
rake spec:compliance

# Update test cases from official PURL spec
rake spec:update

# Show type information
rake spec:types

# Verify types against official specification
rake spec:verify_types
```

### Testing Against Official Specification

This library includes the official [purl-spec](https://github.com/package-url/purl-spec) repository as a git submodule for testing and validation:

```bash
# Initialize submodule (first time only)
git submodule update --init --recursive

# Update submodule to latest spec
git submodule update --remote purl-spec
```

The tests use files from the submodule to:
- **Schema validation**: Validate our `purl-types.json` against the official schema in `purl-spec/schemas/`
- **Type compliance**: Ensure our supported types match the official types in `purl-spec/types/`
- **Test data**: Access official test cases and examples from `purl-spec/tests/`

The submodule is automatically updated weekly via Dependabot, ensuring tests stay current with the latest specification changes. When the submodule updates, you can review and merge the PR to adopt new spec requirements.

### Rake Tasks

- `rake spec:update` - Fetch latest test cases from official PURL spec repository
- `rake spec:compliance` - Run compliance tests against official test suite  
- `rake spec:types` - Show information about all PURL types and their support
- `rake spec:verify_types` - Verify our types list against official specification
- `rake spec:validate_schemas` - Validate JSON files against their schemas
- `rake spec:debug` - Show detailed info about failing test cases

## Funding

If you find this project useful, please consider supporting its development:

- [GitHub Sponsors](https://github.com/sponsors/andrew)
- [Ko-fi](https://ko-fi.com/andrewnez)
- [Buy Me a Coffee](https://www.buymeacoffee.com/andrewnez)

Your support helps maintain and improve this library for the entire Ruby community.

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Make your changes
4. Add tests for your changes
5. Ensure all tests pass (`rake test`)
6. Commit your changes (`git commit -am 'Add some feature'`)
7. Push to the branch (`git push origin my-new-feature`)
8. Create new Pull Request

### Adding New Package Types

To add support for a new package type:

1. Update `purl-types.json` with the new type configuration
2. Add registry URL patterns if applicable
3. Add type-specific validation rules if needed in `lib/purl/package_url.rb`
4. Add tests for the new functionality

## License

This gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes and releases.

## Code of Conduct

Everyone interacting in the Purl project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).