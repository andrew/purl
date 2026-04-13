# frozen_string_literal: true

require_relative "test_helper"

# Tests for security hardening in network code.
# These exercise internal methods directly to avoid hitting the real network.
class TestSecurity < Minitest::Test
  def setup
    @lookup = Purl::Lookup.new
    @advisory = Purl::Advisory.new
  end

  # SSRF: make_request must refuse hosts outside the allowlist.
  # Without this guard, a malicious versions_url in an API response can pivot
  # the client to cloud metadata endpoints, localhost admin ports, etc.

  def test_lookup_refuses_cloud_metadata_endpoint
    uri = URI("http://169.254.169.254/latest/meta-data/")
    err = assert_raises(Purl::LookupError) { @lookup.send(:make_request, uri) }
    assert_match(/disallowed host/i, err.message)
  end

  def test_lookup_refuses_localhost
    uri = URI("http://localhost:8080/admin")
    err = assert_raises(Purl::LookupError) { @lookup.send(:make_request, uri) }
    assert_match(/disallowed host/i, err.message)
  end

  def test_lookup_refuses_arbitrary_external_host
    uri = URI("https://evil.example.com/exfil")
    err = assert_raises(Purl::LookupError) { @lookup.send(:make_request, uri) }
    assert_match(/disallowed host/i, err.message)
  end

  def test_lookup_refuses_plaintext_to_allowed_host
    # Even the right host must be reached over https
    uri = URI("http://packages.ecosyste.ms/api/v1/packages/lookup")
    err = assert_raises(Purl::LookupError) { @lookup.send(:make_request, uri) }
    assert_match(/disallowed/i, err.message)
  end

  def test_lookup_allowed_hosts_constant_defined
    assert Purl::Lookup.const_defined?(:ALLOWED_HOSTS)
    hosts = Purl::Lookup::ALLOWED_HOSTS
    assert_includes hosts, "packages.ecosyste.ms"
    assert_includes hosts, "repos.ecosyste.ms"
    assert hosts.frozen?
  end

  def test_advisory_refuses_arbitrary_host
    uri = URI("https://evil.example.com/advisories")
    err = assert_raises(Purl::AdvisoryError) { @advisory.send(:make_request, uri) }
    assert_match(/disallowed host/i, err.message)
  end

  def test_advisory_refuses_plaintext_to_allowed_host
    uri = URI("http://advisories.ecosyste.ms/api/v1/advisories/lookup")
    err = assert_raises(Purl::AdvisoryError) { @advisory.send(:make_request, uri) }
    assert_match(/disallowed/i, err.message)
  end

  def test_advisory_allowed_hosts_constant_defined
    assert Purl::Advisory.const_defined?(:ALLOWED_HOSTS)
    hosts = Purl::Advisory::ALLOWED_HOSTS
    assert_includes hosts, "advisories.ecosyste.ms"
    assert hosts.frozen?
  end

  # SSRF via fetch_version_info: this is the actual attack surface.
  # versions_url comes from JSON response body and gets fetched blindly.
  # The host guard in make_request must catch it; fetch_version_info swallows
  # the error and returns nil rather than propagating attacker-chosen content.

  def test_fetch_version_info_with_malicious_url_returns_nil
    result = @lookup.send(:fetch_version_info, "http://169.254.169.254/latest", "1.0.0")
    assert_nil result
  end

  def test_fetch_version_info_with_attacker_host_returns_nil
    result = @lookup.send(:fetch_version_info, "https://attacker.test/steal", "1.0.0")
    assert_nil result
  end

  # Connection cache scheme confusion: an http URL on port 443 must not share
  # a cache slot with an https URL to the same host. Otherwise a single SSRF
  # response can poison the connection pool and downgrade later requests.

  def test_connection_key_distinguishes_scheme
    http_uri = URI("http://packages.ecosyste.ms:443/path")
    https_uri = URI("https://packages.ecosyste.ms/path")

    # Both resolve to host=packages.ecosyste.ms port=443 but must key differently
    assert_equal 443, http_uri.port
    assert_equal 443, https_uri.port

    http_key = @lookup.send(:connection_key, http_uri)
    https_key = @lookup.send(:connection_key, https_uri)

    refute_equal http_key, https_key,
      "http and https on the same host:port must use distinct connection cache keys"
  end

  # Response size limits

  def test_lookup_max_response_bytes_constant_defined
    assert Purl::Lookup.const_defined?(:MAX_RESPONSE_BYTES)
    limit = Purl::Lookup::MAX_RESPONSE_BYTES
    assert_kind_of Integer, limit
    assert limit > 0
    assert limit <= 50 * 1024 * 1024, "limit should be reasonable, got #{limit}"
  end

  def test_advisory_max_response_bytes_constant_defined
    assert Purl::Advisory.const_defined?(:MAX_RESPONSE_BYTES)
    limit = Purl::Advisory::MAX_RESPONSE_BYTES
    assert_kind_of Integer, limit
    assert limit > 0
  end
end
