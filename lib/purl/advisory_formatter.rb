# frozen_string_literal: true

module Purl
  # Formats security advisory lookup results for human-readable display
  class AdvisoryFormatter
    def initialize
    end

    # Format advisory lookup results for console output
    #
    # @param advisories [Array<Hash>] Array of advisory hashes from Purl::Advisory#lookup
    # @param purl [PackageURL] Original PURL object
    # @return [String] Formatted output string
    def format_text(advisories, purl)
      return "No security advisories found" if advisories.nil? || advisories.empty?

      output = []
      output << "Security Advisories for #{purl.to_s}"
      output << "=" * 80
      output << ""

      advisories.each_with_index do |advisory, index|
        output << format_advisory_text(advisory, index + 1)
        output << "" unless index == advisories.length - 1
      end

      output << ""
      output << "Total advisories found: #{advisories.length}"

      output.join("\n")
    end

    # Format advisory lookup results for JSON output
    #
    # @param advisories [Array<Hash>] Array of advisory hashes from Purl::Advisory#lookup
    # @param purl [PackageURL] Original PURL object
    # @return [Hash] JSON-ready hash structure
    def format_json(advisories, purl)
      {
        success: true,
        purl: purl.to_s,
        advisories: advisories,
        count: advisories.length
      }
    end

    private

    def format_advisory_text(advisory, number)
      output = []

      # Header with identifiers
      identifiers = format_identifiers(advisory)
      output << "Advisory ##{number}: #{advisory[:title]}"
      output << "Identifiers: #{identifiers}" if identifiers

      # Severity and scoring
      if advisory[:severity] || advisory[:cvss_score]
        severity_line = []
        severity_line << "Severity: #{advisory[:severity]}" if advisory[:severity]
        if advisory[:cvss_score] && advisory[:cvss_score] > 0
          severity_line << "CVSS Score: #{advisory[:cvss_score]}"
        end
        output << severity_line.join(" | ")
      end

      # Description
      if advisory[:description]
        output << ""
        output << "Description:"
        output << wrap_text(advisory[:description], 78, "  ")
      end

      # Affected packages
      if advisory[:affected_packages] && !advisory[:affected_packages].empty?
        output << ""
        output << "Affected Packages:"
        advisory[:affected_packages].each do |pkg|
          version_info = []
          version_info << "  Package: #{pkg[:ecosystem]}/#{pkg[:name]}"
          version_info << "  Vulnerable: #{pkg[:vulnerable_version_range]}" if pkg[:vulnerable_version_range]
          version_info << "  Patched: #{pkg[:first_patched_version]}" if pkg[:first_patched_version]
          output.concat(version_info)
        end
      end

      # Source and dates
      output << ""
      source_info = []
      source_info << "Source: #{advisory[:source_kind]}" if advisory[:source_kind]
      source_info << "Origin: #{advisory[:origin]}" if advisory[:origin]
      source_info << "Published: #{format_date(advisory[:published_at])}" if advisory[:published_at]
      output << source_info.join(" | ") unless source_info.empty?

      if advisory[:withdrawn_at]
        output << "Status: WITHDRAWN on #{format_date(advisory[:withdrawn_at])}"
      end

      # URLs
      urls = []
      urls << "Advisory URL: #{advisory[:url]}" if advisory[:url]
      urls << "Repository: #{advisory[:repository_url]}" if advisory[:repository_url]
      output.concat(urls) unless urls.empty?

      # References
      if advisory[:references] && !advisory[:references].empty? && advisory[:references].any? { |ref| ref.is_a?(String) && !ref.empty? }
        output << ""
        output << "References:"
        advisory[:references].each do |ref|
          output << "  - #{ref}" if ref.is_a?(String) && !ref.empty?
        end
      end

      output.join("\n")
    end

    def format_identifiers(advisory)
      return nil unless advisory[:identifiers] && !advisory[:identifiers].empty?
      advisory[:identifiers].join(", ")
    end

    def format_date(date_string)
      return nil unless date_string
      # Keep ISO format for now, could parse and reformat if needed
      date_string
    end

    def wrap_text(text, width, indent = "")
      return text unless text

      # Split on double newlines to preserve paragraph breaks
      paragraphs = text.split(/\n\n+/)

      wrapped_paragraphs = paragraphs.map do |paragraph|
        # Replace single newlines within a paragraph with spaces
        # but preserve intentional formatting (like lists)
        paragraph = paragraph.gsub(/\n/, " ")

        # Wrap the paragraph
        words = paragraph.split(/\s+/)
        lines = []
        current_line = indent.dup

        words.each do |word|
          if (current_line + word).length > width
            lines << current_line.rstrip
            current_line = indent + word + " "
          else
            current_line += word + " "
          end
        end

        lines << current_line.rstrip unless current_line.strip.empty?
        lines.join("\n")
      end

      wrapped_paragraphs.join("\n#{indent}\n")
    end
  end
end
