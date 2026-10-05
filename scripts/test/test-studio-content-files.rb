#!/usr/bin/env ruby
# frozen_string_literal: true
# AC-STU: schema file coverage for site-copy paths.
# Spec: docs/features/studio.md

require "date"
require "pathname"
require "yaml"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
CONFIG_PATH = REPO_ROOT.join("studio/schema.yml")
CONTENT_ROOT = REPO_ROOT.join("content")

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

def each_content_entry(nodes, &block)
  Array(nodes).each do |entry|
    next unless entry.is_a?(Hash)

    type = entry["type"].to_s
    if type == "group"
      each_content_entry(entry["items"], &block)
    else
      yield entry
    end
  end
end

def schema_file_paths(config)
  paths = []
  each_content_entry(config["content"]) do |entry|
    next unless entry["type"].to_s == "file"

    path = entry["path"].to_s
    paths << path unless path.empty?
  end
  paths.sort
end

def required_cms_paths
  paths = []
  pages_root = CONTENT_ROOT.join("pages")
  if pages_root.directory?
    pages_root.glob("**/*.{yml,yaml}").sort.each do |data_file|
      paths << data_file.relative_path_from(REPO_ROOT).to_s.tr("\\", "/")
    end
    pages_root.glob("**/*.{md,markdown}").sort.each do |fragment|
      paths << fragment.relative_path_from(REPO_ROOT).to_s.tr("\\", "/")
    end
  end

  data_root = CONTENT_ROOT.join("collections/data")
  %w[contacts.yml education.yml languages.yml skills.yml].each do |name|
    path = data_root.join(name)
    paths << path.relative_path_from(REPO_ROOT).to_s.tr("\\", "/") if path.file?
  end

  paths.sort.uniq
end

puts "Testing Studio content file coverage..."

check!(CONFIG_PATH.file?, "missing studio/schema.yml")

config = YAML.safe_load(CONFIG_PATH.read, permitted_classes: [Date, Time], aliases: true) || {}
registered = schema_file_paths(config)
required = required_cms_paths

missing = required - registered
extra = registered - required

check!(missing.empty?,
       "studio/schema.yml is missing file entries for:\n  #{missing.join("\n  ")}")
check!(extra.empty?,
       "studio/schema.yml points at files that are not editorial CMS paths:\n  #{extra.join("\n  ")}")

puts "All Studio content file checks passed (#{required.length} paths)."
