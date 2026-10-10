# frozen_string_literal: true

require "jekyll"
require_relative "../../discovery"

module Pandorga
  module Jekyll
    # Writes /sitemap.xml and /robots.txt from the pages already generated.
    class DiscoveryGenerator < ::Jekyll::Generator
      safe true
      priority :lowest

      def generate(site)
        origin = Pandorga::Discovery.origin(site.config)
        paths = Pandorga::Discovery.public_paths(site.pages)
        sitemap = Pandorga::Discovery.absolute(origin, "/sitemap.xml")
        emit(site, "sitemap.xml", Pandorga::Discovery.sitemap_xml(origin, paths))
        emit(site, "robots.txt", Pandorga::Discovery.robots_txt(sitemap))
      end

      private

      def emit(site, name, content)
        page = ::Jekyll::PageWithoutAFile.new(site, site.source, "", name)
        page.data["layout"] = nil
        page.data["sitemap"] = false
        page.content = content
        site.pages << page
      end
    end
  end
end
