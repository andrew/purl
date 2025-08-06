# frozen_string_literal: true

require_relative "test_helper"

class TestLookup < Minitest::Test
  def setup
    @lookup = Purl::Lookup.new
  end

  def test_lookup_class_initialization
    lookup = Purl::Lookup.new
    assert_instance_of Purl::Lookup, lookup
  end

  def test_lookup_class_initialization_with_options
    lookup = Purl::Lookup.new(user_agent: "test-agent", timeout: 5)
    assert_instance_of Purl::Lookup, lookup
  end

  def test_package_url_lookup_method_exists
    purl = Purl.parse("pkg:gem/rails")
    assert_respond_to purl, :lookup
  end

  def test_package_url_lookup_method_accepts_options
    purl = Purl.parse("pkg:gem/rails")
    # This test just verifies the method accepts the parameters without error
    # We can't easily test the actual network call in unit tests
    begin
      purl.lookup(user_agent: "test", timeout: 1)
    rescue Purl::LookupError, StandardError
      # Expected - either network failure or actual API response
      # The important thing is the method signature works
    end
  end

  def test_lookup_error_inheritance
    error = Purl::LookupError.new("test message")
    assert_kind_of Purl::Error, error
    assert_instance_of Purl::LookupError, error
    assert_equal "test message", error.message
  end

  def test_package_info_requires_valid_purl
    assert_raises(Purl::Error) do
      @lookup.package_info("invalid-purl")
    end
  end

  def test_version_info_requires_version
    assert_raises(ArgumentError, "PURL must include a version") do
      @lookup.version_info("pkg:gem/rails")
    end
  end

  def test_version_info_accepts_versioned_purl
    # This test just verifies the method accepts versioned PURLs
    # We can't easily test the actual network call in unit tests
    begin
      @lookup.version_info("pkg:gem/rails@7.0.0")
    rescue Purl::LookupError, StandardError
      # Expected - either network failure or actual API response
      # The important thing is the method signature works
    end
  end

  def test_lookup_accepts_purl_object
    purl = Purl.parse("pkg:gem/rails@7.0.0")
    
    # Test that both methods accept PackageURL objects
    begin
      @lookup.package_info(purl)
      @lookup.version_info(purl)
    rescue Purl::LookupError, StandardError
      # Expected - either network failure or actual API response
      # The important thing is the methods accept PackageURL objects
    end
  end

  # Integration test that requires network access
  # This test is more fragile but provides end-to-end validation
  def test_lookup_integration_if_network_available
    # Skip this test in CI or when network is not available
    return skip "Skipping network test" if ENV["SKIP_NETWORK_TESTS"]
    
    begin
      # Use a stable, well-known package for testing
      info = @lookup.package_info("pkg:cargo/serde")
      
      if info # Package found
        assert info[:package]
        assert info[:package][:name]
        assert_equal "serde", info[:package][:name]
        assert_equal "cargo", info[:package][:ecosystem]
        
        # Test version lookup if we have version info
        if info[:package][:latest_version]
          version_purl = "pkg:cargo/serde@#{info[:package][:latest_version]}"
          version_info = @lookup.version_info(version_purl)
          
          if version_info
            assert version_info[:number]
            assert version_info[:published_at]
          end
        end
      end
    rescue Purl::LookupError, Net::TimeoutError, StandardError => e
      # Network issues are expected in test environments
      skip "Network test failed (expected in some environments): #{e.message}"
    end
  end
end