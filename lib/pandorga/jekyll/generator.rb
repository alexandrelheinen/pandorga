# frozen_string_literal: true

require "jekyll"
require_relative "../registry"

module Pandorga
  module Jekyll
    # Generates listing pages and nav data from pandorga.pages (PLT-AC-3).
    class Generator < ::Jekyll::Generator
      safe true
      priority :high

      # Template defaults when registry omits `detail` (English platform paths).
      DEFAULT_DETAILS = {
        "articles" => "/articles/:slug/",
        "blog" => "/posts/:slug/",
        "portfolio" => "/projects/:slug/"
      }.freeze

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
        site.data["pandorga_home_bands"] = PandorgaRegistry.home_bands(pages)

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

        listing_path = path.end_with?("/") ? path : "#{path}/"
        rel_dir = path.sub(%r{\A/}, "").sub(%r{/\z}, "")
        page = ::Jekyll::PageWithoutAFile.new(site, site.source, rel_dir, "index.html")
        page.data["layout"] = PandorgaRegistry.layout_for(entry)
        page.data["key"] = entry["key"]
        page.data["template"] = entry["template"] if entry["template"]
        page.data["title"] = entry["title"] if entry["title"]
        page.data["description"] = entry["description"] if entry["description"]
        page.data["accent"] = entry["accent"] if entry["accent"]
        page.data["badge"] = entry["badge"] if entry["badge"]
        page.data["lang"] = entry["language"] if entry["language"]
        page.data["permalink"] = listing_path
        # listing_path is explicit: Jekyll reserves page.path for the source file.
        page.data["listing_path"] = listing_path
        page.data["collection"] = entry["collection"] if entry["collection"]
        detail = entry["detail"].to_s
        detail = DEFAULT_DETAILS[entry["template"].to_s].to_s if detail.empty?
        page.data["detail"] = detail unless detail.empty?
        page.content = ""
        site.pages << page
      end
    end
  end
end
