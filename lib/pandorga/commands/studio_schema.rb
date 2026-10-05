# frozen_string_literal: true

require "pathname"
require "yaml"
require "fileutils"

module Pandorga
  module Commands
    # Compose studio/schema.yml from template studio.yml files + registry.
    class StudioSchema
      def run(argv)
        root = Pathname.new(argv[0] || Dir.pwd).expand_path
        templates_root = Pathname.new(Pandorga.gem_path("templates"))
        config_path = root.join("_config.yml")
        unless config_path.file?
          warn "error: no _config.yml in #{root}"
          return 1
        end

        config = YAML.safe_load(config_path.read, permitted_classes: [Date]) || {}
        pages = config.dig("pandorga", "pages") || []
        collections = {}

        pages.each do |page|
          next unless page.is_a?(Hash)

          template = page["template"].to_s
          studio_yml = templates_root.join(template, "studio.yml")
          next unless studio_yml.file?

          fragment = YAML.safe_load(studio_yml.read) || {}
          collection = page["collection"] || page.dig("collections")&.values&.first
          next unless collection

          collections[collection.to_s] = fragment.fetch("collection", fragment)
        end

        overrides = root.join("studio.overrides.yml")
        if overrides.file?
          extra = YAML.safe_load(overrides.read) || {}
          collections.merge!(extra["collections"] || {}) if extra.is_a?(Hash)
        end

        schema = {
          "version" => 1,
          "generated_by" => "pandorga studio-schema #{Pandorga::VERSION}",
          "collections" => collections
        }

        out = root.join("studio", "schema.yml")
        FileUtils.mkdir_p(out.dirname)
        out.write(YAML.dump(schema))
        puts "pandorga studio-schema: wrote #{out}"
        0
      end
    end
  end
end
