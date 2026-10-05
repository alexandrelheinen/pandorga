# frozen_string_literal: true

require "date"
require "pathname"
require "set"
require "yaml"

require_relative "git_chronology"
require_relative "content_keys"
require_relative "content_writing_paths"
require_relative "lib/text_excerpt"
require_relative "lib/writing_entry"

# Indexes articles and posts from /content for timeline and network features
# without emitting Jekyll collection pages (those load from the content API).
module Jekyll
  class ContentWritingIndex < Generator
    safe true
    priority :high


    def generate(site)
      return if site.config["shell_content_agnostic"]

      content_root = File.join(site.source, site.config["content_root"] || "content")
      entries = []

      if File.directory?(content_root)
        ContentWritingPaths::INDEX_BY_COLLECTION.each do |collection, relative_path|
          directory = File.join(content_root, relative_path)
          next unless File.directory?(directory)

          Dir.glob(File.join(directory, "*.{md,markdown}")).sort.each do |absolute_path|
            entry = build_entry(absolute_path, collection)
            entries << entry if entry
          end
        end
      end

      site.data["writing_index"] = entries
    end

    private

    def build_entry(absolute_path, collection)
      repo_relative_path = ContentWritingPaths.repo_relative_for_index_collection(
        collection, File.basename(absolute_path)
      )
      WritingEntry.build(absolute_path, collection, repo_relative_path)
    end
  end
end
