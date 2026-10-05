#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"
require "date"
require "time"
require "shellwords"
require "yaml"
require "set"

require_relative "../../_plugins/git_chronology"

require_relative "../../_plugins/content_keys"
require_relative "../../_plugins/writing_slug_limits"
require_relative "../../_plugins/lib/content_validators"
require_relative "../../_plugins/content_site_adapter"
require_relative "../../_plugins/timeline"
require_relative "../lib/content_license"
require_relative "../lib/writing_index_contract"
require_relative "band_art"
require_relative "hero_portraits"

REPO_ROOT = Pathname.new(ENV.fetch("PANDORGA_SITE_ROOT", Dir.pwd)).expand_path
CONTENT_ROOT = Pathname.new(ARGV[0] || "content").expand_path
OUTPUT_ROOT = Pathname.new(ARGV[1] || "_content_json").expand_path

def load_content_api_base_url
  if ENV.key?("CONTENT_API_BASE_URL")
    return ENV["CONTENT_API_BASE_URL"].to_s.chomp("/")
  end

  config_path = REPO_ROOT.join("_config.yml")
  raise "Missing _config.yml; set CONTENT_API_BASE_URL or configure content_api_base_url" unless config_path.file?

  config = YAML.safe_load(config_path.read) || {}
  url = config["content_api_base_url"].to_s.strip
  if url.empty?
    raise "content_api_base_url is empty in _config.yml; set CONTENT_API_BASE_URL for local export"
  end

  url.chomp("/")
end

CONTENT_API_BASE_URL = load_content_api_base_url
CONTENT_LICENSE = ContentLicense.load(REPO_ROOT).freeze
SHELL_ASSET_PREFIXES = [
  "/assets/images/og-default",
  "/assets/images/profile"
].freeze
MEDIA_FRONT_MATTER_KEYS = %w[thumbnail og_image].freeze

def shell_asset_path?(path)
  normalized = path.to_s.strip
  SHELL_ASSET_PREFIXES.any? { |prefix| normalized.start_with?(prefix) }
end

def normalize_media_path(path)
  value = path.to_s.strip
  return nil if value.empty?
  return nil if value.match?(%r{\Ahttps?://}i)

  if value.start_with?("/content/media/")
    "/media/#{value.delete_prefix("/content/media/")}"
  elsif value.start_with?("content/media/")
    "/media/#{value.delete_prefix("content/media/")}"
  elsif value.match?(%r{\A/assets/images/}) && !shell_asset_path?(value)
    value.sub(%r{\A/assets/images/}, "/media/images/")
  elsif value.start_with?("/media/") || value.start_with?("media/")
    value.start_with?("/") ? value : "/#{value}"
  end
end

def resolve_media_url(path)
  value = path.to_s.strip
  return value if value.empty? || value.match?(%r{\Ahttps?://}i)
  return value if shell_asset_path?(value)

  media_path = normalize_media_path(value)
  return value unless media_path

  "#{CONTENT_API_BASE_URL}#{media_path}"
end

def rewrite_media_attribute_paths(text)
  text.gsub(/((?:src|poster|href)\s*=\s*["'])([^"']+)(["'])/i) do
    prefix = Regexp.last_match(1)
    path = Regexp.last_match(2)
    suffix = Regexp.last_match(3)
    "#{prefix}#{resolve_media_url(path)}#{suffix}"
  end
end

def rewrite_markdown_media_paths(text)
  text.gsub(/(\!\[[^\]]*\]\()([^)]+)(\))/) do
    prefix = Regexp.last_match(1)
    path = Regexp.last_match(2)
    suffix = Regexp.last_match(3)
    "#{prefix}#{resolve_media_url(path)}#{suffix}"
  end
end

def rewrite_media_references(text)
  return text unless text.is_a?(String) && !text.empty?

  rewrite_media_attribute_paths(rewrite_markdown_media_paths(text))
end

def rewrite_front_matter_media!(front_matter)
  return front_matter unless front_matter.is_a?(Hash)

  MEDIA_FRONT_MATTER_KEYS.each do |key|
    next unless front_matter[key].is_a?(String)

    front_matter[key] = resolve_media_url(front_matter[key])
  end
  front_matter
end

def split_front_matter(text)
  text = text.sub(/\A\xEF\xBB\xBF/, "")
  return [{}, text] unless text.start_with?("---\n")

  parts = text.split(/^---\s*$\n?/, 3)
  return [{}, text] unless parts.length == 3

  data = YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true) || {}
  [data, parts[2]]
end

def apply_git_chronology!(front_matter, repo_relative_path, type)
  GitChronology.apply!(front_matter, repo_relative_path, type)
end

def json_ready(value)
  case value
  when Hash
    value.transform_values { |v| json_ready(v) }
  when Array
    value.map { |v| json_ready(v) }
  when Date, Time
    value.iso8601
  else
    value
  end
end

WRITTEN_OUTPUT_FILES = []
OUTPUT_WRITE_STATS = { written: 0, unchanged: 0 }

def load_changed_paths
  paths = []
  paths.concat(ENV["CONTENT_EXPORT_CHANGED_PATHS"].to_s.split(/[\n,]+/))
  changed_file = ENV["CONTENT_EXPORT_CHANGED_PATHS_FILE"].to_s
  if !changed_file.empty? && File.file?(changed_file)
    paths.concat(File.readlines(changed_file, chomp: true))
  end
  paths.map { |path| path.to_s.strip.sub(%r{\A\./}, "") }.reject(&:empty?).uniq
end

CHANGED_PATHS = load_changed_paths.freeze
INCREMENTAL_EXPORT = !CHANGED_PATHS.empty?

def path_affected?(*repo_relatives)
  return true unless INCREMENTAL_EXPORT

  CHANGED_PATHS.any? do |changed|
    repo_relatives.any? do |rel|
      rel = rel.to_s.sub(%r{\A\./}, "")
      next false if rel.empty?

      changed == rel ||
        changed.start_with?("#{rel.chomp('/')}/") ||
        rel.start_with?("#{changed.chomp('/')}/")
    end
  end
end

def existing_output_for_source(relative_source)
  @existing_by_source ||= index_existing_export_by_source
  @existing_by_source[relative_source]
end

def index_existing_export_by_source
  index = {}
  return index unless OUTPUT_ROOT.directory?

  OUTPUT_ROOT.glob("**/*.json").each do |path|
    next unless path.file?
    next if %w[manifest.json writing_index.json timeline.json].include?(path.basename.to_s)

    begin
      payload = JSON.parse(path.read)
    rescue JSON::ParserError
      next
    end
    next unless payload.is_a?(Hash)

    src = payload["source_path"].to_s
    next if src.empty?

    index[src] = path
  end
  index
end

def keep_existing_output(output_path)
  WRITTEN_OUTPUT_FILES << output_path.expand_path
  OUTPUT_WRITE_STATS[:unchanged] += 1
  output_path.relative_path_from(OUTPUT_ROOT).to_s
end

def write_json(path, payload)
  content = "#{JSON.pretty_generate(json_ready(payload))}\n"
  FileUtils.mkdir_p(path.dirname)
  WRITTEN_OUTPUT_FILES << path.expand_path

  if path.file? && path.read == content
    OUTPUT_WRITE_STATS[:unchanged] += 1
    return :unchanged
  end

  path.write(content)
  OUTPUT_WRITE_STATS[:written] += 1
  :written
end

# Same contract as write_json for anything that is not JSON: register the path
# so the pruner keeps it, and reuse the bytes when nothing changed so the R2
# sync can skip the object.
def write_text(path, content)
  FileUtils.mkdir_p(path.dirname)
  WRITTEN_OUTPUT_FILES << path.expand_path

  if path.file? && path.read == content
    OUTPUT_WRITE_STATS[:unchanged] += 1
    return :unchanged
  end

  path.write(content)
  OUTPUT_WRITE_STATS[:written] += 1
  :written
end

def prune_stale_output_files!
  return unless OUTPUT_ROOT.directory?

  keep = WRITTEN_OUTPUT_FILES.map(&:to_s).to_set
  stale = []
  OUTPUT_ROOT.find do |path|
    next unless path.file?

    stale << path unless keep.include?(path.expand_path.to_s)
  end

  stale.each(&:delete)
  # Remove empty directories left beNewsreader by unpublish/rename.
  OUTPUT_ROOT.find.sort.reverse_each do |path|
    next unless path.directory?
    next if path == OUTPUT_ROOT

    path.rmdir if path.children.empty?
  rescue Errno::ENOTEMPTY, Errno::ENOENT
    # Concurrent or non-empty; ignore.
  end

  stale.length
end

def published_for_export?(front_matter)
  return true if ENV["CONTENT_EXPORT_INCLUDE_UNPUBLISHED"] == "1"

  front_matter["published"] != false
end

# Print-only CV copy. Private PDF builds read these from Git via Jekyll;
# they must not land in the public R2 JSON. Spec: docs/content/architecture.md.
PRINT_ONLY_PAGE_FRAGMENTS = %w[
  cv/summary-extended
  cv/summary-single-page
  cv/ai-practice
].freeze

# Private CV PDF sidebar only; the public CV page has no skills section.
PRINT_ONLY_DATA_FILES = %w[skills.yml].freeze

# Allowlist for public job JSON (PLT-AC-7). Anything else (body_extended,
# body_single_page, …) never leaves the repository.
PUBLIC_JOB_EXPORT_FIELDS = %w[
  title key company role start end location summary skills links
  body_public published thumbnail description author
].freeze

def load_writing_index_collections
  config_path = REPO_ROOT.join("_config.yml")
  return nil unless config_path.file?

  require "pandorga/registry"
  config = YAML.safe_load(config_path.read, aliases: true) || {}
  pages = PandorgaRegistry.pages(config)
  return nil if pages.empty?

  PandorgaRegistry.writing_collections(pages)
rescue StandardError
  nil
end

WRITING_INDEX_COLLECTIONS_FALLBACK = {
  "articles" => "article",
  "posts" => "post",
  "products" => "product",
  "projects" => "project"
}.freeze

def public_front_matter(front_matter, type)
  if type == "job"
    allowed = PUBLIC_JOB_EXPORT_FIELDS
    return front_matter.select { |key, _| allowed.include?(key.to_s) }
  end

  if %w[article post].include?(type)
    return front_matter.reject { |key, _| %w[date last_updated].include?(key.to_s) }
  end

  front_matter
end

def export_markdown_tree(source_dir, output_dir, type)
  return [] unless source_dir.directory?

  files = []
  source_dir.glob("**/*.{md,markdown}").sort.each do |source|
    front_matter, body = split_front_matter(source.read)
    next unless published_for_export?(front_matter)

    relative_source = source.relative_path_from(CONTENT_ROOT).to_s
    repo_relative_path = Pathname.new("content").join(relative_source).to_s
    existing = existing_output_for_source(relative_source)
    if !path_affected?(repo_relative_path) && existing
      files << keep_existing_output(existing)
      next
    end

    apply_git_chronology!(front_matter, repo_relative_path, type)
    rewrite_front_matter_media!(front_matter)

    if ContentKeys::KEYED_TYPES.include?(type)
      key = ContentKeys.normalize_key(front_matter["key"])
      path_segment = ContentKeys.path_segment(type, key, date: front_matter["date"])
      detail_url = ContentKeys.detail_path(type, key, date: front_matter["date"])
    else
      path_segment = source.basename(source.extname).to_s
      detail_url = nil
    end

    output_path = output_dir.join("#{path_segment}.json")

    payload = {
      "type" => type,
      "slug" => path_segment,
      "key" => ContentKeys.normalize_key(front_matter["key"]),
      "source_path" => relative_source,
      "front_matter" => public_front_matter(front_matter, type),
      "body_markdown" => rewrite_media_references(body.strip)
    }
    payload["url"] = detail_url if detail_url
    if %w[article post].include?(type)
      payload["date"] = front_matter["date"]
      payload["last_updated"] = front_matter["last_updated"]
    end
    if ContentLicense.editorial?(type)
      payload["license"] = ContentLicense.payload(CONTENT_LICENSE)
      payload["copyright"] = ContentLicense.copyright_notice(CONTENT_LICENSE)
    end

    write_json(output_path, payload)
    files << output_path.relative_path_from(OUTPUT_ROOT).to_s
  end
  files
end

def export_bibliography(source_dir, output_dir)
  bib_dir = source_dir.join("collections/bibliography")
  return [] unless bib_dir.directory?

  output_path = output_dir.join("collections/bibliography/references.json")
  if !path_affected?("content/collections/bibliography") && output_path.file?
    return [keep_existing_output(output_path)]
  end

  entries = {}
  bib_dir.glob("*.{yml,yaml}").sort.each do |source|
    key = source.basename(".*").to_s
    data = YAML.safe_load(source.read, permitted_classes: [Date, Time], aliases: true) || {}
    type = data.delete("type").to_s
    fields = {}
    data.each do |name, value|
      fields[name.to_s] = value.to_s
    end

    entries[key] = {
      "type" => type,
      "fields" => fields
    }
  end

  write_json(output_path, entries)
  [output_path.relative_path_from(OUTPUT_ROOT).to_s]
rescue StandardError => e
  warn "Bibliography export failed: #{e.message}"
  []
end

def export_data_tree(source_dir, output_dir)
  return [] unless source_dir.directory?

  files = []
  source_dir.glob("**/*.{yml,yaml}").sort.each do |source|
    next if PRINT_ONLY_DATA_FILES.include?(source.basename.to_s)

    relative = source.relative_path_from(source_dir).to_s.sub(/\.(ya?ml)\z/, ".json")
    output_path = output_dir.join(relative)
    repo_relative = Pathname.new("content/collections/data").join(source.relative_path_from(source_dir)).to_s
    if !path_affected?(repo_relative) && output_path.file?
      files << keep_existing_output(output_path)
      next
    end

    data = YAML.safe_load(source.read, permitted_classes: [Date, Time], aliases: true) || {}
    write_json(output_path, data)
    files << output_path.relative_path_from(OUTPUT_ROOT).to_s
  end
  files
end

def export_page_fragments(source_dir, output_dir)
  return [] unless source_dir.directory?

  files = []
  source_dir.glob("**/*.{md,markdown}").sort.each do |source|
    front_matter, body = split_front_matter(source.read)
    next unless published_for_export?(front_matter)

    relative_output = source.relative_path_from(source_dir).to_s.sub(/\.(md|markdown)\z/, ".json")
    fragment_key = relative_output.sub(/\.json\z/, "")
    next if PRINT_ONLY_PAGE_FRAGMENTS.include?(fragment_key)

    relative_source = source.relative_path_from(CONTENT_ROOT).to_s
    repo_relative_path = Pathname.new("content").join(relative_source).to_s
    existing = existing_output_for_source(relative_source)
    if !path_affected?(repo_relative_path) && existing
      files << keep_existing_output(existing)
      next
    end

    apply_git_chronology!(front_matter, repo_relative_path, "page_fragment")
    rewrite_front_matter_media!(front_matter)

    slug = source.basename(source.extname).to_s
    output_path = output_dir.join(relative_output)

    payload = {
      "type" => "page_fragment",
      "slug" => slug,
      "source_path" => relative_source,
      "front_matter" => front_matter,
      "body_markdown" => rewrite_media_references(body.strip)
    }

    write_json(output_path, payload)
    files << output_path.relative_path_from(OUTPUT_ROOT).to_s
  end
  files
end

# Structured YAML for the pages, exported as plain JSON objects the browser
# runtime fetches directly. `headers.yml` sits at the top of content/pages/ and
# carries every page title, tag line and home band introduction in one object
# at pages/headers.json. A page directory may also keep its own YAML beside its
# markdown fragments; that is exported to pages/<page>/<name>.json. Both shapes
# are handled so a page can add structured copy later without touching this.
def export_page_headers(source_dir, output_dir)
  pages_path = source_dir.join("pages")
  return [] unless pages_path.directory?

  files = []
  sources = pages_path.glob("*.{yml,yaml}").sort + pages_path.glob("*/*.{yml,yaml}").sort
  sources.each do |source|
    relative = source.relative_path_from(pages_path)
    output_path = output_dir.join("pages", relative.to_s.sub(/\.(ya?ml)\z/, ".json"))
    repo_relative = Pathname.new("content/pages").join(relative).to_s
    if !path_affected?(repo_relative) && output_path.file?
      files << keep_existing_output(output_path)
      next
    end

    data = YAML.safe_load(source.read, permitted_classes: [Date, Time], aliases: true) || {}
    write_json(output_path, data)
    files << output_path.relative_path_from(OUTPUT_ROOT).to_s
  end
  files
end

# One object per image in content/media/images/hero/. The browser reads this
# file; there is no author-maintained list. Runs on a full export, and on an
# incremental export when the folder changed.
def export_hero_portraits(content_root, output_root)
  output_path = output_root.join("pages/home/portraits.json")
  affected = path_affected?("content/media/images/hero")
  if !affected && output_path.file?
    return keep_existing_output(output_path)
  end

  write_json(output_path, HeroPortraits.entries(content_root))
  output_path.relative_path_from(output_root).to_s
end

def index_date(value)
  case value
  when Date then value.iso8601
  when Time then value.to_date.iso8601
  else
    value.to_s
  end
end

WRITING_INDEX_XCITE_RE = /\{%-?\s*include\s+xcite\.html\s+key=["']([^"']+)["'][^%]*-?%\}/
WRITING_INDEX_COLLECTIONS = load_writing_index_collections || WRITING_INDEX_COLLECTIONS_FALLBACK

def writing_index_from_export(output_root, content_root)
  entries = []
  WRITING_INDEX_COLLECTIONS.each do |collection, type|
    output_root.glob("collections/#{collection}/*.json").sort.each do |json_path|
      payload = JSON.parse(json_path.read)
      next unless payload["type"].to_s == type

      entry = writing_index_entry_from_export(payload, content_root, collection)
      entries << entry if entry
    end
  end
  entries
end

def writing_index_entry_from_export(payload, content_root, collection)
  source_path = payload["source_path"].to_s
  source = Pathname.new(content_root).join(source_path)
  if source.file?
    front_matter, body = split_front_matter(source.read.sub(/\A\xEF\xBB\xBF/, ""))
  else
    front_matter = payload["front_matter"].is_a?(Hash) ? payload["front_matter"] : {}
    body = payload["body_markdown"].to_s
  end
  return nil if front_matter["published"] == false

  key = payload["key"].to_s
  key = ContentKeys.normalize_key(front_matter["key"]) if key.empty?
  return nil if key.empty?

  slug = payload["slug"].to_s
  return nil if slug.empty?

  xcites = Array(front_matter["xcites"]).map(&:to_s).reject(&:empty?)
  xcites = body.scan(WRITING_INDEX_XCITE_RE).flatten.uniq if xcites.empty?
  listing = TextExcerpt.listing_fields(front_matter, body)

  title = front_matter["title"].to_s
  title = front_matter["product"].to_s if title.empty? && front_matter["product"]
  title = front_matter["project"].to_s if title.empty? && front_matter["project"]

  publication_date = payload["date"] || front_matter["date"] || front_matter["start_date"]
  last_updated = payload["last_updated"] || front_matter["last_updated"]
  writing_type = payload["type"]
  url = payload["url"].to_s
  if url.empty? && ContentKeys::TYPE_CONFIG.key?(writing_type)
    url = ContentKeys.detail_path(writing_type, key, date: publication_date)
  end

  legacy = File.basename(source_path, File.extname(source_path))
  {
    "slug" => slug,
    "key" => key,
    "title" => title,
    "date" => index_date(publication_date),
    "last_updated" => index_date(last_updated),
    "url" => url,
    "type" => collection,
    "collection" => collection,
    "category" => front_matter["category"].to_s,
    "language" => front_matter["language"].to_s,
    "description" => listing["description"],
    "excerpt" => listing["excerpt"],
    "thumbnail" => front_matter["thumbnail"].to_s,
    "xcites" => xcites,
    "company" => front_matter["company"].to_s,
    "product" => front_matter["product"].to_s,
    "project" => front_matter["project"].to_s,
    "tagline" => front_matter["tagline"].to_s,
    "start_date" => front_matter["start_date"].to_s,
    "end_date" => front_matter["end_date"].to_s,
    "sort_order" => front_matter["sort_order"],
    "status" => front_matter["status"].to_s,
    "label" => front_matter["label"].to_s,
    "icon" => front_matter["icon"].to_s,
    "tags" => Array(front_matter["tags"]),
    "external_url" => front_matter["external_url"].to_s,
    "article_url" => front_matter["article_url"].to_s,
    "github" => front_matter["github"].to_s,
    "aliases" => ContentKeys.alias_slugs(
      "legacy_segment" => legacy,
      "key" => key,
      "redirects" => ContentKeys.normalize_redirects(front_matter),
      "path_segment" => slug
    )
  }
end

def export_derived_data(content_root, output_root)
  adapter = ContentSiteAdapter.new(content_root, include_writing_index: false)
  timeline_path = output_root.join("data/timeline.json")
  writing_index_path = output_root.join("data/writing_index.json")

  # Slug/date/url come from the just-exported JSON so listings cannot point at
  # a dated path that is not in the object set (08-23 index vs 08-22 file).
  index = writing_index_from_export(output_root, content_root)
  adapter.data["writing_index"] = index
  write_json(writing_index_path, index)
  WritingIndexContract.assert_slugs_match_export!(output_root, index)
  write_json(timeline_path, TimelineBuilder.build(adapter))

  {
    "timeline" => [timeline_path.relative_path_from(output_root).to_s],
    "writing_index" => [writing_index_path.relative_path_from(output_root).to_s],
    "band_art" => export_band_art(output_root, index)
  }
end

# The home page's reference band, drawn from the corpus this run just exported
# rather than from committed markup. See docs/features/home-band-art.md for why
# it lives here: a Studio save never rebuilds the shell, so art baked into a
# layout stops counting the day it is written.
def export_band_art(output_root, writing_index)
  resources = Pathname.glob(output_root.join("collections", "resources", "*.json"))
                      .sort
                      .map do |path|
    payload = JSON.parse(path.read)
    (payload["front_matter"] || {}).merge("slug" => payload["slug"])
  end

  BandArt.build(writing_index: writing_index, resources: resources).map do |name, svg|
    path = output_root.join("data", "band-art-#{name}.svg")
    write_text(path, svg)
    path.relative_path_from(output_root).to_s
  end.sort
end

ContentValidators.validate_all!(REPO_ROOT) unless ENV["CONTENT_EXPORT_SKIP_VALIDATE"] == "1"

# Output mirrors a flat collections/ hierarchy in the bucket (articles, posts,
# products, ...) aligned with source paths under content/collections/.
# Reuse an existing OUTPUT_ROOT when present: identical payloads keep their
# bytes/mtimes. CONTENT_EXPORT_CHANGED_PATHS(_FILE) skips chronology/rebuild
# for untouched sources (still exports missing files; always rebuilds
# writing_index, timeline, and manifest). Stale files are pruned afterward.
files = {
  "articles" => export_markdown_tree(CONTENT_ROOT.join("collections", "articles"), OUTPUT_ROOT.join("collections", "articles"), "article"),
  "posts" => export_markdown_tree(CONTENT_ROOT.join("collections", "posts"), OUTPUT_ROOT.join("collections", "posts"), "post"),
  "products" => export_markdown_tree(CONTENT_ROOT.join("collections", "products"), OUTPUT_ROOT.join("collections", "products"), "product"),
  "projects" => export_markdown_tree(CONTENT_ROOT.join("collections", "projects"), OUTPUT_ROOT.join("collections", "projects"), "project"),
  "jobs" => export_markdown_tree(CONTENT_ROOT.join("collections", "jobs"), OUTPUT_ROOT.join("collections", "jobs"), "job"),
  "resources" => export_markdown_tree(CONTENT_ROOT.join("collections", "resources"), OUTPUT_ROOT.join("collections", "resources"), "resource"),
  "page_fragments" => export_page_fragments(CONTENT_ROOT.join("pages"), OUTPUT_ROOT.join("pages")),
  "page_headers" => export_page_headers(CONTENT_ROOT, OUTPUT_ROOT) << export_hero_portraits(CONTENT_ROOT, OUTPUT_ROOT),
  "data" => export_data_tree(CONTENT_ROOT.join("collections", "data"), OUTPUT_ROOT.join("data")),
  "bibliography" => export_bibliography(CONTENT_ROOT, OUTPUT_ROOT)
}
files.merge!(export_derived_data(CONTENT_ROOT, OUTPUT_ROOT))
counts = files.transform_values(&:length)

write_json(OUTPUT_ROOT.join("manifest.json"), {
  "schema_version" => 1,
  "generated_at" => Time.now.utc.iso8601,
  "content_root" => CONTENT_ROOT.to_s,
  "content_api_base_url" => CONTENT_API_BASE_URL,
  "content_license" => ContentLicense.payload(CONTENT_LICENSE),
  "software_license" => ContentLicense::SOFTWARE,
  "counts" => counts,
  "files" => files
})

pruned = prune_stale_output_files!

ContentKeys.sync_redirects_file!(REPO_ROOT) unless INCREMENTAL_EXPORT

puts "Exported content JSON to #{OUTPUT_ROOT}"
counts.each { |name, count| puts "  #{name}: #{count}" }
puts "  write: changed=#{OUTPUT_WRITE_STATS[:written]} unchanged=#{OUTPUT_WRITE_STATS[:unchanged]} pruned=#{pruned}"
if INCREMENTAL_EXPORT
  puts "  incremental paths: #{CHANGED_PATHS.length}"
end
