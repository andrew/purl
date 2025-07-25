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
      # Get the default registry for this type from parent config
      type_config = load_types_config["types"][type]
      default_registry = type_config["default_registry"]
      
      # Build full URLs from templates if we have a default registry
      route_patterns = []
      if default_registry && config["path_template"]
        route_patterns << default_registry + config["path_template"]
        if config["version_path_template"]
          route_patterns << default_registry + config["version_path_template"]
        end
      end
      # Fall back to legacy route_patterns if available
      route_patterns = config["route_patterns"] if route_patterns.empty? && config["route_patterns"]
      
      # Build reverse regex from template or use legacy format
      reverse_regex = nil
      if config["reverse_regex"]
        if config["reverse_regex"].start_with?("/") && default_registry
          # Domain-agnostic pattern - combine with default registry domain
          domain_pattern = default_registry.sub(/^https?:\/\//, '').gsub('.', '\\.')
          reverse_regex = Regexp.new("^https?://#{domain_pattern}" + config["reverse_regex"])
        else
          # Legacy full pattern
          reverse_regex = Regexp.new(config["reverse_regex"])
        end
      end
      
      {
        base_url: config["base_url"] || (default_registry ? default_registry + config["path_template"]&.split('/:').first : nil),
        route_patterns: route_patterns,
        reverse_regex: reverse_regex,
        pattern: build_generation_lambda(type, config, default_registry),
        reverse_parser: reverse_regex ? build_reverse_parser(type, config) : nil
      }
    end

    # Load types config (needed for accessing default_registry)
    def self.load_types_config
      @types_config ||= begin
        config_path = File.join(__dir__, "..", "..", "purl-types.json")
        require "json"
        JSON.parse(File.read(config_path))
      end
    end

    def self.build_generation_lambda(type, config, default_registry = nil)
      # Use base_url from config, or build from default_registry + path_template
      base_url = config["base_url"] || (default_registry ? default_registry + config["path_template"]&.split('/:').first : nil)
      return nil unless base_url
      case type
      when "npm"
        ->(purl) do
          if purl.namespace
            "#{base_url}/#{purl.namespace}/#{purl.name}"
          else
            "#{base_url}/#{purl.name}"
          end
        end
      when "composer", "maven", "swift"
        ->(purl) do
          if purl.namespace
            "#{base_url}/#{purl.namespace}/#{purl.name}"
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
            "#{base_url}/#{purl.namespace}/#{purl.name}"
          else
            "#{base_url}/#{purl.name}"
          end
        end
      when "pypi"
        ->(purl) { "#{base_url}/#{purl.name}/" }
      when "hackage"
        ->(purl) do
          if purl.version
            "#{base_url}/#{purl.name}-#{purl.version}"
          else
            "#{base_url}/#{purl.name}"
          end
        end
      when "deno"
        ->(purl) do
          if purl.version
            "#{base_url}/#{purl.name}@#{purl.version}"
          else
            "#{base_url}/#{purl.name}"
          end
        end
      when "clojars"
        ->(purl) do
          if purl.namespace
            "#{base_url}/#{purl.namespace}/#{purl.name}"
          else
            "#{base_url}/#{purl.name}"
          end
        end
      when "elm"
        ->(purl) do
          if purl.namespace
            version = purl.version || "latest"
            "#{base_url}/#{purl.namespace}/#{purl.name}/#{version}"
          else
            raise MissingRegistryInfoError.new(
              "Elm packages require a namespace",
              type: purl.type,
              missing: "namespace"
            )
          end
        end
      else
        ->(purl) { "#{base_url}/#{purl.name}" }
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

    def self.generate(purl, base_url: nil)
      new(purl).generate(base_url: base_url)
    end

    def self.supported_types
      REGISTRY_PATTERNS.keys.sort
    end

    def self.supports?(type)
      REGISTRY_PATTERNS.key?(type.to_s.downcase)
    end

    def self.from_url(registry_url, type: nil)
      # If type is specified, try that specific type first with domain-agnostic parsing
      if type
        normalized_type = type.to_s.downcase
        config = REGISTRY_PATTERNS[normalized_type]
        
        if config && config[:reverse_regex] && config[:reverse_parser]
          # Create a domain-agnostic version of the regex by replacing the base domain
          original_regex = config[:reverse_regex].source
          
          # For simplified JSON patterns that start with /, create domain-agnostic regex
          domain_agnostic_regex = nil
          if original_regex.start_with?("/")
            # Domain-agnostic pattern - match any domain with this path
            domain_agnostic_regex = Regexp.new("^https?://[^/]+" + original_regex)
          else
            # Legacy full regex pattern
            if original_regex =~ /\^https?:\/\/[^\/]+(.+)$/
              path_pattern = $1
              # Create domain-agnostic regex that matches any domain with the same path structure
              domain_agnostic_regex = Regexp.new("^https?://[^/]+" + path_pattern)
            end
          end
            
          if domain_agnostic_regex
            match = registry_url.match(domain_agnostic_regex)
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
        end
        
        # If specified type didn't work, fall through to normal domain-matching logic
      end
      
      # Try to parse the registry URL back into a PURL using domain matching
      REGISTRY_PATTERNS.each do |registry_type, config|
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
      
      error_message = if type
        "Unable to parse registry URL: #{registry_url} as type '#{type}'. " +
        "URL structure doesn't match expected pattern for this type."
      else
        "Unable to parse registry URL: #{registry_url}. No matching pattern found."
      end
      
      raise UnsupportedTypeError.new(
        error_message,
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

    def generate(base_url: nil)
      pattern_config = REGISTRY_PATTERNS[@purl.type.downcase]
      
      unless pattern_config
        raise UnsupportedTypeError.new(
          "No registry URL pattern defined for type '#{@purl.type}'. Supported types: #{self.class.supported_types.join(", ")}",
          type: @purl.type,
          supported_types: self.class.supported_types
        )
      end

      begin
        if base_url
          # Use custom base URL with the same URL structure
          generate_with_custom_base_url(base_url, pattern_config)
        else
          # Use default base URL
          pattern_config[:pattern].call(@purl)
        end
      rescue MissingRegistryInfoError
        raise
      rescue => e
        raise RegistryError, "Failed to generate registry URL for #{@purl.type}: #{e.message}"
      end
    end

    def generate_with_version(base_url: nil)
      registry_url = generate(base_url: base_url)
      
      case @purl.type.downcase
      when "npm"
        @purl.version ? "#{registry_url}/v/#{@purl.version}" : registry_url
      when "pypi"
        @purl.version ? "#{registry_url}#{@purl.version}/" : registry_url
      when "gem"
        @purl.version ? "#{registry_url}/versions/#{@purl.version}" : registry_url
      when "maven"
        @purl.version ? "#{registry_url}/#{@purl.version}" : registry_url
      when "nuget"
        @purl.version ? "#{registry_url}/#{@purl.version}" : registry_url
      else
        # For other types, just return the base URL since version-specific URLs vary
        registry_url
      end
    end

    private

    def generate_with_custom_base_url(custom_base_url, pattern_config)
      
      # Replace the base URL in the pattern lambda
      case @purl.type.downcase
      when "npm"
        if @purl.namespace
          "#{custom_base_url}/#{@purl.namespace}/#{@purl.name}"
        else
          "#{custom_base_url}/#{@purl.name}"
        end
      when "composer", "maven", "swift"
        if @purl.namespace
          "#{custom_base_url}/#{@purl.namespace}/#{@purl.name}"
        else
          raise MissingRegistryInfoError.new(
            "#{@purl.type.capitalize} packages require a namespace",
            type: @purl.type,
            missing: "namespace"
          )
        end
      when "golang"
        if @purl.namespace
          "#{custom_base_url}/#{@purl.namespace}/#{@purl.name}"
        else
          "#{custom_base_url}/#{@purl.name}"
        end
      when "pypi"
        "#{custom_base_url}/#{@purl.name}/"
      when "hackage"
        if @purl.version
          "#{custom_base_url}/#{@purl.name}-#{@purl.version}"
        else
          "#{custom_base_url}/#{@purl.name}"
        end
      when "deno"
        if @purl.version
          "#{custom_base_url}/#{@purl.name}@#{@purl.version}"
        else
          "#{custom_base_url}/#{@purl.name}"
        end
      when "clojars"
        if @purl.namespace
          "#{custom_base_url}/#{@purl.namespace}/#{@purl.name}"
        else
          "#{custom_base_url}/#{@purl.name}"
        end
      when "elm"
        if @purl.namespace
          version = @purl.version || "latest"
          "#{custom_base_url}/#{@purl.namespace}/#{@purl.name}/#{version}"
        else
          raise MissingRegistryInfoError.new(
            "Elm packages require a namespace",
            type: @purl.type,
            missing: "namespace"
          )
        end
      else
        "#{custom_base_url}/#{@purl.name}"
      end
    end

    private

    attr_reader :purl
  end

  # Add registry URL generation methods to PackageURL
  class PackageURL
    def registry_url(base_url: nil)
      RegistryURL.generate(self, base_url: base_url)
    end

    def registry_url_with_version(base_url: nil)
      RegistryURL.new(self).generate_with_version(base_url: base_url)
    end

    def supports_registry_url?
      RegistryURL.supports?(type)
    end
  end
end