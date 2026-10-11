# frozen_string_literal: true

require "jekyll"
require "pathname"

require_relative "../../detail_routes"
require_relative "lib/writing_entry"

module Pandorga
  module Jekyll
    # One static page per published article, post, project, and product.
    # The listing layout stays, so the client still opens the entry from
    # the URL. `listing_path` stays the listing URL. The permalink is the
    # detail URL, which is what the sitemap and the static canonical use.
    class DetailDocumentsGenerator < ::Jekyll::Generator
      safe true
      priority :low

      COLLECTION_FOR_TYPE = {
        "article" => "articles",
        "post" => "posts",
        "project" => "projects",
        "product" => "products"
      }.freeze

      DETAIL_PATTERN = {
        "article" => "/articles/:slug/",
        "post" => "/posts/:slug/",
        "project" => "/projects/:slug/",
        "product" => "/products/:slug/"
      }.freeze

      SCHEMA = {
        "article" => "Article",
        "post" => "BlogPosting"
      }.freeze

      def generate(site)
        return if site.config["shell_content_agnostic"]

        root = Pathname.new(site.source)
        COLLECTION_FOR_TYPE.each do |type, collection|
          listing = listing_page(site, type)
          next unless listing
          next if listing.data["listing_path"].to_s.empty?

          directory = root.join(ContentKeys::CONTENT_PATHS.fetch(type))
          next unless directory.directory?

          Dir.glob(directory.join("*.{md,markdown}")).sort.each do |absolute|
            emit(site, listing, type, collection, absolute, root)
          end
        end
      end

      private

      def emit(site, listing, type, collection, absolute, root)
        relative = Pathname.new(absolute).relative_path_from(root.join("content"))
        repo_relative = Pathname.new("content").join(relative).to_s
        record = WritingEntry.build(absolute, collection, repo_relative)
        return if record.nil?

        detail_path = record["url"].to_s
        return if detail_path.empty?
        return if taken?(site, detail_path)

        front_matter, = ContentKeys.split_front_matter(File.read(absolute))
        dir = detail_path.sub(%r{\A/}, "").sub(%r{/\z}, "")
        page = ::Jekyll::PageWithoutAFile.new(site, site.source, dir, "index.html")
        page.data["layout"] = listing.data["layout"]
        page.data["permalink"] = detail_path
        page.data["canonical_url"] = detail_path
        page.data["listing_path"] = listing.data["listing_path"]
        page.data["collection"] = collection
        page.data["detail"] = listing.data["detail"].to_s
        page.data["detail"] = DETAIL_PATTERN.fetch(type) if page.data["detail"].empty?
        page.data["detail_document"] = true
        page.data["accent"] = listing.data["accent"] if listing.data["accent"]
        title = record["title"].to_s.strip
        title = record["key"].to_s if title.empty?
        page.data["title"] = title unless title.empty?
        description = record["description"].to_s.strip
        description = record["excerpt"].to_s.strip if description.empty?
        page.data["description"] = description unless description.empty?
        page.data["date"] = record["date"] unless record["date"].to_s.empty?
        page.data["last_updated"] = record["last_updated"] unless record["last_updated"].to_s.empty?
        thumbnail = record["thumbnail"].to_s.strip
        page.data["thumbnail"] = thumbnail unless thumbnail.empty?
        lang = front_matter["language"] || front_matter["lang"] || listing.data["lang"]
        page.data["lang"] = lang if lang
        if SCHEMA.key?(type)
          page.data["og_type"] = "article"
          page.data["schema_type"] = SCHEMA.fetch(type)
        end
        page.content = ""
        site.pages << page
      end

      def taken?(site, detail_path)
        site.pages.any? do |page|
          page.data["permalink"].to_s == detail_path || page.url.to_s == detail_path
        end
      end

      def listing_page(site, type)
        entry = registry_entry(site, type)
        return nil unless entry

        site.pages.find do |page|
          page.data["detail_document"] != true && page.data["key"].to_s == entry["key"].to_s
        end
      end

      def registry_entry(site, type)
        pages = site.data["pandorga_pages"]
        return nil unless pages.is_a?(Array)

        pages.find { |entry| entry.is_a?(Hash) && registry_match?(entry, type) }
      end

      def registry_match?(entry, type)
        case type
        when "article"
          entry["template"].to_s == "articles" || entry["collection"].to_s == "articles"
        when "post"
          entry["template"].to_s == "blog" || entry["collection"].to_s == "posts"
        when "project"
          entry["template"].to_s == "portfolio" || entry["collection"].to_s == "projects"
        when "product"
          cols = entry["collections"]
          entry["template"].to_s == "cv" ||
            (cols.is_a?(Hash) && !cols["products"].to_s.empty?)
        else
          false
        end
      end
    end
  end
end

Jekyll::Hooks.register :site, :post_write do |site|
  # Jekyll skips underscore files, so a source `_redirects` never reaches
  # the output unless the site lists it under `include`. The published
  # file has to be the one Cloudflare reads.
  dest = File.join(site.dest, "_redirects")
  source = File.join(site.source, "_redirects")
  File.write(dest, File.read(source)) if !File.file?(dest) && File.file?(source)
  next unless File.file?(dest)

  original = File.read(dest)
  stripped = Pandorga::DetailRoutes.strip_splat_rewrites(original)
  File.write(dest, stripped) if stripped != original
end
