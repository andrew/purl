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
    purl = Purl::PackageURL.new(type: "maven", name: "junit")
    assert_raises(Purl::MissingRegistryInfoError) do
      purl.registry_url
    end
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

  def test_from_registry_url_unsupported
    registry_url = "https://unknown-registry.com/package/test"
    
    assert_raises(Purl::UnsupportedTypeError) do
      Purl.from_registry_url(registry_url)
    end
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
    assert_equal 37, known_types.length
    
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
    assert gem_info[:registry_url_generation]
    assert gem_info[:reverse_parsing]
    assert_instance_of Array, gem_info[:route_patterns]
    assert_includes gem_info[:route_patterns], "https://rubygems.org/gems/:name"
    
    # Test unknown type
    unknown_info = Purl.type_info("unknown")
    refute unknown_info[:known]
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
end
