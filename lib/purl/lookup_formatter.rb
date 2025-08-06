# frozen_string_literal: true

module Purl
  # Formats package lookup results for human-readable display
  class LookupFormatter
    def initialize
    end

    # Format package lookup results for console output
    #
    # @param lookup_result [Hash] Result from Purl::Lookup#package_info
    # @param purl [PackageURL] Original PURL object
    # @return [String] Formatted output string
    def format_text(lookup_result, purl)
      return "Package not found" unless lookup_result

      if lookup_result[:package]
        format_package_text(lookup_result, purl)
      elsif lookup_result[:repository]
        format_repository_text(lookup_result, purl)
      else
        "No information found"
      end
    end

    # Format package lookup results for JSON output
    #
    # @param lookup_result [Hash] Result from Purl::Lookup#package_info
    # @param purl [PackageURL] Original PURL object
    # @return [Hash] JSON-ready hash structure
    def format_json(lookup_result, purl)
      return {
        success: false,
        purl: purl.to_s,
        error: "Package not found in ecosyste.ms database"
      } unless lookup_result

      result = {
        success: true,
        purl: purl.to_s
      }
      
      if lookup_result[:package]
        result[:package] = lookup_result[:package]
        result[:version] = lookup_result[:version] if lookup_result[:version]
      elsif lookup_result[:repository]
        result[:repository] = lookup_result[:repository]
      end
      
      result
    end

    private

    def format_package_text(lookup_result, purl)
      package = lookup_result[:package]
      version_info = lookup_result[:version]
      
      output = []
      
      # Package header
      output << "Package: #{package[:name]} (#{package[:ecosystem]})"
      output << "#{package[:description]}" if package[:description]
      
      # Keywords - add without extra spacing, the blank line before Version Info will handle spacing
      if package[:keywords] && !package[:keywords].empty?
        output << "Keywords: #{package[:keywords].join(", ")}"
      end
      
      # Version Information section
      output << ""
      output << "Version Information:"
      if package[:latest_version]
        output << "  Latest: #{package[:latest_version]}"
        output << "  Published: #{package[:latest_version_published_at]}" if package[:latest_version_published_at]
      end
      output << "  Total versions: #{format_number(package[:versions_count])}" if package[:versions_count]
      
      # Links section
      output << ""
      output << "Links:"
      output << "  Homepage: #{package[:homepage]}" if package[:homepage]
      output << "  Repository: #{package[:repository_url]}" if package[:repository_url]
      output << "  Registry: #{package[:registry_url]}" if package[:registry_url]
      output << "  Documentation: #{package[:documentation_url]}" if package[:documentation_url]
      
      # Package Info section
      if package[:licenses] || package[:install_command] || package[:maintainers]
        output << ""
        output << "Package Info:"
        output << "  License: #{package[:licenses]}" if package[:licenses]
        output << "  Install: #{package[:install_command]}" if package[:install_command]
        
        if package[:maintainers] && !package[:maintainers].empty?
          output << "  Maintainers:"
          package[:maintainers].each do |maintainer|
            if maintainer[:name] && maintainer[:login]
              output << "    #{maintainer[:name]} (#{maintainer[:login]})"
            elsif maintainer[:login]
              output << "    #{maintainer[:login]}"
            end
          end
        end
      end
      
      # Version-specific details
      if version_info
        output << ""
        output << "Specific Version (#{purl.version}):"
        output << "  Published: #{version_info[:published_at]}" if version_info[:published_at]
        output << "  Published by: #{version_info[:published_by]}" if version_info[:published_by]
        output << "  Downloads: #{format_number(version_info[:downloads])}" if version_info[:downloads]
        output << "  Size: #{format_number(version_info[:size])} bytes" if version_info[:size]
        output << "  Yanked: #{version_info[:yanked] ? 'Yes' : 'No'}" if version_info.key?(:yanked)
        
        if version_info[:registry_url] || version_info[:documentation_url] || version_info[:download_url]
          output << "  Version Links:"
          output << "    Registry: #{version_info[:registry_url]}" if version_info[:registry_url]
          output << "    Documentation: #{version_info[:documentation_url]}" if version_info[:documentation_url]
          output << "    Download: #{version_info[:download_url]}" if version_info[:download_url]
          output << "    API: #{version_info[:version_url]}" if version_info[:version_url]
        end
      end
      
      output.join("\n")
    end

    def format_repository_text(lookup_result, purl)
      repository = lookup_result[:repository]
      
      output = []
      
      # Repository header - map to package-like format
      output << "Package: #{repository[:name]} (repository)"
      output << "#{repository[:description]}" if repository[:description]
      
      # Repository stats section (maps to version info)
      output << ""
      output << "Version Information:"
      output << "  Default branch: #{repository[:default_branch]}" if repository[:default_branch]
      output << "  Last updated: #{repository[:pushed_at]}" if repository[:pushed_at]
      output << "  Created: #{repository[:created_at]}" if repository[:created_at]
      
      # Links section
      output << ""
      output << "Links:"
      output << "  Homepage: #{repository[:homepage]}" if repository[:homepage]
      output << "  Repository: #{repository[:url]}" if repository[:url]
      
      # Package Info section (repository stats)
      output << ""
      output << "Package Info:"
      output << "  Language: #{repository[:language]}" if repository[:language]
      output << "  License: #{repository[:license]}" if repository[:license]
      output << "  Stars: #{format_number(repository[:stars])}" if repository[:stars]
      output << "  Forks: #{format_number(repository[:forks])}" if repository[:forks]
      output << "  Open issues: #{format_number(repository[:open_issues])}" if repository[:open_issues]
      output << "  Fork: #{repository[:fork] ? 'Yes' : 'No'}" if !repository[:fork].nil?
      output << "  Archived: #{repository[:archived] ? 'Yes' : 'No'}" if !repository[:archived].nil?
      
      if repository[:topics] && !repository[:topics].empty?
        output << "  Topics: #{repository[:topics].join(", ")}"
      end
      
      output.join("\n")
    end

    private

    def format_number(num)
      return num.to_s unless num.is_a?(Numeric)
      num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end
end