# frozen_string_literal: true

module Purl
  # Base error class for all Purl-related errors
  class Error < StandardError; end

  # Validation errors for PURL components
  #
  # Contains additional context about which component failed validation
  # and what rule was violated.
  #
  # @example
  #   begin
  #     PackageURL.new(type: "123invalid", name: "test")
  #   rescue ValidationError => e
  #     puts e.component  # :type
  #     puts e.rule       # "cannot start with number" 
  #   end
  class ValidationError < Error
    # @return [Symbol, nil] the PURL component that failed validation
    attr_reader :component
    
    # @return [Object, nil] the value that failed validation
    attr_reader :value
    
    # @return [String, nil] the validation rule that was violated
    attr_reader :rule

    # @param message [String] error message
    # @param component [Symbol, nil] component that failed validation
    # @param value [Object, nil] value that failed validation  
    # @param rule [String, nil] validation rule that was violated
    def initialize(message, component: nil, value: nil, rule: nil)
      super(message)
      @component = component
      @value = value
      @rule = rule
    end
  end

  # Parsing errors for malformed PURL strings
  class ParseError < Error; end

  # Specific validation errors for PURL components
  
  # Raised when a PURL type is invalid
  class InvalidTypeError < ValidationError; end
  
  # Raised when a PURL name is invalid
  class InvalidNameError < ValidationError; end
  
  # Raised when a PURL namespace is invalid
  class InvalidNamespaceError < ValidationError; end
  
  # Raised when a PURL qualifier is invalid
  class InvalidQualifierError < ValidationError; end
  
  # Raised when a PURL version is invalid
  class InvalidVersionError < ValidationError; end
  
  # Raised when a PURL subpath is invalid
  class InvalidSubpathError < ValidationError; end

  # Parsing-specific errors
  
  # Raised when a PURL string doesn't start with "pkg:"
  class InvalidSchemeError < ParseError; end
  
  # Raised when a PURL string is malformed
  class MalformedUrlError < ParseError; end

  # Registry URL generation errors
  #
  # Contains additional context about which type caused the error.
  class RegistryError < Error
    # @return [String, nil] the PURL type that caused the error
    attr_reader :type

    # @param message [String] error message
    # @param type [String, nil] PURL type that caused the error
    def initialize(message, type: nil)
      super(message)
      @type = type
    end
  end

  # Raised when trying to generate registry URLs for unsupported types
  class UnsupportedTypeError < RegistryError
    # @return [Array<String>] list of supported types
    attr_reader :supported_types

    # @param message [String] error message
    # @param type [String, nil] unsupported type
    # @param supported_types [Array<String>] list of supported types
    def initialize(message, type: nil, supported_types: [])
      super(message, type: type)
      @supported_types = supported_types
    end
  end

  # Raised when required registry information is missing
  class MissingRegistryInfoError < RegistryError
    # @return [String, nil] the missing information (e.g., "namespace")
    attr_reader :missing

    # @param message [String] error message
    # @param type [String, nil] PURL type
    # @param missing [String, nil] what information is missing
    def initialize(message, type: nil, missing: nil)
      super(message, type: type)
      @missing = missing
    end
  end

  # Legacy compatibility - matches packageurl-ruby's exception name
  # @deprecated Use {ParseError} instead
  InvalidPackageURL = ParseError
end