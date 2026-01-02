# frozen_string_literal: true

require_relative "test_helper"

class TestDownloadURL < Minitest::Test
  def test_gem_download_url
    purl = Purl::PackageURL.new(type: "gem", name: "rails", version: "7.0.0")
    assert_equal "https://rubygems.org/downloads/rails-7.0.0.gem", purl.download_url
  end

  def test_npm_download_url
    purl = Purl::PackageURL.new(type: "npm", name: "lodash", version: "4.17.21")
    assert_equal "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz", purl.download_url
  end

  def test_npm_scoped_download_url
    purl = Purl::PackageURL.new(type: "npm", namespace: "@babel", name: "core", version: "7.20.0")
    assert_equal "https://registry.npmjs.org/@babel/core/-/core-7.20.0.tgz", purl.download_url
  end

  def test_cargo_download_url
    purl = Purl::PackageURL.new(type: "cargo", name: "serde", version: "1.0.152")
    assert_equal "https://static.crates.io/crates/serde/serde-1.0.152.crate", purl.download_url
  end

  def test_nuget_download_url
    purl = Purl::PackageURL.new(type: "nuget", name: "Newtonsoft.Json", version: "13.0.1")
    assert_equal "https://api.nuget.org/v3-flatcontainer/newtonsoft.json/13.0.1/newtonsoft.json.13.0.1.nupkg", purl.download_url
  end

  def test_hex_download_url
    purl = Purl::PackageURL.new(type: "hex", name: "phoenix", version: "1.6.15")
    assert_equal "https://repo.hex.pm/tarballs/phoenix-1.6.15.tar", purl.download_url
  end

  def test_hackage_download_url
    purl = Purl::PackageURL.new(type: "hackage", name: "aeson", version: "2.1.1.0")
    assert_equal "https://hackage.haskell.org/package/aeson-2.1.1.0/aeson-2.1.1.0.tar.gz", purl.download_url
  end

  def test_pub_download_url
    purl = Purl::PackageURL.new(type: "pub", name: "http", version: "0.13.5")
    assert_equal "https://pub.dev/packages/http/versions/0.13.5.tar.gz", purl.download_url
  end

  def test_golang_download_url
    purl = Purl::PackageURL.new(type: "golang", namespace: "github.com/gorilla", name: "mux", version: "v1.8.0")
    assert_equal "https://proxy.golang.org/github.com/gorilla/mux/@v/v1.8.0.zip", purl.download_url
  end

  def test_golang_download_url_with_capitals
    purl = Purl::PackageURL.new(type: "golang", namespace: "github.com/Azure", name: "azure-sdk-for-go", version: "v1.0.0")
    assert_equal "https://proxy.golang.org/github.com/!azure/azure-sdk-for-go/@v/v1.0.0.zip", purl.download_url
  end

  def test_maven_download_url
    purl = Purl::PackageURL.new(type: "maven", namespace: "org.apache.commons", name: "commons-lang3", version: "3.12.0")
    assert_equal "https://repo.maven.apache.org/maven2/org/apache/commons/commons-lang3/3.12.0/commons-lang3-3.12.0.jar", purl.download_url
  end

  def test_download_url_requires_version
    purl = Purl::PackageURL.new(type: "gem", name: "rails")
    assert_raises(Purl::MissingVersionError) do
      purl.download_url
    end
  end

  def test_unsupported_type_download_url
    purl = Purl::PackageURL.new(type: "unknown", name: "test", version: "1.0.0")
    assert_raises(Purl::UnsupportedTypeError) do
      purl.download_url
    end
  end

  def test_supports_download_url
    gem_purl = Purl::PackageURL.new(type: "gem", name: "rails", version: "7.0.0")
    unknown_purl = Purl::PackageURL.new(type: "unknown", name: "test", version: "1.0.0")

    assert gem_purl.supports_download_url?
    refute unknown_purl.supports_download_url?
  end

  def test_download_url_with_custom_base_url
    purl = Purl::PackageURL.new(type: "gem", name: "rails", version: "7.0.0")
    custom_url = purl.download_url(base_url: "https://gems.internal.com/downloads")
    assert_equal "https://gems.internal.com/downloads/rails-7.0.0.gem", custom_url
  end

  def test_download_url_with_repository_url_qualifier
    purl = Purl::PackageURL.new(
      type: "gem",
      name: "rails",
      version: "7.0.0",
      qualifiers: { "repository_url" => "https://gems.mycompany.com/downloads" }
    )
    assert_equal "https://gems.mycompany.com/downloads/rails-7.0.0.gem", purl.download_url
  end

  def test_download_url_explicit_base_url_overrides_qualifier
    purl = Purl::PackageURL.new(
      type: "gem",
      name: "rails",
      version: "7.0.0",
      qualifiers: { "repository_url" => "https://gems.qualifier.com/downloads" }
    )
    custom_url = purl.download_url(base_url: "https://gems.explicit.com/downloads")
    assert_equal "https://gems.explicit.com/downloads/rails-7.0.0.gem", custom_url
  end

  def test_maven_download_url_with_custom_repository
    purl = Purl::PackageURL.new(
      type: "maven",
      namespace: "com.example",
      name: "mylib",
      version: "1.0.0",
      qualifiers: { "repository_url" => "https://artifactory.internal.com/maven" }
    )
    assert_equal "https://artifactory.internal.com/maven/com/example/mylib/1.0.0/mylib-1.0.0.jar", purl.download_url
  end

  def test_npm_download_url_with_custom_registry
    purl = Purl::PackageURL.new(
      type: "npm",
      name: "lodash",
      version: "4.17.21",
      qualifiers: { "repository_url" => "https://npm.mycompany.com" }
    )
    assert_equal "https://npm.mycompany.com/lodash/-/lodash-4.17.21.tgz", purl.download_url
  end

  def test_cran_download_url
    purl = Purl::PackageURL.new(type: "cran", name: "ggplot2", version: "3.4.0")
    assert_equal "https://cran.r-project.org/src/contrib/ggplot2_3.4.0.tar.gz", purl.download_url
  end

  def test_bioconductor_download_url
    purl = Purl::PackageURL.new(type: "bioconductor", name: "IRanges", version: "2.28.0")
    assert_equal "https://bioconductor.org/packages/release/bioc/src/contrib/IRanges_2.28.0.tar.gz", purl.download_url
  end

  def test_clojars_download_url_with_namespace
    purl = Purl::PackageURL.new(type: "clojars", namespace: "org.clojure", name: "clojure", version: "1.11.1")
    assert_equal "https://repo.clojars.org/org/clojure/clojure/1.11.1/clojure-1.11.1.jar", purl.download_url
  end

  def test_clojars_download_url_without_namespace
    purl = Purl::PackageURL.new(type: "clojars", name: "ring", version: "1.9.5")
    assert_equal "https://repo.clojars.org/ring/ring/1.9.5/ring-1.9.5.jar", purl.download_url
  end

  def test_elm_download_url
    purl = Purl::PackageURL.new(type: "elm", namespace: "elm", name: "http", version: "2.0.0")
    assert_equal "https://github.com/elm/http/archive/2.0.0.zip", purl.download_url
  end

  def test_github_download_url
    purl = Purl::PackageURL.new(type: "github", namespace: "rails", name: "rails", version: "v7.0.0")
    assert_equal "https://github.com/rails/rails/archive/refs/tags/v7.0.0.tar.gz", purl.download_url
  end

  def test_gitlab_download_url
    purl = Purl::PackageURL.new(type: "gitlab", namespace: "gitlab-org", name: "gitlab", version: "v16.0.0")
    assert_equal "https://gitlab.com/gitlab-org/gitlab/-/archive/v16.0.0/gitlab-v16.0.0.tar.gz", purl.download_url
  end

  def test_bitbucket_download_url
    purl = Purl::PackageURL.new(type: "bitbucket", namespace: "atlassian", name: "python-bitbucket", version: "0.1.0")
    assert_equal "https://bitbucket.org/atlassian/python-bitbucket/get/0.1.0.tar.gz", purl.download_url
  end

  def test_luarocks_download_url
    purl = Purl::PackageURL.new(type: "luarocks", namespace: "luasocket", name: "luasocket", version: "3.0rc1-2")
    assert_equal "https://luarocks.org/manifests/luasocket/luasocket-3.0rc1-2.src.rock", purl.download_url
  end

  def test_swift_download_url_github
    purl = Purl::PackageURL.new(type: "swift", namespace: "github.com/Alamofire", name: "Alamofire", version: "5.6.4")
    assert_equal "https://github.com/Alamofire/Alamofire/archive/refs/tags/5.6.4.tar.gz", purl.download_url
  end

  def test_swift_download_url_gitlab
    purl = Purl::PackageURL.new(type: "swift", namespace: "gitlab.com/example", name: "mypackage", version: "1.0.0")
    assert_equal "https://gitlab.com/example/mypackage/-/archive/1.0.0/mypackage-1.0.0.tar.gz", purl.download_url
  end

  def test_elm_requires_namespace
    purl = Purl::PackageURL.new(type: "elm", name: "http", version: "2.0.0")
    assert_raises(Purl::UnsupportedTypeError) do
      purl.download_url
    end
  end

  def test_github_requires_namespace
    purl = Purl::PackageURL.new(type: "github", name: "rails", version: "v7.0.0")
    assert_raises(Purl::UnsupportedTypeError) do
      purl.download_url
    end
  end

  def test_supported_types
    supported = Purl::DownloadURL.supported_types

    assert_includes supported, "gem"
    assert_includes supported, "npm"
    assert_includes supported, "cargo"
    assert_includes supported, "nuget"
    assert_includes supported, "hex"
    assert_includes supported, "hackage"
    assert_includes supported, "pub"
    assert_includes supported, "golang"
    assert_includes supported, "maven"
    assert_includes supported, "cran"
    assert_includes supported, "bioconductor"
    assert_includes supported, "clojars"
    assert_includes supported, "elm"
    assert_includes supported, "github"
    assert_includes supported, "gitlab"
    assert_includes supported, "bitbucket"
    assert_includes supported, "luarocks"
    assert_includes supported, "swift"
  end

  def test_download_supported_types_module_method
    supported = Purl.download_supported_types

    assert_instance_of Array, supported
    assert_includes supported, "gem"
    assert_includes supported, "npm"
  end

  def test_type_info_includes_download_url_generation
    gem_info = Purl.type_info("gem")
    assert gem_info[:download_url_generation]

    unknown_info = Purl.type_info("unknown")
    refute unknown_info[:download_url_generation]
  end
end
