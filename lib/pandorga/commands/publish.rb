# frozen_string_literal: true

require "pathname"

module Pandorga
  module Commands
    # Publish content JSON to R2. Delegates to a site script when present;
    # otherwise requires R2_* environment variables and aws-compatible sync.
    class Publish
      def run(argv)
        root = Pathname.new(argv[0] || Dir.pwd).expand_path
        site_script = root.join("scripts", "content", "publish-content-to-r2.sh")
        if site_script.file?
          Dir.chdir(root) do
            exec("bash", site_script.to_s, *argv[1..])
          end
        end

        %w[R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET].each do |key|
          next unless ENV[key].to_s.empty?

          warn "error: #{key} is required (or provide scripts/content/publish-content-to-r2.sh)"
          return 1
        end

        export_status = Export.new.run([root.join("content").to_s, root.join("_content_json").to_s])
        return export_status if export_status != 0

        warn "error: generic R2 sync is not wired yet; use the site publish script"
        1
      end
    end
  end
end
