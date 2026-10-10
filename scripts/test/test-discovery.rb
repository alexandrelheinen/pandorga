#!/usr/bin/env ruby
# frozen_string_literal: true

# Portrait sources and discovery documents (PLT-AC-20, PLT-AC-21).

require "pathname"

require_relative "../../lib/pandorga/discovery"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-discovery: #{message}"
  exit 1
end

origin = Pandorga::Discovery.origin(
  "url" => "https://fallback.example",
  "pandorga" => { "identity" => { "url" => "https://example.com/" } }
)
fail!("identity.url must win over site.url") unless origin == "https://example.com"

paths = Pandorga::Discovery.public_paths([
  { "url" => "/", "data" => {} },
  { "url" => "/pages/articles/", "data" => {} },
  { "url" => "/sitemap.xml", "data" => {} },
  { "url" => "/secret/", "data" => { "sitemap" => false } }
])
fail!("sitemap filtering is wrong: #{paths.inspect}") unless paths == ["/", "/pages/articles/"]

xml = Pandorga::Discovery.sitemap_xml("https://example.com", paths)
fail!("sitemap missing a loc") unless xml.include?("<loc>https://example.com/pages/articles/</loc>")
fail!("sitemap included a skipped path") if xml.include?("secret")

robots = Pandorga::Discovery.robots_txt("https://example.com/sitemap.xml")
fail!("robots missing the sitemap line") unless robots.include?("Sitemap: https://example.com/sitemap.xml")
fail!("robots missing the studio skip") unless robots.include?("Disallow: /studio/")

runtime = ROOT.join("_includes/content-runtime/60-fragments.html").read
fail!("portrait srcset is not read") unless runtime.include?("record.srcset = srcset")
fail!("portrait sources are not applied") unless runtime.include?("applyHeroPortraitSources")
shell = ROOT.join("_layouts/shell.html").read
fail!("shell missing JSON-LD") unless shell.include?("theme/json-ld.html")
fail!("discovery generator is not loaded from the plugin dir") unless ROOT.join("lib/pandorga/jekyll/plugins/discovery.rb").file?

puts "PASS test-discovery"
