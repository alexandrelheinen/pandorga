# frozen_string_literal: true

require "pathname"
require "rbconfig"

module Pandorga
  module Commands
    # Local development: export JSON, then jekyll serve with unpublished content.
    class Serve
      def run(argv)
        root = Pathname.new(argv[0] || Dir.pwd).expand_path
        Dir.chdir(root) do
          export_status = Export.new.run(%w[content _content_json])
          return export_status if export_status != 0

          config = %w[_config.yml]
          config << "_config_dev.yml" if root.join("_config_dev.yml").file?
          env = ENV.to_h.merge(
            "CONTENT_API_BASE_URL" => "",
            "JEKYLL_ENV" => "development",
            "PANDORGA_SITE_ROOT" => root.to_s
          )
          cmd = [
            "bundle", "exec", "jekyll", "serve",
            "--unpublished",
            "--config", config.join(",")
          ]
          puts "pandorga serve: #{cmd.join(' ')}"
          exec(env, *cmd)
        end
      end
    end
  end
end
