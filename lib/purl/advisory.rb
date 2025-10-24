# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "timeout"

module Purl
  # Provides advisory lookup functionality for packages using the advisories.ecosyste.ms API
  class Advisory
    ADVISORIES_API_BASE = "https://advisories.ecosyste.ms/api/v1"

    # Initialize a new Advisory instance
    #
    # @param user_agent [String] User agent string for API requests
    # @param timeout [Integer] Request timeout in seconds
    def initialize(user_agent: nil, timeout: 10)
      @user_agent = user_agent || "purl-ruby/#{Purl::VERSION}"
      @timeout = timeout
    end

    # Look up security advisories for a given PURL
    #
    # @param purl [String, PackageURL] PURL string or PackageURL object
    # @return [Array<Hash>, nil] Array of advisory hashes or nil if none found
    # @raise [AdvisoryError] if the lookup fails due to network or API errors
    #
    # @example
    #   advisory = Purl::Advisory.new
    #   advisories = advisory.lookup("pkg:npm/lodash@4.17.20")
    #   advisories.each { |adv| puts adv[:title] }
    def lookup(purl)
      purl_obj = purl.is_a?(PackageURL) ? purl : PackageURL.parse(purl.to_s)

      # Query advisories API
      uri = URI("#{ADVISORIES_API_BASE}/advisories/lookup")
      uri.query = URI.encode_www_form({ purl: purl_obj.to_s })

      response_data = make_request(uri)

      if response_data.is_a?(Array) && response_data.length > 0
        advisories = response_data.map { |advisory_data| extract_advisory_info(advisory_data) }

        # Filter by version if specified
        if purl_obj.version
          advisories = filter_by_version(advisories, purl_obj.version)
        end

        return advisories
      end

      []
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
        []
      else
        raise AdvisoryError, "API request failed with status #{response.code}"
      end
    rescue JSON::ParserError => e
      raise AdvisoryError, "Failed to parse API response: #{e.message}"
    rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout => e
      raise AdvisoryError, "Request timeout: #{e.message}"
    rescue StandardError => e
      raise AdvisoryError, "Advisory lookup failed: #{e.message}"
    end

    def extract_advisory_info(advisory_data)
      {
        id: advisory_data["uuid"],
        title: advisory_data["title"],
        description: advisory_data["description"],
        severity: advisory_data["severity"],
        cvss_score: advisory_data["cvss_score"],
        cvss_vector: advisory_data["cvss_vector"],
        url: advisory_data["url"],
        repository_url: advisory_data["repository_url"],
        published_at: advisory_data["published_at"],
        updated_at: advisory_data["updated_at"],
        withdrawn_at: advisory_data["withdrawn_at"],
        source_kind: advisory_data["source_kind"],
        origin: advisory_data["origin"],
        classification: advisory_data["classification"],
        affected_packages: extract_affected_packages(advisory_data["packages"]),
        references: advisory_data["references"],
        identifiers: advisory_data["identifiers"]
      }.compact
    end

    def extract_affected_packages(packages)
      return [] unless packages && packages.is_a?(Array)

      packages.map do |pkg|
        version_info = pkg["versions"]&.first || {}
        {
          ecosystem: pkg["ecosystem"],
          name: pkg["package_name"],
          purl: pkg["purl"],
          vulnerable_version_range: version_info["vulnerable_version_range"],
          first_patched_version: version_info["first_patched_version"]
        }.compact
      end
    end

    def filter_by_version(advisories, version)
      # For now, return all advisories if version is specified
      # More sophisticated version range matching could be added later
      advisories
    end
  end

  # Error raised when advisory lookup fails
  class AdvisoryError < Error
    def initialize(message)
      super(message)
    end
  end
end
