# frozen_string_literal: true

# Refs: PLT-AC-4 — dual template instances emit distinct listing runtime config in HTML.
require "pathname"
require "yaml"
require "tmpdir"
require "jekyll"
require "liquid"

ROOT = Pathname.new(__dir__).join("../..").expand_path
$LOAD_PATH.unshift(ROOT.join("lib").to_s)
require "pandorga/registry"
require "pandorga/jekyll/generator"

FIXTURE = ROOT.join("scripts/test/fixtures/dual-template")
ATTRS_INCLUDE = ROOT.join("_includes/page/listing-runtime-attrs.html")
ARTICLES_LAYOUT = ROOT.join("_layouts/articles.html")

config_path = FIXTURE.join("_config.yml")
unless config_path.file?
  warn "FAIL test-dual-template-runtime: missing #{config_path}"
  exit 1
end

unless ATTRS_INCLUDE.file?
  warn "FAIL test-dual-template-runtime: missing #{ATTRS_INCLUDE}"
  exit 1
end

unless ARTICLES_LAYOUT.file?
  warn "FAIL test-dual-template-runtime: missing #{ARTICLES_LAYOUT}"
  exit 1
end

site_yaml = YAML.safe_load(config_path.read, aliases: true)
pages = PandorgaRegistry.pages(site_yaml)
PandorgaRegistry.validate!(pages)

article_pages = pages.select { |p| p["template"].to_s == "articles" }
unless article_pages.length == 2
  warn "FAIL test-dual-template-runtime: expected 2 articles pages, got #{article_pages.length}"
  exit 1
end

layout_src = ARTICLES_LAYOUT.read
%w[listing-runtime-attrs data-listing-collection].each do |token|
  next if layout_src.include?(token)

  warn "FAIL test-dual-template-runtime: articles layout missing #{token.inspect}"
  exit 1
end

attrs_src = ATTRS_INCLUDE.read
%w[listing_collection listing_path listing_detail data-listing-collection data-listing-path data-listing-detail].each do |token|
  next if attrs_src.include?(token)

  warn "FAIL test-dual-template-runtime: listing-runtime-attrs missing #{token.inspect}"
  exit 1
end

if layout_src.match?(/loadWritingIndex\(\s*['"]articles['"]\s*\)/)
  warn "FAIL test-dual-template-runtime: articles layout still hardcodes loadWritingIndex('articles')"
  exit 1
end

if layout_src.include?("'/pages/articles/?tag='") || layout_src.include?('"/pages/articles/?tag="')
  warn "FAIL test-dual-template-runtime: articles layout still hardcodes /pages/articles/ tag href"
  exit 1
end

attrs_template = Liquid::Template.parse(ATTRS_INCLUDE.read)

Dir.mktmpdir("pandorga-dual-template-runtime") do |dest|
  jekyll_config = Jekyll.configuration(
    "source" => FIXTURE.to_s,
    "destination" => dest,
    "quiet" => true,
    "safe" => false
  )
  jekyll_config["pandorga"] = site_yaml["pandorga"]

  site = Jekyll::Site.new(jekyll_config)
  Pandorga::Jekyll::Generator.new.generate(site)

  keys = article_pages.map { |p| p["key"].to_s }
  generated = site.pages.select { |p| keys.include?(p.data["key"].to_s) }
  unless generated.length == 2
    warn "FAIL test-dual-template-runtime: generator emitted #{generated.length} pages, expected 2"
    exit 1
  end

  html_by_key = {}
  generated.each do |page|
    %w[collection listing_path detail].each do |field|
      value = page.data[field].to_s
      if value.empty?
        warn "FAIL test-dual-template-runtime: page #{page.data['key']} missing #{field}"
        exit 1
      end
    end

    html = attrs_template.render(
      "page" => {
        "collection" => page.data["collection"],
        "listing_path" => page.data["listing_path"],
        "permalink" => page.data["permalink"],
        "detail" => page.data["detail"],
        "key" => page.data["key"]
      },
      "include" => {
        "default_collection" => "articles",
        "default_path" => "/pages/articles/",
        "default_detail" => "/articles/:slug/"
      }
    )
    html_by_key[page.data["key"].to_s] = html
  end

  collections = generated.map { |p| p.data["collection"].to_s }.uniq
  paths = generated.map { |p| p.data["listing_path"].to_s }.uniq
  details = generated.map { |p| p.data["detail"].to_s }.uniq
  unless collections.length == 2 && paths.length == 2 && details.length == 2
    warn "FAIL test-dual-template-runtime: page data must differ in collection, listing_path, and detail " \
         "(collections=#{collections.inspect} paths=#{paths.inspect} details=#{details.inspect})"
    exit 1
  end

  htmls = html_by_key.values
  unless htmls.length == 2 && htmls.uniq.length == 2
    warn "FAIL test-dual-template-runtime: rendered listing attrs must differ per instance: #{html_by_key.inspect}"
    exit 1
  end

  article_pages.each do |entry|
    key = entry["key"].to_s
    html = html_by_key.fetch(key)
    expected_collection = entry["collection"].to_s
    expected_path = entry["path"].to_s
    expected_path = "#{expected_path}/" unless expected_path.end_with?("/")
    expected_detail = entry["detail"].to_s

    unless html.include?("data-listing-collection=\"#{expected_collection}\"")
      warn "FAIL test-dual-template-runtime: #{key} HTML missing collection #{expected_collection.inspect}: #{html}"
      exit 1
    end
    unless html.include?("data-listing-path=\"#{expected_path}\"")
      warn "FAIL test-dual-template-runtime: #{key} HTML missing path #{expected_path.inspect}: #{html}"
      exit 1
    end
    unless html.include?("data-listing-detail=\"#{expected_detail}\"")
      warn "FAIL test-dual-template-runtime: #{key} HTML missing detail #{expected_detail.inspect}: #{html}"
      exit 1
    end
  end

  # Both instances must not collapse onto the English articles defaults.
  if htmls.all? { |html| html.include?('data-listing-collection="articles"') }
    warn "FAIL test-dual-template-runtime: both instances still point at collection articles"
    exit 1
  end
  if htmls.all? { |html| html.include?('data-listing-path="/pages/articles/"') }
    warn "FAIL test-dual-template-runtime: both instances still point at /pages/articles/"
    exit 1
  end
end

puts "PASS test-dual-template-runtime"
