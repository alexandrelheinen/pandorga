#!/usr/bin/env ruby
# frozen_string_literal: true

# The [EN]/[PT] pills read `language` off writing_index entries. The field has
# always been in front matter, but was never exported, so listings had no way
# to reach it. Guard both halves: the key is always present, and any value it
# carries is one the UI knows how to render.

require "json"
require "pathname"
require "yaml"
require "date"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
EXPORT_ROOT = REPO_ROOT.join("_content_json")
CONTENT_ROOT = REPO_ROOT.join("content/collections")

# Empty is allowed: an unset language renders no pill at all, which is the
# correct behaviour for an item whose language was never declared.
ALLOWED = ["", "enus", "ptbr"].freeze
TAGGED_COLLECTIONS = %w[articles posts].freeze

def fail!(message)
  warn message
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
end

puts "Testing language export..."

index_path = EXPORT_ROOT.join("data/writing_index.json")
unless index_path.file?
  puts "  skipped: no export at #{index_path.relative_path_from(REPO_ROOT)}"
  exit 0
end

entries = JSON.parse(index_path.read)
check!(entries.any?, "writing_index.json is empty")

missing = entries.reject { |e| e.key?("language") }
check!(missing.empty?,
       "writing_index entries missing the language key: " \
       "#{missing.take(3).map { |e| e['slug'] }.join(', ')}")

bad = entries.reject { |e| ALLOWED.include?(e["language"].to_s) }
check!(bad.empty?,
       "unknown language values: " \
       "#{bad.take(5).map { |e| "#{e['slug']}=#{e['language'].inspect}" }.join(', ')}")

# Front matter is the source of truth; catch a value that exists on disk but
# is dropped somewhere between parsing and the index.
TAGGED_COLLECTIONS.each do |collection|
  Dir.glob(CONTENT_ROOT.join(collection, "*.md")).sort.each do |path|
    source = File.read(path)
    next unless source.start_with?("---")

    front_matter = YAML.safe_load(source.split(/^---\s*$/, 3)[1],
                                  permitted_classes: [Date, Time]) || {}
    next if front_matter["published"] == false

    declared = front_matter["language"].to_s.strip
    next if declared.empty?

    slug = File.basename(path, ".md")
    entry = entries.find { |e| e["slug"] == slug && e["collection"] == collection }
    next if entry.nil?

    check!(entry["language"].to_s == declared,
           "#{collection}/#{slug}: front matter language #{declared.inspect} " \
           "but index has #{entry['language'].inspect}")
  end
end

declared_count = entries.count { |e| !e["language"].to_s.empty? }
puts "  #{entries.size} entries, #{declared_count} with a declared language."
puts "All language export tests passed."
