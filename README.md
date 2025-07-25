# Purl - Package URL Parser for Ruby

A comprehensive Ruby library for parsing, validating, and working with Package URLs (PURLs) as defined by the [PURL specification](https://github.com/package-url/purl-spec).

This library provides better error handling than existing solutions with namespaced error types, bidirectional registry URL conversion, and JSON-based configuration for cross-language compatibility.

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%202.7-red.svg)](https://www.ruby-lang.org/)
[![Gem Version](https://badge.fury.io/rb/purl.svg)](https://rubygems.org/gems/purl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**🔗 [Available on RubyGems](https://rubygems.org/gems/purl)**

## Features

- 🎯 **Comprehensive PURL parsing and validation** with 37 package types (32 official + 5 additional ecosystems)
- 🔥 **Better error handling** with namespaced error classes and contextual information
- 🔄 **Bidirectional registry URL conversion** - generate registry URLs from PURLs and parse PURLs from registry URLs
- 📋 **Type-specific validation** for conan, cran, and swift packages
- 🌐 **Registry URL generation** for 20 package ecosystems (npm, gem, maven, pypi, etc.)
- 🎨 **Rails-style route patterns** for registry URL templates
- 📊 **100% compliance** with official PURL specification test suite (59/59 tests passing)
- 🤝 **Cross-language compatibility** with JSON-based configuration
- 📚 **Comprehensive documentation** and examples

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

## Usage

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

# Get detailed type information
info = Purl.type_info("gem")
puts info[:known]                     # => true
puts info[:default_registry]          # => "https://rubygems.org"
puts info[:registry_url_generation]   # => true
puts info[:reverse_parsing]           # => true
puts info[:route_patterns]            # => ["https://rubygems.org/gems/:name", ...]
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

### Rake Tasks

- `rake spec:update` - Fetch latest test cases from official PURL spec repository
- `rake spec:compliance` - Run compliance tests against official test suite  
- `rake spec:types` - Show information about all PURL types and their support
- `rake spec:verify_types` - Verify our types list against official specification
- `rake spec:debug` - Show detailed info about failing test cases

## Funding

If you find this project useful, please consider supporting its development:

- 💝 [GitHub Sponsors](https://github.com/sponsors/andrew)
- ☕ [Buy me a coffee](https://www.buymeacoffee.com/andrew)

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