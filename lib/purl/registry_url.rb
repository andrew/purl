# frozen_string_literal: true

require "addressable/template"

module Purl
  class RegistryURL
    # Load registry patterns from JSON configuration
    def self.load_registry_patterns
      @registry_patterns ||= begin
        # Load extended registry configs
        config_path = File.join(__dir__, "..", "..", "purl-types.json")
        require "json"
        config = JSON.parse(File.read(config_path))
        patterns = {}
        
        config["types"].each do |type, type_config|
          # Only process types that have registry_config
          next unless type_config["registry_config"]
          
          registry_config = type_config["registry_config"]
          patterns[type] = build_pattern_config(type, registry_config, type_config)
        end
        
        patterns
      end
    end

    def self.build_pattern_config(type, config, type_config)
      # Get the default registry for this type from the extended config
      default_registry = type_config["default_registry"]
      
      # Route patterns are replaced by URI templates
      
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
        reverse_regex: reverse_regex,
        pattern: build_generation_lambda(type, config, default_registry),
        reverse_parser: reverse_regex ? build_reverse_parser(type, config) : nil,
        uri_template: config["uri_template"] ? Addressable::Template.new(config["uri_template"]) : nil,
        uri_template_no_namespace: config["uri_template_no_namespace"] ? Addressable::Template.new(config["uri_template_no_namespace"]) : nil,
        uri_template_with_version: config["uri_template_with_version"] ? Addressable::Template.new(config["uri_template_with_version"]) : nil,
        uri_template_with_version_no_namespace: config["uri_template_with_version_no_namespace"] ? Addressable::Template.new(config["uri_template_with_version_no_namespace"]) : nil
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
      # Use base_url from config, or build from default_registry + path_template base
      if config["base_url"]
        base_url = config["base_url"]
      elsif default_registry && config["path_template"]
        # Extract the base path from the template (everything before first :parameter)
        base_path = config["path_template"].split('/:').first
        base_url = default_registry + base_path
      else
        return nil
      end
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
      
      # Generate route patterns from URI templates
      patterns = []
      
      if pattern_config[:uri_template]
        patterns << uri_template_to_route_pattern(pattern_config[:uri_template])
      end
      
      if pattern_config[:uri_template_no_namespace]
        patterns << uri_template_to_route_pattern(pattern_config[:uri_template_no_namespace])
      end
      
      if pattern_config[:uri_template_with_version]
        patterns << uri_template_to_route_pattern(pattern_config[:uri_template_with_version])
      end
      
      if pattern_config[:uri_template_with_version_no_namespace]
        patterns << uri_template_to_route_pattern(pattern_config[:uri_template_with_version_no_namespace])
      end
      
      patterns.uniq
    end

    def self.all_route_patterns
      result = {}
      REGISTRY_PATTERNS.each do |type, config|
        patterns = route_patterns_for(type)
        result[type] = patterns unless patterns.empty?
      end
      result
    end
    
    private_class_method def self.uri_template_to_route_pattern(template)
      # Convert URI template format {variable} to route pattern format :variable
      template.pattern.gsub(/\{([^}]+)\}/, ':\1')
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
        elsif pattern_config[:uri_template]
          # Use URI template if available
          template = select_uri_template(pattern_config, include_version: false)
          generate_with_uri_template(template)
        else
          # Fall back to legacy lambda pattern
          pattern_config[:pattern].call(@purl)
        end
      rescue MissingRegistryInfoError
        raise
      rescue => e
        raise RegistryError, "Failed to generate registry URL for #{@purl.type}: #{e.message}"
      end
    end

    def generate_with_version(base_url: nil)
      return generate(base_url: base_url) unless @purl.version
      
      pattern_config = REGISTRY_PATTERNS[@purl.type.downcase]
      
      if base_url
        # Use custom base URL with version
        generate_with_custom_base_url_and_version(base_url, pattern_config)
      elsif pattern_config[:uri_template_with_version] || pattern_config[:uri_template]
        # Use version-specific URI template if available
        template = select_uri_template(pattern_config, include_version: true)
        generate_with_uri_template(template, include_version: true)
      else
        # Fall back to legacy version handling
        registry_url = generate(base_url: base_url)
        
        case @purl.type.downcase
        when "npm"
          "#{registry_url}/v/#{@purl.version}"
        when "pypi"
          "#{registry_url}#{@purl.version}/"
        when "gem"
          "#{registry_url}/versions/#{@purl.version}"
        when "maven"
          "#{registry_url}/#{@purl.version}"
        when "nuget"
          "#{registry_url}/#{@purl.version}"
        else
          registry_url
        end
      end
    end

    private

    def select_uri_template(pattern_config, include_version: false)
      if include_version
        if @purl.namespace && pattern_config[:uri_template_with_version]
          pattern_config[:uri_template_with_version]
        elsif !@purl.namespace && pattern_config[:uri_template_with_version_no_namespace]
          pattern_config[:uri_template_with_version_no_namespace]
        elsif pattern_config[:uri_template_with_version]
          pattern_config[:uri_template_with_version]
        elsif @purl.namespace && pattern_config[:uri_template]
          pattern_config[:uri_template]
        elsif !@purl.namespace && pattern_config[:uri_template_no_namespace]
          pattern_config[:uri_template_no_namespace]
        else
          pattern_config[:uri_template]
        end
      else
        if @purl.namespace && pattern_config[:uri_template]
          pattern_config[:uri_template]
        elsif !@purl.namespace && pattern_config[:uri_template_no_namespace]
          pattern_config[:uri_template_no_namespace]
        else
          pattern_config[:uri_template]
        end
      end
    end

    def generate_with_uri_template(template, include_version: false)
      variables = {
        name: @purl.name
      }
      
      # Add namespace if present and required
      if @purl.namespace
        variables[:namespace] = @purl.namespace
      end
      
      # Add version if requested and present
      if include_version && @purl.version
        variables[:version] = @purl.version
      end
      
      # Handle namespace requirements based on package type
      case @purl.type.downcase
      when "composer", "maven", "swift", "elm"
        unless @purl.namespace
          raise MissingRegistryInfoError.new(
            "#{@purl.type.capitalize} packages require a namespace",
            type: @purl.type,
            missing: "namespace"
          )
        end
      end
      
      # Build the URL manually to avoid encoding issues with special characters like @
      result = template.pattern
      
      variables.each do |key, value|
        result = result.gsub("{#{key}}", value.to_s)
      end
      
      result
    end

    def generate_with_custom_base_url_and_version(custom_base_url, pattern_config)
      # For now, fall back to the existing custom base URL method and add version
      base_result = generate_with_custom_base_url(custom_base_url, pattern_config)
      
      case @purl.type.downcase
      when "npm"
        "#{base_result}/v/#{@purl.version}"
      when "pypi"
        "#{base_result}#{@purl.version}/"
      when "gem"
        "#{base_result}/versions/#{@purl.version}"
      when "maven", "nuget"
        "#{base_result}/#{@purl.version}"
      else
        base_result
      end
    end

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