# frozen_string_literal: true

require_relative "test_helper"

class TestEcosystemsURL < Minitest::Test
  def test_gem_registry_name
    purl = Purl::PackageURL.new(type: "gem", name: "rake", version: "13.3.1")
    assert_equal "rubygems.org", purl.ecosystems_registry
  end

  def test_npm_registry_name
    purl = Purl::PackageURL.new(type: "npm", name: "lodash", version: "4.17.21")
    assert_equal "npmjs.org", purl.ecosystems_registry
  end

  def test_cargo_registry_name
    purl = Purl::PackageURL.new(type: "cargo", name: "serde", version: "1.0.152")
    assert_equal "crates.io", purl.ecosystems_registry
  end

  def test_pypi_registry_name
    purl = Purl::PackageURL.new(type: "pypi", name: "requests", version: "2.28.0")
    assert_equal "pypi.org", purl.ecosystems_registry
  end

  def test_maven_registry_name
    purl = Purl::PackageURL.new(type: "maven", namespace: "org.apache.commons", name: "commons-lang3", version: "3.12.0")
    assert_equal "repo1.maven.org", purl.ecosystems_registry
  end

  def test_nuget_registry_name
    purl = Purl::PackageURL.new(type: "nuget", name: "Newtonsoft.Json", version: "13.0.1")
    assert_equal "nuget.org", purl.ecosystems_registry
  end

  def test_golang_registry_name
    purl = Purl::PackageURL.new(type: "golang", namespace: "github.com/gorilla", name: "mux", version: "v1.8.0")
    assert_equal "proxy.golang.org", purl.ecosystems_registry
  end

  def test_hex_registry_name
    purl = Purl::PackageURL.new(type: "hex", name: "phoenix", version: "1.6.15")
    assert_equal "hex.pm", purl.ecosystems_registry
  end

  def test_pub_registry_name
    purl = Purl::PackageURL.new(type: "pub", name: "http", version: "0.13.5")
    assert_equal "pub.dev", purl.ecosystems_registry
  end

  def test_composer_registry_name
    purl = Purl::PackageURL.new(type: "composer", namespace: "symfony", name: "console", version: "6.0.0")
    assert_equal "packagist.org", purl.ecosystems_registry
  end

  def test_hackage_registry_name
    purl = Purl::PackageURL.new(type: "hackage", name: "aeson", version: "2.1.1.0")
    assert_equal "hackage.haskell.org", purl.ecosystems_registry
  end

  def test_clojars_registry_name
    purl = Purl::PackageURL.new(type: "clojars", namespace: "org.clojure", name: "clojure", version: "1.11.1")
    assert_equal "clojars.org", purl.ecosystems_registry
  end

  def test_elm_registry_name
    purl = Purl::PackageURL.new(type: "elm", namespace: "elm", name: "http", version: "2.0.0")
    assert_equal "package.elm-lang.org", purl.ecosystems_registry
  end

  def test_deno_registry_name
    purl = Purl::PackageURL.new(type: "deno", name: "oak", version: "12.0.0")
    assert_equal "deno.land", purl.ecosystems_registry
  end

  def test_homebrew_registry_name
    purl = Purl::PackageURL.new(type: "homebrew", name: "wget", version: "1.21.3")
    assert_equal "formulae.brew.sh", purl.ecosystems_registry
  end

  def test_bioconductor_registry_name
    purl = Purl::PackageURL.new(type: "bioconductor", name: "IRanges", version: "2.28.0")
    assert_equal "bioconductor.org", purl.ecosystems_registry
  end

  def test_cocoapods_registry_name
    purl = Purl::PackageURL.new(type: "cocoapods", name: "Alamofire", version: "5.6.4")
    assert_equal "cocoapods.org", purl.ecosystems_registry
  end

  def test_swift_registry_name
    purl = Purl::PackageURL.new(type: "swift", namespace: "Alamofire", name: "Alamofire", version: "5.6.4")
    assert_equal "swiftpackageindex.com", purl.ecosystems_registry
  end

  # API URL tests

  def test_gem_version_api_url
    purl = Purl::PackageURL.new(type: "gem", name: "rake", version: "13.3.1")
    expected = "https://packages.ecosyste.ms/api/v1/registries/rubygems.org/packages/rake/versions/13.3.1"
    assert_equal expected, purl.ecosystems_api_url
    assert_equal expected, purl.ecosystems_version_api_url
  end

  def test_gem_package_api_url
    purl = Purl::PackageURL.new(type: "gem", name: "rake")
    expected = "https://packages.ecosyste.ms/api/v1/registries/rubygems.org/packages/rake"
    assert_equal expected, purl.ecosystems_api_url
    assert_equal expected, purl.ecosystems_package_api_url
  end

  def test_npm_scoped_package_api_url
    purl = Purl::PackageURL.new(type: "npm", namespace: "@babel", name: "core", version: "7.20.0")
    expected = "https://packages.ecosyste.ms/api/v1/registries/npmjs.org/packages/%40babel%2Fcore/versions/7.20.0"
    assert_equal expected, purl.ecosystems_api_url
  end

  def test_maven_namespaced_api_url
    purl = Purl::PackageURL.new(type: "maven", namespace: "org.apache.commons", name: "commons-lang3", version: "3.12.0")
    expected = "https://packages.ecosyste.ms/api/v1/registries/repo1.maven.org/packages/org.apache.commons%2Fcommons-lang3/versions/3.12.0"
    assert_equal expected, purl.ecosystems_api_url
  end

  def test_golang_namespaced_api_url
    purl = Purl::PackageURL.new(type: "golang", namespace: "github.com/gorilla", name: "mux", version: "v1.8.0")
    expected = "https://packages.ecosyste.ms/api/v1/registries/proxy.golang.org/packages/github.com%2Fgorilla%2Fmux/versions/v1.8.0"
    assert_equal expected, purl.ecosystems_api_url
  end

  def test_composer_namespaced_api_url
    purl = Purl::PackageURL.new(type: "composer", namespace: "symfony", name: "console", version: "6.0.0")
    expected = "https://packages.ecosyste.ms/api/v1/registries/packagist.org/packages/symfony%2Fconsole/versions/6.0.0"
    assert_equal expected, purl.ecosystems_api_url
  end

  def test_api_url_without_version_returns_package_url
    purl = Purl::PackageURL.new(type: "cargo", name: "serde")
    expected = "https://packages.ecosyste.ms/api/v1/registries/crates.io/packages/serde"
    assert_equal expected, purl.ecosystems_api_url
  end

  def test_version_api_url_returns_nil_without_version
    purl = Purl::PackageURL.new(type: "cargo", name: "serde")
    assert_nil purl.ecosystems_version_api_url
  end

  def test_unsupported_type_returns_nil
    purl = Purl::PackageURL.new(type: "unknown", name: "test", version: "1.0.0")
    assert_nil purl.ecosystems_registry
    assert_nil purl.ecosystems_api_url
  end

  def test_class_methods
    purl = Purl::PackageURL.new(type: "gem", name: "rake", version: "13.3.1")

    assert_equal "rubygems.org", Purl::EcosystemsURL.registry_name(purl)
    assert_equal purl.ecosystems_api_url, Purl::EcosystemsURL.api_url(purl)
    assert_equal purl.ecosystems_package_api_url, Purl::EcosystemsURL.package_api_url(purl)
    assert_equal purl.ecosystems_version_api_url, Purl::EcosystemsURL.version_api_url(purl)
  end

  def test_works_with_purl_string
    purl_string = "pkg:gem/rake@13.3.1"
    expected = "https://packages.ecosyste.ms/api/v1/registries/rubygems.org/packages/rake/versions/13.3.1"
    assert_equal expected, Purl::EcosystemsURL.api_url(purl_string)
  end
end
