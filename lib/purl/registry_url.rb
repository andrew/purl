# frozen_string_literal: true

module Purl
  class RegistryURL
    # Load registry patterns from JSON configuration
    def self.load_registry_patterns
      @registry_patterns ||= begin
        # Load JSON config directly to avoid circular dependency
        config_path = File.join(__dir__, "..", "..", "purl-types.json")
        require "json"
        config = JSON.parse(File.read(config_path))
        patterns = {}
        
        config["types"].each do |type, type_config|
          # Only process types that have registry_config
          next unless type_config["registry_config"]
          
          registry_config = type_config["registry_config"]
          patterns[type] = build_pattern_config(type, registry_config)
        end
        
        patterns
      end
    end

    def self.build_pattern_config(type, config)
      {
        base_url: config["base_url"],
        route_patterns: config["route_patterns"] || [],
        reverse_regex: config["reverse_regex"] ? Regexp.new(config["reverse_regex"]) : nil,
        pattern: build_generation_lambda(type, config),
        reverse_parser: config["reverse_regex"] ? build_reverse_parser(type, config) : nil
      }
    end

    def self.build_generation_lambda(type, config)
      case type
      when "npm"
        ->(purl) do
          if purl.namespace
            "#{config["base_url"]}/#{purl.namespace}/#{purl.name}"
          else
            "#{config["base_url"]}/#{purl.name}"
          end
        end
      when "composer", "maven", "swift"
        ->(purl) do
          if purl.namespace
            "#{config["base_url"]}/#{purl.namespace}/#{purl.name}"
          else
            raise MissingRegistryInfoError.new(
              "#{type.capitalize} packages require a namespace",
              type: purl.type,
              missing: "namespace"
            )
          end
        end
      when "golang"
        ->(purl) do
          if purl.namespace
            "#{config["base_url"]}/#{purl.namespace}/#{purl.name}"
          else
            "#{config["base_url"]}/#{purl.name}"
          end
        end
      when "pypi"
        ->(purl) { "#{config["base_url"]}/#{purl.name}/" }
      when "hackage"
        ->(purl) do
          if purl.version
            "#{config["base_url"]}/#{purl.name}-#{purl.version}"
          else
            "#{config["base_url"]}/#{purl.name}"
          end
        end
      when "deno"
        ->(purl) do
          if purl.version
            "#{config["base_url"]}/#{purl.name}@#{purl.version}"
          else
            "#{config["base_url"]}/#{purl.name}"
          end
        end
      when "clojars"
        ->(purl) do
          if purl.namespace
            "#{config["base_url"]}/#{purl.namespace}/#{purl.name}"
          else
            "#{config["base_url"]}/#{purl.name}"
          end
        end
      when "elm"
        ->(purl) do
          if purl.namespace
            version = purl.version || "latest"
            "#{config["base_url"]}/#{purl.namespace}/#{purl.name}/#{version}"
          else
            raise MissingRegistryInfoError.new(
              "Elm packages require a namespace",
              type: purl.type,
              missing: "namespace"
            )
          end
        end
      else
        ->(purl) { "#{config["base_url"]}/#{purl.name}" }
      end
    end

    def self.build_reverse_parser(type, config)
      case type
      when "npm"
        ->(match) do
          namespace = match[1] # @scope or nil
          name = match[2]
          version = match[3] # from /v/version or nil
          { type: type, namespace: namespace, name: name, version: version }
        end
      when "gem"
        ->(match) do
          name = match[1]
          version = match[2] # from /versions/version or nil
          { type: type, namespace: nil, name: name, version: version }
        end
      when "maven"
        ->(match) do
          namespace = match[1]
          name = match[2]
          version = match[3]
          { type: type, namespace: namespace, name: name, version: version }
        end
      when "pypi"
        ->(match) do
          name = match[1]
          version = match[2] unless match[2] == name # avoid duplicate name as version
          { type: type, namespace: nil, name: name, version: version }
        end
      when "cargo"
        ->(match) do
          name = match[1]
          { type: type, namespace: nil, name: name, version: nil }
        end
      when "golang"
        ->(match) do
          if match[1] && match[2]
            # Has namespace: pkg.go.dev/namespace/name
            namespace = match[1]
            name = match[2]
          else
            # No namespace: pkg.go.dev/name
            namespace = nil
            name = match[1] || match[2]
          end
          { type: type, namespace: namespace, name: name, version: nil }
        end
      when "hackage"
        ->(match) do
          name = match[1]
          version = match[2] # from name-version pattern
          { type: type, namespace: nil, name: name, version: version }
        end
      when "deno"
        ->(match) do
          name = match[1]
          version = match[2] # from @version pattern
          { type: type, namespace: nil, name: name, version: version }
        end
      when "homebrew"
        ->(match) do
          name = match[1]
          { type: type, namespace: nil, name: name, version: nil }
        end
      when "elm"
        ->(match) do
          namespace = match[1]
          name = match[2]
          version = match[3] unless match[3] == "latest"
          { type: type, namespace: namespace, name: name, version: version }
        end
      when "cocoapods"
        ->(match) do
          name = match[1]
          { type: type, namespace: nil, name: name, version: nil }
        end
      when "composer"
        ->(match) do
          namespace = match[1]
          name = match[2]
          { type: type, namespace: namespace, name: name, version: nil }
        end
      when "conda"
        ->(match) do
          name = match[1]
          { type: type, namespace: nil, name: name, version: nil }
        end
      when "cpan"
        ->(match) do
          name = match[1]
          { type: type, namespace: nil, name: name, version: nil }
        end
      when "hex"
        ->(match) do
          name = match[1]
          { type: type, namespace: nil, name: name, version: nil }
        end
      when "nuget"
        ->(match) do
          name = match[1]
          version = match[2] # from /version pattern
          { type: type, namespace: nil, name: name, version: version }
        end
      when "pub"
        ->(match) do
          name = match[1]
          { type: type, namespace: nil, name: name, version: nil }
        end
      when "swift"
        ->(match) do
          namespace = match[1]
          name = match[2]
          { type: type, namespace: namespace, name: name, version: nil }
        end
      when "bioconductor"
        ->(match) do
          name = match[1]
          { type: type, namespace: nil, name: name, version: nil }
        end
      when "clojars"
        ->(match) do
          if match[1] && match[2]
            # Has namespace: clojars.org/namespace/name
            namespace = match[1]
            name = match[2]
          else
            # No namespace: clojars.org/name
            namespace = nil
            name = match[1] || match[2]
          end
          { type: type, namespace: namespace, name: name, version: nil }
        end
      else
        ->(match) do
          { type: type, namespace: nil, name: match[1], version: nil }
        end
      end
    end

    # Registry patterns loaded from JSON configuration
    REGISTRY_PATTERNS = load_registry_patterns.freeze

    def self.generate(purl)
      new(purl).generate
    end

    def self.supported_types
      REGISTRY_PATTERNS.keys.sort
    end

    def self.supports?(type)
      REGISTRY_PATTERNS.key?(type.to_s.downcase)
    end

    def self.from_url(registry_url)
      # Try to parse the registry URL back into a PURL
      REGISTRY_PATTERNS.each do |type, config|
        next unless config[:reverse_regex] && config[:reverse_parser]
        
        match = registry_url.match(config[:reverse_regex])
        if match
          parsed_data = config[:reverse_parser].call(match)
          return PackageURL.new(
            type: parsed_data[:type],
            namespace: parsed_data[:namespace],
            name: parsed_data[:name],
            version: parsed_data[:version]
          )
        end
      end
      
      raise UnsupportedTypeError.new(
        "Unable to parse registry URL: #{registry_url}. No matching pattern found.",
        supported_types: REGISTRY_PATTERNS.keys.select { |k| REGISTRY_PATTERNS[k][:reverse_regex] }
      )
    end

    def self.supported_reverse_types
      REGISTRY_PATTERNS.select { |_, config| config[:reverse_regex] }.keys.sort
    end

    def self.route_patterns_for(type)
      pattern_config = REGISTRY_PATTERNS[type.to_s.downcase]
      return [] unless pattern_config
      
      pattern_config[:route_patterns] || []
    end

    def self.all_route_patterns
      result = {}
      REGISTRY_PATTERNS.each do |type, config|
        if config[:route_patterns]
          result[type] = config[:route_patterns]
        end
      end
      result
    end

    def initialize(purl)
      @purl = purl
    end

    def generate
      pattern_config = REGISTRY_PATTERNS[@purl.type.downcase]
      
      unless pattern_config
        raise UnsupportedTypeError.new(
          "No registry URL pattern defined for type '#{@purl.type}'. Supported types: #{self.class.supported_types.join(", ")}",
          type: @purl.type,
          supported_types: self.class.supported_types
        )
      end

      begin
        pattern_config[:pattern].call(@purl)
      rescue MissingRegistryInfoError
        raise
      rescue => e
        raise RegistryError, "Failed to generate registry URL for #{@purl.type}: #{e.message}"
      end
    end

    def generate_with_version
      base_url = generate
      
      case @purl.type.downcase
      when "npm"
        @purl.version ? "#{base_url}/v/#{@purl.version}" : base_url
      when "pypi"
        @purl.version ? "#{base_url}#{@purl.version}/" : base_url
      when "gem"
        @purl.version ? "#{base_url}/versions/#{@purl.version}" : base_url
      when "maven"
        @purl.version ? "#{base_url}/#{@purl.version}" : base_url
      when "nuget"
        @purl.version ? "#{base_url}/#{@purl.version}" : base_url
      else
        # For other types, just return the base URL since version-specific URLs vary
        base_url
      end
    end

    private

    attr_reader :purl
  end

  # Add registry URL generation methods to PackageURL
  class PackageURL
    def registry_url
      RegistryURL.generate(self)
    end

    def registry_url_with_version
      RegistryURL.new(self).generate_with_version
    end

    def supports_registry_url?
      RegistryURL.supports?(type)
    end
  end
end