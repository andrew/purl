# frozen_string_literal: true

module Purl
  # Base error class for all Purl-related errors
  class Error < StandardError; end

  # Validation errors for PURL components
  class ValidationError < Error
    attr_reader :component, :value, :rule

    def initialize(message, component: nil, value: nil, rule: nil)
      super(message)
      @component = component
      @value = value
      @rule = rule
    end
  end

  # Parsing errors for malformed PURL strings
  class ParseError < Error; end

  # Specific validation errors
  class InvalidTypeError < ValidationError; end
  class InvalidNameError < ValidationError; end
  class InvalidNamespaceError < ValidationError; end
  class InvalidQualifierError < ValidationError; end
  class InvalidVersionError < ValidationError; end
  class InvalidSubpathError < ValidationError; end

  # Parsing-specific errors
  class InvalidSchemeError < ParseError; end
  class MalformedUrlError < ParseError; end

  # Registry URL generation errors
  class RegistryError < Error
    attr_reader :type

    def initialize(message, type: nil)
      super(message)
      @type = type
    end
  end

  class UnsupportedTypeError < RegistryError
    attr_reader :supported_types

    def initialize(message, type: nil, supported_types: [])
      super(message, type: type)
      @supported_types = supported_types
    end
  end

  class MissingRegistryInfoError < RegistryError
    attr_reader :missing

    def initialize(message, type: nil, missing: nil)
      super(message, type: type)
      @missing = missing
    end
  end

  # Legacy compatibility - matches packageurl-ruby's exception name
  InvalidPackageURL = ParseError
end