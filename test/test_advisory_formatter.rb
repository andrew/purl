# frozen_string_literal: true

require_relative "test_helper"

class TestAdvisoryFormatter < Minitest::Test
  def setup
    @formatter = Purl::AdvisoryFormatter.new
    @sample_advisories = [
      {
        id: "test-uuid-123",
        title: "Test Security Vulnerability",
        description: "This is a test security vulnerability description that should be formatted properly in the output.",
        severity: "HIGH",
        cvss_score: 7.5,
        cvss_vector: "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:H",
        url: "https://github.com/advisories/TEST-123",
        repository_url: "https://github.com/test/package",
        published_at: "2023-01-01T12:00:00Z",
        updated_at: "2023-01-02T12:00:00Z",
        source_kind: "github",
        origin: "UNSPECIFIED",
        classification: "malicious",
        affected_packages: [
          {
            ecosystem: "npm",
            name: "test-package",
            purl: "pkg:npm/test-package",
            vulnerable_version_range: "< 1.0.0",
            first_patched_version: "1.0.0"
          }
        ],
        references: [
          "https://nvd.nist.gov/vuln/detail/CVE-2023-0001",
          "https://github.com/test/package/issues/1"
        ],
        identifiers: ["CVE-2023-0001", "GHSA-test-1234"]
      }
    ]
    @sample_purl = Purl.parse("pkg:npm/test-package@0.9.0")
  end

  def test_formatter_initialization
    formatter = Purl::AdvisoryFormatter.new
    assert_instance_of Purl::AdvisoryFormatter, formatter
  end

  def test_format_text_basic_advisory
    text_output = @formatter.format_text(@sample_advisories, @sample_purl)

    assert_includes text_output, "Security Advisories for pkg:npm/test-package@0.9.0"
    assert_includes text_output, "Advisory #1: Test Security Vulnerability"
    assert_includes text_output, "Identifiers: CVE-2023-0001, GHSA-test-1234"
    assert_includes text_output, "Severity: HIGH"
    assert_includes text_output, "CVSS Score: 7.5"
    assert_includes text_output, "Description:"
    assert_includes text_output, "This is a test security vulnerability"
    assert_includes text_output, "Affected Packages:"
    assert_includes text_output, "Package: npm/test-package"
    assert_includes text_output, "Vulnerable: < 1.0.0"
    assert_includes text_output, "Patched: 1.0.0"
    assert_includes text_output, "Source: github"
    assert_includes text_output, "Origin: UNSPECIFIED"
    assert_includes text_output, "Published: 2023-01-01T12:00:00Z"
    assert_includes text_output, "Advisory URL: https://github.com/advisories/TEST-123"
    assert_includes text_output, "Repository: https://github.com/test/package"
    assert_includes text_output, "References:"
    assert_includes text_output, "https://nvd.nist.gov/vuln/detail/CVE-2023-0001"
    assert_includes text_output, "Total advisories found: 1"
  end

  def test_format_text_handles_empty_advisories
    text_output = @formatter.format_text([], @sample_purl)
    assert_equal "No security advisories found", text_output
  end

  def test_format_text_handles_nil_advisories
    text_output = @formatter.format_text(nil, @sample_purl)
    assert_equal "No security advisories found", text_output
  end

  def test_format_text_multiple_advisories
    multiple_advisories = [
      @sample_advisories[0],
      {
        id: "test-uuid-456",
        title: "Another Vulnerability",
        description: "Another test vulnerability.",
        severity: "MODERATE",
        url: "https://github.com/advisories/TEST-456",
        published_at: "2023-02-01T12:00:00Z",
        source_kind: "osv",
        affected_packages: [],
        references: [],
        identifiers: ["CVE-2023-0002"]
      }
    ]

    text_output = @formatter.format_text(multiple_advisories, @sample_purl)

    assert_includes text_output, "Advisory #1: Test Security Vulnerability"
    assert_includes text_output, "Advisory #2: Another Vulnerability"
    assert_includes text_output, "Total advisories found: 2"
  end

  def test_format_json_basic_advisories
    json_output = @formatter.format_json(@sample_advisories, @sample_purl)

    assert_equal true, json_output[:success]
    assert_equal "pkg:npm/test-package@0.9.0", json_output[:purl]
    assert_equal 1, json_output[:count]
    assert_equal @sample_advisories, json_output[:advisories]
  end

  def test_format_json_handles_empty_advisories
    json_output = @formatter.format_json([], @sample_purl)

    assert_equal true, json_output[:success]
    assert_equal "pkg:npm/test-package@0.9.0", json_output[:purl]
    assert_equal 0, json_output[:count]
    assert_equal [], json_output[:advisories]
  end

  def test_format_text_handles_missing_optional_fields
    minimal_advisory = [
      {
        id: "minimal-id",
        title: "Minimal Advisory",
        # No description, severity, affected_packages, references
        published_at: "2023-01-01T12:00:00Z",
        url: "https://example.com/advisory",
        source_kind: "test"
      }
    ]

    text_output = @formatter.format_text(minimal_advisory, @sample_purl)

    assert_includes text_output, "Advisory #1: Minimal Advisory"
    assert_includes text_output, "Source: test"
    # Should not crash or include empty sections for missing fields
  end

  def test_format_text_without_cvss_score
    advisory_without_cvss = [
      {
        id: "test-uuid",
        title: "Test Vulnerability",
        description: "Test",
        severity: "MODERATE",
        cvss_score: 0.0,  # Zero score shouldn't be displayed
        url: "https://example.com/advisory",
        published_at: "2023-01-01T12:00:00Z",
        source_kind: "test",
        affected_packages: [],
        references: [],
        identifiers: []
      }
    ]

    text_output = @formatter.format_text(advisory_without_cvss, @sample_purl)

    assert_includes text_output, "Severity: MODERATE"
    refute_includes text_output, "CVSS Score: 0.0"
  end

  def test_format_text_withdrawn_advisory
    withdrawn_advisory = [
      {
        id: "withdrawn-id",
        title: "Withdrawn Advisory",
        description: "This advisory was withdrawn",
        severity: "LOW",
        url: "https://example.com/advisory",
        published_at: "2023-01-01T12:00:00Z",
        withdrawn_at: "2023-01-15T12:00:00Z",
        source_kind: "test",
        affected_packages: [],
        references: [],
        identifiers: []
      }
    ]

    text_output = @formatter.format_text(withdrawn_advisory, @sample_purl)

    assert_includes text_output, "Status: WITHDRAWN on 2023-01-15T12:00:00Z"
  end

  def test_format_text_with_multiple_affected_packages
    advisory_with_multiple_packages = [
      {
        id: "multi-pkg-id",
        title: "Multi-Package Vulnerability",
        description: "Affects multiple packages",
        severity: "HIGH",
        url: "https://example.com/advisory",
        published_at: "2023-01-01T12:00:00Z",
        source_kind: "test",
        affected_packages: [
          {
            ecosystem: "npm",
            name: "package-one",
            purl: "pkg:npm/package-one",
            vulnerable_version_range: "< 1.0.0",
            first_patched_version: "1.0.0"
          },
          {
            ecosystem: "npm",
            name: "package-two",
            purl: "pkg:npm/package-two",
            vulnerable_version_range: "< 2.0.0",
            first_patched_version: "2.0.0"
          }
        ],
        references: [],
        identifiers: []
      }
    ]

    text_output = @formatter.format_text(advisory_with_multiple_packages, @sample_purl)

    assert_includes text_output, "Package: npm/package-one"
    assert_includes text_output, "Package: npm/package-two"
  end
end
