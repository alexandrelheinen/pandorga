# frozen_string_literal: true

require "date"
require "pathname"
require "ostruct"
require "yaml"

require_relative "git_chronology"
require_relative "content_keys"
require_relative "content_writing_paths"
require_relative "lib/text_excerpt"
require_relative "lib/writing_entry"

begin
  require "pandorga/registry"
rescue LoadError
  # Exporter may load this file before the gem lib path is on $LOAD_PATH.
end

# Minimal site-like object built from /content for export-time derived data
# (timeline, writing_index) without running a Jekyll build.
class ContentSiteAdapter
  Doc = Struct.new(:data, :url, :path, keyword_init: true)

  COLLECTION_DIRS = {
    "products" => "collections/products",
    "projects" => "collections/projects",
    "jobs" => "collections/jobs"
  }.freeze

  attr_reader :collections, :data

  def initialize(content_root, include_writing_index: true, config: nil)
    @content_root = Pathname.new(content_root)
    @config = config.is_a?(Hash) ? config : load_site_config
    @collections = build_collections
    @data = {
      "education" => load_yaml_array("collections/data/education.yml"),
      "writing_index" => include_writing_index ? build_writing_index : []
    }
  end

  private

  def load_site_config
    root = Pathname.new(ENV.fetch("PANDORGA_SITE_ROOT", Dir.pwd)).expand_path
    path = root.join("_config.yml")
    return {} unless path.file?

    YAML.safe_load(path.read, permitted_classes: [Date, Time], aliases: true) || {}
  rescue StandardError
    {}
  end

  def collection_dirs
    return COLLECTION_DIRS unless defined?(PandorgaRegistry)

    pages = PandorgaRegistry.pages(@config)
    return COLLECTION_DIRS if pages.empty?

    dirs = PandorgaRegistry.adapter_collection_dirs(pages)
    dirs.empty? ? COLLECTION_DIRS : dirs
  end

  def build_collections
    collection_dirs.each_with_object({}) do |(name, relative), hash|
      hash[name] = OpenStruct.new(docs: load_collection_docs(relative, name))
    end
  end

  def load_collection_docs(relative_dir, collection_name)
    dir = @content_root.join(relative_dir)
    return [] unless dir.directory?

    type = case collection_name
           when "products" then "product"
           when "projects" then "project"
           when "jobs" then "job"
           else collection_name
           end

    Dir.glob(dir.join("*.{md,markdown}")).sort.filter_map do |absolute_path|
      text = File.read(absolute_path).sub(/\A\xEF\xBB\xBF/, "")
      front_matter, = split_front_matter(text)
      next if front_matter["published"] == false

      if ContentKeys::KEYED_TYPES.include?(type)
        key = ContentKeys.normalize_key(front_matter["key"])
        path_segment = ContentKeys.path_segment(type, key, date: front_matter["date"])
        url = ContentKeys.detail_path(type, key, date: front_matter["date"])
      else
        key = ContentKeys.filename_stem(absolute_path)
        path_segment = key
        url = "/#{collection_name}/#{path_segment}/"
      end

      Doc.new(
        data: stringify_keys(front_matter.merge("key" => key, "slug" => path_segment)),
        url: url,
        path: absolute_path
      )
    end
  end

  def build_writing_index
    entries = []
    index_collections.each do |collection, relative_path|
      directory = @content_root.join(relative_path)
      next unless directory.directory?

      Dir.glob(directory.join("*.{md,markdown}")).sort.each do |absolute_path|
        entry = build_writing_entry(absolute_path, collection)
        entries << entry if entry
      end
    end
    entries
  end

  def index_collections
    if defined?(PandorgaRegistry)
      pages = PandorgaRegistry.pages(@config)
      unless pages.empty?
        map = PandorgaRegistry.writing_collections(pages)
        return map.keys.each_with_object({}) do |name, hash|
          hash[name] = "collections/#{name}"
        end
      end
    end
    ContentWritingPaths::INDEX_BY_COLLECTION
  end

  def build_writing_entry(absolute_path, collection)
    relative_source = Pathname.new(absolute_path).relative_path_from(@content_root).to_s
    repo_relative_path = Pathname.new(ContentWritingPaths::CONTENT_ROOT_SEGMENT)
                         .join(relative_source).to_s
    WritingEntry.build(absolute_path, collection, repo_relative_path)
  end

  def load_yaml_array(relative_path)
    path = @content_root.join(relative_path)
    return [] unless path.file?

    YAML.safe_load_file(path, permitted_classes: [Date, Time], aliases: true) || []
  end

  def split_front_matter(text)
    return [{}, text] unless text.start_with?("---\n")

    parts = text.split(/^---\s*$\n?/, 3)
    return [{}, text] unless parts.length == 3

    data = YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true) || {}
    [data, parts[2]]
  end

  def stringify_keys(hash)
    hash.transform_keys(&:to_s)
  end
end
