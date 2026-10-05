# frozen_string_literal: true

require "pathname"
require "rbconfig"
require_relative "../object_store_env"

module Pandorga
  module Commands
    # Publish content JSON to an S3-compatible object store (R2, MinIO, AWS S3, …).
    class Publish
      def run(argv)
        root = Pathname.new(argv[0] || Dir.pwd).expand_path
        site_script = root.join("scripts", "content", "publish-content-to-r2.sh")
        if site_script.file? && site_script.expand_path != gem_publish_script
          Dir.chdir(root) do
            exec("bash", site_script.to_s, *argv[1..])
          end
        end

        begin
          ObjectStoreEnv.require!(:endpoint, :bucket, :access_key_id, :secret_access_key)
        rescue ArgumentError => e
          warn "error: #{e.message}"
          warn "hint: set S3_* (or legacy R2_*) variables for any S3-compatible bucket"
          return 1
        end

        ObjectStoreEnv.apply_aws_env!

        export_status = Export.new.run(
          [root.join("content").to_s, root.join("_content_json").to_s]
        )
        return export_status if export_status != 0

        script = gem_publish_script
        unless script.file?
          warn "error: publish script missing at #{script}"
          return 1
        end

        env = ENV.to_h.merge("PANDORGA_SITE_ROOT" => root.to_s)
        puts "pandorga publish: syncing #{root.join('_content_json')} → object store"
        system(env, "bash", script.to_s, root.join("_content_json").to_s, chdir: root.to_s) ? 0 : 1
      end

      private

      def gem_publish_script
        Pathname.new(Pandorga.gem_path("scripts/content/publish-content-to-object-store.sh"))
      end
    end
  end
end
