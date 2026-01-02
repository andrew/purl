# frozen_string_literal: true

module Purl
  class DownloadURL
    DOWNLOAD_PATTERNS = {
      "gem" => {
        base_url: "https://rubygems.org/downloads",
        pattern: ->(purl) { "#{purl.name}-#{purl.version}.gem" }
      },
      "npm" => {
        base_url: "https://registry.npmjs.org",
        pattern: ->(purl) do
          # npm: /{name}/-/{basename}-{version}.tgz
          # For scoped packages: /@scope/name/-/name-version.tgz
          basename = purl.name.split("/").last
          if purl.namespace
            "#{purl.namespace}/#{purl.name}/-/#{basename}-#{purl.version}.tgz"
          else
            "#{purl.name}/-/#{purl.name}-#{purl.version}.tgz"
          end
        end
      },
      "cargo" => {
        base_url: "https://static.crates.io/crates",
        pattern: ->(purl) { "#{purl.name}/#{purl.name}-#{purl.version}.crate" }
      },
      "nuget" => {
        base_url: "https://api.nuget.org/v3-flatcontainer",
        pattern: ->(purl) do
          name_lower = purl.name.downcase
          "#{name_lower}/#{purl.version}/#{name_lower}.#{purl.version}.nupkg"
        end
      },
      "hex" => {
        base_url: "https://repo.hex.pm/tarballs",
        pattern: ->(purl) { "#{purl.name}-#{purl.version}.tar" }
      },
      "hackage" => {
        base_url: "https://hackage.haskell.org/package",
        pattern: ->(purl) { "#{purl.name}-#{purl.version}/#{purl.name}-#{purl.version}.tar.gz" }
      },
      "pub" => {
        base_url: "https://pub.dev/packages",
        pattern: ->(purl) { "#{purl.name}/versions/#{purl.version}.tar.gz" }
      },
      "golang" => {
        base_url: "https://proxy.golang.org",
        pattern: ->(purl) do
          # Go module proxy requires encoding capital letters as !lowercase
          full_path = purl.namespace ? "#{purl.namespace}/#{purl.name}" : purl.name
          encoded = full_path.gsub(/[A-Z]/) { |s| "!#{s.downcase}" }
          "#{encoded}/@v/#{purl.version}.zip"
        end
      },
      "maven" => {
        base_url: "https://repo.maven.apache.org/maven2",
        pattern: ->(purl) do
          # Maven: /{group_path}/{artifact}/{version}/{artifact}-{version}.jar
          # group_id uses dots, path uses slashes
          group_path = purl.namespace.gsub(".", "/")
          "#{group_path}/#{purl.name}/#{purl.version}/#{purl.name}-#{purl.version}.jar"
        end
      },
      "cran" => {
        base_url: "https://cran.r-project.org/src/contrib",
        pattern: ->(purl) { "#{purl.name}_#{purl.version}.tar.gz" }
      },
      "bioconductor" => {
        base_url: "https://bioconductor.org/packages/release/bioc/src/contrib",
        pattern: ->(purl) { "#{purl.name}_#{purl.version}.tar.gz" }
      },
      "clojars" => {
        base_url: "https://repo.clojars.org",
        pattern: ->(purl) do
          # Clojars uses maven-style paths
          # namespace is group_id, name is artifact_id
          # If no namespace, group_id = artifact_id
          group_id = purl.namespace || purl.name
          artifact_id = purl.name
          group_path = group_id.gsub(".", "/")
          "#{group_path}/#{artifact_id}/#{purl.version}/#{artifact_id}-#{purl.version}.jar"
        end
      },
      "elm" => {
        base_url: "https://github.com",
        pattern: ->(purl) do
          # Elm packages are hosted on GitHub
          # namespace/name format maps to GitHub user/repo
          return nil unless purl.namespace
          "#{purl.namespace}/#{purl.name}/archive/#{purl.version}.zip"
        end
      },
      "github" => {
        base_url: "https://github.com",
        pattern: ->(purl) do
          return nil unless purl.namespace
          "#{purl.namespace}/#{purl.name}/archive/refs/tags/#{purl.version}.tar.gz"
        end
      },
      "gitlab" => {
        base_url: "https://gitlab.com",
        pattern: ->(purl) do
          return nil unless purl.namespace
          "#{purl.namespace}/#{purl.name}/-/archive/#{purl.version}/#{purl.name}-#{purl.version}.tar.gz"
        end
      },
      "bitbucket" => {
        base_url: "https://bitbucket.org",
        pattern: ->(purl) do
          return nil unless purl.namespace
          "#{purl.namespace}/#{purl.name}/get/#{purl.version}.tar.gz"
        end
      },
      "luarocks" => {
        base_url: "https://luarocks.org/manifests",
        pattern: ->(purl) do
          return nil unless purl.namespace
          "#{purl.namespace}/#{purl.name}-#{purl.version}.src.rock"
        end
      },
      "swift" => {
        base_url: nil,
        pattern: ->(purl) do
          # Swift namespace is like "github.com/owner", name is repo
          # e.g. pkg:swift/github.com/Alamofire/Alamofire@5.6.4
          return nil unless purl.namespace
          parts = purl.namespace.split("/", 2)
          host = parts[0]
          owner = parts[1]
          return nil unless host && owner

          case host
          when "github.com"
            "https://github.com/#{owner}/#{purl.name}/archive/refs/tags/#{purl.version}.tar.gz"
          when "gitlab.com"
            "https://gitlab.com/#{owner}/#{purl.name}/-/archive/#{purl.version}/#{purl.name}-#{purl.version}.tar.gz"
          when "bitbucket.org"
            "https://bitbucket.org/#{owner}/#{purl.name}/get/#{purl.version}.tar.gz"
          end
        end
      },
      "composer" => {
        base_url: nil,
        pattern: ->(purl) { nil },
        note: "Composer packages are downloaded from source repositories, not Packagist"
      },
      "cocoapods" => {
        base_url: nil,
        pattern: ->(purl) { nil },
        note: "CocoaPods packages are downloaded from source repositories"
      }
    }.freeze

    def self.generate(purl, base_url: nil)
      new(purl).generate(base_url: base_url)
    end

    # Types that require a namespace for download URLs
    NAMESPACE_REQUIRED_TYPES = %w[maven elm github gitlab bitbucket luarocks swift].freeze

    def self.supported_types
      DOWNLOAD_PATTERNS.keys.select do |k|
        pattern = DOWNLOAD_PATTERNS[k]
        # Skip types with notes (they're not really supported)
        next false if pattern[:note]

        # Test with appropriate namespace for types that need it
        namespace = if NAMESPACE_REQUIRED_TYPES.include?(k)
          k == "swift" ? "github.com/test" : "test"
        end
        begin
          result = pattern[:pattern].call(Purl::PackageURL.new(type: k, name: "test", version: "1.0", namespace: namespace))
          !result.nil?
        rescue
          false
        end
      end.sort
    end

    def self.supports?(type)
      pattern = DOWNLOAD_PATTERNS[type.to_s.downcase]
      return false unless pattern
      # Types with base_url are supported, or types that return full URLs (like swift)
      return true if pattern[:base_url]
      # Check if this type returns full URLs by testing with a sample
      return false if pattern[:note] # Has a note means it's not really supported
      true
    end

    def initialize(purl)
      @purl = purl
    end

    def generate(base_url: nil)
      unless @purl.version
        raise MissingVersionError.new(
          "Download URL requires a version",
          type: @purl.type
        )
      end

      pattern_config = DOWNLOAD_PATTERNS[@purl.type.downcase]

      unless pattern_config
        raise UnsupportedTypeError.new(
          "No download URL pattern defined for type '#{@purl.type}'. Supported types: #{self.class.supported_types.join(", ")}",
          type: @purl.type,
          supported_types: self.class.supported_types
        )
      end

      # Check for repository_url qualifier in the PURL
      qualifier_base_url = @purl.qualifiers&.dig("repository_url")

      # Generate the path/URL from the pattern
      path = pattern_config[:pattern].call(@purl)

      if path.nil?
        raise UnsupportedTypeError.new(
          "Could not generate download URL for '#{@purl.type}'. #{pattern_config[:note]}",
          type: @purl.type,
          supported_types: self.class.supported_types
        )
      end

      # If the pattern returns a full URL, use it directly
      return path if path.start_with?("http://", "https://")

      # For relative paths, we need a base_url
      effective_base_url = base_url || qualifier_base_url || pattern_config[:base_url]

      unless effective_base_url
        raise UnsupportedTypeError.new(
          "Download URLs are not available for type '#{@purl.type}'. #{pattern_config[:note]}",
          type: @purl.type,
          supported_types: self.class.supported_types
        )
      end

      "#{effective_base_url}/#{path}"
    end

    attr_reader :purl
  end

  # Error for missing version
  class MissingVersionError < Error
    attr_reader :type

    def initialize(message, type: nil)
      @type = type
      super(message)
    end
  end

  # Add download URL generation methods to PackageURL
  class PackageURL
    def download_url(base_url: nil)
      DownloadURL.generate(self, base_url: base_url)
    end

    def supports_download_url?
      DownloadURL.supports?(type)
    end
  end
end
