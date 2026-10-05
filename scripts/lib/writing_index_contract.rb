# frozen_string_literal: true

require "json"
require "pathname"

# writing_index slugs must resolve to an exported collections JSON object.
# Catches the Freshy-class bug (index date 2026-08-23, file still 2026-08-22).
module WritingIndexContract
  TYPE_TO_COLLECTION = {
    "article" => "articles",
    "post" => "posts",
    "product" => "products",
    "project" => "projects",
    "articles" => "articles",
    "posts" => "posts",
    "products" => "products",
    "projects" => "projects"
  }.freeze

  module_function

  def collection_for(entry)
    TYPE_TO_COLLECTION[entry["collection"].to_s] ||
      TYPE_TO_COLLECTION[entry["type"].to_s]
  end

  def export_path_for(entry)
    collection = collection_for(entry)
    slug = entry["slug"].to_s
    return nil if collection.nil? || slug.empty?

    "collections/#{collection}/#{slug}.json"
  end

  def mismatches(output_root, entries = nil)
    root = Pathname.new(output_root)
    entries = JSON.parse(root.join("data/writing_index.json").read) if entries.nil?
    errors = []

    Array(entries).each do |entry|
      relative = export_path_for(entry)
      if relative.nil?
        errors << "writing_index entry #{entry['key'].inspect} missing collection/slug"
        next
      end

      next if root.join(relative).file?

      errors << "writing_index slug #{entry['slug'].inspect} (key=#{entry['key']}) " \
                "has no #{relative}"
    end
    errors
  end

  def assert_slugs_match_export!(output_root, entries = nil)
    errors = mismatches(output_root, entries)
    return if errors.empty?

    raise "writing_index slug/export mismatch:\n  - #{errors.join("\n  - ")}"
  end
end
