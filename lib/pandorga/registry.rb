# frozen_string_literal: true

# Page registry helpers (no Jekyll dependency — safe for the exporter CLI).
# Refs: PLT-AC-3, PLT-AC-5

module PandorgaRegistry
  KNOWN_TEMPLATES = %w[
    cv articles blog media network bibliography portfolio
  ].freeze

  module_function

  def pages(config)
    raw = config.dig("pandorga", "pages")
    return [] unless raw.is_a?(Array)

    raw
  end

  def validate!(pages)
    keys = []
    paths = []
    pages.each_with_index do |page, i|
      raise ArgumentError, "pandorga.pages[#{i}] must be a mapping" unless page.is_a?(Hash)

      key = page["key"].to_s
      raise ArgumentError, "pandorga.pages[#{i}]: missing key" if key.empty?
      raise ArgumentError, "pandorga.pages: duplicate key #{key.inspect}" if keys.include?(key)

      keys << key

      template = page["template"].to_s
      raise ArgumentError, "pandorga.pages[#{key}]: missing template" if template.empty?
      unless KNOWN_TEMPLATES.include?(template)
        raise ArgumentError,
              "pandorga.pages[#{key}]: unknown template #{template.inspect} " \
              "(known: #{KNOWN_TEMPLATES.join(', ')})"
      end

      path = page["path"].to_s
      next if path.empty?
      raise ArgumentError, "pandorga.pages: conflicting path #{path.inspect}" if paths.include?(path)

      paths << path
    end
  end

  def build_nav(pages)
    groups = {}
    order = []
    pages.each do |page|
      next unless page.is_a?(Hash)
      next if page["nav"] == false

      nav = page["nav"].is_a?(Hash) ? page["nav"] : {}
      group = nav["group"] || "Pages"
      unless groups.key?(group)
        groups[group] = []
        order << group
      end
      item = { "key" => page["key"] }
      item["icon"] = nav["icon"] if nav["icon"]
      groups[group] << item
    end
    order.map { |label| { "label" => label, "pages" => groups[label] } }
  end

  def writing_collections(pages)
    map = {}
    pages.each do |page|
      next unless page.is_a?(Hash)
      next unless %w[articles blog].include?(page["template"].to_s)

      collection = page["collection"].to_s
      next if collection.empty?

      type = case collection
             when "articles" then "article"
             when "posts" then "post"
             else collection.sub(/s\z/, "")
             end
      map[collection] = type
    end
    map["products"] ||= "product"
    map["projects"] ||= "project"
    map
  end
end
