# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rdoc/task"

Minitest::TestTask.create

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "doc"
  rdoc.title = "PURL - Package URL Library"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("README.md", "lib/**/*.rb")
  rdoc.options << "--line-numbers"
  rdoc.options << "--all"
  rdoc.options << "--charset=UTF-8"
end

task default: :test

namespace :spec do
  desc "Show available PURL specification tasks"
  task :help do
    puts "🔧 PURL Specification Tasks"
    puts "=" * 30
    puts "rake spec:update      - Fetch latest test cases from official PURL spec repository"
    puts "rake spec:stats       - Show statistics about current test suite data"
    puts "rake spec:compliance  - Run all compliance tests against the official test suite"
    puts "rake spec:debug       - Show detailed info about failing test cases"
    puts "rake spec:types       - Show information about all PURL types and their support"
    puts "rake spec:verify_types - Verify our types list against the official specification"
    puts "rake spec:validate_schemas - Validate JSON files against their schemas"
    puts "rake spec:validate_examples - Validate all PURL examples in purl-types.json"
    puts "rake spec:help        - Show this help message"
    puts
    puts "Example workflow:"
    puts "  1. rake spec:update     # Get latest test cases"
    puts "  2. rake spec:stats      # Review test suite composition"
    puts "  3. rake spec:compliance # Run compliance tests"
    puts "  4. rake spec:debug      # Debug any failures"
    puts
    puts "The test suite data is stored in test-suite-data.json at the project root."
  end

  desc "Import/update official PURL specification test cases"
  task :update do
    require "net/http"
    require "uri"
    require "json"
    require "fileutils"
    
    puts "Fetching official PURL specification test cases..."
    
    # URL for the official test suite data
    url = "https://raw.githubusercontent.com/package-url/purl-spec/master/test-suite-data.json"
    test_file_path = File.join(__dir__, "test-suite-data.json")
    backup_path = "#{test_file_path}.backup"
    
    begin
      # Create backup of existing file if it exists
      if File.exist?(test_file_path)
        puts "Creating backup of existing test file..."
        FileUtils.cp(test_file_path, backup_path)
      end
      
      # Fetch the latest test data
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.code == "200"
        # Validate that we got valid JSON
        test_data = JSON.parse(response.body)
        
        # Write the new test data
        File.write(test_file_path, response.body)
        
        puts "✅ Successfully updated test suite data!"
        puts "   - Test cases: #{test_data.length}"
        puts "   - File: #{test_file_path}"
        
        # Remove backup if update was successful
        File.delete(backup_path) if File.exist?(backup_path)
        
        # Show summary of test case types
        types = test_data.group_by { |tc| tc["type"] || "unknown" }.transform_values(&:count)
        puts "\n📊 Test case distribution by package type:"
        types.sort_by { |type, _| type.to_s }.each do |type, count|
          puts "   #{type}: #{count} cases"
        end
        
        # Show invalid vs valid cases
        invalid_count = test_data.count { |tc| tc["is_invalid"] }
        valid_count = test_data.count { |tc| !tc["is_invalid"] }
        puts "\n📋 Test case categories:"
        puts "   Valid cases: #{valid_count}"
        puts "   Invalid cases: #{invalid_count}"
        
      else
        raise "HTTP request failed with status #{response.code}: #{response.message}"
      end
      
    rescue => e
      puts "❌ Failed to update test suite data: #{e.message}"
      
      # Restore backup if update failed
      if File.exist?(backup_path)
        puts "Restoring backup..."
        FileUtils.mv(backup_path, test_file_path)
      end
      
      exit 1
    end
  end
  
  desc "Show current test suite statistics"
  task :stats do
    require "json"
    
    test_file_path = File.join(__dir__, "test-suite-data.json")
    
    unless File.exist?(test_file_path)
      puts "❌ Test suite data file not found. Run 'rake spec:update' first."
      exit 1
    end
    
    begin
      test_data = JSON.parse(File.read(test_file_path))
      
      puts "📊 PURL Test Suite Statistics"
      puts "=" * 40
      puts "Total test cases: #{test_data.length}"
      puts "File location: #{test_file_path}"
      puts "File size: #{File.size(test_file_path)} bytes"
      puts "Last modified: #{File.mtime(test_file_path)}"
      
      # Distribution by package type
      puts "\n📦 Distribution by package type:"
      types = test_data.group_by { |tc| tc["type"] || "unknown" }.transform_values(&:count)
      types.sort_by { |_, count| -count }.each do |type, count|
        percentage = (count.to_f / test_data.length * 100).round(1)
        puts "   #{type.to_s.ljust(12)} #{count.to_s.rjust(3)} cases (#{percentage}%)"
      end
      
      # Valid vs invalid cases
      invalid_count = test_data.count { |tc| tc["is_invalid"] }
      valid_count = test_data.count { |tc| !tc["is_invalid"] }
      puts "\n✅ Test case validity:"
      puts "   Valid cases:   #{valid_count} (#{(valid_count.to_f / test_data.length * 100).round(1)}%)"
      puts "   Invalid cases: #{invalid_count} (#{(invalid_count.to_f / test_data.length * 100).round(1)}%)"
      
      # Cases with different components
      has_namespace = test_data.count { |tc| tc["namespace"] }
      has_version = test_data.count { |tc| tc["version"] }
      has_qualifiers = test_data.count { |tc| tc["qualifiers"] && !tc["qualifiers"].empty? }
      has_subpath = test_data.count { |tc| tc["subpath"] }
      
      puts "\n🔧 Component usage:"
      puts "   With namespace:  #{has_namespace} cases"
      puts "   With version:    #{has_version} cases"
      puts "   With qualifiers: #{has_qualifiers} cases"
      puts "   With subpath:    #{has_subpath} cases"
      
    rescue JSON::ParserError => e
      puts "❌ Failed to parse test suite data: #{e.message}"
      exit 1
    rescue => e
      puts "❌ Error reading test suite data: #{e.message}"
      exit 1
    end
  end
  
  desc "Run compliance tests against the official test suite"
  task :compliance do
    puts "Running PURL specification compliance tests..."
    system("ruby test/test_purl_spec_compliance.rb")
  end
  
  desc "Verify our PURL types against the official specification"
  task :verify_types do
    require "net/http"
    require "uri"
    require_relative "lib/purl"
    
    puts "🔍 Verifying PURL Types Against Official Specification"
    puts "=" * 60
    
    begin
      # Fetch the official PURL-TYPES.rst file
      url = "https://raw.githubusercontent.com/package-url/purl-spec/main/PURL-TYPES.rst"
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.code != "200"
        puts "❌ Failed to fetch official specification: HTTP #{response.code}"
        exit 1
      end
      
      content = response.body
      
      # Extract type names from the specification
      # Look for lines like "**alpm**" or lines that start type definitions
      official_types = []
      content.scan(/^\*\*(\w+)\*\*/) do |match|
        official_types << match[0].downcase
      end
      
      # Also look for types in different format patterns (but be more restrictive)
      content.scan(/^(\w+)\s*$/) do |match|
        type = match[0].downcase
        # Filter out common words that aren't types and document sections
        unless %w[types purl package url specification license abstract].include?(type)
          official_types << type if type.length > 2 && type != "license"
        end
      end
      
      official_types = official_types.uniq.sort
      our_types = Purl.known_types.sort
      
      puts "📊 Comparison Results:"
      puts "   Official specification: #{official_types.length} types"
      puts "   Our implementation: #{our_types.length} types"
      
      # Find missing types
      missing_from_ours = official_types - our_types
      extra_in_ours = our_types - official_types
      
      if missing_from_ours.empty? && extra_in_ours.empty?
        puts "\n✅ Perfect match! All types are synchronized."
      else
        if missing_from_ours.any?
          puts "\n❌ Types in specification but missing from our list:"
          missing_from_ours.each { |type| puts "   - #{type}" }
        end
        
        if extra_in_ours.any?
          puts "\n⚠️  Types in our list but not found in specification:"
          extra_in_ours.each { |type| puts "   + #{type}" }
        end
      end
      
      puts "\n📋 All Official Types Found:"
      official_types.each_with_index do |type, index|
        status = our_types.include?(type) ? "✓" : "✗"
        puts "   #{status} #{(index + 1).to_s.rjust(2)}. #{type}"
      end
      
    rescue => e
      puts "❌ Error verifying types: #{e.message}"
      exit 1
    end
  end

  desc "Show information about PURL types"
  task :types do
    require_relative "lib/purl"
    
    puts "🔍 PURL Type Information"
    puts "=" * 40
    
    puts "\n📋 All Known PURL Types (#{Purl.known_types.length}):"
    Purl.known_types.each_slice(4) do |slice|
      puts "   #{slice.map { |t| t.ljust(12) }.join(" ")}"
    end
    
    puts "\n🌐 Registry URL Generation Support (#{Purl.registry_supported_types.length}):"
    Purl.registry_supported_types.each_slice(4) do |slice|
      puts "   #{slice.map { |t| t.ljust(12) }.join(" ")}"
    end
    
    puts "\n🔄 Reverse Parsing Support (#{Purl.reverse_parsing_supported_types.length}):"
    Purl.reverse_parsing_supported_types.each_slice(4) do |slice|
      puts "   #{slice.map { |t| t.ljust(12) }.join(" ")}"
    end
    
    puts "\n📊 Type Support Matrix:"
    puts "   Type         Known  Registry  Reverse"
    puts "   " + "-" * 35
    
    all_types = (Purl.known_types + Purl.registry_supported_types).uniq.sort
    all_types.each do |type|
      info = Purl.type_info(type)
      known_mark = info[:known] ? "✓" : "✗"
      registry_mark = info[:registry_url_generation] ? "✓" : "✗"
      reverse_mark = info[:reverse_parsing] ? "✓" : "✗"
      
      puts "   #{type.ljust(12)} #{known_mark.center(5)} #{registry_mark.center(9)} #{reverse_mark.center(7)}"
    end
    
    puts "\n🛤  Route Patterns Examples:"
    ["gem", "npm", "maven"].each do |type|
      patterns = Purl::RegistryURL.route_patterns_for(type)
      if patterns.any?
        puts "\n   #{type.upcase}:"
        patterns.each { |pattern| puts "     #{pattern}" }
      end
    end
  end

  desc "Show failing test cases for debugging"
  task :debug do
    require "json"
    require_relative "lib/purl"
    
    test_file_path = File.join(__dir__, "test-suite-data.json")
    
    unless File.exist?(test_file_path)
      puts "❌ Test suite data file not found. Run 'rake spec:update' first."
      exit 1
    end
    
    test_data = JSON.parse(File.read(test_file_path))
    
    puts "🔍 Debugging failing test cases..."
    puts "=" * 50
    
    failed_cases = []
    
    test_data.each_with_index do |test_case, index|
      description = test_case["description"]
      purl_string = test_case["purl"]
      is_invalid = test_case["is_invalid"]
      
      begin
        if is_invalid
          begin
            Purl::PackageURL.parse(purl_string)
            failed_cases << {
              index: index + 1,
              description: description,
              purl: purl_string,
              error: "Expected parsing to fail but it succeeded",
              type: "validation"
            }
          rescue Purl::Error
            # Correctly failed - this is expected
          end
        else
          purl = Purl::PackageURL.parse(purl_string)
          
          # Check if canonical form matches expected
          expected_canonical = test_case["canonical_purl"]
          if expected_canonical && purl.to_s != expected_canonical
            failed_cases << {
              index: index + 1,
              description: description,
              purl: purl_string,
              error: "Canonical mismatch: expected '#{expected_canonical}', got '#{purl.to_s}'",
              type: "canonical"
            }
          end
          
          # Check component mismatches
          %w[type namespace name version qualifiers subpath].each do |component|
            expected = test_case[component]
            actual = purl.send(component)
            
            if expected != actual
              failed_cases << {
                index: index + 1,
                description: description,
                purl: purl_string,
                error: "#{component.capitalize} mismatch: expected #{expected.inspect}, got #{actual.inspect}",
                type: "component"
              }
              break  # Only report first mismatch per test case
            end
          end
        end
      rescue => e
        failed_cases << {
          index: index + 1,
          description: description,
          purl: purl_string,
          error: "#{e.class}: #{e.message}",
          type: "exception"
        }
      end
    end
    
    if failed_cases.empty?
      puts "🎉 All test cases are passing!"
    else
      puts "❌ Found #{failed_cases.length} failing test cases:\n"
      
      # Group by failure type
      failed_cases.group_by { |fc| fc[:type] }.each do |failure_type, cases|
        puts "#{failure_type.upcase} FAILURES (#{cases.length}):"
        puts "-" * 30
        
        cases.first(5).each do |failed_case|  # Show first 5 of each type
          puts "Case #{failed_case[:index]}: #{failed_case[:description]}"
          puts "  PURL: #{failed_case[:purl]}"
          puts "  Error: #{failed_case[:error]}"
          puts
        end
        
        if cases.length > 5
          puts "  ... and #{cases.length - 5} more #{failure_type} failures\n"
        end
      end
      
      success_rate = ((test_data.length - failed_cases.length).to_f / test_data.length * 100).round(1)
      puts "Overall success rate: #{success_rate}% (#{test_data.length - failed_cases.length}/#{test_data.length})"
    end
  end

  desc "Validate JSON files against their schemas"
  task :validate_schemas do
    require "json"
    
    begin
      require "json-schema"
    rescue LoadError => e
      puts "❌ json-schema gem not available: #{e.message}"
      puts "   Install with: gem install json-schema"
      exit 1
    end
    
    puts "🔍 Validating JSON files against schemas..."
    puts "=" * 50
    
    schemas_dir = File.join(__dir__, "schemas")
    
    validations = [
      {
        name: "PURL Types Configuration",
        data_file: "purl-types.json",
        schema_file: File.join(schemas_dir, "purl-types.schema.json")
      },
      {
        name: "Test Suite Data", 
        data_file: "test-suite-data.json",
        schema_file: File.join(schemas_dir, "test-suite-data.schema.json")
      }
    ]
    
    all_valid = true
    
    validations.each do |validation|
      puts "\n📋 Validating #{validation[:name]}..."
      
      data_path = File.join(__dir__, validation[:data_file])
      schema_path = validation[:schema_file]
      
      # Check if files exist
      unless File.exist?(data_path)
        puts "   ❌ Data file not found: #{validation[:data_file]}"
        all_valid = false
        next
      end
      
      unless File.exist?(schema_path)
        puts "   ❌ Schema file not found: #{validation[:schema_file]}"
        all_valid = false
        next
      end
      
      begin
        # Load and parse files
        data = JSON.parse(File.read(data_path))
        schema = JSON.parse(File.read(schema_path))
        
        # Validate
        errors = JSON::Validator.fully_validate(schema, data)
        
        if errors.empty?
          puts "   ✅ Valid - conforms to schema"
        else
          puts "   ❌ Invalid - found #{errors.length} error(s):"
          errors.first(5).each { |error| puts "      • #{error}" }
          if errors.length > 5
            puts "      • ... and #{errors.length - 5} more errors"
          end
          all_valid = false
        end
        
      rescue JSON::ParserError => e
        puts "   ❌ JSON parsing error: #{e.message}"
        all_valid = false
      rescue => e
        puts "   ❌ Validation error: #{e.message}"
        all_valid = false
      end
    end
    
    puts "\n" + "=" * 50
    if all_valid
      puts "🎉 All JSON files are valid according to their schemas!"
    else
      puts "❌ One or more JSON files failed schema validation"
      exit 1
    end
  end

  desc "Validate all PURL examples in purl-types.json"
  task :validate_examples do
    require "json"
    require_relative "lib/purl"
    
    puts "🔍 Validating PURL examples in purl-types.json..."
    puts "=" * 60
    
    project_root = __dir__
    purl_types_data = JSON.parse(File.read(File.join(project_root, "purl-types.json")))
    
    total_examples = 0
    invalid_examples = []
    
    purl_types_data["types"].each do |type_name, type_config|
      examples = type_config["examples"]
      next unless examples && examples.is_a?(Array)
      
      puts "\n📦 #{type_name} (#{examples.length} examples):"
      
      examples.each do |example_purl|
        total_examples += 1
        
        begin
          # Try to parse the example PURL
          parsed = Purl::PackageURL.parse(example_purl)
          
          # Verify the type matches
          if parsed.type == type_name
            puts "   ✅ #{example_purl}"
          else
            puts "   ❌ #{example_purl} - Type mismatch: expected '#{type_name}', got '#{parsed.type}'"
            invalid_examples << {
              type: type_name,
              example: example_purl,
              error: "Type mismatch: expected '#{type_name}', got '#{parsed.type}'"
            }
          end
          
        rescue => e
          puts "   ❌ #{example_purl} - #{e.class}: #{e.message}"
          invalid_examples << {
            type: type_name,
            example: example_purl,
            error: "#{e.class}: #{e.message}"
          }
        end
      end
    end
    
    puts "\n" + "=" * 60
    puts "📊 Validation Summary:"
    puts "   Total examples: #{total_examples}"
    puts "   Valid examples: #{total_examples - invalid_examples.length}"
    puts "   Invalid examples: #{invalid_examples.length}"
    
    if invalid_examples.empty?
      puts "\n🎉 All PURL examples are valid!"
    else
      puts "\n❌ Found #{invalid_examples.length} invalid examples:"
      invalid_examples.each do |invalid|
        puts "   • #{invalid[:type]}: #{invalid[:example]}"
        puts "     Error: #{invalid[:error]}"
      end
      
      puts "\n📝 These examples should be reported upstream to the PURL specification maintainers."
      exit 1
    end
  end
end
