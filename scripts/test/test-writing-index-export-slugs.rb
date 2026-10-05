#!/usr/bin/env ruby
# frozen_string_literal: true

# writing_index slugs must point at exported JSON (08-23 vs 08-22 class of bug).

$stdout.sync = true
$stderr.sync = true

require "fileutils"
require "json"
require "pathname"
require "tmpdir"

require_relative "../lib/writing_index_contract"

def fail!(message)
  warn message
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
end

puts "Testing writing_index ↔ export slug contract..."

Dir.mktmpdir("writing-index-slugs-") do |dir|
  root = Pathname.new(dir)
  FileUtils.mkdir_p(root.join("collections/articles"))
  FileUtils.mkdir_p(root.join("data"))

  root.join("collections/articles/2026-08-22-freshy-cooling-map.json").write(<<~JSON)
    {"type":"article","slug":"2026-08-22-freshy-cooling-map","key":"freshy-cooling-map"}
  JSON

  matching = [
    {
      "slug" => "2026-08-22-freshy-cooling-map",
      "key" => "freshy-cooling-map",
      "type" => "articles",
      "collection" => "articles"
    }
  ]
  check!(WritingIndexContract.mismatches(root, matching).empty?,
         "matching 08-22 slug must pass")

  stale = [
    {
      "slug" => "2026-08-23-freshy-cooling-map",
      "key" => "freshy-cooling-map",
      "type" => "articles",
      "collection" => "articles"
    }
  ]
  errors = WritingIndexContract.mismatches(root, stale)
  check!(!errors.empty?, "08-23 index vs 08-22 file must fail")
  check!(errors.any? { |line| line.include?("2026-08-23-freshy-cooling-map") },
         "mismatch should name the bad slug (#{errors.inspect})")

  root.join("data/writing_index.json").write(JSON.pretty_generate(stale))
  begin
    WritingIndexContract.assert_slugs_match_export!(root)
    fail!("assert_slugs_match_export! should raise on 08-23 vs 08-22")
  rescue RuntimeError => e
    check!(e.message.include?("2026-08-23-freshy-cooling-map"),
           "assertion message should include the stale slug")
  end
end

puts "writing_index export slug contract OK"

existing = ARGV[0]
if existing
  out = Pathname.new(existing).expand_path
  check!(out.directory?, "export dir missing: #{out}")
  WritingIndexContract.assert_slugs_match_export!(out)
  index = JSON.parse(out.join("data/writing_index.json").read)
  freshy = index.find { |entry| entry["key"] == "freshy-cooling-map" }
  if freshy
    check!(out.join("collections/articles/#{freshy['slug']}.json").file?,
           "Freshy writing_index slug must match collections/articles/#{freshy['slug']}.json")
  end
  puts "writing_index slugs match #{out}"
end
