# frozen_string_literal: true

require_relative "test_helper"

class TestLookupFormatter < Minitest::Test
  def setup
    @formatter = Purl::LookupFormatter.new
    @sample_package_info = {
      package: {
        name: "test-package",
        ecosystem: "gem",
        description: "A test package for demonstration",
        keywords: ["test", "demo"],
        latest_version: "1.0.0",
        latest_version_published_at: "2023-01-01T12:00:00Z",
        versions_count: 5,
        homepage: "https://example.com",
        repository_url: "https://github.com/user/test-package",
        registry_url: "https://rubygems.org/gems/test-package",
        documentation_url: "https://rubydoc.info/gems/test-package",
        licenses: "MIT",
        install_command: "gem install test-package",
        maintainers: [
          { login: "testuser", name: "Test User", url: "https://github.com/testuser" }
        ]
      }
    }
    @sample_purl = Purl.parse("pkg:gem/test-package@1.0.0")
  end

  def test_formatter_initialization
    formatter = Purl::LookupFormatter.new
    assert_instance_of Purl::LookupFormatter, formatter
  end

  def test_format_text_basic_package
    text_output = @formatter.format_text(@sample_package_info, @sample_purl)
    
    assert_includes text_output, "Package: test-package (gem)"
    assert_includes text_output, "A test package for demonstration"
    assert_includes text_output, "Keywords: test, demo"
    assert_includes text_output, "Version Information:"
    assert_includes text_output, "Latest: 1.0.0"
    assert_includes text_output, "Total versions: 5"
    assert_includes text_output, "Links:"
    assert_includes text_output, "Homepage: https://example.com"
    assert_includes text_output, "Package Info:"
    assert_includes text_output, "License: MIT"
    assert_includes text_output, "Maintainers:"
    assert_includes text_output, "Test User (testuser)"
  end

  def test_format_text_with_version_info
    package_info_with_version = @sample_package_info.dup
    package_info_with_version[:version] = {
      number: "1.0.0",
      published_at: "2023-01-01T12:00:00Z",
      published_by: "Test Publisher",
      downloads: 1000,
      size: 5000,
      yanked: false,
      registry_url: "https://rubygems.org/gems/test-package/versions/1.0.0"
    }

    text_output = @formatter.format_text(package_info_with_version, @sample_purl)
    
    assert_includes text_output, "Specific Version (1.0.0):"
    assert_includes text_output, "Published: 2023-01-01T12:00:00Z"
    assert_includes text_output, "Published by: Test Publisher"
    assert_includes text_output, "Downloads: 1,000"
    assert_includes text_output, "Size: 5,000 bytes"
    assert_includes text_output, "Yanked: No"
  end

  def test_format_text_handles_nil_result
    text_output = @formatter.format_text(nil, @sample_purl)
    assert_equal "Package not found", text_output
  end

  def test_format_json_basic_package
    json_output = @formatter.format_json(@sample_package_info, @sample_purl)
    
    assert_equal true, json_output[:success]
    assert_equal "pkg:gem/test-package@1.0.0", json_output[:purl]
    assert_equal @sample_package_info[:package], json_output[:package]
    refute json_output.key?(:version)
  end

  def test_format_json_with_version_info
    package_info_with_version = @sample_package_info.dup
    version_info = { number: "1.0.0", published_at: "2023-01-01T12:00:00Z" }
    package_info_with_version[:version] = version_info

    json_output = @formatter.format_json(package_info_with_version, @sample_purl)
    
    assert_equal true, json_output[:success]
    assert_equal version_info, json_output[:version]
  end

  def test_format_json_handles_nil_result
    json_output = @formatter.format_json(nil, @sample_purl)
    
    assert_equal false, json_output[:success]
    assert_equal "pkg:gem/test-package@1.0.0", json_output[:purl]
    assert_includes json_output[:error], "Package not found"
  end

  def test_number_formatting_private_method
    formatter = Purl::LookupFormatter.new
    
    # Test the private method through formatted output
    package_info_with_large_numbers = @sample_package_info.dup
    package_info_with_large_numbers[:version] = {
      downloads: 1234567,
      size: 999999
    }

    text_output = formatter.format_text(package_info_with_large_numbers, @sample_purl)
    
    assert_includes text_output, "Downloads: 1,234,567"
    assert_includes text_output, "Size: 999,999 bytes"
  end

  def test_handles_missing_optional_fields
    minimal_package_info = {
      package: {
        name: "minimal-package",
        ecosystem: "gem"
        # No description, keywords, maintainers, etc.
      }
    }

    text_output = @formatter.format_text(minimal_package_info, @sample_purl)
    
    assert_includes text_output, "Package: minimal-package (gem)"
    assert_includes text_output, "Version Information:"
    assert_includes text_output, "Links:"
    # Should not crash or include empty sections
    refute_includes text_output, "Keywords:"
    refute_includes text_output, "Maintainers:"
  end
end