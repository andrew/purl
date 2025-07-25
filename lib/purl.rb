# frozen_string_literal: true

require_relative "purl/version"
require_relative "purl/errors"
require_relative "purl/package_url"
require_relative "purl/registry_url"

module Purl
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
  def self.known_types
    KNOWN_TYPES.dup
  end

  # Returns types that have registry URL support
  def self.registry_supported_types
    RegistryURL.supported_types
  end

  # Returns types that support reverse parsing from registry URLs
  def self.reverse_parsing_supported_types
    RegistryURL.supported_reverse_types
  end

  # Check if a type is known/valid
  def self.known_type?(type)
    KNOWN_TYPES.include?(type.to_s.downcase)
  end

  # Get type information including registry support
  def self.type_info(type)
    normalized_type = type.to_s.downcase
    {
      type: normalized_type,
      known: known_type?(normalized_type),
      default_registry: default_registry(normalized_type),
      registry_url_generation: RegistryURL.supports?(normalized_type),
      reverse_parsing: RegistryURL.supported_reverse_types.include?(normalized_type),
      route_patterns: RegistryURL.route_patterns_for(normalized_type)
    }
  end

  # Get comprehensive information about all types
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
  def self.type_config(type)
    config = load_types_config["types"][type.to_s.downcase]
    return nil unless config
    
    config.dup # Return a copy to prevent modification
  end

  # Get description for a type
  def self.type_description(type)
    config = type_config(type)
    config ? config["description"] : nil
  end

  # Get registry configuration for a type
  def self.registry_config(type)
    config = type_config(type)
    return nil unless config
    
    config["registry_config"]
  end

  # Get default registry URL for a type
  def self.default_registry(type)
    config = type_config(type)
    return nil unless config
    
    config["default_registry"]
  end

  # Get metadata about the types configuration
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
