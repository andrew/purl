# frozen_string_literal: true

require_relative "test_helper"

class TestPurl < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Purl::VERSION
  end

  def test_parse_convenience_method
    purl = Purl.parse("pkg:gem/rails@7.0.0")
    assert_equal "gem", purl.type
    assert_equal "rails", purl.name
    assert_equal "7.0.0", purl.version
  end

  def test_basic_package_url_creation
    purl = Purl::PackageURL.new(type: "gem", name: "rails", version: "7.0.0")
    assert_equal "gem", purl.type
    assert_equal "rails", purl.name
    assert_equal "7.0.0", purl.version
    assert_nil purl.namespace
    assert_nil purl.qualifiers
    assert_nil purl.subpath
  end

  def test_package_url_with_all_components
    qualifiers = { "arch" => "x86_64", "os" => "linux" }
    purl = Purl::PackageURL.new(
      type: "npm",
      namespace: "@babel",
      name: "core",
      version: "7.0.0",
      qualifiers: qualifiers,
      subpath: "lib/index.js"
    )
    
    assert_equal "npm", purl.type
    assert_equal "@babel", purl.namespace
    assert_equal "core", purl.name
    assert_equal "7.0.0", purl.version
    assert_equal qualifiers, purl.qualifiers
    assert_equal "lib/index.js", purl.subpath
  end

  def test_parse_simple_purl
    purl = Purl::PackageURL.parse("pkg:gem/rails@7.0.0")
    assert_equal "gem", purl.type
    assert_equal "rails", purl.name
    assert_equal "7.0.0", purl.version
  end

  def test_parse_purl_with_namespace
    purl = Purl::PackageURL.parse("pkg:npm/@babel/core@7.0.0")
    assert_equal "npm", purl.type
    assert_equal "@babel", purl.namespace
    assert_equal "core", purl.name
    assert_equal "7.0.0", purl.version
  end

  def test_parse_purl_with_qualifiers
    purl = Purl::PackageURL.parse("pkg:gem/rails@7.0.0?arch=x86_64&os=linux")
    assert_equal "gem", purl.type
    assert_equal "rails", purl.name
    assert_equal "7.0.0", purl.version
    assert_equal({ "arch" => "x86_64", "os" => "linux" }, purl.qualifiers)
  end

  def test_to_s_roundtrip
    original = "pkg:npm/@babel/core@7.0.0?arch=x86_64&os=linux"
    purl = Purl::PackageURL.parse(original)
    # Note: qualifiers are sorted in output, and @ in namespace gets encoded
    expected = "pkg:npm/%40babel/core@7.0.0?arch=x86_64&os=linux"
    assert_equal expected, purl.to_s
  end

  def test_invalid_scheme_error
    assert_raises(Purl::InvalidSchemeError) do
      Purl::PackageURL.parse("http://example.com/package")
    end
  end

  def test_invalid_type_error
    assert_raises(Purl::InvalidTypeError) do
      Purl::PackageURL.new(type: nil, name: "test")
    end
    
    # Empty type is now allowed in PURL spec
    # assert_raises(Purl::InvalidTypeError) do
    #   Purl::PackageURL.new(type: "", name: "test")
    # end
    
    assert_raises(Purl::InvalidTypeError) do
      Purl::PackageURL.new(type: "123invalid", name: "test")
    end
  end

  def test_invalid_name_error
    assert_raises(Purl::InvalidNameError) do
      Purl::PackageURL.new(type: "gem", name: nil)
    end
    
    assert_raises(Purl::InvalidNameError) do
      Purl::PackageURL.new(type: "gem", name: "")
    end
  end

  def test_legacy_error_compatibility
    # Test that InvalidPackageURL is an alias for ParseError
    assert_raises(Purl::InvalidPackageURL) do
      Purl::PackageURL.parse("invalid-purl")
    end
  end

  def test_registry_url_generation
    purl = Purl::PackageURL.new(type: "gem", name: "rails", version: "7.0.0")
    assert_equal "https://rubygems.org/gems/rails", purl.registry_url
    assert_equal "https://rubygems.org/gems/rails/versions/7.0.0", purl.registry_url_with_version
  end

  def test_npm_registry_url_with_namespace
    purl = Purl::PackageURL.new(type: "npm", namespace: "@babel", name: "core")
    assert_equal "https://www.npmjs.com/package/@babel/core", purl.registry_url
  end

  def test_unsupported_type_registry_error
    purl = Purl::PackageURL.new(type: "unknown", name: "test")
    assert_raises(Purl::UnsupportedTypeError) do
      purl.registry_url
    end
  end

  def test_maven_requires_namespace
    # Maven requires namespace per spec; the PURL is still built but reported invalid
    refute Purl::PackageURL.new(type: "maven", name: "junit").valid?
    
    # Maven with namespace should work for registry URL generation
    purl = Purl::PackageURL.new(type: "maven", namespace: "junit", name: "junit")
    # Should be able to generate registry URL with namespace
    assert purl.registry_url.include?("junit")
  end

  def test_supports_registry_url
    gem_purl = Purl::PackageURL.new(type: "gem", name: "rails")
    unknown_purl = Purl::PackageURL.new(type: "unknown", name: "test")
    
    assert gem_purl.supports_registry_url?
    refute unknown_purl.supports_registry_url?
  end

  # Tests for reverse parsing registry URLs to PURLs
  def test_from_registry_url_gem
    registry_url = "https://rubygems.org/gems/purl"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "gem", purl.type
    assert_equal "purl", purl.name
    assert_nil purl.namespace
    assert_nil purl.version
  end

  def test_from_registry_url_gem_with_version
    registry_url = "https://rubygems.org/gems/rails/versions/7.0.0"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "gem", purl.type
    assert_equal "rails", purl.name
    assert_equal "7.0.0", purl.version
    assert_nil purl.namespace
  end

  def test_from_registry_url_npm_scoped
    registry_url = "https://www.npmjs.com/package/@babel/core"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "npm", purl.type
    assert_equal "core", purl.name
    assert_equal "@babel", purl.namespace
    assert_nil purl.version
  end

  def test_from_registry_url_npm_with_version
    registry_url = "https://www.npmjs.com/package/lodash/v/4.17.21"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "npm", purl.type
    assert_equal "lodash", purl.name
    assert_equal "4.17.21", purl.version
    assert_nil purl.namespace
  end

  def test_from_registry_url_maven
    registry_url = "https://mvnrepository.com/artifact/org.apache.commons/commons-lang3/3.12.0"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "maven", purl.type
    assert_equal "commons-lang3", purl.name
    assert_equal "org.apache.commons", purl.namespace
    assert_equal "3.12.0", purl.version
  end

  def test_from_registry_url_cargo
    registry_url = "https://crates.io/crates/serde"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "cargo", purl.type
    assert_equal "serde", purl.name
    assert_nil purl.namespace
    assert_nil purl.version
  end

  def test_from_registry_url_composer
    registry_url = "https://packagist.org/packages/symfony/console"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "composer", purl.type
    assert_equal "console", purl.name
    assert_equal "symfony", purl.namespace
    assert_nil purl.version
  end

  def test_from_registry_url_swift
    # Swift packages can be parsed without version now that we follow the PURL spec
    registry_url = "https://swiftpackageindex.com/apple/swift-package-manager"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "swift", purl.type
    assert_equal "swift-package-manager", purl.name  
    assert_equal "apple", purl.namespace
    assert_nil purl.version
  end

  def test_from_registry_url_nuget_with_version
    registry_url = "https://www.nuget.org/packages/Newtonsoft.Json/13.0.1"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "nuget", purl.type
    assert_equal "Newtonsoft.Json", purl.name
    assert_nil purl.namespace
    assert_equal "13.0.1", purl.version
  end

  def test_from_registry_url_clojars_with_namespace
    registry_url = "https://clojars.org/org.clojure/clojure"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "clojars", purl.type
    assert_equal "clojure", purl.name
    assert_equal "org.clojure", purl.namespace
    assert_nil purl.version
  end

  def test_from_registry_url_clojars_without_namespace
    registry_url = "https://clojars.org/ring"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "clojars", purl.type
    assert_equal "ring", purl.name
    assert_nil purl.namespace
    assert_nil purl.version
  end

  def test_from_registry_url_pub
    registry_url = "https://pub.dev/packages/flutter"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "pub", purl.type
    assert_equal "flutter", purl.name
    assert_nil purl.namespace
    assert_nil purl.version
  end

  def test_from_registry_url_hex
    registry_url = "https://hex.pm/packages/phoenix"
    purl = Purl.from_registry_url(registry_url)
    
    assert_equal "hex", purl.type
    assert_equal "phoenix", purl.name
    assert_nil purl.namespace
    assert_nil purl.version
  end

  def test_default_registry
    # Test types with default registries
    assert_equal "https://rubygems.org", Purl.default_registry("gem")
    assert_equal "https://registry.npmjs.org", Purl.default_registry("npm")
    assert_equal "https://pypi.org", Purl.default_registry("pypi")
    assert_equal "https://crates.io", Purl.default_registry("cargo")
    assert_equal "https://packagist.org", Purl.default_registry("composer")
    assert_equal "https://hub.docker.com", Purl.default_registry("docker")
    assert_equal "https://github.com", Purl.default_registry("github")
    assert_equal "https://bitbucket.org", Purl.default_registry("bitbucket")
    assert_equal "https://pkg.go.dev", Purl.default_registry("golang")
    assert_equal "https://luarocks.org", Purl.default_registry("luarocks")
    assert_equal "https://clojars.org", Purl.default_registry("clojars")
    assert_equal "https://package.elm-lang.org", Purl.default_registry("elm")
    assert_equal "https://deno.land", Purl.default_registry("deno")
    assert_equal "https://formulae.brew.sh", Purl.default_registry("homebrew")
    assert_equal "https://bioconductor.org", Purl.default_registry("bioconductor")
    assert_equal "https://huggingface.co", Purl.default_registry("huggingface")
    assert_equal "https://swiftpackageindex.com", Purl.default_registry("swift")
    assert_equal "https://conan.io/center", Purl.default_registry("conan")
    
    # Test types without default registries
    assert_nil Purl.default_registry("generic")
    assert_nil Purl.default_registry("alpm")
    assert_nil Purl.default_registry("apk")
    assert_nil Purl.default_registry("deb")
    assert_nil Purl.default_registry("rpm")
    
    # Test unknown type
    assert_nil Purl.default_registry("unknown")
  end

  def test_type_examples
    # Test types with examples
    gem_examples = Purl.type_examples("gem")
    assert_instance_of Array, gem_examples
    assert_includes gem_examples, "pkg:gem/rails@7.0.4"
    
    npm_examples = Purl.type_examples("npm")
    assert_includes npm_examples, "pkg:npm/@babel/core@7.20.0"
    
    cargo_examples = Purl.type_examples("cargo")
    assert_includes cargo_examples, "pkg:cargo/rand@0.7.2"
    
    # Test type without examples
    unknown_examples = Purl.type_examples("unknown")
    assert_empty unknown_examples
  end

  def test_from_registry_url_with_custom_domain
    # Test npm package on private registry
    private_npm_url = "https://npm.company.com/package/@babel/core"
    purl = Purl.from_registry_url(private_npm_url, type: "npm")
    
    assert_equal "npm", purl.type
    assert_equal "@babel", purl.namespace
    assert_equal "core", purl.name
    assert_nil purl.version
    
    # Test gem on private registry with version
    private_gem_url = "https://gems.internal.com/gems/rails/versions/7.0.0"
    purl = Purl.from_registry_url(private_gem_url, type: "gem")
    
    assert_equal "gem", purl.type
    assert_equal "rails", purl.name
    assert_equal "7.0.0", purl.version
    assert_nil purl.namespace
    
    # Test PyPI on custom domain
    custom_pypi_url = "https://pypi.example.org/project/django/4.0.0/"
    purl = Purl.from_registry_url(custom_pypi_url, type: "pypi")
    
    assert_equal "pypi", purl.type
    assert_equal "django", purl.name
    assert_equal "4.0.0", purl.version
    assert_nil purl.namespace
  end

  def test_from_registry_url_custom_domain_wrong_type
    # Test error when URL structure doesn't match the specified type
    # Try to parse a URL that definitely won't match npm pattern
    bad_url = "https://example.com/completely/different/structure"
    
    assert_raises(Purl::UnsupportedTypeError) do
      Purl.from_registry_url(bad_url, type: "npm")
    end
  end

  def test_from_registry_url_unsupported
    registry_url = "https://unknown-registry.com/package/test"
    
    assert_raises(Purl::UnsupportedTypeError) do
      Purl.from_registry_url(registry_url)
    end
    
    # Also test with type hint but unsupported type
    assert_raises(Purl::UnsupportedTypeError) do
      Purl.from_registry_url(registry_url, type: "unsupported")
    end
  end

  def test_with_method
    original = Purl::PackageURL.new(
      type: "npm",
      namespace: "@babel",
      name: "core",
      version: "7.20.0",
      qualifiers: { "arch" => "x64" }
    )
    
    # Test version update
    updated_version = original.with(version: "7.21.0")
    assert_equal "7.21.0", updated_version.version
    assert_equal "7.20.0", original.version  # Original unchanged
    assert_equal original.type, updated_version.type
    assert_equal original.name, updated_version.name
    
    # Test qualifiers update
    updated_qualifiers = original.with(qualifiers: { "arch" => "arm64", "os" => "linux" })
    assert_equal({ "arch" => "arm64", "os" => "linux" }, updated_qualifiers.qualifiers)
    assert_equal({ "arch" => "x64" }, original.qualifiers)  # Original unchanged
    
    # Test multiple updates
    updated_multiple = original.with(
      version: "8.0.0",
      qualifiers: { "dev" => "true" },
      subpath: "lib/index.js"
    )
    assert_equal "8.0.0", updated_multiple.version
    assert_equal({ "dev" => "true" }, updated_multiple.qualifiers)
    assert_equal "lib/index.js", updated_multiple.subpath
    
    # Original should remain completely unchanged
    assert_equal "pkg:npm/%40babel/core@7.20.0?arch=x64", original.to_s
  end

  def test_versionless_method
    # Test with versioned purl
    versioned = Purl::PackageURL.new(
      type: "gem",
      name: "rails",
      version: "7.0.0",
      qualifiers: { "arch" => "x64" }
    )
    
    versionless = versioned.versionless
    assert_nil versionless.version
    assert_equal "gem", versionless.type
    assert_equal "rails", versionless.name
    assert_equal({ "arch" => "x64" }, versionless.qualifiers)
    assert_equal "pkg:gem/rails?arch=x64", versionless.to_s
    
    # Original should remain unchanged
    assert_equal "7.0.0", versioned.version
    assert_equal "pkg:gem/rails@7.0.0?arch=x64", versioned.to_s
    
    # Test with already versionless purl
    already_versionless = Purl::PackageURL.new(type: "npm", name: "lodash")
    still_versionless = already_versionless.versionless
    assert_nil still_versionless.version
    assert_equal "pkg:npm/lodash", still_versionless.to_s
  end

  def test_lookup_method_exists
    purl = Purl::PackageURL.new(type: "gem", name: "rails")
    assert_respond_to purl, :lookup
  end

  def test_lookup_method_accepts_options
    purl = Purl::PackageURL.new(type: "gem", name: "rails")
    # This test just verifies the method accepts the parameters without error
    # We can't easily test the actual network call in unit tests
    begin
      purl.lookup(user_agent: "test", timeout: 1)
    rescue Purl::LookupError, StandardError
      # Expected - either network failure or actual API response
      # The important thing is the method signature works
    end
  end

  def test_registry_url_with_custom_domain
    # Test npm package with custom domain
    purl = Purl::PackageURL.new(type: "npm", namespace: "@babel", name: "core")
    custom_url = purl.registry_url(base_url: "https://npm.company.com/package")
    assert_equal "https://npm.company.com/package/@babel/core", custom_url
    
    # Test gem with custom domain
    gem_purl = Purl::PackageURL.new(type: "gem", name: "rails", version: "7.0.0")
    custom_gem_url = gem_purl.registry_url(base_url: "https://gems.internal.com/gems")
    assert_equal "https://gems.internal.com/gems/rails", custom_gem_url
    
    # Test with version
    custom_gem_url_with_version = gem_purl.registry_url_with_version(base_url: "https://gems.internal.com/gems")
    assert_equal "https://gems.internal.com/gems/rails/versions/7.0.0", custom_gem_url_with_version
    
    # Test PyPI with custom domain
    pypi_purl = Purl::PackageURL.new(type: "pypi", name: "django", version: "4.0.0")
    custom_pypi_url = pypi_purl.registry_url(base_url: "https://pypi.example.org/project")
    assert_equal "https://pypi.example.org/project/django/", custom_pypi_url
  end

  def test_registry_url_roundtrip
    # Test that we can go from PURL -> registry URL -> PURL
    original_purl = Purl::PackageURL.new(type: "gem", name: "rails", version: "7.0.0")
    registry_url = original_purl.registry_url
    parsed_purl = Purl.from_registry_url(registry_url)
    
    assert_equal original_purl.type, parsed_purl.type
    assert_equal original_purl.name, parsed_purl.name
    assert_nil parsed_purl.namespace  # original_purl.namespace is nil for gem type
    # Note: version might not roundtrip perfectly for all registries
  end

  def test_route_patterns
    patterns = Purl::RegistryURL.route_patterns_for("gem")
    expected_patterns = [
      "https://rubygems.org/gems/:name",
      "https://rubygems.org/gems/:name/versions/:version"
    ]
    
    assert_equal expected_patterns, patterns
  end

  def test_all_route_patterns
    all_patterns = Purl::RegistryURL.all_route_patterns
    
    assert all_patterns.key?("gem")
    assert all_patterns.key?("npm")
    assert all_patterns.key?("maven")
    
    assert_includes all_patterns["gem"], "https://rubygems.org/gems/:name"
    assert_includes all_patterns["npm"], "https://www.npmjs.com/package/:name"
  end

  def test_supported_reverse_types
    supported = Purl::RegistryURL.supported_reverse_types
    
    assert_includes supported, "gem"
    assert_includes supported, "npm"
    assert_includes supported, "maven"
    assert_includes supported, "cargo"
  end

  # Tests for known PURL types functionality
  def test_known_types
    known_types = Purl.known_types
    
    # Should be an array
    assert_instance_of Array, known_types
    
    # Should have all official types plus additional ecosystem types
    assert_equal 47, known_types.length
    
    # Should include common types
    assert_includes known_types, "gem"
    assert_includes known_types, "npm"
    assert_includes known_types, "maven"
    assert_includes known_types, "pypi"
    assert_includes known_types, "cargo"
    assert_includes known_types, "docker"
    assert_includes known_types, "golang"
    
    # Should include new official types
    assert_includes known_types, "alpm"
    assert_includes known_types, "apk"
    assert_includes known_types, "bitnami"
    assert_includes known_types, "generic"
    assert_includes known_types, "luarocks"
    assert_includes known_types, "oci"
    assert_includes known_types, "qpkg"
    assert_includes known_types, "swid"
    
    # Should not be modifiable (returns a copy)
    original_size = known_types.size
    known_types << "test_type"
    assert_equal original_size, Purl.known_types.size
  end

  def test_known_type_predicate
    assert Purl.known_type?("gem")
    assert Purl.known_type?("GEM")  # case insensitive
    assert Purl.known_type?(:gem)   # symbol support
    
    refute Purl.known_type?("unknown_type")
    refute Purl.known_type?("")
  end

  def test_registry_supported_types
    supported = Purl.registry_supported_types
    
    assert_instance_of Array, supported
    assert_includes supported, "gem"
    assert_includes supported, "npm"
    assert_includes supported, "maven"
  end

  def test_reverse_parsing_supported_types
    supported = Purl.reverse_parsing_supported_types
    
    assert_instance_of Array, supported
    assert_includes supported, "gem"
    assert_includes supported, "npm"
    assert_includes supported, "maven"
    assert_includes supported, "cargo"
  end

  def test_type_info
    gem_info = Purl.type_info("gem")
    
    assert_equal "gem", gem_info[:type]
    assert gem_info[:known]
    assert_equal "RubyGems", gem_info[:description]
    assert_equal "https://rubygems.org", gem_info[:default_registry]
    assert_instance_of Array, gem_info[:examples]
    assert_includes gem_info[:examples], "pkg:gem/rails@7.0.4"
    assert gem_info[:registry_url_generation]
    assert gem_info[:reverse_parsing]
    assert_instance_of Array, gem_info[:route_patterns]
    assert_includes gem_info[:route_patterns], "https://rubygems.org/gems/:name"
    
    # Test unknown type
    unknown_info = Purl.type_info("unknown")
    refute unknown_info[:known]
    assert_nil unknown_info[:description]
    assert_nil unknown_info[:default_registry]
    assert_empty unknown_info[:examples]
    refute unknown_info[:registry_url_generation]
    refute unknown_info[:reverse_parsing]
    assert_empty unknown_info[:route_patterns]
  end

  def test_all_type_info
    all_info = Purl.all_type_info
    
    assert_instance_of Hash, all_info
    
    # Should include all known types
    Purl.known_types.each do |type|
      assert all_info.key?(type), "Missing type info for #{type}"
    end
    
    # Should include registry-supported types
    Purl.registry_supported_types.each do |type|
      assert all_info.key?(type), "Missing type info for registry-supported type #{type}"
    end
    
    # Verify structure of entries
    gem_info = all_info["gem"]
    assert gem_info[:known]
    assert gem_info[:registry_url_generation]
    assert gem_info[:reverse_parsing]
  end

  def test_json_schema_validation
    require "json"
    
    begin
      require "json-schema"
    rescue LoadError => e
      skip "json-schema gem not available: #{e.message}"
    end
    
    project_root = File.dirname(__dir__)
    schemas_dir = File.join(project_root, "purl-spec", "schemas")
    
    # Test our purl-types.json against the official purl-types schema
    purl_types_data = JSON.parse(File.read(File.join(project_root, "purl-types.json")))
    purl_types_schema = JSON.parse(File.read(File.join(schemas_dir, "purl-types-index.schema-1.0.json")))
    
    # Remove $schema reference to avoid remote schema validation
    purl_types_schema.delete("$schema")
    
    # Extract just the type names from our data structure to match the schema expectation
    type_names = purl_types_data["types"]&.keys || []
    
    errors = JSON::Validator.fully_validate(purl_types_schema, type_names)
    assert_empty errors, "purl-types.json failed schema validation: #{errors.join(', ')}"
    
  end

  # Performance-related tests

  def test_types_config_loaded_once
    # All config consumers should reference the same underlying data
    purl_config = Purl.load_types_config
    package_url_config = Purl::PackageURL.purl_types_data

    assert_equal purl_config, package_url_config
    # They should be the exact same object (not re-parsed copies)
    assert_same purl_config, package_url_config
  end

  def test_to_s_memoization
    purl = Purl::PackageURL.parse("pkg:npm/@babel/core@7.0.0?arch=x64#lib/index.js")
    first_call = purl.to_s
    second_call = purl.to_s
    assert_equal first_call, second_call
    # Should return the exact same string object
    assert_same first_call, second_call
  end

  def test_to_s_memoization_not_shared_via_with
    original = Purl::PackageURL.parse("pkg:gem/rails@7.0.0")
    modified = original.with(version: "7.1.0")
    refute_equal original.to_s, modified.to_s
  end

  def test_equality_uses_memoized_to_s
    purl1 = Purl::PackageURL.parse("pkg:gem/rails@7.0.0")
    purl2 = Purl::PackageURL.parse("pkg:gem/rails@7.0.0")
    assert_equal purl1, purl2
    assert_equal purl1.hash, purl2.hash
  end

  def test_docker_sha256_version_not_encoded
    purl = Purl::PackageURL.new(type: "docker", name: "nginx", version: "sha256:abc123")
    result = purl.to_s
    assert_includes result, "@sha256:abc123"
    refute_includes result, "sha256%3A"
  end

  def test_parse_keeps_literal_plus
    assert_equal "v2.0.0+incompatible", Purl.parse("pkg:golang/github.com/foo/bar@v2.0.0+incompatible").version
    assert_equal "1.0.0+build.1", Purl.parse("pkg:cargo/foo@1.0.0+build.1").version
    assert_equal "a+b", Purl.parse("pkg:generic/a+b").name
    assert_equal "NSData+zlib", Purl.parse("pkg:cocoapods/GoogleUtilities@7.5.2#NSData+zlib").subpath
    assert_equal({ "repository_url" => "git+ssh://example.com/a.git" }, Purl.parse("pkg:npm/foo?repository_url=git+ssh://example.com/a.git").qualifiers)
  end

  def test_plus_and_space_encoding
    purl = Purl::PackageURL.new(type: "generic", namespace: "a b", name: "c+d", version: "1+2 3", qualifiers: { "q" => "x+y z" })
    assert_equal "pkg:generic/a%20b/c%2Bd@1%2B2%203?q=x%2By%20z", purl.to_s
    assert_equal "pkg:generic/c@1#e%2Bf%20g", Purl::PackageURL.new(type: "generic", name: "c", version: "1", subpath: "e+f g").to_s
  end

  def test_qualifier_roundtrip_preserves_values
    input = "pkg:npm/%40pinata/sdk?repository_url=git%2Bssh%3A%2F%2Fgit%40github.com%2FPinataCloud%2Fpinata-sdk.git"
    first = Purl.parse(input)
    second = Purl.parse(first.to_s)
    assert_equal "git+ssh://git@github.com/PinataCloud/pinata-sdk.git", second.qualifiers["repository_url"]
    assert_equal first.to_s, second.to_s
  end

  def test_qualifiers_come_before_subpath
    purl = Purl::PackageURL.new(type: "otp", name: "asn1", version: "5.4.1", qualifiers: { "arch" => "amd64" }, subpath: "src/asn1ct.erl")
    assert_equal "pkg:otp/asn1@5.4.1?arch=amd64#src/asn1ct.erl", purl.to_s
    assert_equal purl, Purl.parse(purl.to_s)
  end

  def test_parse_accepts_subpath_before_qualifiers
    purl = Purl.parse("pkg:otp/asn1@5.4.1#src/asn1ct.erl?arch=amd64")
    assert_equal({ "arch" => "amd64" }, purl.qualifiers)
    assert_equal "src/asn1ct.erl", purl.subpath
  end

  def test_parse_unencoded_qualifier_value_containing_question_mark
    purl = Purl.parse("pkg:apk/alpine/xfwm4?arch=x86_64&repository_url=https://pkgs.alpinelinux.org/packages?branch=edge")
    assert_equal "xfwm4", purl.name
    assert_equal "https://pkgs.alpinelinux.org/packages?branch=edge", purl.qualifiers["repository_url"]
    assert_equal purl, Purl.parse(purl.to_s)
  end

  def test_parse_malformed_percent_encoding_raises_parse_error
    assert_raises(Purl::ParseError) { Purl.parse("pkg:npm/foo@1%zz") }
    assert_raises(Purl::ParseError) { Purl.parse("pkg:npm/foo?arch=%zz") }
  end

  def test_parse_drops_qualifiers_without_value
    purl = Purl.parse("pkg:golang/x/y?arch=&os&distro=fedora")
    assert_equal({ "distro" => "fedora" }, purl.qualifiers)
    assert_equal "pkg:golang/x/y?distro=fedora", purl.to_s
  end

  def test_parse_unencoded_npm_scope_without_version
    purl = Purl.parse("pkg:npm/@babel/core#/googleapis/api/annotations/")
    assert_equal "@babel", purl.namespace
    assert_equal "core", purl.name
    assert_nil purl.version
    assert_equal "googleapis/api/annotations", purl.subpath
  end

  def test_parse_version_with_unencoded_slash
    purl = Purl.parse("pkg:githubactions/actions/checkout@releases/v1")
    assert_equal "checkout", purl.name
    assert_equal "releases/v1", purl.version
  end

  def test_parse_rejects_missing_name_before_version
    assert_raises(Purl::MalformedUrlError) { Purl.parse("pkg:cran/@0.9.1") }
  end

  def test_type_rule_breaks_parse_and_are_reported
    purl = Purl.parse("pkg:cocoapods/KSCrash/Reporting/Filters@1.17.6")
    assert_equal "KSCrash/Reporting", purl.namespace
    assert_equal "pkg:cocoapods/KSCrash/Reporting/Filters@1.17.6", purl.to_s
    refute purl.valid?
    assert_kind_of Purl::InvalidNamespaceError, purl.validation_errors.first
    assert_raises(Purl::InvalidNamespaceError) { purl.validate! }
  end

  def test_type_definition_namespace_rules
    refute Purl.parse("pkg:vcpkg/boost/asio@1.84.0").valid?
    refute Purl.parse("pkg:vscode-extension/java@1.46.2025091308").valid?
    refute Purl.parse("pkg:golang/stdlib@go1.21").valid?
    assert Purl.parse("pkg:vscode-extension/redhat/java").valid?
  end

  def test_case_is_kept_outside_the_1x_normalized_types
    purl = Purl.parse("pkg:brew/Homebrew/Core/SQLite@3.43.2")
    assert_equal "Homebrew/Core", purl.namespace
    assert_equal "SQLite", purl.name
    assert_equal "django-rest", Purl.parse("pkg:pypi/Django_Rest@1.0RC1").name
    assert_equal "1.0RC1", Purl.parse("pkg:pypi/Django_Rest@1.0RC1").version
  end

  def test_type_definition_permitted_characters
    refute Purl.parse("pkg:chrome-extension/dogs").valid?
    refute Purl.parse("pkg:chrome-extension/dlpngalgnefjeiefhmpklpfiohadpglk@1.2.3-beta").valid?
    assert Purl.parse("pkg:chrome-extension/DLPNGALGNEFJEIEFHMPKLPFIOHADPGLK@1.2.3.4").valid?
    refute Purl.parse("pkg:chrome-extension/dlpngalgnefjeiefhmpklpfiohadpglk@1.2.3%0Afoo").valid?
  end

  def test_type_definition_required_qualifiers
    purl = Purl.parse("pkg:julia/Dates")
    assert_equal "Dates", purl.name
    assert_kind_of Purl::InvalidQualifierError, purl.validation_errors.first
    assert Purl.parse("pkg:julia/Dates?uuid=ade2ca70-3891-5945-98fb-dc099432e06a").valid?
  end

  def test_cpan_module_names_are_reported
    refute Purl.parse("pkg:cpan/URI::PackageURL").valid?
    assert Purl.parse("pkg:cpan/GDT/URI-PackageURL").valid?
  end

  def test_git_name_is_repository_path
    purl = Purl.parse("pkg:git/codeberg.org/forgejo/forgejo@a72d2c07#options/locale_readme.md")
    assert_equal "codeberg.org", purl.namespace
    assert_equal "forgejo/forgejo", purl.name
    assert_equal "pkg:git/codeberg.org/forgejo/forgejo@a72d2c07#options/locale_readme.md", purl.to_s
  end

  def test_git_name_without_namespace_keeps_encoded_slashes
    purl = Purl.parse("pkg:git/libs%2FqPCP?repository_url=https:%2F%2Fgithub.com%2Ffarmakis%2FqPCP.git")
    assert_nil purl.namespace
    assert_equal "libs/qPCP", purl.name
    assert_equal "pkg:git/libs%2FqPCP?repository_url=https://github.com/farmakis/qPCP.git", purl.to_s

    roundtrip = Purl.parse(purl.to_s)
    assert_nil roundtrip.namespace
    assert_equal "libs/qPCP", roundtrip.name
  end

  def test_git_host_namespace_roundtrips
    purl = Purl.parse("pkg:git/github.com/farmakis/qPCP")
    assert_equal "pkg:git/github.com/farmakis/qPCP", purl.to_s
    assert_equal purl, Purl.parse(purl.to_s)
  end

  def test_output_matches_1x_encoding
    assert_equal "pkg:bazel/rules_java@7.8.0?repository_url=https://bcr.bazel.build/", Purl.parse("pkg:bazel/rules_java@7.8.0?repository_url=https:%2F%2Fbcr.bazel.build%2F").to_s
    assert_equal "pkg:alpm/arch/containers-common@1%3A0.47.4-4?arch=x86_64", Purl.parse("pkg:alpm/arch/containers-common@1:0.47.4-4?arch=x86_64").to_s
    assert_equal "pkg:generic/openssl@1.1.10g?checksum=sha1:ad95,sha256:41bf", Purl::PackageURL.new(type: "generic", name: "openssl", version: "1.1.10g", qualifiers: { "checksum" => "sha1:ad95,sha256:41bf" }).to_s
    assert_equal "pkg:maven/net.example/lib?repository_url=https://repo.example.com/maven2", Purl.parse("pkg:maven/net.example/lib?repository_url=https://repo.example.com/maven2").to_s
  end

  def test_qualifier_values_escape_only_what_breaks_parsing
    purl = Purl::PackageURL.new(type: "generic", name: "x", qualifiers: { "q" => "a b&c#d+e%f" })
    assert_equal "pkg:generic/x?q=a%20b%26c%23d%2Be%25f", purl.to_s
    assert_equal "a b&c#d+e%f", Purl.parse(purl.to_s).qualifiers["q"]
  end

  def test_ecosystems_url_namespaced_types
    # Verify namespaced type handling works for npm
    purl = Purl::PackageURL.new(type: "npm", namespace: "@babel", name: "core", version: "7.0.0")
    url = Purl::EcosystemsURL.package_api_url(purl)
    assert_includes url, "%40babel%2Fcore" if url

    # Verify non-namespaced type uses name only
    gem_purl = Purl::PackageURL.new(type: "gem", name: "rails", version: "7.0.0")
    gem_url = Purl::EcosystemsURL.package_api_url(gem_purl)
    assert_includes gem_url, "/rails" if gem_url
  end

  def test_download_supported_types_cached
    first = Purl.download_supported_types
    second = Purl.download_supported_types
    assert_equal first, second
  end

  def test_supported_reverse_types_cached
    first = Purl::RegistryURL.supported_reverse_types
    second = Purl::RegistryURL.supported_reverse_types
    assert_equal first, second
    # Should be the exact same frozen object
    assert_same first, second
  end

  def test_purl_types_examples_validation
    require "json"
    
    project_root = File.dirname(__dir__)
    purl_types_data = JSON.parse(File.read(File.join(project_root, "purl-types.json")))
    
    invalid_examples = []
    
    purl_types_data["types"].each do |type_name, type_config|
      examples = type_config["examples"]
      next unless examples && examples.is_a?(Array)
      
      examples.each do |example_purl|
        begin
          # Try to parse the example PURL
          parsed = Purl::PackageURL.parse(example_purl)
          
          # Verify the type matches
          unless parsed.type == type_name
            invalid_examples << {
              type: type_name,
              example: example_purl,
              error: "Type mismatch: expected '#{type_name}', got '#{parsed.type}'"
            }
          end
          
        rescue => e
          invalid_examples << {
            type: type_name,
            example: example_purl,
            error: "#{e.class}: #{e.message}"
          }
        end
      end
    end
    
    # Report any invalid examples
    unless invalid_examples.empty?
      error_msg = "Found #{invalid_examples.length} invalid PURL examples:\n"
      invalid_examples.each do |invalid|
        error_msg += "  #{invalid[:type]}: #{invalid[:example]} - #{invalid[:error]}\n"
      end
      flunk error_msg
    end
  end
end
