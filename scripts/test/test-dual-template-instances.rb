# frozen_string_literal: true

# Refs: PLT-AC-4 — same template twice with different collections yields two pages.
require "pathname"
require "yaml"
require "tmpdir"
require "jekyll"

ROOT = Pathname.new(__dir__).join("../..").expand_path
$LOAD_PATH.unshift(ROOT.join("lib").to_s)
require "pandorga/registry"
require "pandorga/jekyll/generator"

FIXTURE = ROOT.join("scripts/test/fixtures/dual-template")
config_path = FIXTURE.join("_config.yml")
unless config_path.file?
  warn "FAIL test-dual-template-instances: missing #{config_path}"
  exit 1
end

site_yaml = YAML.safe_load(config_path.read, aliases: true)
pages = PandorgaRegistry.pages(site_yaml)

begin
  PandorgaRegistry.validate!(pages)
rescue ArgumentError => e
  warn "FAIL test-dual-template-instances: registry rejected dual articles: #{e.message}"
  exit 1
end

article_pages = pages.select { |p| p["template"].to_s == "articles" }
unless article_pages.length == 2
  warn "FAIL test-dual-template-instances: expected 2 articles pages, got #{article_pages.length}"
  exit 1
end

collections = article_pages.map { |p| p["collection"].to_s }.uniq
paths = article_pages.map { |p| p["path"].to_s }.uniq
keys = article_pages.map { |p| p["key"].to_s }.uniq
unless collections.length == 2 && paths.length == 2 && keys.length == 2
  warn "FAIL test-dual-template-instances: dual pages must differ in key, collection, and path"
  exit 1
end

writing = PandorgaRegistry.writing_collections(pages)
collections.each do |name|
  unless writing.key?(name)
    warn "FAIL test-dual-template-instances: writing_collections missing #{name.inspect}"
    exit 1
  end
end

Dir.mktmpdir("pandorga-dual-template") do |dest|
  jekyll_config = Jekyll.configuration(
    "source" => FIXTURE.to_s,
    "destination" => dest,
    "quiet" => true,
    "safe" => false
  )
  # Overlay pandorga registry from the fixture without requiring a theme build.
  jekyll_config["pandorga"] = site_yaml["pandorga"]

  site = Jekyll::Site.new(jekyll_config)
  Pandorga::Jekyll::Generator.new.generate(site)

  generated = site.pages.select { |p| keys.include?(p.data["key"].to_s) }
  got_keys = generated.map { |p| p.data["key"].to_s }.sort
  unless got_keys == keys.sort
    warn "FAIL test-dual-template-instances: generator pages #{got_keys.inspect}, expected #{keys.sort.inspect}"
    exit 1
  end

  got_paths = generated.map { |p| p.data["permalink"].to_s }.sort
  expected_paths = paths.map { |p| p.end_with?("/") ? p : "#{p}/" }.sort
  unless got_paths == expected_paths
    warn "FAIL test-dual-template-instances: permalinks #{got_paths.inspect}, expected #{expected_paths.inspect}"
    exit 1
  end

  layouts = generated.map { |p| p.data["layout"].to_s }.uniq
  unless layouts == ["articles"]
    warn "FAIL test-dual-template-instances: expected articles layout for both, got #{layouts.inspect}"
    exit 1
  end
end

puts "PASS test-dual-template-instances"
