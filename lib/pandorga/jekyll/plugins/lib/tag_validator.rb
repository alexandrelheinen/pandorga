# frozen_string_literal: true

require "pathname"
require "yaml"
require "date"

# Tags replaced category as the single classification axis for articles and
# rascunhos. Vocabulary is closed per collection and loaded from
# `_config.yml` → `pandorga.taxonomies` (PLT Phase 1).
module TagValidator
  DEFAULT_MAX_TAGS = 3

  COLLECTIONS_WITHOUT_REQUIRED_TAGS = %w[posts].freeze

  module_function

  def load_vocabularies(repo_root = Pathname.pwd)
    root = Pathname.new(repo_root)
    config_path = root.join("_config.yml")
    return {} unless config_path.file?

    config = YAML.safe_load(config_path.read, permitted_classes: [Date, Time], aliases: true) || {}
    vocab = {}

    taxonomies = config.dig("pandorga", "taxonomies")
    if taxonomies.is_a?(Hash)
      taxonomies.each do |collection, spec|
        next unless spec.is_a?(Hash)

        tags = spec["tags"]
        next unless tags.is_a?(Array)

        vocab[collection.to_s] = tags.map(&:to_s).freeze
      end
    end

    # Page-local taxonomy (pandorga.pages[].taxonomy) fills gaps.
    pages = config.dig("pandorga", "pages")
    if pages.is_a?(Array)
      pages.each do |page|
        next unless page.is_a?(Hash)

        collection = page["collection"].to_s
        next if collection.empty? || vocab.key?(collection)

        spec = page["taxonomy"]
        next unless spec.is_a?(Hash)

        tags = spec["tags"]
        next unless tags.is_a?(Array)

        vocab[collection] = tags.map(&:to_s).freeze
      end
    end

    vocab
  end

  def max_tags_for(collection, repo_root = Pathname.pwd)
    root = Pathname.new(repo_root)
    config_path = root.join("_config.yml")
    return DEFAULT_MAX_TAGS unless config_path.file?

    config = YAML.safe_load(config_path.read, permitted_classes: [Date, Time], aliases: true) || {}
    max = config.dig("pandorga", "taxonomies", collection.to_s, "max")
    if max.nil?
      pages = config.dig("pandorga", "pages")
      if pages.is_a?(Array)
        page = pages.find { |p| p.is_a?(Hash) && p["collection"].to_s == collection.to_s }
        max = page.dig("taxonomy", "max") if page.is_a?(Hash)
      end
    end
    max.nil? ? DEFAULT_MAX_TAGS : Integer(max)
  rescue ArgumentError, TypeError
    DEFAULT_MAX_TAGS
  end

  def collect_errors(repo_root = Pathname.pwd)
    root = Pathname.new(repo_root)
    errors = []
    vocabulary = load_vocabularies(root)

    if vocabulary.empty?
      errors << "_config.yml: pandorga.taxonomies is missing or empty"
      return errors
    end

    vocabulary.each do |collection, allowed|
      dir = root.join("content", "collections", collection)
      next unless dir.directory?

      tags_required = !COLLECTIONS_WITHOUT_REQUIRED_TAGS.include?(collection)
      max_tags = max_tags_for(collection, root)

      Dir.glob(dir.join("*.md")).sort.each do |path|
        relative = Pathname.new(path).relative_path_from(root)
        front_matter = read_front_matter(path)
        next if front_matter.nil?

        if front_matter.key?("category")
          errors << "#{relative}: uses `category`; tags replaced it as the " \
                    "single classification axis"
        end

        tags = front_matter["tags"]
        if tags.nil?
          errors << "#{relative}: missing `tags`" if tags_required
          next
        end

        unless tags.is_a?(Array)
          errors << "#{relative}: `tags` must be a list, got #{tags.class}"
          next
        end

        if tags.empty?
          errors << "#{relative}: `tags` is empty; every entry needs at least one" if tags_required
          next
        end

        if tags.size > max_tags
          errors << "#{relative}: #{tags.size} tags exceeds the #{max_tags} " \
                    "allowed — pick the ones that would actually be filtered on"
        end

        if tags.uniq.size != tags.size
          errors << "#{relative}: duplicate tags #{(tags - tags.uniq).uniq.inspect}"
        end

        unknown = tags.reject { |tag| allowed.include?(tag.to_s) }
        next if unknown.empty?

        errors << "#{relative}: unknown #{collection} tag(s) #{unknown.inspect}. " \
                  "Allowed: #{allowed.join(', ')}"
      end
    end

    errors
  end

  def read_front_matter(path)
    source = File.read(path)
    return nil unless source.start_with?("---")

    raw = source.split(/^---\s*$/, 3)[1]
    return nil if raw.nil?

    parsed = YAML.safe_load(raw, permitted_classes: [Date, Time], aliases: true)
    parsed.is_a?(Hash) ? parsed : nil
  rescue Psych::SyntaxError
    nil
  end
end
