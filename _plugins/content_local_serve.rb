# frozen_string_literal: true

require "fileutils"
require "pathname"
require "json"
require "rbconfig"
require "jekyll"

# When local_content_serve is enabled (_config_dev.yml), copies the content
# pipeline export and editorial media into the Jekyll output so the browser
# runtime reads the same JSON layout as Cloudflare R2.
module Jekyll
  module ContentLocalServe
    EXPORT_MUTEX = Mutex.new

    class << self
      attr_accessor :serve_options, :site_config

      def enabled?(site)
        site.config["local_content_serve"] == true
      end

      def export_root(site)
        File.join(site.source, site.config["local_content_export_dir"] || "_content_json")
      end

      def content_root(site)
        File.join(site.source, site.config["content_root"] || "content")
      end

      # Cold start only. The export stamps `generated_at` into manifest.json, and
      # it writes into a directory Jekyll watches, so exporting on every build
      # makes `jekyll serve --watch` regenerate itself forever. dev-serve.sh owns
      # the re-export when content changes; this covers the case where somebody
      # runs Jekyll against the dev config with no export on disk at all.
      def export_content!(site)
        script = File.join(site.source, "scripts", "content", "export-content-json.rb")
        return unless File.file?(script)
        return if File.directory?(export_root(site))

        content_dir = site.config["content_root"] || "content"
        output_dir = site.config["local_content_export_dir"] || "_content_json"
        env = {
          "CONTENT_API_BASE_URL" => site.config["content_api_base_url"].to_s.strip,
          "CONTENT_EXPORT_INCLUDE_UNPUBLISHED" => site.config["content_include_unpublished"] == true ? "1" : "0"
        }

        ruby_bin = RbConfig.ruby
        success = system(env, ruby_bin, script, content_dir, output_dir, chdir: site.source)
        return if success

        Jekyll.logger.error "ContentLocalServe:", "export-content-json.rb failed"
        raise "Content export failed; run ruby scripts/content/export-content-json.rb content _content_json"
      end

      def copy_tree(source, destination)
        return unless File.directory?(source)

        Pathname.glob(File.join(source, "**", "*"), File::FNM_DOTMATCH).each do |path|
          next if path.directory?

          relative = path.relative_path_from(Pathname.new(source)).to_s
          target = File.join(destination, relative)
          FileUtils.mkdir_p(File.dirname(target))
          FileUtils.cp(path.to_s, target)
        end
      end

      def publish!(site)
        export_root = export_root(site)
        export_content!(site)

        copy_tree(export_root, site.dest)
        copy_tree(File.join(content_root(site), "media"), File.join(site.dest, "media"))
      end

      def store_serve_options(options)
        @serve_options = Jekyll.configuration(options)
      rescue StandardError
        @serve_options = options
      end

      def reexport!(options = nil)
        opts = options || serve_options || site_config || {}
        source = opts["source"] || Dir.pwd
        destination = opts["destination"] || File.join(source, "_site")
        content_dir = opts["content_root"] || "content"
        output_dir = opts["local_content_export_dir"] || "_content_json"
        script = File.join(source, "scripts", "content", "export-content-json.rb")

        return [false, "Missing export script at #{script}"] unless File.file?(script)

        env = {
          "CONTENT_API_BASE_URL" => opts.fetch("content_api_base_url", "").to_s.strip,
          "CONTENT_EXPORT_INCLUDE_UNPUBLISHED" => (opts["content_include_unpublished"] != false) ? "1" : "0"
        }

        ruby_bin = RbConfig.ruby
        Jekyll.logger.info "ContentLocalServe:", "Re-exporting content JSON..."
        success = system(env, ruby_bin, script, content_dir, output_dir, chdir: source)
        return [false, "export-content-json.rb execution failed"] unless success

        export_path = File.join(source, output_dir)
        copy_tree(export_path, destination)
        copy_tree(File.join(source, content_dir, "media"), File.join(destination, "media"))

        shell_trigger = File.join(source, "pages", "articles", "index.html")
        FileUtils.touch(shell_trigger) if File.file?(shell_trigger)

        Jekyll.logger.info "ContentLocalServe:", "Re-export complete and mirrored to #{destination}"
        [true, "Content JSON re-exported successfully"]
      rescue StandardError => e
        Jekyll.logger.error "ContentLocalServe:", "Re-export error: #{e.message}"
        [false, "Re-export error: #{e.message}"]
      end

      def handle_reexport_request(_req, res)
        res["Content-Type"] = "application/json; charset=utf-8"
        res["Cache-Control"] = "no-store, no-cache, must-revalidate"

        opts = serve_options || site_config || {}
        unless opts["content_include_unpublished"] || opts["unpublished"] || opts["local_content_serve"]
          res.status = 403
          res.body = JSON.generate({ "ok" => false, "error" => "Dev re-export is disabled in production mode" })
          return
        end

        EXPORT_MUTEX.synchronize do
          success, message = reexport!(opts)
          if success
            res.status = 200
            res.body = JSON.generate({ "ok" => true, "message" => message })
          else
            res.status = 500
            res.body = JSON.generate({ "ok" => false, "error" => message })
          end
        end
      end
    end

    Jekyll::Hooks.register :site, :after_init do |site|
      ContentLocalServe.site_config = site.config
    end

    Jekyll::Hooks.register :site, :post_write do |site|
      next unless ContentLocalServe.enabled?(site)

      ContentLocalServe.publish!(site)
      Jekyll.logger.info "ContentLocalServe:", "Published local content JSON and media to #{site.dest}"
    end
  end
end
