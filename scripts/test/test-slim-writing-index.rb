#!/usr/bin/env ruby
# frozen_string_literal: true

# Gate: xcite resolution must use the slim writing_index, not bulk loadCollection
# of articles/posts/products/projects. Spec: GitHub issue #364.

require "json"
require "open3"
require "pathname"
require "tmpdir"

require_relative "../lib/writing_index_contract"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
EXPORT_SCRIPT = REPO_ROOT.join("scripts/content/export-content-json.rb")
XCITE_INCLUDE = REPO_ROOT.join("_includes/content-runtime/30-includes-xcite.html")
FRAGMENTS_INCLUDE = REPO_ROOT.join("_includes/content-runtime/60-fragments.html")
LISTING_INCLUDE = REPO_ROOT.join("_includes/content-runtime/40-listing.html")
BLOG_LAYOUT = REPO_ROOT.join("_layouts/blog.html")
ARTICLES_LAYOUT = REPO_ROOT.join("_layouts/articles.html")

def fail!(message)
  warn message
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
end

puts "Testing slim writing index / xcite fetch contract..."

xcite_src = XCITE_INCLUDE.read
check!(xcite_src.include?("data/writing_index.json"),
       "ensureXciteIndex must load data/writing_index.json")
check!(!xcite_src.match?(/loadCollection\(\s*['"]collections\/(articles|posts)/),
       "ensureXciteIndex must not call loadCollection for articles/posts")
check!(!xcite_src.match?(/loadCollection\(\s*['"]collections\/(products|projects)/),
       "ensureXciteIndex must not call loadCollection for products/projects")

fragments_src = FRAGMENTS_INCLUDE.read
check!(fragments_src.include?("jsonCache"),
       "loadJson must memoize in-memory")
check!(fragments_src.include?("function loadWritingIndex"),
       "runtime must expose loadWritingIndex for listing shells")
check!(fragments_src.include?("excerpt: entry.excerpt"),
       "writingIndexAsListingItem must pass excerpt through to listing cards")

listing_src = LISTING_INCLUDE.read
check!(listing_src.include?("function listingPreview"),
       "runtime must expose listingPreview so cards can fall back to excerpts")

[BLOG_LAYOUT, ARTICLES_LAYOUT].each do |layout|
  check!(layout.read.include?("listingPreview"),
         "#{layout.relative_path_from(REPO_ROOT)} cards must use listingPreview")
end

Dir.mktmpdir("writing-index-") do |tmp|
  out_dir = Pathname.new(tmp)
  stdout, stderr, status = Open3.capture3(
    { "CONTENT_API_BASE_URL" => "" },
    "ruby", EXPORT_SCRIPT.to_s, "content", out_dir.to_s,
    chdir: REPO_ROOT.to_s
  )
  fail!("export-content-json.rb failed:\n#{stderr}\n#{stdout}") unless status.success?

  index_path = out_dir.join("data/writing_index.json")
  check!(index_path.file?, "export must write data/writing_index.json")

  entries = JSON.parse(index_path.read)
  check!(entries.is_a?(Array) && !entries.empty?, "writing_index must be a non-empty array")

  required = %w[key slug title url type collection date xcites category description excerpt thumbnail aliases]
  sample = entries.first
  required.each do |field|
    check!(sample.key?(field), "writing_index entries must include #{field}")
  end

  types = entries.map { |e| e["collection"] || e["type"] }.uniq
  %w[articles posts products projects].each do |collection|
    check!(types.include?(collection),
           "writing_index must cover #{collection} (got #{types.inspect})")
  end

  posts = entries.select { |entry| (entry["collection"] || entry["type"]) == "posts" }
  check!(!posts.empty?, "writing_index must include posts")
  post_without_description = posts.find { |entry| entry["description"].to_s.strip.empty? }
  check!(!post_without_description.nil?, "expected at least one post with an empty editorial description")
  excerpt = post_without_description["excerpt"].to_s.strip
  check!(!excerpt.empty?, "posts without description must still export a body excerpt")
  check!(excerpt.length <= 220, "excerpt must stay within the listing preview limit")

  article = entries.find { |entry| (entry["collection"] || entry["type"]) == "articles" && !entry["description"].to_s.strip.empty? }
  check!(!article.nil?, "expected an article with an editorial description")
  check!(!article["excerpt"].to_s.strip.empty?, "articles must still export a body excerpt alongside description")

  WritingIndexContract.assert_slugs_match_export!(out_dir, entries)
  freshy = entries.find { |entry| entry["key"] == "freshy-cooling-map" }
  if freshy
    check!(out_dir.join("collections/articles/#{freshy['slug']}.json").file?,
           "Freshy writing_index slug must match collections/articles/#{freshy['slug']}.json")
  end

  expected_aliases = {
    "ai-agents-sdd" => "ai-agents-sdd",
    "vibe-coding" => "2026-03-24-where-to-do-vibe-coding",
    "wsl" => "20260224-wsl",
    "stitch-and-claude" => "stitch-and-claude"
  }
  expected_aliases.each do |key, alias_slug|
    entry = entries.find { |item| item["key"] == key }
    check!(!entry.nil?, "writing_index must include #{key}")
    aliases = Array(entry["aliases"])
    check!(aliases.include?(alias_slug),
           "#{key} writing_index aliases must include #{alias_slug} (got #{aliases.inspect})")
  end
end

check!(FRAGMENTS_INCLUDE.read.include?("function resolveWritingAlias"),
       "runtime must resolve old slugs from writing_index aliases")
check!(ARTICLES_LAYOUT.read.include?("resolveWritingAlias"),
       "articles shell must resolve writing_index aliases before loading JSON")
check!(ARTICLES_LAYOUT.read.include?("adoptCanonicalDetailUrl"),
       "articles shell must replaceState to the canonical URL when an alias matches")

puts "All slim writing index / xcite fetch checks passed."
