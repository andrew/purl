# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Purl
  # Provides lookup functionality for packages using the ecosyste.ms API
  class Lookup
    ECOSYSTE_MS_API_BASE = "https://packages.ecosyste.ms/api/v1"
    
    # Initialize a new Lookup instance
    #
    # @param user_agent [String] User agent string for API requests
    # @param timeout [Integer] Request timeout in seconds
    def initialize(user_agent: nil, timeout: 10)
      @user_agent = user_agent || "purl-ruby/#{Purl::VERSION}"
      @timeout = timeout
    end

    # Look up package information for a given PURL
    #
    # @param purl [String, PackageURL] PURL string or PackageURL object
    # @return [Hash, nil] Package information hash or nil if not found
    # @raise [LookupError] if the lookup fails due to network or API errors
    #
    # @example
    #   lookup = Purl::Lookup.new
    #   info = lookup.package_info("pkg:cargo/rand@0.9.2")
    #   puts info[:package][:name]  # => "rand"
    #   puts info[:version][:published_at] if info[:version]  # => "2025-07-20T17:47:01.870Z"
    def package_info(purl)
      purl_obj = purl.is_a?(PackageURL) ? purl : PackageURL.parse(purl.to_s)
      
      # Make API request to ecosyste.ms
      uri = URI("#{ECOSYSTE_MS_API_BASE}/packages/lookup")
      uri.query = URI.encode_www_form({ purl: purl_obj.to_s })
      
      response_data = make_request(uri)
      
      return nil unless response_data.is_a?(Array) && response_data.length > 0
      
      package_data = response_data[0]
      
      result = {
        purl: purl_obj.to_s,
        package: extract_package_info(package_data)
      }
      
      # If PURL has a version and we have a versions_url, fetch version-specific details
      if purl_obj.version && package_data["versions_url"]
        version_info = fetch_version_info(package_data["versions_url"], purl_obj.version)
        result[:version] = version_info if version_info
      end
      
      result
    end

    # Look up version information for a specific version of a package
    #
    # @param purl [String, PackageURL] PURL string or PackageURL object (must include version)
    # @return [Hash, nil] Version information hash or nil if not found
    # @raise [LookupError] if the lookup fails due to network or API errors
    # @raise [ArgumentError] if the PURL doesn't include a version
    #
    # @example
    #   lookup = Purl::Lookup.new
    #   version_info = lookup.version_info("pkg:cargo/rand@0.9.2")
    #   puts version_info[:published_at]  # => "2025-07-20T17:47:01.870Z"
    def version_info(purl)
      purl_obj = purl.is_a?(PackageURL) ? purl : PackageURL.parse(purl.to_s)
      
      raise ArgumentError, "PURL must include a version" unless purl_obj.version
      
      # First get the package info to get the versions_url
      package_result = package_info(purl_obj.versionless)
      return nil unless package_result && package_result[:package][:versions_url]
      
      fetch_version_info(package_result[:package][:versions_url], purl_obj.version)
    end

    private

    def make_request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = @timeout
      http.open_timeout = @timeout
      
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = @user_agent
      
      response = http.request(request)
      
      case response.code.to_i
      when 200
        JSON.parse(response.body)
      when 404
        nil
      else
        raise LookupError, "API request failed with status #{response.code}"
      end
    rescue JSON::ParserError => e
      raise LookupError, "Failed to parse API response: #{e.message}"
    rescue Net::TimeoutError, Net::OpenTimeout, Net::ReadTimeout => e
      raise LookupError, "Request timeout: #{e.message}"
    rescue StandardError => e
      raise LookupError, "Lookup failed: #{e.message}"
    end

    def extract_package_info(package_data)
      {
        name: package_data["name"],
        ecosystem: package_data["ecosystem"],
        description: package_data["description"],
        homepage: package_data["homepage"],
        repository_url: package_data["repository_url"],
        registry_url: package_data["registry_url"],
        licenses: package_data["licenses"],
        latest_version: package_data["latest_release_number"],
        latest_version_published_at: package_data["latest_release_published_at"],
        versions_count: package_data["versions_count"],
        keywords: package_data["keywords_array"],
        install_command: package_data["install_command"],
        documentation_url: package_data["documentation_url"],
        maintainers: extract_maintainers(package_data["maintainers"]),
        versions_url: package_data["versions_url"]
      }
    end

    def fetch_version_info(versions_url, version)
      return nil unless versions_url && version
      
      begin
        uri = URI("#{versions_url}/#{URI.encode_www_form_component(version)}")
        data = make_request(uri)
        
        return nil unless data
        
        # Extract relevant version information
        version_info = {
          number: data["number"],
          published_at: data["published_at"],
          version_url: data["version_url"],
          download_url: data["download_url"],
          registry_url: data["registry_url"],
          documentation_url: data["documentation_url"],
          install_command: data["install_command"]
        }
        
        # Add metadata if available
        if data["metadata"]
          metadata = data["metadata"]
          version_info[:downloads] = metadata["downloads"] if metadata["downloads"]
          version_info[:size] = metadata["crate_size"] || metadata["size"] if metadata["crate_size"] || metadata["size"]
          version_info[:yanked] = metadata["yanked"] if metadata.key?("yanked")
          
          if metadata["published_by"] && metadata["published_by"].is_a?(Hash)
            published_by = metadata["published_by"]
            if published_by["name"] && published_by["login"]
              version_info[:published_by] = "#{published_by["name"]} (#{published_by["login"]})"
            elsif published_by["login"]
              version_info[:published_by] = published_by["login"]
            end
          end
        end
        
        version_info
      rescue StandardError
        # Don't fail if version lookup fails
        nil
      end
    end

    def extract_maintainers(maintainers_data)
      return nil unless maintainers_data && maintainers_data.is_a?(Array)
      
      maintainers_data.map do |maintainer|
        {
          login: maintainer["login"],
          name: maintainer["name"],
          url: maintainer["url"]
        }.compact # Remove nil values
      end
    end
  end

  # Error raised when package lookup fails
  class LookupError < Error
    def initialize(message)
      super(message)
    end
  end
end