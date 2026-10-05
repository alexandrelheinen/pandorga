# frozen_string_literal: true

require_relative "lib/pandorga/version"

Gem::Specification.new do |spec|
  spec.name = "pandorga"
  spec.version = Pandorga::VERSION
  spec.authors = ["The Pandorga contributors"]
  spec.email = ["community@example.com"]

  spec.summary = "Jekyll theme, plugin, and CLI for a static shell with JSON content"
  spec.description = <<~DESC
    Pandorga is a publishing platform: Jekyll shell, browser content runtime,
    JSON export pipeline, and Studio editor. Sites declare pages in a registry;
    the gem supplies templates, gates, and the pandorga CLI.
  DESC
  spec.homepage = "https://github.com/alexandrelheinen/pandorga"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "lib/**/*",
      "exe/*",
      "_layouts/**/*",
      "_includes/**/*",
      "_plugins/**/*",
      "_data/**/*",
      "assets/**/*",
      "templates/**/*",
      "functions/**/*",
      "studio/**/*",
      "studio-app/**/*",
      "scripts/**/*",
      "examples/**/*",
      "DESIGN.md",
      "LICENSE",
      "README.md",
      "CHANGELOG.md"
    ].select { |f| File.file?(f) }
  end
  spec.bindir = "exe"
  spec.executables = ["pandorga"]
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", "~> 4.3"
  spec.add_dependency "jekyll-redirect-from", "~> 0.16"
  spec.add_dependency "jekyll-relative-links", "~> 0.6"
  spec.add_dependency "jekyll-scholar", "~> 7.3"

  spec.add_development_dependency "rake", "~> 13.0"
end
