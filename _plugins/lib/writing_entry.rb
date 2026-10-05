# frozen_string_literal: true

require "date"
require "yaml"

require_relative "../git_chronology"
require_relative "../content_keys"
require_relative "../content_writing_paths"
require_relative "text_excerpt"

# Builds one writing-index record from a content Markdown file.
#
# Two callers need the identical record from the identical files:
# Jekyll::ContentWritingIndex (inside a Jekyll build) and ContentSiteAdapter
# (standalone, for scripts/content/export-content-json.rb). They differ only in how
# they derive the repo-relative path used for Git chronology, so each passes
# its own. Everything downstream lives here, because a field added or a bug
# fixed in one copy used to leave the other silently beNewsreader.
module WritingEntry
  XCITE_RE = /\{%-?\s*include\s+xcite\.html\s+key=["']([^"']+)["'][^%]*-?%\}/

  module_function

  # Returns the record hash, or nil when the document is unpublished or keyless.
  def build(absolute_path, collection, repo_relative_path)
    text = File.read(absolute_path).sub(/\A\xEF\xBB\xBF/, "")
    front_matter, body = split_front_matter(text)
    return nil if front_matter["published"] == false

    writing_type = ContentWritingPaths::INDEX_TYPE_FOR_COLLECTION.fetch(collection)
    if %w[article post].include?(writing_type)
      GitChronology.apply!(front_matter, repo_relative_path, writing_type)
      publication_date = front_matter["date"]
    else
      publication_date = ContentKeys.normalize_date(front_matter["date"]) ||
                         ContentKeys.normalize_date(front_matter["start_date"])
    end

    key = ContentKeys.normalize_key(front_matter["key"])
    return nil if key.empty?

    path_segment = ContentKeys.path_segment(writing_type, key, date: publication_date)
    xcites = Array(front_matter["xcites"]).map(&:to_s).reject(&:empty?)
    xcites = body.scan(XCITE_RE).flatten.uniq if xcites.empty?

    title = front_matter["title"].to_s
    title = front_matter["product"].to_s if title.empty? && front_matter["product"]
    title = front_matter["project"].to_s if title.empty? && front_matter["project"]
    listing = TextExcerpt.listing_fields(front_matter, body)

    {
      "slug" => path_segment,
      "key" => key,
      "title" => title,
      "date" => normalize_date(publication_date),
      "last_updated" => normalize_date(front_matter["last_updated"]),
      "url" => ContentKeys.detail_path(writing_type, key, date: publication_date),
      "type" => collection,
      "collection" => collection,
      "category" => front_matter["category"].to_s,
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
        "legacy_segment" => File.basename(absolute_path, File.extname(absolute_path)),
        "key" => key,
        "redirects" => ContentKeys.normalize_redirects(front_matter),
        "path_segment" => path_segment
      )
    }
  end

  def split_front_matter(text)
    return [{}, text] unless text.start_with?("---\n")

    parts = text.split(/^---\s*$\n?/, 3)
    return [{}, text] unless parts.length == 3

    data = YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true) || {}
    [data, parts[2]]
  end

  def normalize_date(value)
    case value
    when Date then value.iso8601
    when Time then value.to_date.iso8601
    when String then value
    else
      value&.to_s
    end
  end
end
