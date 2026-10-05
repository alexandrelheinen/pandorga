#!/usr/bin/env ruby
# frozen_string_literal: true

# Refs: PLT-AC-3 — Studio schema includes registry collections and drops them
# when the page is removed.
require "pathname"
require "yaml"
require "fileutils"
require "tmpdir"
require "open3"

ROOT = Pathname.new(__dir__).join("../..").expand_path
$LOAD_PATH.unshift(ROOT.join("lib").to_s)
require "pandorga"
require "pandorga/commands/studio_schema"

EXAMPLE = ROOT.join("examples/full")
TEMPLATES = ROOT.join("templates")
EXE = ROOT.join("exe/pandorga")

def fail!(message)
  warn "FAIL test-studio-schema-composition: #{message}"
  exit 1
end

def registered_collections(config)
  names = []
  Array(config.dig("pandorga", "pages")).each do |page|
    next unless page.is_a?(Hash)

    single = page["collection"].to_s
    names << single unless single.empty?

    cols = page["collections"]
    next unless cols.is_a?(Hash)

    cols.each_value do |name|
      n = name.to_s
      next if n.empty? || n == "data" || n == "profile"

      names << n
    end
  end
  names.uniq
end

def collection_names_from_schema(schema)
  names = []
  Array(schema["content"]).each do |group|
    next unless group.is_a?(Hash)

    Array(group["items"]).each do |item|
      next unless item.is_a?(Hash)
      next unless item["type"].to_s == "collection"

      names << item["name"].to_s
    end
  end
  if schema["collections"].is_a?(Hash)
    names |= schema["collections"].keys.map(&:to_s)
  end
  names.uniq
end

config = YAML.safe_load(EXAMPLE.join("_config.yml").read, aliases: true)
expected = registered_collections(config)
fail!("examples/full has no registered collections") if expected.empty?

composer = Pandorga::Commands::StudioSchema.new
schema = composer.compose(config, TEMPLATES)
present = collection_names_from_schema(schema)

missing = expected - present
fail!("schema missing collections: #{missing.inspect} (have #{present.inspect})") unless missing.empty?

unless schema["media"].is_a?(Hash)
  fail!("composed schema should include a media block when templates need it")
end

unless schema["content"].is_a?(Array) && !schema["content"].empty?
  fail!("composed schema should include content groups")
end

# Taxonomy from examples/full should land on the articles tags field.
articles_entry = schema.dig("collections", "articles")
fail!("articles collection missing from index") unless articles_entry.is_a?(Hash)
tags_field = Array(articles_entry["fields"]).find { |f| f.is_a?(Hash) && f["name"] == "tags" }
tag_values = tags_field&.dig("options", "values")
unless tag_values == ["Writing"]
  fail!("articles tags should come from pandorga.taxonomies (got #{tag_values.inspect})")
end

# Remove the articles page; articles must leave the schema.
reduced = Marshal.load(Marshal.dump(config))
reduced["pandorga"]["pages"].reject! { |p| p.is_a?(Hash) && p["key"].to_s == "articles" }
reduced_schema = composer.compose(reduced, TEMPLATES)
reduced_names = collection_names_from_schema(reduced_schema)
if reduced_names.include?("articles")
  fail!("articles still present after removing the page from the registry")
end
still_expected = registered_collections(reduced)
still_missing = still_expected - reduced_names
unless still_missing.empty?
  fail!("after removal, still missing: #{still_missing.inspect}")
end

# CLI writes schema under a temp site root (optional end-to-end check).
Dir.mktmpdir("pandorga-studio-schema-") do |dir|
  site = Pathname.new(dir)
  FileUtils.cp(EXAMPLE.join("_config.yml"), site.join("_config.yml"))
  env = { "RUBYOPT" => "-I#{ROOT.join('lib')}" }
  stdout, stderr, status = Open3.capture3(
    env, "ruby", EXE.to_s, "studio-schema", site.to_s
  )
  fail!("CLI failed: #{stdout}\n#{stderr}") unless status.success?

  written = site.join("studio/schema.yml")
  fail!("CLI did not write #{written}") unless written.file?

  from_disk = YAML.safe_load(written.read, aliases: true)
  disk_names = collection_names_from_schema(from_disk)
  disk_missing = expected - disk_names
  fail!("CLI schema missing: #{disk_missing.inspect}") unless disk_missing.empty?
end

puts "PASS test-studio-schema-composition (#{expected.length} collections; removal + CLI ok)"
