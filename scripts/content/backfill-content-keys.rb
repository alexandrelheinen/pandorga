#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "yaml"

require_relative "../../_plugins/content_keys"
require_relative "../../_plugins/content_detail_paths"
require_relative "../../_plugins/git_chronology"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
CONTENT_ROOT = REPO_ROOT.join("content")

KEY_OVERRIDES = {
  "content/collections/posts/2026-03-06-horse-auto-follow.md" => "horse-auto-follow-pt",
  "content/collections/posts/2026-03-02-mcmc.md" => "mcmc-pt"
}.freeze

def split_front_matter(text)
  ContentKeys.split_front_matter(text)
end

def write_front_matter(path, front_matter, body)
  yaml = front_matter.to_yaml.sub(/\A---\n/, "").strip
  path.write("---\n#{yaml}\n---\n\n#{body}")
end

def infer_key(entry)
  override = KEY_OVERRIDES[entry["repo_relative_path"]]
  return override if override

  key = ContentKeys.normalize_key(entry["key"])
  return key unless key.empty?

  ContentKeys.infer_key_from_filename(entry["path"], entry["type"])
end

def legacy_detail_path(type, legacy_segment)
  case type
  when "article" then ContentDetailPaths.article_detail_path(legacy_segment)
  when "post" then ContentDetailPaths.post_detail_path(legacy_segment)
  when "project" then ContentDetailPaths.project_detail_path(legacy_segment)
  when "product" then ContentDetailPaths.product_detail_path(legacy_segment)
  else
    raise "unknown type #{type}"
  end
end

def migrate_redirect_fields!(front_matter)
  redirects = ContentKeys.normalize_redirects(front_matter)
  front_matter.delete("redirect_from")
  front_matter["redirects"] = redirects unless redirects.empty?
  front_matter
end

def ensure_legacy_redirect!(front_matter, type, legacy_segment, canonical_path)
  redirects = ContentKeys.normalize_redirects(front_matter)
  legacy = legacy_detail_path(type, legacy_segment).chomp("/")
  canonical = canonical_path.chomp("/")
  redirects << legacy unless legacy == canonical
  redirects = redirects.map { |path| ContentKeys.normalize_redirect_path(path) }.compact.uniq
  front_matter["redirects"] = redirects unless redirects.empty?
  front_matter.delete("redirects") if redirects.empty?
  front_matter
end

updated = 0
ContentKeys::CONTENT_PATHS.each do |type, relative_dir|
  directory = CONTENT_ROOT.join(relative_dir.sub(%r{\Acontent/}, ""))
  next unless directory.directory?

  Dir.glob(directory.join("*.{md,markdown}")).sort.each do |absolute_path|
    entry = ContentKeys.load_entry(absolute_path, type, repo_root: REPO_ROOT)
    text = File.read(absolute_path).sub(/\A\xEF\xBB\xBF/, "")
    front_matter, body = split_front_matter(text)
    original_yaml = front_matter.to_yaml

    key = infer_key(entry)
    front_matter["key"] = key
    migrate_redirect_fields!(front_matter)

    if %w[article post].include?(type)
      GitChronology.apply!(front_matter, entry["repo_relative_path"], type)
    end

    canonical = ContentKeys.detail_path(type, key, date: front_matter["date"])
    ensure_legacy_redirect!(front_matter, type, entry["legacy_segment"], canonical)

    next if front_matter.to_yaml == original_yaml

    write_front_matter(Pathname(absolute_path), front_matter, body.sub(/\A\n+/, ""))
    updated += 1
    puts "updated #{entry['repo_relative_path']} (key=#{key})"
  end
end

ContentKeys.validate!(REPO_ROOT)
ContentKeys.sync_redirects_file!(REPO_ROOT)
puts "Backfill complete (#{updated} file(s) updated). Redirects synced to _redirects."
