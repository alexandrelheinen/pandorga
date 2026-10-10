# frozen_string_literal: true

# Loads editorial files from /content into site.data without making /content part
# of the Jekyll render graph. The site must be able to build even when the
# content directory is absent; external storage becomes the publishing path.
#
# Example: content/pages/blog/sidebar-intro.md becomes
#   site.data["content_fragments"]["blog/sidebar-intro"]
# Example: content/collections/data/education.yml becomes
#   site.data["education"]

require "yaml"
require "pathname"
require "date"

module Jekyll
  class ContentLayerGenerator < Generator
    safe true
    priority :highest

    def generate(site)
      return if site.config["shell_content_agnostic"]

      content_path = File.join(site.source, site.config["content_root"] || "content")
      site.data["content_fragments"] ||= {}

      load_page_content(site, content_path)
      load_page_headers(site, content_path)
      load_structured_data(site, content_path)
    end

    private

    def load_page_content(site, content_path)
      pages_path = File.join(content_path, "pages")
      return unless Dir.exist?(pages_path)

      Dir.glob(File.join(pages_path, "**", "*.md")).sort.each do |file|
        key = relative_key(file, pages_path)
        site.data["content_fragments"][key] = File.read(file)
      end
    end

    # content/pages/headers.yml is also exported as pages/headers.json.
    # The home bands read it here so a section title and note are in the
    # HTML. A heading painted later by the runtime becomes the LCP element.
    def load_page_headers(site, content_path)
      path = File.join(content_path, "pages", "headers.yml")
      return unless File.file?(path)

      loaded = load_yaml(path)
      site.data["page_headers"] = loaded.is_a?(Hash) ? loaded : {}
    end

    def load_structured_data(site, content_path)
      data_path = File.join(content_path, "collections", "data")
      return unless Dir.exist?(data_path)

      Dir.glob(File.join(data_path, "**", "*.{yml,yaml}")).sort.each do |file|
        parts = relative_key(file, data_path).split("/")
        write_nested_data(site.data, parts, load_yaml(file))
      end
    end

    def write_nested_data(target, parts, value)
      key = parts.first
      if parts.length == 1
        target[key] = value
        return
      end

      target[key] ||= {}
      write_nested_data(target[key], parts.drop(1), value)
    end

    def relative_key(file, base)
      pathname = Pathname.new(file).relative_path_from(Pathname.new(base)).to_s
      pathname.sub(/\.(md|ya?ml)\z/, "")
    end

    def load_yaml(file)
      YAML.safe_load_file(file, permitted_classes: [Date, Time], aliases: true) || {}
    end
  end
end
