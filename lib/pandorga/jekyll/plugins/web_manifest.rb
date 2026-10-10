# frozen_string_literal: true

require "jekyll"
require "json"

module Pandorga
  module Jekyll
    # Writes the web app manifests the shell and Studio link. The icons are
    # theme assets. A site file at the same path overrides an icon; the
    # manifest itself is generated so the name follows the site identity.
    class WebManifestGenerator < ::Jekyll::Generator
      safe true
      priority :low

      def generate(site)
        emit(site, "site.webmanifest", site_manifest(site))
        emit(site, "studio.webmanifest", studio_manifest)
      end

      private

      def emit(site, name, payload)
        page = ::Jekyll::PageWithoutAFile.new(site, site.source, "", name)
        page.data["layout"] = nil
        page.data["sitemap"] = false
        page.content = "#{JSON.pretty_generate(payload)}\n"
        site.pages << page
      end

      def site_manifest(site)
        config = site.config
        pandorga = config["pandorga"].is_a?(Hash) ? config["pandorga"] : {}
        identity = pandorga["identity"].is_a?(Hash) ? pandorga["identity"] : {}
        name = identity["name"].to_s.strip
        name = config["title"].to_s.strip if name.empty?
        name = "Site" if name.empty?
        short = identity["short_name"].to_s.strip
        short = name if short.empty?
        manifest("/", name, short, studio: false)
      end

      def studio_manifest
        manifest("/studio/", "Studio", "Studio", studio: true)
      end

      def manifest(start, name, short, studio:)
        {
          "id" => start,
          "name" => name,
          "short_name" => short,
          "start_url" => start,
          "scope" => start,
          "display" => "standalone",
          "background_color" => "#5e5d59",
          "theme_color" => "#5e5d59",
          "icons" => icons(studio: studio)
        }
      end

      # Stems match scripts/render-pwa-icons.py. The site maskable file is
      # icon-maskable-*.png. Studio's is studio-maskable-*.png.
      def icons(studio:)
        any_stem = studio ? "studio-icon" : "icon"
        mask_stem = studio ? "studio-maskable" : "icon-maskable"
        [
          [512, any_stem, "any"],
          [512, mask_stem, "maskable"],
          [192, any_stem, "any"],
          [192, mask_stem, "maskable"]
        ].map do |size, stem, purpose|
          {
            "src" => "/assets/icons/#{stem}-#{size}.png",
            "sizes" => "#{size}x#{size}",
            "type" => "image/png",
            "purpose" => purpose
          }
        end
      end
    end
  end
end
