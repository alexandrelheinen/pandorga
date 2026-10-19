#!/usr/bin/env ruby
# frozen_string_literal: true

# Refs: PLT-AC-43
require "pathname"
require "yaml"
require "fileutils"
require "tmpdir"
require "open3"
require "date"

ROOT = Pathname.new(__dir__).join("../..").expand_path
EXE = ROOT.join("exe/pandorga")
GEM_SCHEMA = ROOT.join("studio/schema.yml")
FIXTURES = ROOT.join("scripts/test/fixtures/studio-taxonomy")
TOP_LEVEL_CONFIG = FIXTURES.join("top-level/_config.yml")
PAGE_LOCAL_CONFIG = FIXTURES.join("page-local/_config.yml")

LEFTOVER_TAGS = %w[
  Aesthetics
  Social
  Mathematics
  Robotics
  DevOps
  brasilidade
  engraçadinho
  devaneio
  provocação
].freeze

def fail!(message)
  warn "FAIL test-studio-taxonomy: #{message}"
  exit 1
end

def run_install_functions(dest)
  env = { "RUBYOPT" => "-I#{ROOT.join('lib')}" }
  Open3.capture3(env, "ruby", EXE.to_s, "install-functions", dest.to_s)
end

def load_yaml(path)
  YAML.safe_load(path.read, permitted_classes: [Date, Time], aliases: true) || {}
end

def find_content_collection(schema, name)
  Array(schema["content"]).each do |group|
    next unless group.is_a?(Hash)

    Array(group["items"]).each do |item|
      next unless item.is_a?(Hash)
      next unless item["type"].to_s == "collection"

      return item if item["name"].to_s == name.to_s
    end
  end
  nil
end

def find_tags_field(entry)
  return nil unless entry.is_a?(Hash)

  Array(entry["fields"]).find { |f| f.is_a?(Hash) && f["name"].to_s == "tags" }
end

# a, b, e, d. Top-level fixture, no leftovers, overrides, and config change.
Dir.mktmpdir("pandorga-studio-tax-top-") do |dir|
  site = Pathname.new(dir)
  FileUtils.cp(TOP_LEVEL_CONFIG, site.join("_config.yml"))

  stdout, stderr, status = run_install_functions(site)
  fail!("case a CLI failed: #{stdout}\n#{stderr}") unless status.success?

  installed_path = site.join("studio/schema.yml")
  fail!("installed schema missing at #{installed_path}") unless installed_path.file?

  schema = load_yaml(installed_path)
  [
    ["content.articles", find_content_collection(schema, "articles")],
    ["collections.articles", schema.dig("collections", "articles")]
  ].each do |label, entry|
    # The gem's schema has no collections index; the installer must not add one.
    next if label.start_with?("collections.") && !schema.key?("collections")

    fail!("missing #{label}") unless entry.is_a?(Hash)
    opts = find_tags_field(entry)&.fetch("options", nil)
    fail!("missing tags options on #{label}") unless opts.is_a?(Hash)
    unless opts["values"] == %w[Design Organizations]
      fail!("#{label} values expected [Design, Organizations], got #{opts['values'].inspect}")
    end
    fail!("#{label} max expected 2, got #{opts['max'].inspect}") unless opts["max"] == 2
    fail!("#{label} min expected 1, got #{opts['min'].inspect}") unless opts["min"] == 1
  end

  [
    ["content.posts", find_content_collection(schema, "posts")],
    ["collections.posts", schema.dig("collections", "posts")]
  ].each do |label, entry|
    # The gem's schema has no collections index; the installer must not add one.
    next if label.start_with?("collections.") && !schema.key?("collections")

    fail!("missing #{label}") unless entry.is_a?(Hash)
    opts = find_tags_field(entry)&.fetch("options", nil)
    fail!("missing tags options on #{label}") unless opts.is_a?(Hash)
    unless opts["values"] == %w[alpha beta gamma]
      fail!("#{label} values expected [alpha, beta, gamma], got #{opts['values'].inspect}")
    end
    fail!("#{label} max expected 3, got #{opts['max'].inspect}") unless opts["max"] == 3
    if opts.key?("min")
      fail!("#{label} should not have min key, got #{opts['min'].inspect}")
    end
  end

  fail!("installer must not add a collections index") if schema.key?("collections")

  # Free-text tags (type string, list) are not pickers and stay untouched.
  projects_tags = find_tags_field(find_content_collection(schema, "projects"))
  gem_projects_tags = find_tags_field(find_content_collection(load_yaml(GEM_SCHEMA), "projects"))
  unless projects_tags && projects_tags == gem_projects_tags
    fail!("free-text projects tags changed: #{projects_tags.inspect}")
  end

  # b. No leftover site vocabulary in installed schema.
  raw_text = installed_path.read
  LEFTOVER_TAGS.each do |word|
    if raw_text.include?(word)
      fail!("installed schema still contains leftover tag #{word.inspect}")
    end
  end

  # e. Overrides applied after taxonomies.
  site.join("studio.overrides.yml").write(<<~YAML)
    collections:
      articles:
        label: Essays
  YAML
  stdout, stderr, status = run_install_functions(site)
  fail!("case e CLI failed: #{stdout}\n#{stderr}") unless status.success?

  overridden = load_yaml(installed_path)
  articles_item = find_content_collection(overridden, "articles")
  unless articles_item&.fetch("label", nil) == "Essays"
    fail!("expected overridden articles label 'Essays', got #{articles_item&.fetch('label', nil).inspect}")
  end
  articles_vals = find_tags_field(articles_item)&.dig("options", "values")
  unless articles_vals == %w[Design Organizations]
    fail!("expected overridden articles tags [Design, Organizations], got #{articles_vals.inspect}")
  end
  FileUtils.rm_f(site.join("studio.overrides.yml"))

  # d. Changing _config.yml changes the output.
  site.join("_config.yml").write(<<~YAML)
    pandorga:
      taxonomies:
        articles:
          tags: [Zeta]
          max: 2
        posts:
          tags: [alpha, beta, gamma]
          max: 3
  YAML
  stdout, stderr, status = run_install_functions(site)
  fail!("case d CLI failed: #{stdout}\n#{stderr}") unless status.success?

  updated = load_yaml(installed_path)
  updated_vals = find_tags_field(find_content_collection(updated, "articles"))&.dig("options", "values")
  unless updated_vals == %w[Zeta]
    fail!("expected updated articles tags [Zeta], got #{updated_vals.inspect}")
  end
end

# c. Page-local fixture: articles falls back to pages[].taxonomy; posts stays [] with a warning.
Dir.mktmpdir("pandorga-studio-tax-page-") do |dir|
  site = Pathname.new(dir)
  FileUtils.cp(PAGE_LOCAL_CONFIG, site.join("_config.yml"))

  stdout, stderr, status = run_install_functions(site)
  fail!("case c CLI failed: #{stdout}\n#{stderr}") unless status.success?

  schema = load_yaml(site.join("studio/schema.yml"))
  articles_opts = find_tags_field(find_content_collection(schema, "articles"))&.fetch("options", nil)
  fail!("case c missing articles tags options") unless articles_opts.is_a?(Hash)
  unless articles_opts["values"] == %w[Notes]
    fail!("case c articles values expected [Notes], got #{articles_opts['values'].inspect}")
  end
  unless articles_opts["max"] == 1
    fail!("case c articles max expected 1, got #{articles_opts['max'].inspect}")
  end

  posts_opts = find_tags_field(find_content_collection(schema, "posts"))&.fetch("options", nil)
  fail!("case c missing posts tags options") unless posts_opts.is_a?(Hash)
  unless posts_opts["values"] == []
    fail!("case c posts values expected [], got #{posts_opts['values'].inspect}")
  end

  combined = "#{stdout}\n#{stderr}"
  unless combined.match?(/warning:.*posts/i)
    fail!("case c expected warning mentioning posts, got:\n#{combined}")
  end
end

# f. Gem source: studio/schema.yml has values: [] on every select tags field.
gem_schema = load_yaml(GEM_SCHEMA)
gem_tag_fields = 0
Array(gem_schema["content"]).each do |group|
  next unless group.is_a?(Hash)

  Array(group["items"]).each do |item|
    next unless item.is_a?(Hash) && item["type"].to_s == "collection"

    field = find_tags_field(item)
    next unless field && (field["type"].to_s == "select" || field["options"].is_a?(Hash))

    gem_tag_fields += 1
    vals = field.dig("options", "values")
    unless vals == []
      fail!("gem studio/schema.yml #{item['name']} tags values expected [], got #{vals.inspect}")
    end
  end
end
if gem_schema["collections"].is_a?(Hash)
  gem_schema["collections"].each do |name, item|
    field = find_tags_field(item)
    next unless field && (field["type"].to_s == "select" || field["options"].is_a?(Hash))

    vals = field.dig("options", "values")
    unless vals == []
      fail!("gem studio/schema.yml collections.#{name} tags values expected [], got #{vals.inspect}")
    end
  end
end
fail!("expected select tags fields in gem studio/schema.yml") if gem_tag_fields.zero?

# g. No _config.yml in destination: command succeeds and copies schema unchanged.
Dir.mktmpdir("pandorga-studio-tax-noconfig-") do |dir|
  site = Pathname.new(dir)
  stdout, stderr, status = run_install_functions(site)
  fail!("case g CLI failed: #{stdout}\n#{stderr}") unless status.success?

  installed_path = site.join("studio/schema.yml")
  fail!("case g missing studio/schema.yml") unless installed_path.file?
  unless installed_path.read == GEM_SCHEMA.read
    fail!("case g expected studio/schema.yml to be copied unchanged when _config.yml is absent")
  end
end

puts "PASS test-studio-taxonomy"
