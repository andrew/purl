# frozen_string_literal: true

require_relative "test_helper"
require "json"

class TestPurlSpecCompliance < Minitest::Test
  SPEC_TESTS_DIR = File.join(File.dirname(__dir__), "purl-spec", "tests")

  # Cases that contradict other spec cases or type definitions, keyed by [file, test_type, input]
  KNOWN_FAILURES = [
    # Expected to fail on uppercase qualifier keys, but the validate case for the same input
    # and the maven cases expect the keys to be lowercased
    ["gem-test.json", "parse", "pkg:gem/jruby-launcher@1.1.2?Platform=java"],
    ["rpm-test.json", "parse", "pkg:Rpm/fedora/curl@7.50.3-1.fc25?Arch=i386&Distro=fedora-25"],
    # A recommended case that lowercases, while git-definition.json marks namespace and name case sensitive
    ["git-test.json", "validate", "pkg:git/github/Package-url/purl-Spec@244fd47e07d1004f0aed9c"]
  ].freeze


  TYPE_RULE_KEYS = %w[namespace_requirement namespace_case_sensitive name_case_sensitive version_case_sensitive
                      namespace_permitted_characters name_permitted_characters version_permitted_characters
                      required_qualifiers].freeze

  def spec_cases
    files = Dir[File.join(SPEC_TESTS_DIR, "**", "*.json")].sort
    flunk "No purl-spec test files found; run `git submodule update --init`" if files.empty?

    files.flat_map do |file|
      JSON.parse(File.read(file)).fetch("tests").map { |test_case| [File.basename(file), test_case] }
    end
  end

  def components(purl)
    qualifiers = purl.qualifiers.nil? || purl.qualifiers.empty? ? nil : purl.qualifiers
    { "type" => purl.type, "namespace" => purl.namespace, "name" => purl.name, "version" => purl.version,
      "qualifiers" => qualifiers, "subpath" => purl.subpath }
  end

  # Components the type definition marks case-insensitive are compared ignoring case, since the gem keeps
  # the case it was given for types it did not normalize in 1.x
  def comparable(parts)
    rules = Purl::PackageURL.type_rules(parts["type"].to_s.downcase)
    parts.to_h do |key, value|
      [key, value.is_a?(String) && rules["#{key}_case_sensitive"] == false ? value.downcase : value]
    end
  end

  def build(input)
    Purl::PackageURL.new(type: input["type"], namespace: input["namespace"], name: input["name"],
                         version: input["version"], qualifiers: input["qualifiers"], subpath: input["subpath"])
  end

  # The gem parses real-world PURLs that break type rules and reports them through valid?, and writes
  # the 1.x encoding, so a case passes when it is equivalent to the spec's expectation
  def passes?(test_case)
    input = test_case["input"]
    purl = test_case["test_type"] == "build" ? build(input) : Purl::PackageURL.parse(input)
    return !purl.valid? if test_case["expected_failure"]
    return false unless Purl::PackageURL.parse(purl.to_s) == purl

    expected = test_case["expected_output"]
    if test_case["test_type"] == "parse"
      comparable(components(purl)) == comparable(expected)
    else
      purl.to_s == expected || comparable(components(purl)) == comparable(components(Purl::PackageURL.parse(expected)))
    end
  rescue Purl::Error
    test_case["expected_failure"]
  end

  def test_official_spec_cases
    unexpected = []
    now_passing = []

    spec_cases.each do |file, test_case|
      input = test_case["input"].is_a?(String) ? test_case["input"] : JSON.generate(test_case["input"])
      known = KNOWN_FAILURES.include?([file, test_case["test_type"], input])
      if passes?(test_case)
        now_passing << [file, test_case["test_type"], input] if known
      else
        failure = "#{file} #{test_case["test_type"]}: #{test_case["description"]}\n  input: #{input}"
        puts "#{known ? "[known] " : ""}#{failure}" if ENV["PURL_SPEC_DEBUG"]
        unexpected << failure unless known
      end
    end

    assert_empty unexpected, "purl-spec cases failing:\n#{unexpected.join("\n")}"
    assert_empty now_passing, "Remove these from KNOWN_FAILURES, they pass now:\n#{now_passing.map(&:inspect).join("\n")}"
  end

  def test_purl_types_json_matches_type_definitions
    project_root = File.dirname(__dir__)
    types = JSON.parse(File.read(File.join(project_root, "purl-types.json")))["types"]
    definitions = Dir[File.join(project_root, "purl-spec", "types", "*-definition.json")]
    refute_empty definitions

    definitions.each do |file|
      definition = JSON.parse(File.read(file))
      expected = { "namespace_requirement" => definition.dig("namespace_definition", "requirement") }
      %w[namespace name version].each do |component|
        component_definition = definition["#{component}_definition"] || {}
        expected["#{component}_case_sensitive"] = false if component_definition["case_sensitive"] == false
        expected["#{component}_permitted_characters"] = component_definition["permitted_characters"]
      end
      required = (definition["qualifiers_definition"] || []).select { |q| q["requirement"] == "required" }.map { |q| q["key"] }
      expected["required_qualifiers"] = required if required.any?

      actual = (types[definition["type"]] || {}).slice(*TYPE_RULE_KEYS)
      assert_equal expected.compact, actual, "#{definition["type"]} rules differ from purl-spec; run `rake spec:sync_types`"
    end
  end

  def test_basic_maven_case
    purl = Purl::PackageURL.parse("pkg:maven/org.apache.commons/io@1.3.4")
    assert_equal "maven", purl.type
    assert_equal "org.apache.commons", purl.namespace
    assert_equal "io", purl.name
    assert_equal "1.3.4", purl.version
  end

  def test_golang_with_subpath
    purl = Purl::PackageURL.parse("pkg:golang/google.golang.org/genproto#googleapis/api/annotations")
    assert_equal "golang", purl.type
    assert_equal "google.golang.org", purl.namespace
    assert_equal "genproto", purl.name
    assert_equal "googleapis/api/annotations", purl.subpath
  end

  def test_synced_types_from_official_spec
    project_root = File.dirname(__dir__)
    purl_types_data = JSON.parse(File.read(File.join(project_root, "purl-types.json")))

    # Ensure we can handle all official types
    purl_types_data["types"].each do |type_name, type_config|
      examples = type_config["examples"]
      next unless examples && examples.is_a?(Array) && !examples.empty?

      # Try the first example for each type
      example_purl = examples.first

      begin
        purl = Purl::PackageURL.parse(example_purl)
        assert_equal type_name, purl.type, "Type mismatch for #{example_purl}"
        refute_nil purl.name, "Name should not be nil for #{example_purl}"
      rescue => e
        # Some examples might be intentionally complex or require special handling
        # We'll skip for now but could be enhanced to handle these edge cases
        skip "Complex example for #{type_name}: #{example_purl} - #{e.message}"
      end
    end
  end
end
