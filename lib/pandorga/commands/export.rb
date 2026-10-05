# frozen_string_literal: true

require "pathname"
require "fileutils"
require "json"
require "yaml"
require "time"
require "date"

module Pandorga
  module Commands
    # Export content collections to JSON (static / R2 pipeline).
    # Registry-driven: reads pandorga.pages from _config.yml when present;
    # otherwise falls back to scanning content/collections/*.
    class Export
      SCHEMA_VERSION = 1

      def run(argv)
        src = Pathname.new(argv[0] || "content").expand_path
        dest = Pathname.new(argv[1] || "_content_json").expand_path
        site_root = detect_site_root(src)

        unless src.directory?
          warn "error: content source not found: #{src}"
          return 1
        end

        FileUtils.mkdir_p(dest)
        collections = collections_from_registry(site_root)
        collections = discover_collections(src) if collections.empty?

        exported = []
        collections.each do |name|
          dir = src.join("collections", name)
          next unless dir.directory?

          out_dir = dest.join("collections", name)
          FileUtils.mkdir_p(out_dir)
          Dir.glob(dir.join("*.md")).sort.each do |path|
            item = export_entry(Pathname.new(path), name)
            next unless item

            out = out_dir.join("#{item['slug']}.json")
            out.write(JSON.pretty_generate(item) + "\n")
            exported << "#{name}/#{item['slug']}"
          end
        end

        write_manifest(dest, exported, site_root)
        puts "pandorga export: #{exported.size} entries → #{dest}"
        0
      end

      private

      def detect_site_root(src)
        candidate = src.parent
        return candidate if candidate.join("_config.yml").file?

        Pathname.pwd
      end

      def collections_from_registry(site_root)
        config_path = site_root.join("_config.yml")
        return [] unless config_path.file?

        config = YAML.safe_load(config_path.read, permitted_classes: [Date]) || {}
        pages = config.dig("pandorga", "pages")
        return [] unless pages.is_a?(Array)

        names = []
        pages.each do |page|
          next unless page.is_a?(Hash)

          if page["collection"]
            names << page["collection"].to_s
          elsif page["collections"].is_a?(Hash)
            page["collections"].each_value { |v| names << v.to_s }
          end
        end
        names.uniq.reject { |n| n == "data" }
      end

      def discover_collections(src)
        root = src.join("collections")
        return [] unless root.directory?

        root.children.select(&:directory?).map { |p| p.basename.to_s }.sort
      end

      def export_entry(path, collection)
        text = path.read
        return nil unless text.start_with?("---")

        parts = text.split(/^---\s*$/, 3)
        return nil if parts.size < 3

        fm = YAML.safe_load(parts[1], permitted_classes: [Date, Time]) || {}
        body = parts[2].to_s.sub(/\A\n/, "")
        slug = path.basename(".md").to_s
        key = fm["key"] || slug

        # Allowlist: only known public fields leave the repository (PLT-AC-7).
        public_fields = %w[
          title key date tags language thumbnail description author
          summary status withdrawn featured start end role company
          skills links media type url source
        ]
        item = {
          "slug" => slug,
          "key" => key,
          "collection" => collection,
          "body" => body
        }
        public_fields.each do |field|
          item[field] = fm[field] if fm.key?(field)
        end
        # CV jobs: export body_public only when present; never body_extended.
        item["body"] = fm["body_public"] if fm.key?("body_public")
        item
      end

      def write_manifest(dest, exported, site_root)
        identity = {}
        config_path = site_root.join("_config.yml")
        if config_path.file?
          config = YAML.safe_load(config_path.read, permitted_classes: [Date]) || {}
          identity = config.dig("pandorga", "identity") || {}
        end

        manifest = {
          "schema_version" => SCHEMA_VERSION,
          "generated_at" => Time.now.utc.iso8601,
          "identity" => identity.slice("name", "url", "locale"),
          "entries" => exported
        }
        dest.join("manifest.json").write(JSON.pretty_generate(manifest) + "\n")
      end
    end
  end
end
