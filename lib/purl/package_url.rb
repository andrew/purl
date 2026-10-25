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

    # Percent-decoding, not form decoding, so a literal '+' is not turned into a space
    def self.fast_decode(str)
      str.include?("%") ? URI.decode_uri_component(str) : str
    end

    # Components are written as 1.x wrote them, except a space is %20 because a literal '+' now stays a plus
    def self.encode_component(str)
      URI.encode_www_form_component(str.to_s).gsub("+", "%20")
    end

    QUALIFIER_VALUE_ESCAPES = { "%" => "%25", "+" => "%2B", "&" => "%26", "#" => "%23", " " => "%20" }.freeze

    # Qualifier values are written as is, as 1.x did, apart from the characters that would not survive parsing
    def self.encode_qualifier_value(str)
      str.to_s.gsub(/[%+&# ]/, QUALIFIER_VALUE_ESCAPES)
    end

    VALID_TYPE_CHARS = /\A[a-zA-Z0-9\.\+\-]+\z/.freeze
    VALID_QUALIFIER_KEY_CHARS = /\A[a-zA-Z0-9\.\-_]+\z/.freeze
    STARTS_WITH_DIGIT = /\A\d/.freeze

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
      @namespace = validate_namespace(namespace)
      @version = validate_version(version) if version
      @qualifiers = validate_qualifiers(qualifiers) if qualifiers
      @subpath = validate_subpath(subpath) if subpath

      # Apply post-validation normalization that depends on other components
      apply_post_validation_normalization
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
      
      # Format: pkg:type/namespace/name@version?qualifiers#subpath
      version = nil
      subpath = nil
      query_string = nil

      # Split at the first '?' and '#' rather than the last: qualifier values written by versions
      # before 2.0 were not encoded and can contain both, while path and version never do.
      question_index = remainder.index("?")
      hash_index = remainder.index("#")
      subpath_part = nil
      if hash_index && (question_index.nil? || hash_index < question_index)
        # Versions before 2.0 wrote #subpath?qualifiers
        subpath_part, query_string = remainder[(hash_index + 1)..].split("?", 2)
        remainder = remainder[0...hash_index]
      elsif question_index
        query_string, subpath_part = remainder[(question_index + 1)..].split("#", 2)
        remainder = remainder[0...question_index]
      end

      if subpath_part
        # Clean up subpath - remove leading/trailing slashes and decode components
        unless subpath_part.empty?
          subpath_clean = subpath_part.strip
          subpath_clean = subpath_clean[1..-1] if subpath_clean.start_with?("/")
          subpath_clean = subpath_clean[0..-2] if subpath_clean.end_with?("/")
          
          unless subpath_clean.empty?
            # Decode each component separately to handle paths properly
            subpath_components = subpath_clean.split("/").map { |part| fast_decode(part) }
            subpath = subpath_components.join("/")
          end
        end
      end

      path_and_version_part = remainder

      # An '@' that starts a segment with more path after it is an unencoded npm scope like @babel/core
      at_index = path_and_version_part.rindex("@")
      if at_index && path_and_version_part[at_index - 1] == "/" && path_and_version_part.index("/", at_index)
        at_index = nil
      end
      if at_index
        path_part = path_and_version_part[0...at_index]
        version_part = path_and_version_part[at_index + 1..-1]
        version = fast_decode(version_part) unless version_part.empty?
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
      type = fast_decode(path_components.shift)
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
            namespace = fast_decode(path_components[0])
          else
            namespace = path_components.map { |part| fast_decode(part) }.join("/")
          end
        end
      else
        # Normal parsing logic
        # For simple cases like gem/rails, there's just the name
        # For namespaced cases like npm/@babel/core, @babel is namespace, core is name
        if type.downcase == "git" && path_components.length > 1
          # The namespace is the git host and the name is the repository path on it
          namespace = fast_decode(path_components.shift)
          name = path_components.map { |part| fast_decode(part) }.join("/")
        elsif path_components.length == 1
          # Simple case: just type/name
          name = fast_decode(path_components[0])
          namespace = nil
        else
          # Multiple components - assume last is name, others are namespace
          name = fast_decode(path_components.pop)

          # Everything else is namespace
          if path_components.length == 1
            namespace = fast_decode(path_components[0])
          else
            # Multiple remaining components - treat as namespace joined together
            namespace = path_components.map { |part| fast_decode(part) }.join("/")
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
      return @canonical if @canonical

      parts = ["pkg:", type.downcase]
      
      if namespace
        # Encode namespace parts, but preserve the structure
        namespace_parts = namespace.split("/").map do |part|
          self.class.encode_component(part)
        end
        parts << "/" << namespace_parts.join("/")
      end

      # Legacy git PURLs without a host namespace keep slashes in the name encoded so they reparse the same
      name_parts = type == "git" && namespace ? name.split("/") : [name]
      parts << "/" << name_parts.map { |part| self.class.encode_component(part) }.join("/")

      if version
        # Docker versions such as sha256:abc are written unencoded
        parts << "@" << (type == "docker" ? version : self.class.encode_component(version))
      end

      if qualifiers && !qualifiers.empty?
        query_parts = qualifiers.sort.map do |key, value|
          "#{key}=#{self.class.encode_qualifier_value(value)}"
        end
        parts << "?" << query_parts.join("&")
      end

      if subpath
        # Normalize the subpath to remove . and .. components
        normalized_subpath = self.class.normalize_subpath(subpath)
        if normalized_subpath
          subpath_parts = normalized_subpath.split("/").map { |part| self.class.encode_component(part) }
          parts << "#" << subpath_parts.join("/")
        end
      end

      @canonical = parts.join.freeze
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

    # Create a new PackageURL without the version component
    #
    # @return [PackageURL] new PackageURL instance with version set to nil
    #
    # @example
    #   purl = PackageURL.parse("pkg:gem/rails@7.0.0")
    #   versionless = purl.versionless
    #   puts versionless.to_s  # "pkg:gem/rails"
    def versionless
      with(version: nil)
    end

    # Look up package information using the ecosyste.ms API
    #
    # @param user_agent [String] User agent string for API requests
    # @param timeout [Integer] Request timeout in seconds
    # @return [Hash, nil] Package information hash or nil if not found
    # @raise [LookupError] if the lookup fails due to network or API errors
    #
    # @example
    #   purl = PackageURL.parse("pkg:cargo/rand@0.9.2")
    #   info = purl.lookup
    #   puts info[:package][:name]  # => "rand"
    #   puts info[:version][:published_at] if info[:version]  # => "2025-07-20T17:47:01.870Z"
    def lookup(user_agent: nil, timeout: 10)
      require_relative "lookup"
      lookup_client = Lookup.new(user_agent: user_agent, timeout: timeout)
      lookup_client.package_info(self)
    end

    # Look up security advisories using the advisories.ecosyste.ms API
    #
    # @param user_agent [String] User agent string for API requests
    # @param timeout [Integer] Request timeout in seconds
    # @return [Array<Hash>] Array of advisory hashes, empty if none found
    # @raise [AdvisoryError] if the lookup fails due to network or API errors
    #
    # @example
    #   purl = PackageURL.parse("pkg:npm/lodash@4.17.20")
    #   advisories = purl.advisories
    #   advisories.each { |adv| puts adv[:title] }
    def advisories(user_agent: nil, timeout: 10)
      require_relative "advisory"
      advisory_client = Advisory.new(user_agent: user_agent, timeout: timeout)
      advisory_client.lookup(self)
    end

    # Rules from the purl-spec type definitions that this PURL breaks. Real-world PURLs often
    # break them, so they are reported here instead of raised by parse and new.
    #
    # @return [Array<ValidationError>]
    def validation_errors
      @validation_errors ||= type_rule_errors.freeze
    end

    # @return [Boolean] true when the PURL follows its type definition
    def valid?
      validation_errors.empty?
    end

    # @return [PackageURL] self
    # @raise [ValidationError] the first broken type rule
    def validate!
      raise validation_errors.first unless valid?
      self
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
      
      if type_str.match?(STARTS_WITH_DIGIT)
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
      
      # Apply type-specific normalization (@type is already lowercased)
      case @type
      when "bitbucket", "github", "composer"
        name_str.downcase
      when "pypi"
        name_str.downcase.gsub("_", "-")
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
        decoded_segment = self.class.fast_decode(segment)
        if decoded_segment.include?("/")
          raise InvalidNamespaceError.new(
            "Namespace segments cannot contain '/' after URL decoding",
            component: :namespace,
            value: namespace,
            rule: "no '/' in decoded segments"
          )
        end
      end
      
      case @type
      when "bitbucket", "github", "composer"
        namespace_str.downcase
      else
        namespace_str
      end
    end

    def validate_version(version)
      return nil if version.nil?

      version_str = version.to_s.strip
      return nil if version_str.empty?

      @type == "huggingface" ? version_str.downcase : version_str
    end

    def type_rules
      self.class.type_rules(@type)
    end

    def self.type_rules(type)
      Purl.load_types_config["types"][type] || {}
    end

    def type_rule_errors
      rules = type_rules
      errors = []

      case rules["namespace_requirement"]
      when "required"
        errors << rule_error(InvalidNamespaceError, :namespace, nil, "#{@type} PURLs require a namespace") if namespace.nil?
      when "prohibited"
        errors << rule_error(InvalidNamespaceError, :namespace, namespace, "#{@type} PURLs do not have a namespace") if namespace
      end

      { "namespace" => [namespace, InvalidNamespaceError], "name" => [name, InvalidNameError], "version" => [version, InvalidVersionError] }.each do |component, (value, error_class)|
        pattern = rules["#{component}_permitted_characters"]
        next unless pattern && value
        checked = rules["#{component}_case_sensitive"] == false ? value.downcase : value
        next if self.class.permitted_regex(pattern).match?(checked)

        errors << rule_error(error_class, component.to_sym, value, "#{@type} #{component} does not match #{pattern}")
      end

      if @type == "cpan" && name.include?("::")
        errors << rule_error(InvalidNameError, :name, name, "cpan names are distribution names like URI-PackageURL, not module names like URI::PackageURL")
      end

      missing = Array(rules["required_qualifiers"]) - (qualifiers || {}).keys
      errors << rule_error(InvalidQualifierError, :qualifiers, qualifiers, "#{@type} PURLs require the #{missing.join(", ")} qualifier") if missing.any?

      errors
    end

    def rule_error(error_class, component, value, message)
      error_class.new(message, component: component, value: value, rule: "#{@type} type definition")
    end

    def self.permitted_regex(pattern)
      @permitted_regexes ||= {}
      # Spec patterns use ^ and $, which in Ruby also match at line breaks
      @permitted_regexes[pattern] ||= Regexp.new(pattern.sub(/\A\^/) { "\\A" }.sub(/\$\z/) { "\\z" })
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

    def apply_post_validation_normalization
      if @type == "mlflow" && @qualifiers && @qualifiers["repository_url"] && @qualifiers["repository_url"].include?("azuredatabricks")
        # Databricks MLflow is case insensitive - normalize to lowercase per spec
        @name = @name.downcase
      end
      # Other MLflow repositories (like Azure ML) are case sensitive - no normalization needed
    end

    def self.namespace_required_types
      @namespace_required_types ||= begin
        config = Purl.load_types_config
        types = config["types"].select { |_, v| v["namespace_requirement"] == "required" }.keys
        Set.new(types).freeze
      end
    end

    def self.purl_types_data
      Purl.load_types_config
    end

    def self.parse_qualifiers(query_string)
      return {} if query_string.nil? || query_string.empty?
      
      qualifiers = {}
      query_string.split("&").each do |pair|
        next if pair.empty?
        key, value = pair.split("=", 2)
        value = fast_decode(value.to_s)
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