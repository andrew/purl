# frozen_string_literal: true

require "test_helper"
require "open3"
require "tempfile"

class TestCLI < Minitest::Test
  def setup
    @cli_path = File.expand_path("../exe/purl", __dir__)
  end

  def run_cli(*args)
    cmd = [@cli_path] + args
    stdout, stderr, status = Open3.capture3(*cmd)
    [stdout, stderr, status]
  end

  def test_help_command
    stdout, _stderr, status = run_cli("--help")
    assert status.success?
    assert_includes stdout, "Usage:"
    assert_includes stdout, "parse"
    assert_includes stdout, "validate"
    assert_includes stdout, "convert"
    assert_includes stdout, "generate"
    assert_includes stdout, "info"
    assert_includes stdout, "--json"
  end

  def test_version_command
    stdout, _stderr, status = run_cli("--version")
    assert status.success?
    assert_match(/\A\d+\.\d+\.\d+/, stdout.strip)
  end

  def test_parse_valid_purl
    stdout, _stderr, status = run_cli("parse", "pkg:gem/rails@7.0.0")
    assert status.success?
    assert_includes stdout, "Valid PURL: pkg:gem/rails@7.0.0"
    assert_includes stdout, "Type:       gem"
    assert_includes stdout, "Name:       rails"
    assert_includes stdout, "Version:    7.0.0"
  end

  def test_parse_complex_purl
    stdout, _stderr, status = run_cli("parse", "pkg:npm/@babel/core@7.0.0#lib/index.js")
    assert status.success?
    assert_includes stdout, "Type:       npm"
    assert_includes stdout, "Namespace:  @babel"
    assert_includes stdout, "Name:       core"
    assert_includes stdout, "Version:    7.0.0"
    assert_includes stdout, "Subpath:    lib/index.js"
  end

  def test_parse_invalid_purl
    stdout, _stderr, status = run_cli("parse", "invalid-purl")
    refute status.success?
    assert_includes stdout, "Error parsing PURL:"
  end

  def test_validate_valid_purl
    stdout, _stderr, status = run_cli("validate", "pkg:gem/rails@7.0.0")
    assert status.success?
    assert_includes stdout, "Valid PURL"
  end

  def test_validate_invalid_purl
    stdout, _stderr, status = run_cli("validate", "invalid-purl")
    refute status.success?
    assert_includes stdout, "Invalid PURL:"
  end

  def test_generate_simple_purl
    stdout, _stderr, status = run_cli("generate", "--type", "gem", "--name", "rails")
    assert status.success?
    assert_equal "pkg:gem/rails", stdout.strip
  end

  def test_generate_complex_purl
    stdout, _stderr, status = run_cli("generate", 
                                     "--type", "npm", 
                                     "--namespace", "@babel", 
                                     "--name", "core", 
                                     "--version", "7.0.0",
                                     "--qualifiers", "arch=x64,os=linux",
                                     "--subpath", "lib/index.js")
    assert status.success?
    purl = stdout.strip
    # Note: @ gets URL encoded to %40 in namespace
    assert_includes purl, "pkg:npm/%40babel/core@7.0.0"
    assert_includes purl, "arch=x64"
    assert_includes purl, "os=linux"
    assert_includes purl, "#lib/index.js"
  end

  def test_generate_missing_required_args
    stdout, _stderr, status = run_cli("generate", "--type", "gem")
    refute status.success?
    assert_includes stdout, "--type and --name are required"
  end

  def test_info_all_types
    stdout, _stderr, status = run_cli("info")
    assert status.success?
    assert_includes stdout, "Known PURL types:"
    assert_includes stdout, "Total types:"
  end

  def test_info_specific_type
    stdout, _stderr, status = run_cli("info", "gem")
    assert status.success?
    assert_includes stdout, "Type: gem"
    assert_includes stdout, "Known: Yes"
  end

  def test_unknown_command
    stdout, _stderr, status = run_cli("unknown-command")
    refute status.success?
    assert_includes stdout, "Unknown command: unknown-command"
  end

  def test_no_args
    stdout, _stderr, status = run_cli()
    refute status.success?
    assert_includes stdout, "Usage:"
  end

  def test_parse_missing_args
    stdout, _stderr, status = run_cli("parse")
    refute status.success?
    assert_includes stdout, "PURL string required"
  end

  def test_validate_missing_args
    stdout, _stderr, status = run_cli("validate")
    refute status.success?
    assert_includes stdout, "PURL string required"
  end

  def test_convert_missing_args
    stdout, _stderr, status = run_cli("convert")
    refute status.success?
    assert_includes stdout, "Registry URL required"
  end

  def test_url_supported_type
    stdout, _stderr, status = run_cli("url", "pkg:gem/rails@7.0.0")
    assert status.success?
    assert_includes stdout, "https://rubygems.org/gems/rails"
  end

  def test_url_unsupported_type
    stdout, _stderr, status = run_cli("url", "pkg:generic/example")
    refute status.success?
    assert_includes stdout, "Registry URL generation not supported for type 'generic'"
  end

  def test_url_invalid_purl
    stdout, _stderr, status = run_cli("url", "invalid-purl")
    refute status.success?
    assert_includes stdout, "Error:"
  end

  def test_url_missing_args
    stdout, _stderr, status = run_cli("url")
    refute status.success?
    assert_includes stdout, "PURL string required"
  end

  # JSON output tests
  def test_parse_json_output
    stdout, _stderr, status = run_cli("--json", "parse", "pkg:gem/rails@7.0.0")
    assert status.success?
    
    result = JSON.parse(stdout)
    assert_equal true, result["success"]
    assert_equal "pkg:gem/rails@7.0.0", result["purl"]
    assert_equal "gem", result["components"]["type"]
    assert_equal "rails", result["components"]["name"]
    assert_equal "7.0.0", result["components"]["version"]
    assert_nil result["components"]["namespace"]
  end

  def test_validate_json_output_valid
    stdout, _stderr, status = run_cli("--json", "validate", "pkg:gem/rails@7.0.0")
    assert status.success?
    
    result = JSON.parse(stdout)
    assert_equal true, result["success"]
    assert_equal true, result["valid"]
    assert_equal "pkg:gem/rails@7.0.0", result["purl"]
  end

  def test_validate_json_output_invalid
    stdout, _stderr, status = run_cli("--json", "validate", "invalid-purl")
    refute status.success?
    
    result = JSON.parse(stdout)
    assert_equal false, result["success"]
    assert_equal false, result["valid"]
    assert_includes result["error"], "PURL must start with 'pkg:'"
  end

  def test_generate_json_output
    stdout, _stderr, status = run_cli("--json", "generate", "--type", "gem", "--name", "rails", "--version", "7.0.0")
    assert status.success?
    
    result = JSON.parse(stdout)
    assert_equal true, result["success"]
    assert_equal "pkg:gem/rails@7.0.0", result["purl"]
    assert_equal "gem", result["components"]["type"] 
    assert_equal "rails", result["components"]["name"]
    assert_equal "7.0.0", result["components"]["version"]
  end

  def test_info_json_output_specific_type
    stdout, _stderr, status = run_cli("--json", "info", "gem")
    assert status.success?
    
    result = JSON.parse(stdout)
    assert_equal true, result["success"]
    assert_equal "gem", result["type"]["type"]
    assert_equal true, result["type"]["known"]
    assert_includes result["type"]["description"], "Ruby"
  end

  def test_info_json_output_all_types
    stdout, _stderr, status = run_cli("--json", "info")
    assert status.success?
    
    result = JSON.parse(stdout)
    assert_equal true, result["success"]
    assert result["types"].is_a?(Hash)
    assert result["metadata"].is_a?(Hash)
    assert result["metadata"]["total_types"] > 0
  end

  def test_error_json_output
    stdout, _stderr, status = run_cli("--json", "parse")
    refute status.success?
    
    result = JSON.parse(stdout)
    assert_equal false, result["success"]
    assert_includes result["error"], "PURL string required"
  end

  def test_url_json_output_supported
    stdout, _stderr, status = run_cli("--json", "url", "pkg:gem/rails@7.0.0")
    assert status.success?
    
    result = JSON.parse(stdout)
    assert_equal true, result["success"]
    assert_equal "pkg:gem/rails@7.0.0", result["purl"]
    assert_includes result["registry_url"], "https://rubygems.org/gems/rails"
    assert_equal "gem", result["type"]
  end

  def test_url_json_output_unsupported
    stdout, _stderr, status = run_cli("--json", "url", "pkg:generic/example")
    refute status.success?
    
    result = JSON.parse(stdout)
    assert_equal false, result["success"]
    assert_includes result["error"], "Registry URL generation not supported for type 'generic'"
  end
end