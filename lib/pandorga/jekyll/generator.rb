# frozen_string_literal: true

require "jekyll"
require_relative "../registry"

module Pandorga
  module Jekyll
    # Generates listing pages and nav data from pandorga.pages (PLT-AC-3).
    class Generator < ::Jekyll::Generator
      safe true
      priority :high

      def generate(site)
        pages = PandorgaRegistry.pages(site.config)
        return if pages.empty?

        begin
          PandorgaRegistry.validate!(pages)
        rescue ArgumentError => e
          raise ::Jekyll::Errors::FatalException, e.message
        end

        # Website shell reads site.data.nav (label/pages/key shape).
        site.data["nav"] = PandorgaRegistry.build_nav(pages)
        site.data["pandorga_pages"] = pages
        site.data["pandorga_nav"] = site.data["nav"]

        existing_keys = site.pages.map { |p| p.data["key"] }.compact
        pages.each do |entry|
          next unless entry.is_a?(Hash)
          next if existing_keys.include?(entry["key"])

          emit_page(site, entry)
        end
      end

      private

      def emit_page(site, entry)
        path = entry["path"].to_s
        return if path.empty?

        rel_dir = path.sub(%r{\A/}, "").sub(%r{/\z}, "")
        page = ::Jekyll::PageWithoutAFile.new(site, site.source, rel_dir, "index.html")
        page.data["layout"] = entry["layout"] || "pandorga/#{entry['template']}"
        page.data["key"] = entry["key"]
        page.data["title"] = entry["title"] if entry["title"]
        page.data["description"] = entry["description"] if entry["description"]
        page.data["accent"] = entry["accent"] if entry["accent"]
        page.data["badge"] = entry["badge"] if entry["badge"]
        page.data["lang"] = entry["language"] if entry["language"]
        page.data["permalink"] = path.end_with?("/") ? path : "#{path}/"
        page.content = ""
        site.pages << page
      end
    end
  end
end
