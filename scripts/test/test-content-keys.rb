#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "set"
require "tmpdir"

require_relative "../../_plugins/content_keys"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def check!(condition, message)
  raise message unless condition
end

puts "Testing ContentKeys..."

begin
  ContentKeys.validate!(REPO_ROOT)
  puts "  key uniqueness: OK"
rescue ContentKeys::ValidationError => e
  raise "ContentKeys validation failed: #{e.message}"
end

entries = ContentKeys.published_entries(REPO_ROOT)
check! !entries.empty?, "expected published keyed content entries"

entries.each do |entry|
  check! !entry["key"].empty?, "missing key on #{entry['repo_relative_path']}"
  check! !entry["path_segment"].to_s.empty?, "missing path segment on #{entry['repo_relative_path']}"
  check! entry["detail_path"].start_with?("/"), "invalid detail path for #{entry['repo_relative_path']}"
end

rules = ContentKeys.redirect_rules(entries)
rules.each do |source, target, code|
  check! source.start_with?("/"), "redirect source must be absolute: #{source}"
  check! target.start_with?("/"), "redirect target must be absolute: #{target}"
  check! code == 301, "redirects must be permanent"
end

expected_aliases = {
  "ai-agents-sdd" => %w[ai-agents-sdd],
  "vibe-coding" => %w[2026-03-24-where-to-do-vibe-coding 2026-03-24-when-to-vibe-code],
  "wsl" => %w[20260224-wsl wsl],
  "stitch-and-claude" => %w[stitch-and-claude]
}
expected_aliases.each do |key, slugs|
  entry = entries.find { |item| item["key"] == key }
  check! !entry.nil?, "missing published entry for #{key}"
  aliases = ContentKeys.alias_slugs(entry)
  slugs.each do |slug|
    check! aliases.include?(slug), "#{key} aliases must include #{slug} (got #{aliases.inspect})"
  end
end

# Studio once rewrote includes as key="" when fromBlock destructured the RegExp
# match wrong. Reject empty xcite targets in published markdown.
xcite_empty = /\{%-?\s*include\s+xcite\.html\s+key=["']\s*["'][^%]*-?%\}/
known_keys = entries.map { |item| item["key"] }.to_set
xcite_re = /\{%-?\s*include\s+xcite\.html\s+key=["']([^"']+)["'][^%]*-?%\}/
Pathname.glob(REPO_ROOT.join("content/collections/*/*.md")).each do |path|
  path.read.each_line.with_index(1) do |line, lineno|
    if line.match?(xcite_empty)
      raise "empty xcite key in #{path.relative_path_from(REPO_ROOT)}:#{lineno}"
    end
    line.scan(xcite_re).flatten.each do |target|
      next if known_keys.include?(target)

      raise "unknown xcite key #{target.inspect} in #{path.relative_path_from(REPO_ROOT)}:#{lineno}"
    end
  end
end
puts "  xcite includes: OK"

redirects_path = REPO_ROOT.join("_redirects")
text = redirects_path.read
check! ContentKeys.generated_redirects_precede_catchalls?(text),
       "generated content-key 301s must sit above /articles/:slug, /posts/:slug, and /blog/:slug 200 rewrites"

%w[
  /articles/20260224-wsl
  /articles/2026-03-20-stitch-e-claude
  /articles/2026-03-24-where-to-do-vibe-coding
].each do |source|
  check! text.include?("#{source} "), "expected 301 source #{source} in _redirects"
end

Dir.mktmpdir("content-keys-redirects-") do |tmp|
  stale = Pathname.new(tmp).join("_redirects")
  stale.write(<<~REDIRECTS)
    /media/* https://example.test/media/:splat 302

    /articles/:slug /pages/articles/ 200
    /posts/:slug /pages/blog/ 200
    /blog/:slug /pages/blog/ 200

    #{ContentKeys::REDIRECTS_BEGIN}
    /articles/stale-alias /articles/canonical/ 301
    #{ContentKeys::REDIRECTS_END}
  REDIRECTS

  ContentKeys.sync_redirects_file!(REPO_ROOT, redirects_path: stale)
  synced = stale.read
  check! ContentKeys.generated_redirects_precede_catchalls?(synced),
         "sync_redirects_file! must move generated 301s above SPA catch-all 200s"
  check! synced.include?("/articles/20260224-wsl /articles/2026-02-24-wsl/ 301"),
         "sync must emit content key 301 redirects"
end

puts "All ContentKeys tests passed (#{entries.length} entries, #{rules.length} redirect rule(s))."
