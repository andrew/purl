# frozen_string_literal: true

require_relative "purl/version"
require_relative "purl/errors"
require_relative "purl/package_url"
require_relative "purl/registry_url"
require_relative "purl/lookup"
require_relative "purl/lookup_formatter"
require_relative "purl/advisory"
require_relative "purl/advisory_formatter"

# The main PURL (Package URL) module providing functionality to parse,
# validate, and generate package URLs according to the PURL specification.
#
# A Package URL is a mostly universal standard to reference a software package
# in a uniform way across many tools, programming languages and ecosystems.
#
# @example Basic usage
#   purl = Purl.parse("pkg:gem/rails@7.0.0")
#   puts purl.type     # "gem"
#   puts purl.name     # "rails"
#   puts purl.version  # "7.0.0"
#
# @example Registry URL conversion
#   purl = Purl.from_registry_url("https://rubygems.org/gems/rails")
#   puts purl.to_s     # "pkg:gem/rails"
#
# @example Package information lookup
#   purl = Purl.parse("pkg:cargo/rand@0.9.2")
#   info = purl.lookup
#   puts info[:package][:description]
#   puts info[:version][:published_at] if info[:version]
#
# @see https://github.com/package-url/purl-spec PURL Specification
module Purl
  # Base error class for all PURL-related errors
  class Error < StandardError; end
  
  # Load PURL types configuration from JSON file
  def self.load_types_config
    @types_config ||= begin
      config_path = File.join(__dir__, "..", "purl-types.json")
      require "json"
      JSON.parse(File.read(config_path))
    end
  end

  # Known PURL types loaded from JSON configuration
  KNOWN_TYPES = load_types_config["types"].keys.sort.freeze
  
  # Convenience method for parsing PURL strings
  #
  # @param purl_string [String] a PURL string starting with "pkg:"
  # @return [PackageURL] parsed package URL object
  # @raise [InvalidSchemeError] if string doesn't start with "pkg:"
  # @raise [MalformedUrlError] if string is malformed
  #
  # @example
  #   purl = Purl.parse("pkg:gem/rails@7.0.0")
  #   puts purl.name  # "rails"
  def self.parse(purl_string)
    PackageURL.parse(purl_string)
  end

  # Convenience method for parsing registry URLs back to PURLs
  # @param registry_url [String] The registry URL to parse
  # @param type [String, Symbol, nil] Optional type hint for custom domains
  def self.from_registry_url(registry_url, type: nil)
    RegistryURL.from_url(registry_url, type: type)
  end

  # Returns all known PURL types
  #
  # @return [Array<String>] sorted array of known PURL type names
  #
  # @example
  #   types = Purl.known_types
  #   puts types.include?("gem")  # true
  def self.known_types
    KNOWN_TYPES.dup
  end

  # Returns types that have registry URL support
  #
  # @return [Array<String>] sorted array of types that can generate registry URLs
  #
  # @example
  #   types = Purl.registry_supported_types
  #   puts types.include?("npm")  # true if npm has registry support
  def self.registry_supported_types
    RegistryURL.supported_types
  end

  # Returns types that support reverse parsing from registry URLs
  #
  # @return [Array<String>] sorted array of types that can parse registry URLs back to PURLs
  #
  # @example
  #   types = Purl.reverse_parsing_supported_types
  #   puts types.include?("gem")  # true if gem has reverse parsing support
  def self.reverse_parsing_supported_types
    RegistryURL.supported_reverse_types
  end

  # Check if a type is known/valid
  #
  # @param type [String, Symbol] the type to check
  # @return [Boolean] true if type is known, false otherwise
  #
  # @example
  #   Purl.known_type?("gem")     # true
  #   Purl.known_type?("unknown") # false
  def self.known_type?(type)
    KNOWN_TYPES.include?(type.to_s.downcase)
  end

  # Get comprehensive type information including registry support
  #
  # @param type [String, Symbol] the type to get information for
  # @return [Hash] hash containing type information with keys:
  #   - +:type+: normalized type name
  #   - +:known+: whether type is known
  #   - +:description+: human-readable description
  #   - +:default_registry+: default registry URL
  #   - +:examples+: array of example PURLs
  #   - +:registry_url_generation+: whether registry URL generation is supported
  #   - +:reverse_parsing+: whether reverse parsing is supported
  #   - +:route_patterns+: array of URL patterns for this type
  #
  # @example
  #   info = Purl.type_info("gem")
  #   puts info[:description]  # "Ruby gems from RubyGems.org"
  def self.type_info(type)
    normalized_type = type.to_s.downcase
    {
      type: normalized_type,
      known: known_type?(normalized_type),
      description: type_description(normalized_type),
      default_registry: default_registry(normalized_type),
      examples: type_examples(normalized_type),
      registry_url_generation: RegistryURL.supports?(normalized_type),
      reverse_parsing: RegistryURL.supported_reverse_types.include?(normalized_type),
      route_patterns: RegistryURL.route_patterns_for(normalized_type)
    }
  end

  # Get comprehensive information about all types
  #
  # @return [Hash<String, Hash>] hash mapping type names to their information
  # @see #type_info for structure of individual type information
  #
  # @example
  #   all_info = Purl.all_type_info
  #   gem_info = all_info["gem"]
  def self.all_type_info
    result = {}
    
    # Start with known types
    KNOWN_TYPES.each do |type|
      result[type] = type_info(type)
    end
    
    # Add any registry-supported types not in known list
    RegistryURL.supported_types.each do |type|
      unless result.key?(type)
        result[type] = type_info(type)
      end
    end
    
    result
  end

  # Get type configuration from JSON
  #
  # @param type [String, Symbol] the type to get configuration for
  # @return [Hash, nil] configuration hash or nil if type not found
  # @api private
  def self.type_config(type)
    config = load_types_config["types"][type.to_s.downcase]
    return nil unless config
    
    config.dup # Return a copy to prevent modification
  end

  # Get human-readable description for a type
  #
  # @param type [String, Symbol] the type to get description for
  # @return [String, nil] description string or nil if not available
  #
  # @example
  #   desc = Purl.type_description("gem")
  #   puts desc  # "Ruby gems from RubyGems.org"
  def self.type_description(type)
    config = type_config(type)
    config ? config["description"] : nil
  end

  # Get example PURLs for a type
  #
  # @param type [String, Symbol] the type to get examples for
  # @return [Array<String>] array of example PURL strings
  #
  # @example
  #   examples = Purl.type_examples("gem")
  #   puts examples.first  # "pkg:gem/rails@7.0.0"
  def self.type_examples(type)
    config = type_config(type)
    return [] unless config
    
    config["examples"] || []
  end

  # Get registry configuration for a type
  #
  # @param type [String, Symbol] the type to get registry config for
  # @return [Hash, nil] registry configuration hash or nil if not available
  # @api private
  def self.registry_config(type)
    config = type_config(type)
    return nil unless config
    
    config["registry_config"]
  end

  # Get default registry URL for a type
  #
  # @param type [String, Symbol] the type to get default registry for
  # @return [String, nil] default registry URL or nil if not available
  #
  # @example
  #   registry = Purl.default_registry("gem")
  #   puts registry  # "https://rubygems.org"
  def self.default_registry(type)
    config = type_config(type)
    return nil unless config
    
    config["default_registry"]
  end

  # Get metadata about the types configuration
  #
  # @return [Hash] metadata hash with keys:
  #   - +:version+: configuration version
  #   - +:description+: configuration description
  #   - +:source+: source of the configuration
  #   - +:last_updated+: when configuration was last updated
  #   - +:total_types+: total number of types
  #   - +:registry_supported_types+: number of types with registry support
  #   - +:types_with_default_registry+: number of types with default registry
  #
  # @example
  #   metadata = Purl.types_config_metadata
  #   puts "Total types: #{metadata[:total_types]}"
  def self.types_config_metadata
    config = load_types_config
    {
      version: config["version"],
      description: config["description"],
      source: config["source"],
      last_updated: config["last_updated"],
      total_types: config["types"].keys.length,
      registry_supported_types: config["types"].select { |_, v| v["registry_config"] }.keys.length,
      types_with_default_registry: config["types"].select { |_, v| v["default_registry"] }.keys.length
    }
  end
end
