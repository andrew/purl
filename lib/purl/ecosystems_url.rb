# frozen_string_literal: true

module Purl
  class EcosystemsURL
    API_BASE = "https://packages.ecosyste.ms/api/v1"

    def self.registry_name(purl)
      new(purl).registry_name
    end

    def self.api_url(purl)
      new(purl).api_url
    end

    def self.package_api_url(purl)
      new(purl).package_api_url
    end

    def self.version_api_url(purl)
      new(purl).version_api_url
    end

    def initialize(purl)
      @purl = purl.is_a?(PackageURL) ? purl : PackageURL.parse(purl.to_s)
    end

    def registry_name
      # Check for explicit ecosystems_registry in config first
      type_config = Purl.type_config(@purl.type)
      return type_config["ecosystems_registry"] if type_config&.dig("ecosystems_registry")

      # Fall back to extracting host from registry_url
      return nil unless @purl.supports_registry_url?

      host = URI.parse(@purl.registry_url).host
      host.sub(/^www\./, "")
    rescue URI::InvalidURIError, RegistryError
      nil
    end

    def api_url
      @purl.version ? version_api_url : package_api_url
    end

    def package_api_url
      registry = registry_name
      return nil unless registry

      name = package_name_for_api
      "#{API_BASE}/registries/#{registry}/packages/#{encode_path_segment(name)}"
    end

    def version_api_url
      registry = registry_name
      return nil unless registry
      return nil unless @purl.version

      name = package_name_for_api
      "#{API_BASE}/registries/#{registry}/packages/#{encode_path_segment(name)}/versions/#{encode_path_segment(@purl.version)}"
    end

    private

    def package_name_for_api
      # Some ecosystems use namespace/name format
      if @purl.namespace && namespaced_package_types.include?(@purl.type.downcase)
        "#{@purl.namespace}/#{@purl.name}"
      else
        @purl.name
      end
    end

    def namespaced_package_types
      %w[npm composer maven golang swift elm clojars]
    end

    def encode_path_segment(str)
      URI.encode_www_form_component(str)
    end

    attr_reader :purl
  end

  class PackageURL
    def ecosystems_registry
      EcosystemsURL.registry_name(self)
    end

    def ecosystems_api_url
      EcosystemsURL.api_url(self)
    end

    def ecosystems_package_api_url
      EcosystemsURL.package_api_url(self)
    end

    def ecosystems_version_api_url
      EcosystemsURL.version_api_url(self)
    end
  end
end
