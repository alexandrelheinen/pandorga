# frozen_string_literal: true

module Pandorga
  # Sitemap and robots text. No Jekyll dependency, so the gate can call it
  # without building a site.
  module Discovery
    module_function

    def origin(config)
      config = {} unless config.is_a?(Hash)
      pandorga = config["pandorga"]
      pandorga = {} unless pandorga.is_a?(Hash)
      identity = pandorga["identity"]
      identity = {} unless identity.is_a?(Hash)
      url = identity["url"].to_s.strip
      url = config["url"].to_s.strip if url.empty?
      url.sub(%r{/\z}, "")
    end

    def absolute(origin, path)
      path = path.to_s
      return path if path.match?(%r{\Ahttps?://}i)

      path = "/#{path}" unless path.start_with?("/")
      path = "/" if path.empty?
      base = origin.to_s.sub(%r{/\z}, "")
      return path if base.empty?

      "#{base}#{path}"
    end

    def public_paths(pages)
      Array(pages).filter_map do |page|
        data = page_data(page)
        next if data["sitemap"] == false

        url = page.respond_to?(:url) ? page.url.to_s : page["url"].to_s
        next if url.empty?
        next if File.extname(url).match?(/\A\.(xml|txt|json)\z/i)

        url
      end.uniq
    end

    def sitemap_xml(origin, paths)
      locs = Array(paths).map { |path| absolute(origin, path) }.uniq
      body = locs.map { |loc| "  <url><loc>#{xml_escape(loc)}</loc></url>" }.join("\n")
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        #{body}
        </urlset>
      XML
    end

    def robots_txt(sitemap_url)
      <<~TXT
        User-agent: *
        Allow: /
        Disallow: /studio/

        Sitemap: #{sitemap_url}
      TXT
    end

    def xml_escape(value)
      value.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
    end

    def page_data(page)
      return page.data if page.respond_to?(:data) && page.data.is_a?(Hash)

      data = page["data"]
      data.is_a?(Hash) ? data : {}
    end
    private_class_method :page_data
  end
end
