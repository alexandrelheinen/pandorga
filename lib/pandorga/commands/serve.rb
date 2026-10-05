# frozen_string_literal: true

require "pathname"

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
          env = {
            "CONTENT_API_BASE_URL" => "",
            "JEKYLL_ENV" => "development"
          }
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
