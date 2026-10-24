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
    puts "rake spec:update      - Update the purl-spec submodule to the latest upstream commit"
    puts "rake spec:stats       - Show statistics about the purl-spec test cases"
    puts "rake spec:compliance  - Run all compliance tests against the official test suite"
    puts "rake spec:types       - Show information about all PURL types and their support"
    puts "rake spec:verify_types - Verify our types list against the official specification"
    puts "rake spec:validate_examples - Validate all PURL examples in purl-types.json"
    puts "rake spec:help        - Show this help message"
    puts
    puts "The official test cases are read from the purl-spec submodule (purl-spec/tests)."
  end

  desc "Update the purl-spec submodule to the latest upstream commit"
  task :update do
    sh "git submodule update --init --remote purl-spec"
  end

  desc "Show statistics about the purl-spec test cases"
  task :stats do
    require "json"

    files = Dir[File.join(__dir__, "purl-spec", "tests", "**", "*.json")].sort
    abort "No purl-spec test files found; run `git submodule update --init`" if files.empty?

    cases = files.flat_map { |file| JSON.parse(File.read(file)).fetch("tests") }
    puts "purl-spec test cases: #{cases.length} in #{files.length} files"
    cases.group_by { |test_case| test_case["test_type"] }.sort.each do |test_type, list|
      puts "  #{test_type}: #{list.length}"
    end
    puts "  expected to fail: #{cases.count { |test_case| test_case["expected_failure"] }}"
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

namespace :benchmark do
  desc "Run PURL parsing benchmarks"
  task :parse do
    require "benchmark"
    require "json"
    require_relative "lib/purl"
    
    puts "🚀 PURL Parsing Benchmarks"
    puts "=" * 50
    
    # Load sample PURLs from purl-types.json
    purl_types_data = JSON.parse(File.read(File.join(__dir__, "purl-types.json")))
    sample_purls = []
    
    purl_types_data["types"].each do |type_name, type_config|
      examples = type_config["examples"]
      sample_purls.concat(examples) if examples&.is_a?(Array)
    end
    
    # Add some complex PURLs for stress testing
    complex_purls = [
      "pkg:npm/@babel/core@7.20.0?arch=x64&dev=true#lib/index.js",
      "pkg:maven/org.apache.commons/commons-lang3@3.12.0?classifier=sources",
      "pkg:composer/symfony/console@5.4.0?extra=test&dev=true#src/Application.php",
      "pkg:gem/rails@7.0.0?platform=ruby&env=production#app/controllers/application_controller.rb"
    ]
    sample_purls.concat(complex_purls)
    
    puts "📊 Sample size: #{sample_purls.length} PURLs"
    puts "📦 Package types: #{purl_types_data['types'].keys.length}"
    puts
    
    # Benchmark parsing
    puts "🔍 Parsing Performance:"
    parsing_time = Benchmark.realtime do
      sample_purls.each { |purl| Purl.parse(purl) }
    end
    
    puts "   Total time: #{(parsing_time * 1000).round(2)}ms"
    puts "   Average per PURL: #{(parsing_time * 1000 / sample_purls.length).round(3)}ms"
    puts "   PURLs per second: #{(sample_purls.length / parsing_time).round(0)}"
    puts
    
    # Benchmark creation
    puts "🔧 Object Creation Performance:"
    creation_time = Benchmark.realtime do
      1000.times do
        Purl::PackageURL.new(
          type: "gem",
          namespace: "rails",
          name: "rails",
          version: "7.0.0",
          qualifiers: {"arch" => "x64"},
          subpath: "app/models/user.rb"
        )
      end
    end
    
    puts "   1000 objects: #{(creation_time * 1000).round(2)}ms"
    puts "   Average per object: #{(creation_time * 1000 / 1000).round(3)}ms"
    puts "   Objects per second: #{(1000 / creation_time).round(0)}"
    puts
    
    # Benchmark to_s conversion
    puts "🔤 String Conversion Performance:"
    test_purl = Purl.parse("pkg:npm/@babel/core@7.20.0?arch=x64#lib/index.js")
    
    string_time = Benchmark.realtime do
      10000.times { test_purl.to_s }
    end
    
    puts "   10,000 conversions: #{(string_time * 1000).round(2)}ms"
    puts "   Average per conversion: #{(string_time * 1000 / 10000).round(4)}ms"
    puts "   Conversions per second: #{(10000 / string_time).round(0)}"
    puts
    
    # Memory usage estimation
    puts "💾 Memory Usage Estimation:"
    purl_objects = sample_purls.map { |purl| Purl.parse(purl) }
    
    # Rough estimation based on object count and typical Ruby object overhead
    estimated_memory = purl_objects.length * 200  # ~200 bytes per PURL object estimate
    puts "   #{purl_objects.length} PURL objects: ~#{estimated_memory} bytes"
    puts "   Average per object: ~200 bytes"
    puts
    
    # Test different complexity levels
    puts "🎯 Complexity Benchmarks:"
    
    complexity_tests = {
      "Simple" => "pkg:gem/rails@7.0.0",
      "With namespace" => "pkg:npm/@babel/core@7.0.0", 
      "With qualifiers" => "pkg:cargo/rand@0.7.2?arch=x86_64&os=linux",
      "With subpath" => "pkg:maven/org.springframework/spring-core@5.3.0#org/springframework/core/SpringVersion.class",
      "Full complexity" => "pkg:npm/@babel/core@7.20.0?arch=x64&dev=true&os=linux#lib/parser/index.js"
    }
    
    complexity_tests.each do |level, purl_string|
      time = Benchmark.realtime do
        1000.times { Purl.parse(purl_string) }
      end
      puts "   #{level.ljust(15)}: #{(time * 1000 / 1000).round(4)}ms per parse"
    end
    
    puts
    puts "✅ Benchmark completed!"
  end
  
  desc "Compare parsing performance across package types"
  task :types do
    require "benchmark"
    require "json"
    require_relative "lib/purl"
    
    puts "📊 Package Type Parsing Comparison"
    puts "=" * 50
    
    purl_types_data = JSON.parse(File.read(File.join(__dir__, "purl-types.json")))
    
    # Benchmark each type with its examples
    type_benchmarks = {}
    
    purl_types_data["types"].each do |type_name, type_config|
      examples = type_config["examples"]
      next unless examples&.is_a?(Array) && examples.any?
      
      time = Benchmark.realtime do
        100.times do
          examples.each { |purl| Purl.parse(purl) }
        end
      end
      
      avg_time_per_purl = time / (100 * examples.length)
      type_benchmarks[type_name] = {
        time: avg_time_per_purl,
        examples_count: examples.length
      }
    end
    
    # Sort by performance (fastest first)
    sorted_benchmarks = type_benchmarks.sort_by { |_, data| data[:time] }
    
    puts "🏆 Performance Rankings (fastest to slowest):"
    puts "   Rank Type         Avg Time/Parse  Examples"
    puts "   " + "-" * 45
    
    sorted_benchmarks.each_with_index do |(type, data), index|
      rank = (index + 1).to_s.rjust(2)
      time_str = "#{(data[:time] * 1000).round(4)}ms".rjust(10)
      examples_str = data[:examples_count].to_s.rjust(8)
      
      puts "   #{rank}.  #{type.ljust(12)} #{time_str}    #{examples_str}"
    end
    
    fastest = sorted_benchmarks.first
    slowest = sorted_benchmarks.last
    
    puts
    puts "📈 Performance Summary:"
    puts "   Fastest: #{fastest[0]} (#{(fastest[1][:time] * 1000).round(4)}ms)"
    puts "   Slowest: #{slowest[0]} (#{(slowest[1][:time] * 1000).round(4)}ms)"
    puts "   Ratio: #{(slowest[1][:time] / fastest[1][:time]).round(1)}x difference"
    puts
    puts "✅ Type comparison completed!"
  end
  
  desc "Benchmark registry URL generation"
  task :registry do
    require "benchmark"
    require "json"
    require_relative "lib/purl"
    
    puts "🌐 Registry URL Generation Benchmarks"
    puts "=" * 50
    
    # Get PURLs that support registry URL generation
    registry_purls = []
    Purl.registry_supported_types.each do |type|
      examples = Purl.type_examples(type)
      registry_purls.concat(examples) if examples.any?
    end
    
    puts "📊 Testing with #{registry_purls.length} registry-supported PURLs"
    puts
    
    # Parse all PURLs first
    parsed_purls = registry_purls.map { |purl| Purl.parse(purl) }
    
    # Benchmark registry URL generation
    puts "🔗 URL Generation Performance:"
    url_time = Benchmark.realtime do
      parsed_purls.each { |purl| purl.registry_url }
    end
    
    puts "   Total time: #{(url_time * 1000).round(2)}ms"
    puts "   Average per URL: #{(url_time * 1000 / parsed_purls.length).round(3)}ms"
    puts "   URLs per second: #{(parsed_purls.length / url_time).round(0)}"
    puts
    
    # Benchmark versioned URL generation
    puts "🏷️  Versioned URL Performance:"
    versioned_time = Benchmark.realtime do
      parsed_purls.each { |purl| purl.registry_url_with_version }
    end
    
    puts "   Total time: #{(versioned_time * 1000).round(2)}ms"
    puts "   Average per URL: #{(versioned_time * 1000 / parsed_purls.length).round(3)}ms"
    puts "   URLs per second: #{(parsed_purls.length / versioned_time).round(0)}"
    puts
    
    # Compare parsing vs URL generation
    parsing_time = Benchmark.realtime do
      registry_purls.each { |purl| Purl.parse(purl) }
    end
    
    puts "⚖️  Performance Comparison:"
    puts "   Parsing: #{(parsing_time * 1000 / registry_purls.length).round(3)}ms per PURL"
    puts "   URL generation: #{(url_time * 1000 / parsed_purls.length).round(3)}ms per PURL"
    puts "   Versioned URLs: #{(versioned_time * 1000 / parsed_purls.length).round(3)}ms per PURL"
    
    ratio = url_time / parsing_time
    puts "   URL gen vs parsing: #{ratio.round(2)}x #{ratio > 1 ? 'slower' : 'faster'}"
    
    puts
    puts "✅ Registry URL benchmarks completed!"
  end
  
  desc "Benchmark hot paths (to_s, equality, known_type?, type_info, supported_types)"
  task :hotpaths do
    require "benchmark"
    require_relative "lib/purl"

    iterations = 10_000

    sample_purls = [
      "pkg:gem/rails@7.0.0",
      "pkg:npm/@babel/core@7.20.0?arch=x64&dev=true#lib/index.js",
      "pkg:maven/org.apache.commons/commons-lang3@3.12.0?classifier=sources",
      "pkg:cargo/rand@0.7.2",
      "pkg:pypi/django@4.0.0",
      "pkg:docker/nginx@sha256:abc123def",
      "pkg:golang/github.com/gorilla/mux@1.8.0",
    ]

    parsed = sample_purls.map { |p| Purl.parse(p) }

    puts "Hot Path Benchmarks (#{iterations} iterations)"
    puts "=" * 50

    Benchmark.bm(28) do |x|
      x.report("to_s") do
        iterations.times { parsed.each(&:to_s) }
      end

      x.report("== (equal)") do
        pairs = parsed.map { |p| [p, Purl.parse(p.to_s)] }
        iterations.times { pairs.each { |a, b| a == b } }
      end

      x.report("hash") do
        iterations.times { parsed.each(&:hash) }
      end

      types = %w[gem npm maven cargo pypi docker golang unknown fake_type]
      x.report("known_type?") do
        iterations.times { types.each { |t| Purl.known_type?(t) } }
      end

      info_types = %w[gem npm maven cargo pypi]
      x.report("type_info") do
        1_000.times { info_types.each { |t| Purl.type_info(t) } }
      end

      x.report("all_type_info") do
        100.times { Purl.all_type_info }
      end

      x.report("download_supported_types") do
        iterations.times { Purl::DownloadURL.supported_types }
      end

      x.report("supported_reverse_types") do
        iterations.times { Purl::RegistryURL.supported_reverse_types }
      end

      x.report("registry_supported_types") do
        iterations.times { Purl::RegistryURL.supported_types }
      end

      x.report("parse (simple)") do
        iterations.times { Purl.parse("pkg:gem/rails@7.0.0") }
      end

      x.report("parse (complex)") do
        iterations.times { Purl.parse("pkg:npm/@babel/core@7.20.0?arch=x64&dev=true#lib/index.js") }
      end

      x.report("parse (namespaced)") do
        iterations.times { Purl.parse("pkg:maven/org.apache.commons/commons-lang3@3.12.0") }
      end

      x.report("from_url (domain match)") do
        1_000.times { Purl.from_registry_url("https://rubygems.org/gems/rails") }
      end

      x.report("from_url (type hint)") do
        1_000.times { Purl.from_registry_url("https://gems.internal.com/gems/rails", type: "gem") }
      end
    end
  end

  desc "Benchmark memory allocations for hot paths"
  task :memory do
    require "memory_profiler"
    require_relative "lib/purl"

    sample_purls = [
      "pkg:gem/rails@7.0.0",
      "pkg:npm/@babel/core@7.20.0?arch=x64&dev=true#lib/index.js",
      "pkg:maven/org.apache.commons/commons-lang3@3.12.0?classifier=sources",
      "pkg:cargo/rand@0.7.2",
      "pkg:pypi/django@4.0.0",
      "pkg:docker/nginx@sha256:abc123def",
      "pkg:golang/github.com/gorilla/mux@1.8.0",
    ]

    parsed = sample_purls.map { |p| Purl.parse(p) }

    benchmarks = {
      "parse (simple)" => -> { Purl.parse("pkg:gem/rails@7.0.0") },
      "parse (complex)" => -> { Purl.parse("pkg:npm/@babel/core@7.20.0?arch=x64&dev=true#lib/index.js") },
      "parse (namespaced)" => -> { Purl.parse("pkg:maven/org.apache.commons/commons-lang3@3.12.0") },
      "to_s" => -> { parsed.each(&:to_s) },
      "to_s (cold)" => -> { sample_purls.map { |p| Purl.parse(p) }.each(&:to_s) },
      "== (equal)" => -> { parsed.each_cons(2) { |a, b| a == b } },
      "known_type?" => -> { %w[gem npm maven cargo pypi].each { |t| Purl.known_type?(t) } },
      "type_info" => -> { %w[gem npm maven].each { |t| Purl.type_info(t) } },
      "supported_types" => -> { Purl::RegistryURL.supported_types },
      "supported_reverse_types" => -> { Purl::RegistryURL.supported_reverse_types },
      "download_supported_types" => -> { Purl::DownloadURL.supported_types },
      "from_url (domain match)" => -> { Purl.from_registry_url("https://rubygems.org/gems/rails") },
      "from_url (type hint)" => -> { Purl.from_registry_url("https://gems.internal.com/gems/rails", type: "gem") },
    }

    puts "Memory Allocation Benchmarks"
    puts "=" * 70
    printf "%-30s %10s %10s %10s\n", "Benchmark", "Objects", "Memsize", "Strings"
    puts "-" * 70

    benchmarks.each do |name, block|
      report = MemoryProfiler.report { 100.times { block.call } }
      printf "%-30s %10d %10d %10d\n",
        name,
        report.total_allocated,
        report.total_allocated_memsize,
        report.strings_allocated.size
    end
  end

  desc "Run all benchmarks"
  task all: [:parse, :types, :registry, :hotpaths] do
    puts
    puts "All benchmarks completed!"
    puts "   Use 'rake benchmark:parse' for parsing performance"
    puts "   Use 'rake benchmark:types' for type comparison"
    puts "   Use 'rake benchmark:registry' for URL generation"
    puts "   Use 'rake benchmark:hotpaths' for memoization and lookup paths"
    puts "   Use 'rake benchmark:memory' for memory allocations"
  end
end
