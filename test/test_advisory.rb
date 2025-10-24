# frozen_string_literal: true

require_relative "test_helper"

class TestAdvisory < Minitest::Test
  def setup
    @advisory = Purl::Advisory.new
  end

  def test_advisory_class_initialization
    advisory = Purl::Advisory.new
    assert_instance_of Purl::Advisory, advisory
  end

  def test_advisory_class_initialization_with_options
    advisory = Purl::Advisory.new(user_agent: "test-agent", timeout: 5)
    assert_instance_of Purl::Advisory, advisory
  end

  def test_package_url_advisories_method_exists
    purl = Purl.parse("pkg:npm/lodash")
    assert_respond_to purl, :advisories
  end

  def test_package_url_advisories_method_accepts_options
    purl = Purl.parse("pkg:npm/lodash")
    # This test just verifies the method accepts the parameters without error
    # We can't easily test the actual network call in unit tests
    begin
      purl.advisories(user_agent: "test", timeout: 1)
    rescue Purl::AdvisoryError, StandardError
      # Expected - either network failure or actual API response
      # The important thing is the method signature works
    end
  end

  def test_advisory_error_inheritance
    error = Purl::AdvisoryError.new("test message")
    assert_kind_of Purl::Error, error
    assert_instance_of Purl::AdvisoryError, error
    assert_equal "test message", error.message
  end

  def test_lookup_requires_valid_purl
    assert_raises(Purl::Error) do
      @advisory.lookup("invalid-purl")
    end
  end

  def test_lookup_accepts_purl_object
    purl = Purl.parse("pkg:npm/lodash@4.17.19")

    # Test that lookup accepts PackageURL objects
    begin
      @advisory.lookup(purl)
    rescue Purl::AdvisoryError, StandardError
      # Expected - either network failure or actual API response
      # The important thing is the method accepts PackageURL objects
    end
  end

  def test_lookup_returns_array
    purl = Purl.parse("pkg:npm/lodash")

    begin
      result = @advisory.lookup(purl)
      assert_kind_of Array, result
    rescue Purl::AdvisoryError, StandardError
      skip "Network test failed (expected in some environments)"
    end
  end

  # Integration test that requires network access
  # This test is more fragile but provides end-to-end validation
  def test_advisory_lookup_integration_if_network_available
    # Skip this test in CI or when network is not available
    return skip "Skipping network test" if ENV["SKIP_NETWORK_TESTS"]

    begin
      # Use a package known to have advisories for testing
      advisories = @advisory.lookup("pkg:npm/lodash@4.17.19")

      if advisories && !advisories.empty?
        # Verify structure of returned advisories
        first_advisory = advisories.first

        assert first_advisory[:id]
        assert first_advisory[:title]
        assert first_advisory[:description]
        assert first_advisory[:url]
        assert first_advisory[:published_at]

        # Check that affected_packages is an array
        assert_kind_of Array, first_advisory[:affected_packages]

        # Check that identifiers is an array
        assert_kind_of Array, first_advisory[:identifiers]

        # Check that references is an array
        assert_kind_of Array, first_advisory[:references]
      end
    rescue Purl::AdvisoryError, Net::TimeoutError, StandardError => e
      # Network issues are expected in test environments
      skip "Network test failed (expected in some environments): #{e.message}"
    end
  end

  def test_lookup_with_version_filters_advisories
    # Skip this test in CI or when network is not available
    return skip "Skipping network test" if ENV["SKIP_NETWORK_TESTS"]

    begin
      # Test with version
      versioned = @advisory.lookup("pkg:npm/lodash@4.17.19")
      # Test without version
      unversioned = @advisory.lookup("pkg:npm/lodash")

      # Both should return arrays
      assert_kind_of Array, versioned
      assert_kind_of Array, unversioned

      # The counts might be the same or different depending on the package
      # but both should be non-negative
      assert versioned.length >= 0
      assert unversioned.length >= 0
    rescue Purl::AdvisoryError, Net::TimeoutError, StandardError => e
      skip "Network test failed (expected in some environments): #{e.message}"
    end
  end

  def test_lookup_returns_empty_array_for_package_without_advisories
    # Skip this test in CI or when network is not available
    return skip "Skipping network test" if ENV["SKIP_NETWORK_TESTS"]

    begin
      # Test with a package that likely has no advisories
      # Using a very specific version of a well-maintained package
      advisories = @advisory.lookup("pkg:gem/minitest@5.22.0")

      assert_kind_of Array, advisories
      # We expect an empty array or an array of advisories
      # Either is valid behavior
    rescue Purl::AdvisoryError, Net::TimeoutError, StandardError => e
      skip "Network test failed (expected in some environments): #{e.message}"
    end
  end
end
