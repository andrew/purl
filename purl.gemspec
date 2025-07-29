# frozen_string_literal: true

require_relative "lib/purl/version"

Gem::Specification.new do |spec|
  spec.name = "purl"
  spec.version = Purl::VERSION
  spec.authors = ["Andrew Nesbitt"]
  spec.email = ["andrewnez@gmail.com"]

  spec.summary = "Parse and convert package urls (purls)"
  spec.description = "This library features comprehensive error handling with namespaced error types, bidirectional registry URL conversion, and JSON-based configuration for cross-language compatibility.
It supports 37 package types (32 official + 5 additional ecosystems) and is fully compliant with the official PURL specification test suite."
  spec.homepage = "https://github.com/andrew/purl"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/andrew/purl"
  spec.metadata["changelog_uri"] = "https://github.com/andrew/purl/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "addressable", "~> 2.8"
end
