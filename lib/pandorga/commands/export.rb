# frozen_string_literal: true

require "pathname"
require "rbconfig"

module Pandorga
  module Commands
    # Delegate to the full content export pipeline shipped with the gem.
    class Export
      def run(argv)
        site_root = Pathname.new(Dir.pwd).expand_path
        script = Pathname.new(Pandorga.gem_path("scripts/content/export-content-json.rb"))
        unless script.file?
          warn "error: export script missing at #{script}"
          return 1
        end

        content = argv[0] || "content"
        dest = argv[1] || "_content_json"
        env = ENV.to_h.merge(
          "PANDORGA_SITE_ROOT" => site_root.to_s,
          "RUBYOPT" => ["-I#{Pandorga.gem_path('lib')}", ENV["RUBYOPT"]].compact.join(" ")
        )
        cmd = [RbConfig.ruby, script.to_s, content, dest]
        puts "pandorga export: #{content} → #{dest} (site #{site_root})"
        system(env, *cmd, chdir: site_root.to_s) ? 0 : 1
      end
    end
  end
end
