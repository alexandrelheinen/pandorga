# frozen_string_literal: true

require "jekyll"

module Pandorga
  module Jekyll
    # Generates listing pages and nav data from pandorga.pages (PLT-AC-3).
    class Generator < ::Jekyll::Generator
      safe true
      priority :high

      def generate(site)
        pages = site.config.dig("pandorga", "pages")
        return unless pages.is_a?(Array)

        validate!(pages)
        site.data["pandorga_nav"] = build_nav(pages)
        pages.each { |entry| emit_page(site, entry) if entry.is_a?(Hash) }
      end

      private

      def validate!(pages)
        keys = []
        paths = []
        pages.each_with_index do |page, i|
          raise ::Jekyll::Errors::FatalException, "pandorga.pages[#{i}] must be a mapping" unless page.is_a?(Hash)

          key = page["key"].to_s
          raise ::Jekyll::Errors::FatalException, "pandorga.pages[#{i}]: missing key" if key.empty?
          raise ::Jekyll::Errors::FatalException, "pandorga.pages: duplicate key #{key}" if keys.include?(key)

          keys << key
          template = page["template"].to_s
          raise ::Jekyll::Errors::FatalException, "pandorga.pages[#{key}]: missing template" if template.empty?

          path = page["path"].to_s
          next if path.empty?

          raise ::Jekyll::Errors::FatalException, "pandorga.pages: conflicting path #{path}" if paths.include?(path)

          paths << path
        end
      end

      def build_nav(pages)
        groups = {}
        pages.each do |page|
          next unless page.is_a?(Hash)
          next if page["nav"] == false

          nav = page["nav"].is_a?(Hash) ? page["nav"] : {}
          group = nav["group"] || "Pages"
          groups[group] ||= []
          groups[group] << {
            "key" => page["key"],
            "title" => page["title"] || page["key"].to_s.capitalize,
            "path" => page["path"],
            "icon" => nav["icon"]
          }
        end
        groups.map { |name, items| { "name" => name, "items" => items } }
      end

      def emit_page(site, entry)
        path = entry["path"].to_s
        return if path.empty?

        rel = path.sub(%r{\A/}, "").sub(%r{/\z}, "") + "/index.html"
        page = ::Jekyll::PageWithoutAFile.new(site, site.source, File.dirname(rel), File.basename(rel))
        page.data["layout"] = entry["layout"] || "pandorga/#{entry['template']}"
        page.data["key"] = entry["key"]
        page.data["title"] = entry["title"] if entry["title"]
        page.data["permalink"] = path.end_with?("/") ? path : "#{path}/"
        page.content = ""
        site.pages << page
      end
    end
  end
end
