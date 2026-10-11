#!/usr/bin/env ruby
# frozen_string_literal: true

# Portrait sources and discovery documents (PLT-AC-20, PLT-AC-21).

require "fileutils"
require "pathname"

require "tmpdir"

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
fail!("detail pages are not generated from the plugin dir") unless ROOT.join("lib/pandorga/jekyll/plugins/detail_documents.rb").file?

redirects = <<~TXT
  /legacy /articles/2026-01-01-welcome/ 301
  /articles/:slug /pages/articles/ 200
  /posts/:slug/ /pages/blog/ 200
  /blog/:slug /pages/blog/ 200
  /projects/:slug /pages/projects/ 200
  /products/* /pages/cv/ 200
  /keep /pages/articles/ 301
TXT
stripped = Pandorga::DetailRoutes.strip_splat_rewrites(redirects)
fail!("splat 200 rewrite survived") if stripped.match?(%r{/(?:articles|posts|blog|projects|products)/(?::slug|\*)})
fail!("a 301 was stripped with the splats") unless stripped.include?("/legacy /articles/2026-01-01-welcome/ 301")
fail!("a listing 301 was stripped") unless stripped.include?("/keep /pages/articles/ 301")

Dir.mktmpdir("detail-static") do |dir|
  FileUtils.mkdir_p(File.join(dir, "articles", "welcome"))
  File.write(File.join(dir, "articles", "welcome", "index.html"), "<p>welcome</p>")
  fail!("a built detail page must not be rewritten") unless Pandorga::DetailRoutes.static_index?(dir, "/articles/welcome/")
  fail!("a missing detail page must still be rewritten") if Pandorga::DetailRoutes.static_index?(dir, "/articles/missing/")
end

json_ld = ROOT.join("_includes/theme/json-ld.html").read
fail!("detail pages have no Article schema") unless json_ld.include?('page.schema_type == "Article"')
fail!("detail pages have no BlogPosting schema") unless json_ld.include?('page.schema_type == "BlogPosting"')
fail!("detail schema omits datePublished") unless json_ld.include?("datePublished")

puts "PASS test-discovery"
