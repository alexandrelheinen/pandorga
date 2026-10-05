#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerate docs/configuration.md from lib/pandorga/registry/schema.yml.
# Refs: PLT-AC-11

require "pathname"
require "yaml"

ROOT = Pathname.new(__dir__).join("..").expand_path
SCHEMA_PATH = ROOT.join("lib/pandorga/registry/schema.yml")
DOC_PATH = ROOT.join("docs/configuration.md")

def fail!(message)
  warn message
  exit 1
end

def required_cell(value)
  case value
  when true then "yes"
  when false then "no"
  when nil then ""
  else value.to_s
  end
end

def render_keys_table(keys, include_required:)
  lines = []
  if include_required
    lines << "| Key | Type | Required | Notes |"
    lines << "|---|---|---|---|"
  else
    lines << "| Key | Type | Notes |"
    lines << "|---|---|---|"
  end

  keys.each do |key, meta|
    meta = {} unless meta.is_a?(Hash)
    label = meta["key_label"] || key
    type = meta["type"].to_s
    notes = meta["notes"].to_s
    if include_required
      lines << "| `#{label}` | #{type} | #{required_cell(meta['required'])} | #{notes} |"
    else
      lines << "| `#{label}` | #{type} | #{notes} |"
    end
  end
  lines.join("\n")
end

def render_home_attributes(entries)
  lines = ["| Key | Notes |", "|---|---|"]
  entries.each do |entry|
    entry = {} unless entry.is_a?(Hash)
    lines << "| #{entry['key']} | #{entry['notes']} |"
  end
  lines.join("\n")
end

def generate(schema)
  out = []
  out << "# Configuration reference"
  out << ""
  out << "Generated from `lib/pandorga/registry/schema.yml`. Gate: keep in sync"
  out << "via `scripts/generate-configuration-doc.rb` (`PLT-AC-11`)."
  out << ""

  %w[identity content home].each do |section|
    data = schema.fetch(section)
    out << "## #{data.fetch('title')}"
    out << ""
    include_required = section == "identity"
    out << render_keys_table(data.fetch("keys"), include_required: include_required)
    out << ""
    intro = data["intro"].to_s.strip
    unless intro.empty?
      out << intro
      out << ""
    end
  end

  tax = schema.fetch("taxonomies")
  out << "## #{tax.fetch('title')}"
  out << ""
  out << tax.fetch("prose").to_s.strip
  out << ""

  pages = schema.fetch("pages")
  out << "## #{pages.fetch('title')}"
  out << ""
  out << render_keys_table(pages.fetch("keys"), include_required: true)
  out << ""
  footer = pages["footer"].to_s.strip
  out << footer unless footer.empty?
  out << ""

  home_attrs = pages.fetch("home_attributes")
  out << "### #{home_attrs.fetch('title')}"
  out << ""
  out << render_home_attributes(home_attrs.fetch("entries"))
  out << ""

  "#{out.join("\n").rstrip}\n"
end

schema = YAML.safe_load(SCHEMA_PATH.read)
fail!("schema missing or empty: #{SCHEMA_PATH}") unless schema.is_a?(Hash)

text = generate(schema)

if ARGV.include?("--check")
  unless DOC_PATH.file? && DOC_PATH.read == text
    warn "FAIL: docs/configuration.md is stale; run scripts/generate-configuration-doc.rb"
    exit 1
  end
  puts "OK docs/configuration.md matches schema"
  exit 0
end

if ARGV.include?("--stdout")
  print text
  exit 0
end

DOC_PATH.write(text)
puts "Wrote #{DOC_PATH.relative_path_from(ROOT)}"
