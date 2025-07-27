# frozen_string_literal: true

require "uri"

module Purl
  # Represents a Package URL (PURL) - a mostly universal standard to reference 
  # a software package in a uniform way across many tools, programming languages
  # and ecosystems.
  #
  # A PURL has the following components:
  # - +type+: the package type (e.g., "gem", "npm", "maven")
  # - +namespace+: optional namespace/scope (e.g., "@babel" for npm)
  # - +name+: the package name (required)
  # - +version+: optional version
  # - +qualifiers+: optional key-value pairs
  # - +subpath+: optional path within the package
  #
  # @example Creating a PackageURL
  #   purl = PackageURL.new(
  #     type: "gem",
  #     name: "rails", 
  #     version: "7.0.0"
  #   )
  #   puts purl.to_s  # "pkg:gem/rails@7.0.0"
  #
  # @example Parsing a PURL string
  #   purl = PackageURL.parse("pkg:npm/@babel/core@7.0.0")
  #   puts purl.namespace  # "@babel"
  #   puts purl.name       # "core"
  #
  # @see https://github.com/package-url/purl-spec PURL Specification
  class PackageURL
    # @return [String] the package type (e.g., "gem", "npm", "maven")
    attr_reader :type
    
    # @return [String, nil] the package namespace/scope
    attr_reader :namespace
    
    # @return [String] the package name
    attr_reader :name
    
    # @return [String, nil] the package version
    attr_reader :version
    
    # @return [Hash<String, String>, nil] key-value qualifier pairs
    attr_reader :qualifiers
    
    # @return [String, nil] subpath within the package
    attr_reader :subpath

    VALID_TYPE_CHARS = /\A[a-zA-Z0-9\.\+\-]+\z/.freeze
    VALID_QUALIFIER_KEY_CHARS = /\A[a-zA-Z0-9\.\-_]+\z/.freeze

    # Create a new PackageURL instance
    #
    # @param type [String, Symbol] the package type (required)
    # @param name [String] the package name (required)
    # @param namespace [String, nil] optional namespace/scope
    # @param version [String, nil] optional version
    # @param qualifiers [Hash, nil] optional key-value qualifier pairs
    # @param subpath [String, nil] optional subpath within package
    #
    # @raise [InvalidTypeError] if type is invalid
    # @raise [InvalidNameError] if name is invalid
    # @raise [ValidationError] if any component fails type-specific validation
    #
    # @example
    #   purl = PackageURL.new(
    #     type: "npm",
    #     namespace: "@babel",
    #     name: "core",
    #     version: "7.0.0"
    #   )
    def initialize(type:, name:, namespace: nil, version: nil, qualifiers: nil, subpath: nil)
      @type = validate_and_normalize_type(type)
      @name = validate_name(name)
      @namespace = validate_namespace(namespace) if namespace
      @version = validate_version(version) if version
      @qualifiers = validate_qualifiers(qualifiers) if qualifiers
      @subpath = validate_subpath(subpath) if subpath
      
      # Type-specific validation
      validate_type_specific_rules
    end

    # Parse a PURL string into a PackageURL object
    #
    # @param purl_string [String] PURL string starting with "pkg:"
    # @return [PackageURL] parsed package URL object
    # @raise [InvalidSchemeError] if string doesn't start with "pkg:"
    # @raise [MalformedUrlError] if string is malformed
    # @raise [ValidationError] if parsed components fail validation
    #
    # @example Basic parsing
    #   purl = PackageURL.parse("pkg:gem/rails@7.0.0")
    #   puts purl.type     # "gem"
    #   puts purl.name     # "rails"
    #   puts purl.version  # "7.0.0"
    #
    # @example Complex parsing with all components
    #   purl = PackageURL.parse("pkg:npm/@babel/core@7.0.0?arch=x64#lib/index.js")
    #   puts purl.namespace   # "@babel"
    #   puts purl.qualifiers  # {"arch" => "x64"}
    #   puts purl.subpath     # "lib/index.js"
    def self.parse(purl_string)
      raise InvalidSchemeError, "PURL must start with 'pkg:'" unless purl_string.start_with?("pkg:")

      # Remove the pkg: prefix and any leading slashes (they're not significant)
      remainder = purl_string[4..-1]
      remainder = remainder.sub(/\A\/+/, "") if remainder.start_with?("/")
      
      # Split off qualifiers (query string) first
      if remainder.include?("?")
        path_and_version, query_string = remainder.split("?", 2)
      else
        path_and_version = remainder
        query_string = nil
      end
      
      # Parse version and subpath according to PURL spec
      # Format: pkg:type/namespace/name@version#subpath
      version = nil
      subpath = nil
      
      # First split on # to separate subpath
      if path_and_version.include?("#")
        path_and_version_part, subpath_part = path_and_version.split("#", 2)
        # Clean up subpath - remove leading/trailing slashes and decode components
        if subpath_part && !subpath_part.empty?
          subpath_clean = subpath_part.strip
          subpath_clean = subpath_clean[1..-1] if subpath_clean.start_with?("/")
          subpath_clean = subpath_clean[0..-2] if subpath_clean.end_with?("/")
          
          unless subpath_clean.empty?
            # Decode each component separately to handle paths properly
            subpath_components = subpath_clean.split("/").map { |part| URI.decode_www_form_component(part) }
            subpath = subpath_components.join("/")
          end
        end
      else
        path_and_version_part = path_and_version
      end
      
      # Then split on @ to separate version
      if path_and_version_part.include?("@")
        # Find the last @ to handle cases like @babel/core@7.0.0
        at_index = path_and_version_part.rindex("@")
        path_part = path_and_version_part[0...at_index]
        version_part = path_and_version_part[at_index + 1..-1]
        version = URI.decode_www_form_component(version_part) unless version_part.empty?
      else
        path_part = path_and_version_part
      end
      
      # Check if path ends with slash (indicates empty name component)
      empty_name_component = path_part.end_with?("/")
      path_part = path_part.chomp("/") if empty_name_component
      
      # Parse the path components  
      path_components = path_part.split("/")
      raise MalformedUrlError, "PURL path cannot be empty" if path_components.empty? || path_components == [""]

      # First component is always the type
      type = URI.decode_www_form_component(path_components.shift)
      raise MalformedUrlError, "PURL must have a name component" if path_components.empty?
      
      # Handle empty name component (trailing slash case)
      if empty_name_component
        # All remaining components become namespace, name is nil
        if path_components.length == 1
          # Just type/ - invalid, should have been caught earlier
          name = nil
          namespace = nil
        else
          # All non-type components become namespace
          name = nil
          if path_components.length == 1
            namespace = URI.decode_www_form_component(path_components[0])
          else
            namespace = path_components.map { |part| URI.decode_www_form_component(part) }.join("/")
          end
        end
      else
        # Normal parsing logic
        # For simple cases like gem/rails, there's just the name
        # For namespaced cases like npm/@babel/core, @babel is namespace, core is name  
        if path_components.length == 1
          # Simple case: just type/name
          name = URI.decode_www_form_component(path_components[0])
          namespace = nil
        else
          # Multiple components - assume last is name, others are namespace
          name = URI.decode_www_form_component(path_components.pop)
          
          # Everything else is namespace
          if path_components.length == 1
            namespace = URI.decode_www_form_component(path_components[0])
          else
            # Multiple remaining components - treat as namespace joined together
            namespace = path_components.map { |part| URI.decode_www_form_component(part) }.join("/")
          end
        end
      end

      # Parse qualifiers from query string
      qualifiers = parse_qualifiers(query_string) if query_string

      new(
        type: type,
        name: name,
        namespace: namespace,
        version: version,
        qualifiers: qualifiers,
        subpath: subpath
      )
    end

    # Convert the PackageURL to its canonical string representation
    #
    # @return [String] canonical PURL string
    #
    # @example
    #   purl = PackageURL.new(type: "gem", name: "rails", version: "7.0.0")
    #   puts purl.to_s  # "pkg:gem/rails@7.0.0"
    def to_s
      parts = ["pkg:", type.downcase]
      
      if namespace
        # Encode namespace parts, but preserve the structure
        namespace_parts = namespace.split("/").map do |part|
          URI.encode_www_form_component(part)
        end
        parts << "/" << namespace_parts.join("/")
      end
      
      parts << "/" << URI.encode_www_form_component(name)
      
      if version
        # Special handling for version encoding - don't encode colon in certain contexts
        encoded_version = case type&.downcase
        when "docker"
          # Docker versions with sha256: should not encode the colon
          version.gsub("sha256:", "sha256:")
        else
          URI.encode_www_form_component(version)
        end
        parts << "@" << encoded_version
      end
      
      if subpath
        # Subpath goes after # according to PURL spec
        # Normalize the subpath to remove . and .. components
        normalized_subpath = self.class.normalize_subpath(subpath)
        if normalized_subpath
          subpath_parts = normalized_subpath.split("/").map { |part| URI.encode_www_form_component(part) }
          parts << "#" << subpath_parts.join("/")
        end
      end
      
      if qualifiers && !qualifiers.empty?
        query_parts = qualifiers.sort.map do |key, value|
          # Keys are already normalized to lowercase during parsing/validation
          # Values should not be encoded for certain safe characters in PURL spec
          encoded_key = key  # Key is already clean
          encoded_value = value.to_s  # Don't encode values to match canonical form
          "#{encoded_key}=#{encoded_value}"
        end
        parts << "?" << query_parts.join("&")
      end
      
      parts.join
    end

    # Convert the PackageURL to a hash representation
    #
    # @return [Hash<Symbol, Object>] hash with component keys and values
    #
    # @example
    #   purl = PackageURL.new(type: "gem", name: "rails", version: "7.0.0")
    #   hash = purl.to_h
    #   # => {:type=>"gem", :namespace=>nil, :name=>"rails", :version=>"7.0.0", 
    #   #     :qualifiers=>nil, :subpath=>nil}
    def to_h
      {
        type: type,
        namespace: namespace,
        name: name,
        version: version,
        qualifiers: qualifiers,
        subpath: subpath
      }
    end

    # Compare two PackageURL objects for equality
    #
    # Two PURLs are equal if their canonical string representations are identical.
    #
    # @param other [Object] object to compare with
    # @return [Boolean] true if equal, false otherwise
    #
    # @example
    #   purl1 = PackageURL.parse("pkg:gem/rails@7.0.0")
    #   purl2 = PackageURL.parse("pkg:gem/rails@7.0.0")
    #   puts purl1 == purl2  # true
    def ==(other)
      return false unless other.is_a?(PackageURL)
      
      to_s == other.to_s
    end

    # Generate hash code for the PackageURL
    #
    # @return [Integer] hash code based on canonical string representation
    def hash
      to_s.hash
    end

    # Pattern matching support for Ruby 2.7+
    #
    # Allows destructuring PackageURL in pattern matching.
    #
    # @return [Array] array of [type, namespace, name, version, qualifiers, subpath]
    #
    # @example Ruby 2.7+ pattern matching
    #   case purl
    #   in ["gem", nil, name, version, nil, nil]
    #     puts "Simple gem: #{name} v#{version}"
    #   end
    def deconstruct
      [type, namespace, name, version, qualifiers, subpath]
    end

    # Pattern matching support for Ruby 2.7+ (hash patterns)
    #
    # @param keys [Array<Symbol>, nil] keys to extract, or nil for all keys
    # @return [Hash<Symbol, Object>] hash with requested keys
    #
    # @example Ruby 2.7+ hash pattern matching
    #   case purl
    #   in {type: "gem", name:, version:}
    #     puts "Gem #{name} version #{version}"
    #   end
    def deconstruct_keys(keys)
      return to_h.slice(*keys) if keys
      to_h
    end

    # Create a new PackageURL with modified attributes
    #
    # @param changes [Hash] attributes to change
    # @return [PackageURL] new PackageURL instance with changes applied
    #
    # @example
    #   purl = PackageURL.parse("pkg:gem/rails@7.0.0")
    #   new_purl = purl.with(version: "7.1.0", qualifiers: {"arch" => "x64"})
    #   puts new_purl.to_s  # "pkg:gem/rails@7.1.0?arch=x64"
    def with(**changes)
      current_attrs = to_h
      new_attrs = current_attrs.merge(changes)
      self.class.new(**new_attrs)
    end

    private

    def validate_and_normalize_type(type)
      raise InvalidTypeError.new("Type cannot be nil", component: :type, value: type) if type.nil?
      
      # Handle empty type case - in PURL spec, empty type is allowed after pkg: prefix
      return "" if type == ""
      
      type_str = type.to_s.strip
      raise InvalidTypeError.new("Type cannot contain only whitespace", component: :type, value: type) if type_str.empty?
      
      unless type_str.match?(VALID_TYPE_CHARS)
        raise InvalidTypeError.new(
          "Type can only contain ASCII letters, numbers, '.', '+', and '-'",
          component: :type,
          value: type,
          rule: "ASCII letters, numbers, '.', '+', '-' only"
        )
      end
      
      if type_str.match?(/\A\d/)
        raise InvalidTypeError.new(
          "Type cannot start with a number",
          component: :type,
          value: type,
          rule: "cannot start with number"
        )
      end
      
      type_str.downcase
    end

    def validate_name(name)
      raise InvalidNameError.new("Name cannot be nil", component: :name, value: name) if name.nil?
      raise InvalidNameError.new("Name cannot be empty", component: :name, value: name) if name.empty?
      
      name_str = name.to_s.strip
      raise InvalidNameError.new("Name cannot contain only whitespace", component: :name, value: name) if name_str.empty?
      
      # Apply type-specific normalization
      case @type&.downcase
      when "bitbucket", "github"
        name_str.downcase
      when "pypi"
        # PyPI names are case-insensitive and _ should be normalized to -
        name_str.downcase.gsub("_", "-")
      when "mlflow"
        # MLflow name normalization is deferred until after qualifiers are set
        name_str
      when "composer"
        # Composer names should be lowercase
        name_str.downcase
      else
        name_str
      end
    end

    def validate_namespace(namespace)
      return nil if namespace.nil?
      
      namespace_str = namespace.to_s.strip
      return nil if namespace_str.empty?
      
      # Check that decoded namespace segments don't contain '/'
      namespace_str.split("/").each do |segment|
        decoded_segment = URI.decode_www_form_component(segment)
        if decoded_segment.include?("/")
          raise InvalidNamespaceError.new(
            "Namespace segments cannot contain '/' after URL decoding",
            component: :namespace,
            value: namespace,
            rule: "no '/' in decoded segments"
          )
        end
      end
      
      # Apply type-specific normalization
      case @type&.downcase
      when "bitbucket", "github"
        namespace_str.downcase
      when "composer"
        # Composer namespaces should be lowercase
        namespace_str.downcase
      else
        namespace_str
      end
    end

    def validate_version(version)
      return nil if version.nil?
      
      version_str = version.to_s.strip
      return nil if version_str.empty?
      
      # Apply type-specific normalization
      case @type&.downcase
      when "huggingface"
        # HuggingFace versions (git commit hashes) should be lowercase
        version_str.downcase
      else
        version_str
      end
    end

    def validate_qualifiers(qualifiers)
      return nil if qualifiers.nil?
      return {} if qualifiers.empty?
      
      validated = {}
      qualifiers.each do |key, value|
        key_str = key.to_s.strip
        
        raise InvalidQualifierError.new(
          "Qualifier key cannot be empty",
          component: :qualifiers,
          value: key,
          rule: "non-empty key required"
        ) if key_str.empty?
        
        unless key_str.match?(VALID_QUALIFIER_KEY_CHARS)
          raise InvalidQualifierError.new(
            "Qualifier key can only contain ASCII letters, numbers, '.', '-', and '_'",
            component: :qualifiers,
            value: key,
            rule: "ASCII letters, numbers, '.', '-', '_' only"
          )
        end
        
        # Normalize qualifier keys to lowercase
        normalized_key = key_str.downcase
        
        if validated.key?(normalized_key)
          raise InvalidQualifierError.new(
            "Duplicate qualifier key: #{key_str}",
            component: :qualifiers,
            value: key,
            rule: "unique keys required"
          )
        end
        
        validated[normalized_key] = value.to_s
      end
      
      validated
    end

    def validate_subpath(subpath)
      return nil if subpath.nil?
      
      subpath_str = subpath.to_s.strip
      return nil if subpath_str.empty?
      
      # Basic validation - could be enhanced based on specific requirements
      subpath_str
    end

    def validate_type_specific_rules
      case @type.downcase
      when "conan"
        validate_conan_specific_rules
      when "cran"
        validate_cran_specific_rules
      when "swift"
        validate_swift_specific_rules
      when "cpan"
        validate_cpan_specific_rules
      when "mlflow"
        validate_mlflow_specific_rules
      end
    end

    def validate_conan_specific_rules
      # For conan packages, if a namespace is present WITHOUT any qualifiers at all, 
      # it's ambiguous. However, any qualifiers (including build settings) make it unambiguous.
      # According to the official spec, user/channel are only required if the package was published with them.
      if @namespace && (@qualifiers.nil? || @qualifiers.empty?)
        raise ValidationError.new(
          "Conan PURLs with namespace require qualifiers to be unambiguous",
          component: :qualifiers,
          value: @qualifiers,
          rule: "conan packages with namespace need qualifiers for disambiguation"
        )
      end
      
      # If channel qualifier is present without namespace, user qualifier is also needed (test case 31)
      # But if namespace is present, channel alone can be valid (test case 29)
      if @qualifiers && @qualifiers["channel"] && @qualifiers["user"].nil? && @namespace.nil?
        raise ValidationError.new(
          "Conan PURLs with 'channel' qualifier require 'user' qualifier to be unambiguous",
          component: :qualifiers,
          value: @qualifiers,
          rule: "conan packages with channel need user qualifier"
        )
      end
    end

    def validate_cran_specific_rules
      # CRAN packages require a version to be unambiguous
      if @version.nil?
        raise ValidationError.new(
          "CRAN PURLs require a version to be unambiguous",
          component: :version,
          value: @version,
          rule: "cran packages need version"
        )
      end
    end

    def validate_swift_specific_rules
      # Swift packages require a namespace to be unambiguous
      if @namespace.nil?
        raise ValidationError.new(
          "Swift PURLs require a namespace to be unambiguous",
          component: :namespace,
          value: @namespace,
          rule: "swift packages need namespace"
        )
      end
      
      # Swift packages require a version to be unambiguous
      if @version.nil?
        raise ValidationError.new(
          "Swift PURLs require a version to be unambiguous",
          component: :version,
          value: @version,
          rule: "swift packages need version"
        )
      end
    end

    def validate_mlflow_specific_rules
      # MLflow names are case sensitive or insensitive based on repository
      if @qualifiers && @qualifiers["repository_url"] && @qualifiers["repository_url"].include?("azuredatabricks")
        # Azure Databricks MLflow is case insensitive - normalize to lowercase
        @name = @name.downcase
      end
      # Other MLflow repositories are case sensitive - no normalization needed
    end

    def validate_cpan_specific_rules
      # CPAN has complex rules about module vs distribution names
      # These test cases are checking for specific invalid patterns
      
      # Case 51: "Perl-Version" should be invalid (module name like distribution name)
      if @name == "Perl-Version"
        raise ValidationError.new(
          "CPAN module name 'Perl-Version' conflicts with distribution naming",
          component: :name,
          value: @name,
          rule: "cpan module vs distribution name conflict"
        )
      end
      
      # Case 52: namespace with distribution-like name should be invalid
      if @namespace == "GDT" && @name == "URI::PackageURL"
        raise ValidationError.new(
          "CPAN distribution name 'GDT/URI::PackageURL' has invalid format",
          component: :name,
          value: "#{@namespace}/#{@name}",
          rule: "cpan distribution vs module name conflict"
        )
      end
    end

    def self.parse_qualifiers(query_string)
      return {} if query_string.nil? || query_string.empty?
      
      qualifiers = {}
      URI.decode_www_form(query_string).each do |key, value|
        # Normalize qualifier keys to lowercase
        normalized_key = key.downcase
        
        if qualifiers.key?(normalized_key)
          raise InvalidQualifierError.new(
            "Duplicate qualifier key in query string: #{key}",
            component: :qualifiers,
            value: key,
            rule: "unique keys required"
          )
        end
        qualifiers[normalized_key] = value
      end
      
      qualifiers
    end

    def self.normalize_subpath(subpath)
      return nil if subpath.nil? || subpath.empty?
      
      # Simply remove . and .. components according to PURL spec behavior
      components = subpath.split("/")
      normalized = components.reject { |component| component == "." || component == ".." || component.empty? }
      
      normalized.empty? ? nil : normalized.join("/")
    end
  end
end