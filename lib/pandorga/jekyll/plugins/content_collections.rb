# frozen_string_literal: true

require "pathname"
require "set"

# Loads editorial Markdown from /content into Jekyll collections at build time.
# This keeps /content excluded from the default Jekyll read path while still
# providing collection docs for product/project pages, timeline, network graph,
# CV jobs, and related plugins. Articles and posts stay API-backed; their metadata
# is indexed separately by ContentWritingIndex.
module Jekyll
  class ContentCollections < Generator
    safe true
    priority :highest

    COLLECTION_PATHS = {
      "products" => "collections/products",
      "projects" => "collections/projects",
      "jobs" => "collections/jobs",
      "resources" => "collections/resources"
    }.freeze

    def generate(site)
      return if site.config["shell_content_agnostic"]

      content_root = File.join(site.source, site.config["content_root"] || "content")
      return unless File.directory?(content_root)

      COLLECTION_PATHS.each do |collection_name, relative_path|
        inject_documents(site, collection_name, File.join(content_root, relative_path))
      end
    end

    private

    def inject_documents(site, collection_name, directory)
      collection = site.collections[collection_name]
      return unless collection && File.directory?(directory)

      existing_paths = collection.docs.map(&:path).to_set

      Dir.glob(File.join(directory, "**", "*.{md,markdown}")).sort.each do |absolute_path|
        relative_path = Pathname.new(absolute_path).relative_path_from(Pathname.new(site.source)).to_s
        next if existing_paths.include?(relative_path)

        doc = Jekyll::Document.new(relative_path, site: site, collection: collection)
        doc.read
        collection.docs << doc
      end
    end
  end
end
