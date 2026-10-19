# frozen_string_literal: true

require "date"
require "fileutils"
require "pathname"
require "yaml"
require "pandorga/commands/studio_schema"

module Pandorga
  module Commands
    # Option A (PLT-0.2): copy functions/ and studio/ from the gem into the site root
    # so Cloudflare Pages can compile Functions from the project root, then apply
    # site taxonomies and overrides to studio/schema.yml (PLT-AC-43).
    class InstallFunctions
      STAMP = ".pandorga-version"

      def run(argv)
        dest_root = Pathname.new(argv[0] || Dir.pwd).expand_path
        gem_functions = Pathname.new(Pandorga.gem_path("functions"))
        gem_studio = Pathname.new(Pandorga.gem_path("studio"))

        unless gem_functions.directory?
          warn "error: gem has no functions/ directory at #{gem_functions}"
          return 1
        end

        copy_tree(gem_functions, dest_root.join("functions"))
        copy_tree(gem_studio, dest_root.join("studio")) if gem_studio.directory?
        hydrate_studio_schema(dest_root)

        stamp = dest_root.join("functions", STAMP)
        stamp.write("#{Pandorga::VERSION}\n")
        puts "pandorga install-functions: copied to #{dest_root} (v#{Pandorga::VERSION})"
        0
      end

      private

      def copy_tree(src, dest)
        FileUtils.rm_rf(dest) if dest.exist?
        FileUtils.mkdir_p(dest.dirname)
        FileUtils.cp_r(src, dest)
      end

      def hydrate_studio_schema(dest_root)
        config_path = dest_root.join("_config.yml")
        schema_path = dest_root.join("studio", "schema.yml")
        return unless config_path.file? && schema_path.file?

        config = load_yaml(config_path)
        schema = load_yaml(schema_path)
        return unless schema.is_a?(Hash)

        missing = StudioSchema.apply_taxonomies!(schema, config)

        overrides_path = dest_root.join("studio.overrides.yml")
        if overrides_path.file?
          extra = load_yaml(overrides_path)
          StudioSchema.apply_overrides!(schema, extra) if extra.is_a?(Hash)
        end

        header = "# Installed by pandorga install-functions #{Pandorga::VERSION}; " \
                 "tag vocabularies come from _config.yml pandorga.taxonomies.\n"
        schema_path.write("#{header}#{YAML.dump(schema)}")

        missing.each do |name|
          warn "pandorga install-functions: warning: no taxonomy for #{name}; its Studio tags picker is empty"
        end
      end

      def load_yaml(path)
        YAML.safe_load(path.read, permitted_classes: [Date, Time], aliases: true) || {}
      end
    end
  end
end
