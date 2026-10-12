#!/usr/bin/env ruby
# frozen_string_literal: true

# Portrait sources and discovery documents (PLT-AC-20, PLT-AC-21).

require "pathname"

require_relative "../../lib/pandorga/discovery"
require_relative "../../lib/pandorga/detail_routes"

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
og_images = shell.scan(/property="og:image"/)
fail!("shell emits #{og_images.size} og:image properties; one page, one image") unless og_images.size == 1
image_meta = shell[/<meta name="image"[^>]*>/]
fail!("shell missing name=image") unless image_meta
fail!("name=image also sets property=og:image") if image_meta.include?("property=")
fail!("discovery generator is not loaded from the plugin dir") unless ROOT.join("lib/pandorga/jekyll/plugins/discovery.rb").file?
fail!("detail pages are still generated") if ROOT.join("lib/pandorga/jekyll/plugins/detail_documents.rb").file?
fail!("shell redirect hook is missing") unless ROOT.join("lib/pandorga/jekyll/plugins/shell_redirects.rb").file?

redirects = <<~TXT
  /legacy /articles/2026-01-01-welcome/ 301
  /posts/:slug/ /pages/blog/ 200
  /keep /pages/articles/ 301
TXT
ensured = Pandorga::DetailRoutes.ensure_shell_rewrites(redirects)
%w[/articles/:slug /posts/:slug /blog/:slug /projects/:slug /products/:slug].each do |prefix|
  present = ensured.lines.any? { |line| line.strip.start_with?("#{prefix} ") || line.strip.start_with?("#{prefix}/ ") }
  fail!("published _redirects missing #{prefix}") unless present
end
fail!("a 301 was dropped") unless ensured.include?("/legacy /articles/2026-01-01-welcome/ 301")
fail!("a listing 301 was dropped") unless ensured.include?("/keep /pages/articles/ 301")
posts = ensured.lines.select { |line| line.include?("/posts/:slug") }
fail!("an existing splat was duplicated") unless posts.size == 1
fail!("an existing splat target was rewritten") unless posts.first.include?("/pages/blog/")
fail!("ensure is not idempotent") unless Pandorga::DetailRoutes.ensure_shell_rewrites(ensured) == ensured

serve = ROOT.join("lib/pandorga/jekyll/plugins/local_detail_rewrites.rb").read
plugins_serve = ROOT.join("_plugins/local_detail_rewrites.rb").read
fail!("the two local serve copies diverged") unless serve == plugins_serve
fail!("local serve skips a detail URL") if serve.include?("static_index?")
fail!("local serve does not rewrite detail URLs") unless serve.include?("ContentDetailPaths.rewrite_path(req.path)")

detail = ROOT.join("_includes/content-runtime/50-detail.html").read
fail!("the client does not set the canonical link") unless detail.include?("setCanonicalLink")
fail!("the client does not set og:url") unless detail.include?("setMetaTag('og:url'")

json_ld = ROOT.join("_includes/theme/json-ld.html").read
fail!("the build still emits detail JSON-LD") if json_ld.include?("schema_type")
fail!("shell JSON-LD dropped the person") unless json_ld.include?('"@type": "Person"')

puts "PASS test-discovery"
